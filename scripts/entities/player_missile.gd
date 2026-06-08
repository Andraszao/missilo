extends Node3D
# PlayerMissile: Defensive projectile fired by player silos
#
# Flies in a straight line to target position, then detonates.
# Creates an explosion that destroys incoming missiles.

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var speed: float = 15.0

# ============================================================================
# STATE
# ============================================================================

var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var has_detonated: bool = false
var travel_progress: float = 0.0
var explosion_radius: float = 6.0

# Cached distance avoids recomputing sqrt every frame
var _total_distance: float = 0.0

# ============================================================================
# NODES
# ============================================================================

@onready var mesh: MeshInstance3D = $Mesh
@onready var trail: Line2D = $Trail

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("player_missile")

func initialize(start: Vector3, target: Vector3, stats: Dictionary = {}) -> void:
	start_position = start
	target_position = target
	global_position = start
	has_detonated = false
	travel_progress = 0.0

	speed = stats.get("speed", 15.0)
	explosion_radius = stats.get("explosion_radius", 6.0)

	var direction: Vector3 = (target_position - start_position).normalized()
	if direction.length() > 0.01:
		var angle: float = atan2(direction.x, direction.y)
		rotation.z = -angle

	# Cache distance; guard against zero to prevent division by zero
	_total_distance = start_position.distance_to(target_position)
	if _total_distance < 0.01:
		_total_distance = 0.01

# ============================================================================
# FRAME UPDATE
# ============================================================================

func _process(delta: float) -> void:
	if has_detonated:
		return

	travel_progress += (speed * delta) / _total_distance

	if travel_progress >= 1.0:
		detonate()
	else:
		global_position = start_position.lerp(target_position, travel_progress)

# ============================================================================
# DETONATION
# ============================================================================

func detonate() -> void:
	if has_detonated:
		return

	has_detonated = true
	EventBus.player_missile_detonated.emit(target_position, explosion_radius)

	var projectile_manager: Node = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		projectile_manager.spawn_explosion(target_position, explosion_radius)
		projectile_manager.return_to_pool(self)
	else:
		queue_free()
