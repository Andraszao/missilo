extends CharacterBody3D
# IncomingMissile: Enemy projectile threatening cities and silos
#
# Flies from top of screen toward ground targets.
# Can be destroyed by player explosions.
# Awards points when destroyed, damages cities/silos on impact.
#
# Uses CharacterBody3D for physics movement.

# ============================================================================
# STATE
# ============================================================================

var missile_data: MissileData = null
var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var move_velocity: Vector3 = Vector3.ZERO
var speed: float = 3.0
var is_active: bool = false
var hit_by_generation: int = 0  # Track what generation of explosion hit this missile

# ============================================================================
# NODES
# ============================================================================

@onready var mesh: MeshInstance3D = $Mesh
@onready var trail: Line2D = $Trail  # Simple trail effect
@onready var hitbox: Area3D = $Hitbox

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("incoming_missile")

	# CRITICAL: Add hitbox to group too since that's what explosions detect
	if hitbox:
		hitbox.add_to_group("incoming_missile")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func initialize(data: MissileData, start: Vector3, target: Vector3, speed_mult: float = 1.0) -> void:
	"""
	Setup missile for a new flight from start to target.
	Called by ProjectileManager when spawning from pool.
	"""
	missile_data = data
	start_position = start
	target_position = target
	global_position = start
	is_active = true

	# Calculate speed with multiplier
	speed = data.speed * speed_mult

	# Calculate velocity vector
	var direction = (target_position - start_position).normalized()
	move_velocity = direction * speed

	# Point mesh toward target (downward)
	# Calculate angle and rotate to point down at target
	if direction.length() > 0.01:
		var angle = atan2(direction.x, direction.y)
		rotation.z = -angle

	# Ensure hitbox is active (deferred to avoid physics query conflicts)
	if hitbox:
		call_deferred("_enable_hitbox")

	# Apply mesh color from data
	var material = mesh.get_surface_override_material(0)
	if material:
		material.albedo_color = data.mesh_color

func _physics_process(delta: float) -> void:
	"""
	Move toward target and check for arrival
	"""
	if not is_active:
		return

	# Move missile
	velocity = move_velocity
	move_and_slide()

	# Check if reached target
	if global_position.distance_to(target_position) < 0.5:  # Close enough
		impact()

func impact() -> void:
	"""
	Reached target without being destroyed - damage target
	"""
	if not is_active:
		return

	is_active = false

	# Signal impact (cities/silos listen for this)
	EventBus.incoming_missile_impacted.emit(global_position)

	# Return to pool (main game) or queue free (sandbox)
	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		projectile_manager.return_to_pool(self)
	else:
		queue_free()

func set_hit_by_generation(generation: int) -> void:
	"""Track what generation of explosion hit this missile"""
	hit_by_generation = generation

func destroy() -> void:
	"""
	Destroyed by player explosion - award points and create chain reaction!
	"""
	if not is_active:
		return

	is_active = false

	# Award points (if in main game)
	if missile_data:
		EventBus.enemy_destroyed.emit(global_position, missile_data.points_value)

	# Cluster missiles spawn child missiles targeting nearby cities on death
	if missile_data != null and missile_data.special_behavior == "cluster":
		_spawn_cluster_children()

	# Spawn chain reaction explosion
	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		# Main game - use pooling
		var death_explosion = projectile_manager.spawn_explosion(global_position)

		if death_explosion:
			# Calculate radius based on what hit us
			var next_generation = hit_by_generation + 1
			var chain_radius: float

			match next_generation:
				1: chain_radius = 2.5  # Hit by player
				2: chain_radius = 1.5  # Hit by first chain
				3: chain_radius = 1.0  # Hit by second chain
				_: chain_radius = 0.8  # Hit by third+ chain

			if death_explosion.has_method("set_explosion_radius"):
				death_explosion.set_explosion_radius(chain_radius)
			if death_explosion.has_method("set_chain_generation"):
				death_explosion.set_chain_generation(next_generation)

		# Return to pool
		projectile_manager.return_to_pool(self)
	else:
		# Sandbox mode - create explosion manually then queue free
		var explosion_scene = load("res://scenes/entities/explosion.tscn")
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.initialize(global_position)
		explosion.set_explosion_radius(2.5)  # Chain reaction size
		explosion.visible = true
		explosion.set_process(true)
		queue_free()

# ============================================================================
# CLUSTER BEHAVIOR
# ============================================================================

func _spawn_cluster_children() -> void:
	"""
	Spawn 2 mini missiles toward the nearest cities when a cluster missile dies.
	Called from destroy() when special_behavior == "cluster".
	"""
	var cities = get_tree().get_nodes_in_group("city")
	if cities.is_empty():
		return

	# Sort cities by distance to this missile's current position
	var origin = global_position
	cities.sort_custom(func(a, b):
		return a.global_position.distance_to(origin) < b.global_position.distance_to(origin)
	)

	var targets = cities.slice(0, min(2, cities.size()))
	var spawner = get_node_or_null("/root/Main/WaveSpawner")
	if spawner == null:
		return

	var child_data = load("res://resources/missiles/basic_enemy.tres")
	for city in targets:
		spawner.spawn_incoming_missile(global_position, city.global_position, child_data)

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _enable_hitbox() -> void:
	"""Enable hitbox monitoring (called deferred)"""
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true

func _on_hitbox_area_entered(area: Area3D) -> void:
	"""
	Detect collision with player explosions.
	Explosions have Area3D hitboxes that grow with their radius.
	"""
	if area.is_in_group("explosion"):
		destroy()
