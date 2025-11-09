extends Node3D
# Simple Missile Testing Sandbox
#
# Clean environment to test missile firing and explosions
# Press numbers to spawn basic missiles, click to fire

# ============================================================================
# SCENE REFERENCES
# ============================================================================

@export var player_missile_scene: PackedScene
@export var incoming_missile_scene: PackedScene
@export var explosion_scene: PackedScene

# ============================================================================
# NODES
# ============================================================================

@onready var test_silo: Node3D = $TestSilo
@onready var test_entities: Node3D = $TestEntities
@onready var camera: Camera3D = $Camera3D

# ============================================================================
# STATE
# ============================================================================

var mouse_world_position: Vector3 = Vector3.ZERO
var gameplay_plane: Plane = Plane(Vector3.BACK, 0.0)
var basic_missile_data: MissileData

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Hide cursor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	# Debug: Check all references
	print("=== SANDBOX STARTUP ===")
	print("Test Silo: ", test_silo)
	print("Camera: ", camera)
	print("Player missile scene: ", player_missile_scene)
	print("Incoming missile scene: ", incoming_missile_scene)
	print("Explosion scene: ", explosion_scene)
	
	# Load basic missile data
	basic_missile_data = load("res://resources/missiles/basic_enemy.tres")
	print("Missile data: ", basic_missile_data)
	
	# Connect explosion signal
	EventBus.player_missile_detonated.connect(_on_missile_detonated)
	
	# TEST: Add ALL THREE modifiers to test silo (test stacking!)
	var speed_modifier = load("res://resources/modifiers/speed_boost.tres")
	var radius_modifier = load("res://resources/modifiers/blast_radius.tres")
	var ammo_modifier = load("res://resources/modifiers/extra_ammo.tres")
	if test_silo:
		if speed_modifier:
			test_silo.add_modifier(speed_modifier)
			print("✓ Applied Speed Boost modifier!")
		if radius_modifier:
			test_silo.add_modifier(radius_modifier)
			print("✓ Applied Blast Radius modifier!")
		if ammo_modifier:
			test_silo.add_modifier(ammo_modifier)
			print("✓ Applied Extra Ammo modifier!")
	
	print("=== MISSILE SANDBOX ===")
	print("Click - Fire silo (+50% speed, +30% blast, +3 ammo!)")
	print("1 - Spawn incoming missile")
	print("C - Clear all")
	print("R - Reload ammo")
	print("======================")

func _process(_delta: float) -> void:
	"""Update mouse position"""
	update_mouse_world_position()

func _input(event: InputEvent) -> void:
	"""Handle controls - use _input to catch before UI"""
	# Fire silo on mouse click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("CLICK DETECTED - Firing!")
			fire_test_silo()
			get_viewport().set_input_as_handled()
			return
	
	# Spawn missiles
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				print("KEY 1 - Spawning missile")
				spawn_missile()
			KEY_C:
				print("KEY C - Clearing")
				clear_all()
			KEY_R:
				print("KEY R - Reloading")
				test_silo.reload()
				print("Reloaded! Ammo: %d/%d" % [test_silo.current_ammo, test_silo.max_ammo])

# ============================================================================
# SILO FIRING
# ============================================================================

func fire_test_silo() -> void:
	"""Fire a missile from the silo (with modifiers applied!)"""
	if not test_silo:
		print("ERROR: No test silo found!")
		return
	
	# Check ammo
	if test_silo.current_ammo <= 0:
		print("OUT OF AMMO! (Press R to reload)")
		return
	
	# Get stats from silo (includes modifiers)
	var stats = test_silo.calculate_stats()
	
	var start_pos = test_silo.global_position + Vector3(0, 1.2, 0)
	var missile = player_missile_scene.instantiate()
	test_entities.add_child(missile)
	missile.initialize(start_pos, mouse_world_position, stats)
	missile.visible = true
	missile.set_process(true)
	
	# Decrement ammo
	test_silo.current_ammo -= 1
	
	print("FIRED at: (%.1f, %.1f) | Speed: %.1f | Radius: %.1f | Ammo: %d/%d" % [
		mouse_world_position.x, 
		mouse_world_position.y, 
		stats.speed, 
		stats.explosion_radius,
		test_silo.current_ammo,
		test_silo.max_ammo
	])

func _on_missile_detonated(position: Vector3, radius: float = 6.0) -> void:
	"""Spawn explosion when missile detonates"""
	var explosion = explosion_scene.instantiate()
	test_entities.add_child(explosion)
	explosion.initialize(position)
	explosion.set_explosion_radius(radius)
	explosion.visible = true
	explosion.set_process(true)

# ============================================================================
# MISSILE SPAWNING
# ============================================================================

func spawn_missile() -> void:
	"""Spawn a basic incoming missile"""
	var random_x = randf_range(-30.0, 30.0)
	var start_pos = Vector3(random_x, 42.0, 0)
	var target_x = randf_range(-20.0, 20.0)
	var target_pos = Vector3(target_x, 0, 0)
	
	var missile = incoming_missile_scene.instantiate()
	test_entities.add_child(missile)
	missile.initialize(basic_missile_data, start_pos, target_pos, 1.0)
	missile.visible = true
	missile.set_physics_process(true)
	
	print("Spawned missile at X=%.1f" % random_x)

func clear_all() -> void:
	"""Clear all missiles"""
	for child in test_entities.get_children():
		child.queue_free()
	print("Cleared!")

# ============================================================================
# MOUSE TRACKING
# ============================================================================

func update_mouse_world_position() -> void:
	"""Track mouse in 3D space"""
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var intersection = gameplay_plane.intersects_ray(ray_origin, ray_direction)
	
	if intersection != null:
		mouse_world_position = intersection
		mouse_world_position.x = clamp(mouse_world_position.x, -40.0, 40.0)
		mouse_world_position.y = clamp(mouse_world_position.y, 0.0, 45.0)
