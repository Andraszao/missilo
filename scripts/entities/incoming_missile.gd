extends CharacterBody3D
# IncomingMissile: Enemy projectile threatening cities and silos
#
# Flies from top of screen toward ground targets.
# Can be destroyed by player explosions.
# Awards points when destroyed; damages cities/silos on impact.

# ============================================================================
# STATE
# ============================================================================

var missile_data: MissileData = null
var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var move_velocity: Vector3 = Vector3.ZERO
var speed: float = 3.0
var is_active: bool = false

# Generation of the explosion that hit this missile (drives chain reaction sizing)
var hit_by_generation: int = 0

# Max radius of the explosion that killed us — used to scale chain reactions
# so the blast_radius modifier propagates through chains
var _parent_explosion_radius: float = 6.0

# ============================================================================
# NODES
# ============================================================================

@onready var mesh: MeshInstance3D = $Mesh
@onready var trail: Line2D = $Trail
@onready var hitbox: Area3D = $Hitbox

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("incoming_missile")
	if hitbox:
		hitbox.add_to_group("incoming_missile")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func initialize(data: MissileData, start: Vector3, target: Vector3, speed_mult: float = 1.0) -> void:
	missile_data = data
	start_position = start
	target_position = target
	global_position = start
	is_active = true
	hit_by_generation = 0
	_parent_explosion_radius = 6.0  # Reset to base player explosion radius

	speed = data.speed * speed_mult

	var direction: Vector3 = (target_position - start_position).normalized()
	move_velocity = direction * speed

	if direction.length() > 0.01:
		var angle: float = atan2(direction.x, direction.y)
		rotation.z = -angle

	if hitbox:
		call_deferred("_enable_hitbox")

	var material = mesh.get_surface_override_material(0)
	if material:
		material.albedo_color = data.mesh_color

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	velocity = move_velocity
	move_and_slide()

	if global_position.distance_to(target_position) < 0.5:
		impact()

# ============================================================================
# IMPACT & DESTRUCTION
# ============================================================================

func impact() -> void:
	if not is_active:
		return

	is_active = false
	EventBus.incoming_missile_impacted.emit(global_position)

	var pm: Node = get_node_or_null("/root/Main/ProjectileManager")
	if pm:
		pm.return_to_pool(self)
	else:
		queue_free()

func destroy() -> void:
	if not is_active:
		return

	is_active = false

	if missile_data:
		EventBus.enemy_destroyed.emit(global_position, missile_data.points_value)

	var pm: Node = get_node_or_null("/root/Main/ProjectileManager")
	if pm:
		var chain_explosion: Node = pm.spawn_explosion(global_position)
		if chain_explosion:
			_configure_chain_explosion(chain_explosion)
		pm.return_to_pool(self)
	else:
		_spawn_sandbox_explosion()

func set_hit_by_generation(generation: int) -> void:
	hit_by_generation = generation

# ============================================================================
# CHAIN EXPLOSION CONFIGURATION
# ============================================================================

func _configure_chain_explosion(explosion: Node) -> void:
	var next_gen: int = hit_by_generation + 1

	# Base chain radii, scaled by the parent explosion's blast radius.
	# This ensures the blast_radius upgrade propagates through chain reactions.
	var base_radius: float = _get_base_chain_radius(next_gen)
	var scale: float = _parent_explosion_radius / 6.0  # 6.0 = default player explosion radius
	var chain_radius: float = base_radius * scale

	if explosion.has_method("set_explosion_radius"):
		explosion.set_explosion_radius(chain_radius)
	if explosion.has_method("set_chain_generation"):
		explosion.set_chain_generation(next_gen)

func _get_base_chain_radius(generation: int) -> float:
	match generation:
		1: return 2.5
		2: return 1.5
		3: return 1.0
		_: return 0.8

func _spawn_sandbox_explosion() -> void:
	var explosion_scene = load("res://scenes/entities/explosion.tscn")
	var explosion = explosion_scene.instantiate()
	get_parent().add_child(explosion)
	explosion.initialize(global_position)
	explosion.set_explosion_radius(2.5)
	explosion.visible = true
	explosion.set_process(true)
	queue_free()

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _enable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("explosion"):
		# Inherit the parent explosion's radius so chain reactions scale with upgrades
		var explosion_node = area.get_parent()
		if explosion_node and "max_radius" in explosion_node:
			_parent_explosion_radius = explosion_node.max_radius
		destroy()
