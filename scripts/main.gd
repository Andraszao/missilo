extends Node3D
# Main: Root game scene controller
#
# Handles initialization and game start.
# Most game logic is in GameManager and other systems.

func _ready() -> void:
	# Hide mouse cursor (we have a reticle)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
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

func _input(event: InputEvent) -> void:
	"""Handle restart input"""
	if event.is_action_pressed("restart"):
		restart_game()

func restart_game() -> void:
	"""Reload the entire scene to restart"""
	print("=== RESTARTING GAME ===")
	get_tree().reload_current_scene()
