extends Node3D
# PlayerMissile: Defensive projectile fired by player silos
#
# Flies in straight line to target position, then detonates.
# Creates explosion that destroys incoming missiles.
#
# Behavior:
# - Linear interpolation from start to target
# - On arrival, spawn explosion and return to pool
# - Simple trail effect for visual feedback

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var speed: float = 15.0  # Units per second

# ============================================================================
# STATE
# ============================================================================

var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var current_position: Vector3 = Vector3.ZERO
var has_detonated: bool = false
var travel_progress: float = 0.0  # 0.0 to 1.0
var explosion_radius: float = 6.0  # Modified by stats

# ============================================================================
# NODES
# ============================================================================

@onready var mesh: MeshInstance3D = $Mesh
@onready var trail: Line2D = $Trail  # Simple trail (optional for MVP)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("player_missile")

func initialize(start: Vector3, target: Vector3, stats: Dictionary = {}) -> void:
	"""
	Setup missile for a new flight from start to target.
	Called by ProjectileManager when spawning from pool.
	Stats dictionary can contain:
	- speed: missile speed multiplier
	- explosion_radius: explosion size
	- behaviors: array of behavior flags
	"""
	start_position = start
	target_position = target
	current_position = start
	global_position = start
	has_detonated = false
	travel_progress = 0.0
	
	# Apply stats if provided
	if stats.has("speed"):
		speed = stats.speed
	else:
		speed = 15.0  # Default speed
	
	if stats.has("explosion_radius"):
		explosion_radius = stats.explosion_radius
	else:
		explosion_radius = 6.0  # Default radius
	
	# Point mesh toward target
	# Calculate direction and rotate to face target
	var direction = (target_position - start_position).normalized()
	if direction.length() > 0.01:
		# Get angle in Y axis (vertical) and rotate mesh
		var angle = atan2(direction.x, direction.y)
		rotation.z = -angle

func _process(delta: float) -> void:
	"""
	Move toward target and check for arrival
	"""
	if has_detonated:
		return
	
	# Calculate travel distance
	var total_distance = start_position.distance_to(target_position)
	var travel_step = (speed * delta) / total_distance
	
	travel_progress += travel_step
	
	if travel_progress >= 1.0:
		# Arrived at target
		detonate()
	else:
		# Interpolate position
		current_position = start_position.lerp(target_position, travel_progress)
		global_position = current_position

func detonate() -> void:
	"""
	Reached target - spawn explosion and return to pool
	"""
	if has_detonated:
		return
	
	has_detonated = true
	
	# Signal for effects/audio hooks (sandbox listens to this)
	EventBus.player_missile_detonated.emit(target_position, explosion_radius)
	
	# Spawn explosion if ProjectileManager exists (main game)
	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		projectile_manager.spawn_explosion(target_position, explosion_radius)
		projectile_manager.return_to_pool(self)
	else:
		# Sandbox mode - just queue free
		queue_free()
