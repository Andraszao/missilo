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
var _current_health: int = 1
var _is_armored: bool = false

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

	# Initialize health from data
	_current_health = missile_data.health if missile_data else 1
	_is_armored = _current_health > 1

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

	# Apply type-specific visuals (overrides mesh_color for named types)
	_apply_type_visuals()

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

func take_hit() -> void:
	"""
	Receive a hit from an explosion. Armored missiles require multiple hits.
	"""
	_current_health -= 1
	if _current_health <= 0:
		destroy()
	else:
		_flash_armor_hit()

func _flash_armor_hit() -> void:
	"""Brief white flash to show the missile survived a hit."""
	var mat = mesh.get_surface_override_material(0) if mesh else null
	if mat:
		var orig = mat.albedo_color
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		await get_tree().create_timer(0.12).timeout
		if is_inside_tree() and mat:
			mat.albedo_color = orig

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
	elif missile_data != null and missile_data.special_behavior == "decoy":
		_spawn_decoy_children()

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
# VISUALS
# ============================================================================

func _apply_type_visuals() -> void:
	"""Apply color tinting based on missile type (overrides mesh_color for named types)."""
	var mat = mesh.get_surface_override_material(0) if mesh else null
	if mat == null:
		return
	var mtype = missile_data.missile_type if missile_data else "standard"
	match mtype:
		"armored": mat.albedo_color = Color(1.0, 0.35, 0.1)   # orange-red
		"scout":   mat.albedo_color = Color(0.2, 0.9, 1.0)    # cyan
		"mirv":    mat.albedo_color = Color(1.0, 0.9, 0.0)    # gold
		_:         pass  # keep default set by mesh_color above

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
# DECOY BEHAVIOR
# ============================================================================

func _spawn_decoy_children() -> void:
	"""
	Spawn 2 fast child missiles targeting random cities when a decoy dies.
	Called from destroy() when special_behavior == "decoy".
	Children award no points.
	"""
	var pm = get_node_or_null("/root/Main/ProjectileManager")
	if not pm:
		return
	var cities = get_tree().get_nodes_in_group("city")
	if cities.is_empty():
		return
	var live_cities = cities.filter(func(c): return is_instance_valid(c) and c.visible)
	live_cities.shuffle()
	for i in range(min(2, live_cities.size())):
		var child_data = MissileData.new()
		child_data.speed = 5.0
		child_data.points_value = 0
		child_data.mesh_color = Color(1.0, 0.5, 0.1, 1.0)
		child_data.trail_color = Color(1.0, 0.3, 0.0, 1.0)
		child_data.special_behavior = ""
		child_data.health = 1
		pm.spawn_incoming_missile(child_data, global_position, live_cities[i].global_position, 1.0)

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
		take_hit()
