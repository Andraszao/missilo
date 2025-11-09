extends Node3D
# CursorReticle: Visual indicator showing where player will fire
#
# Follows mouse world position from InputManager
# Makes aiming much clearer

@onready var ring: MeshInstance3D = $Ring
# We hop over to the autoloaded InputManager so this reticle always reflects the truth.
@onready var input_manager: Node = get_node("/root/Main/InputManager")

func _process(_delta: float) -> void:
	"""Track mouse world position"""
	if input_manager:
		global_position = input_manager.mouse_world_position
		# Float just above the playfield so the ring stays crisp against the terrain.
		global_position.z = 0.2  # Slightly in front of gameplay plane
