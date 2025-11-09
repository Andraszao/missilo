extends Node
# InputManager: Translates player input into game actions
#
# Responsibilities:
# - Track mouse position in 3D world space (raycast to ground plane)
# - Handle silo selection (A/W/D keys)
# - Handle firing (mouse click)
# - Validate firing (selected silo has ammo and is active)
#
# Design Note:
# This doesn't directly control silos - it emits signals via EventBus.
# Silos listen and react independently. This decoupling makes testing easier.

# ============================================================================
# CONFIGURATION
# ============================================================================

# Which silo is currently selected (0 = left, 1 = center, 2 = right)
var selected_silo_index: int = 1  # Default to center silo

# Current mouse position in 3D world space (on ground plane)
var mouse_world_position: Vector3 = Vector3.ZERO

# ============================================================================
# NODES
# ============================================================================

var camera: Camera3D
var gameplay_plane: Plane = Plane(Vector3.BACK, 0.0)  # Z=0 gameplay plane

# Reference to silos for ammo/active checks
var silos: Array[Node] = []

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Find camera (adjust path based on your scene structure)
	camera = get_viewport().get_camera_3d()
	
	if camera == null:
		push_error("InputManager: No Camera3D found!")
	
	# Find silos (they'll register themselves or we find them)
	# For now, we'll get them on first use

func _process(_delta: float) -> void:
	"""Update mouse world position every frame"""
	if camera != null:
		update_mouse_world_position()

func _input(event: InputEvent) -> void:
	"""Handle all player input"""
	# Only process input during PLAYING state
	if GameManager.game_state != GameManager.GameState.PLAYING:
		return
	
	# Silo selection (A/W/D keys)
	if event.is_action_pressed("select_silo_left"):
		handle_silo_selection(0)
	elif event.is_action_pressed("select_silo_center"):
		handle_silo_selection(1)
	elif event.is_action_pressed("select_silo_right"):
		handle_silo_selection(2)
	
	# Fire missile (mouse click)
	if event.is_action_pressed("fire"):
		handle_fire_input()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func handle_silo_selection(silo_index: int) -> void:
	"""Switch to a different silo"""
	if silo_index == selected_silo_index:
		return  # Already selected
	
	selected_silo_index = silo_index
	EventBus.silo_selected.emit(silo_index)

func handle_fire_input() -> void:
	"""Attempt to fire from selected silo"""
	# Get selected silo reference
	if silos.is_empty():
		cache_silo_references()
	
	if selected_silo_index >= silos.size():
		return
	
	var silo = silos[selected_silo_index]
	
	# Validate silo can fire
	if not silo.is_active:
		return
	
	if silo.current_ammo <= 0:
		return
	
	# Fire!
	EventBus.silo_fired.emit(selected_silo_index, mouse_world_position)

func update_mouse_world_position() -> void:
	"""Raycast from mouse cursor to gameplay plane to get 3D position"""
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Create ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	# Intersect with gameplay plane (Z=0)
	var intersection = gameplay_plane.intersects_ray(ray_origin, ray_direction)
	
	if intersection != null:
		mouse_world_position = intersection
		# Clamp to match full gameplay area (background is 80x50)
		mouse_world_position.x = clamp(mouse_world_position.x, -40.0, 40.0)
		mouse_world_position.y = clamp(mouse_world_position.y, 0.0, 45.0)

func cache_silo_references() -> void:
	"""Find and cache silo nodes for validation"""
	var silos_container = get_node_or_null("/root/Main/Silos")
	if silos_container == null:
		return
	
	silos.clear()
	for child in silos_container.get_children():
		if child.has_method("fire"):  # Duck typing check
			silos.append(child)
	
	silos.sort_custom(func(a, b): return a.silo_index < b.silo_index)

# ============================================================================
# HELPERS
# ============================================================================

func get_selected_silo_index() -> int:
	"""Public API for other systems to check which silo is selected"""
	return selected_silo_index
