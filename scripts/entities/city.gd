extends Node3D
# City: Civilian target that must be defended
#
# Cities are fragile - one hit and they're gone.
# Each surviving city adds bonus points at wave end.
# Lose all cities = game over.
#
# Visual: 2-3 building meshes of varying heights (simple boxes)

# ============================================================================
# CONFIGURATION
# ============================================================================

# Which city this is (0-5 for MVP)
@export var city_index: int = 0

# ============================================================================
# STATE
# ============================================================================

var is_alive: bool = true

# ============================================================================
# NODES
# ============================================================================

@onready var buildings: Node3D = $Buildings
@onready var hitbox: Area3D = $Hitbox

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Add city hitbox to group so missiles can find it
	if hitbox:
		hitbox.add_to_group("city")
	
	# Connect hitbox for incoming missile detection
	hitbox.area_entered.connect(_on_hitbox_area_entered)

# ============================================================================
# DESTRUCTION
# ============================================================================

func destroy() -> void:
	"""
	City is hit by incoming missile - mark as destroyed
	"""
	if not is_alive:
		return  # Already dead
	
	is_alive = false
	
	# Visual feedback: Collapse animation then hide
	_play_destruction_animation()
	
	print("City %d destroyed!" % city_index)
	EventBus.city_destroyed.emit(city_index)

func _play_destruction_animation() -> void:
	"""Collapse buildings and fade out"""
	# Darken first for immediate feedback
	for building in buildings.get_children():
		if building is MeshInstance3D:
			var material = building.get_surface_override_material(0)
			if material:
				material.albedo_color = Color(0.3, 0.15, 0.1)  # Dark red/brown (burning)
	
	# Animate collapse
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Shrink and sink into ground
	tween.tween_property(buildings, "scale", Vector3(0.5, 0.1, 0.5), 0.5)
	tween.tween_property(buildings, "position:y", -1.0, 0.5)
	
	# After animation, hide completely
	tween.finished.connect(func(): buildings.visible = false)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_hitbox_area_entered(area: Area3D) -> void:
	"""
	Detect incoming missile collision.
	Cities are hit by incoming missiles (not explosions).
	"""
	if area.is_in_group("incoming_missile"):
		destroy()
		# Get the missile and trigger its impact
		var missile = area.get_parent()
		if missile and missile.has_method("impact"):
			missile.impact()
