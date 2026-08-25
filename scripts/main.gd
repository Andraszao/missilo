extends Node3D
# Main: Root game scene controller
#
# Handles initialization and game start.
# Most game logic is in GameManager and other systems.

var _camera_origin: Vector3 = Vector3.ZERO
var _shake_intensity: float = 0.0
var _camera_ref: Camera3D

func _ready() -> void:
	# Hide mouse cursor (we have a reticle)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Set up camera shake
	_camera_ref = $Camera3D
	_camera_origin = _camera_ref.position
	EventBus.city_destroyed.connect(func(_i): shake(0.5, 0.4))
	EventBus.silo_destroyed.connect(func(_i): shake(0.4, 0.35))
	EventBus.enemy_destroyed.connect(func(_p, _s): shake(0.08, 0.12))
	EventBus.incoming_missile_impacted.connect(func(_p): shake(0.18, 0.2))

	# Give systems a frame to initialize
	await get_tree().process_frame

	# Start the game!
	print("=== MISSILE COMMAND MVP ===")
	print("Controls:")
	print("  A/W/D - Select silo (left/center/right)")
	print("  Mouse Click - Fire at cursor position")
	print("  R - Restart game")
	print("  Defend 6 cities through 10 waves!")
	print("===========================")

	GameManager.start_game()

func _process(_delta: float) -> void:
	if _shake_intensity > 0.005 and is_instance_valid(_camera_ref):
		_camera_ref.position = _camera_origin + Vector3(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity),
			0.0
		)
	elif is_instance_valid(_camera_ref):
		_camera_ref.position = _camera_origin

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	var tween = create_tween()
	tween.tween_property(self, "_shake_intensity", 0.0, duration)

func _input(event: InputEvent) -> void:
	"""Handle restart input"""
	if event.is_action_pressed("restart"):
		restart_game()

func restart_game() -> void:
	"""Reload the entire scene to restart"""
	print("=== RESTARTING GAME ===")
	get_tree().reload_current_scene()
