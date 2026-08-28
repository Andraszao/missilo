extends Node3D
# Main: Root game scene controller

var _camera_origin: Vector3 = Vector3.ZERO
var _shake_intensity: float = 0.0
var _camera_ref: Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_camera_ref = $Camera3D
	_camera_origin = _camera_ref.position
	EventBus.city_destroyed.connect(func(_i): shake(0.5, 0.4))
	EventBus.silo_destroyed.connect(func(_i): shake(0.4, 0.35))
	EventBus.enemy_destroyed.connect(func(_p, _s): shake(0.08, 0.12))
	EventBus.incoming_missile_impacted.connect(func(_p): shake(0.18, 0.2))

	await get_tree().process_frame

	print("=== MISSILE COMMAND MVP ===")
	print("Controls:")
	print("  A/W/D - Select silo (left/center/right)")
	print("  Mouse Click - Fire at cursor position")
	print("  R - Restart game")
	print("  Defend cities through 10 waves!")
	print("===========================")

	# Ensure stale overlay state is cleared on scene reload, then show menu
	GameOverScreen.hide()
	MainMenu.show()

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
	if event.is_action_pressed("restart"):
		restart_game()

func restart_game() -> void:
	print("=== RESTARTING GAME ===")
	get_tree().reload_current_scene()
