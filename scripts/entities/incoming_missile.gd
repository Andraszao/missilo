extends CharacterBody3D
# IncomingMissile: Enemy projectile threatening cities and silos
#
# Flies from top of screen toward ground targets.
# Can be destroyed by player explosions.
# Awards points when destroyed, damages cities/silos on impact.

# ============================================================================
# STATE
# ============================================================================

var missile_data: MissileData = null
var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var move_velocity: Vector3 = Vector3.ZERO
var speed: float = 3.0
var is_active: bool = false
var hit_by_generation: int = 0
var _current_health: int = 1
var _is_armored: bool = false

# MIRV tracking
var _mirv_has_split: bool = false
var _travel_fraction: float = 0.0
var _total_distance: float = 0.0

# ============================================================================
# NODES
# ============================================================================

@onready var mesh: MeshInstance3D = $Mesh
@onready var hitbox: Area3D = $Hitbox
var _trail: GPUParticles3D = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	add_to_group("incoming_missile")
	_setup_trail()

	if hitbox:
		hitbox.add_to_group("incoming_missile")
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _setup_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.amount = 18
	_trail.lifetime = 0.32
	_trail.local_coords = false  # world-space so particles linger behind as missile moves
	_trail.emitting = false
	_trail.one_shot = false
	_trail.explosiveness = 0.0
	_trail.randomness = 0.2
	_trail.fixed_fps = 0

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3.ZERO
	mat.spread = 22.0
	mat.initial_velocity_min = 0.04
	mat.initial_velocity_max = 0.22
	mat.damping_min = 3.0
	mat.damping_max = 6.0
	mat.scale_min = 0.08
	mat.scale_max = 0.18
	mat.gravity = Vector3.ZERO

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	_trail.process_material = mat

	var sphere = SphereMesh.new()
	sphere.radius = 0.065
	sphere.height = 0.13
	_trail.draw_pass_1 = sphere

	add_child(_trail)

func initialize(data: MissileData, start: Vector3, target: Vector3, speed_mult: float = 1.0) -> void:
	missile_data = data
	start_position = start
	target_position = target
	global_position = start
	is_active = true

	_mirv_has_split = false
	_travel_fraction = 0.0

	_current_health = missile_data.health if missile_data else 1
	_is_armored = _current_health > 1

	speed = data.speed * speed_mult

	var direction = (target_position - start_position).normalized()
	move_velocity = direction * speed

	_total_distance = start.distance_to(target)

	if direction.length() > 0.01:
		var angle = atan2(direction.x, direction.y)
		rotation.z = -angle

	if hitbox:
		call_deferred("_enable_hitbox")

	var material = mesh.get_surface_override_material(0)
	if material:
		material.albedo_color = data.mesh_color

	_apply_type_visuals()

	if _trail:
		_trail.emitting = true

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	velocity = move_velocity
	move_and_slide()

	if _total_distance > 0.0:
		_travel_fraction = 1.0 - (global_position.distance_to(target_position) / _total_distance)

	if missile_data and missile_data.missile_type == "mirv" and not _mirv_has_split:
		if _travel_fraction >= 0.4:
			_mirv_has_split = true
			_spawn_mirv_children()
			destroy()
			return

	if global_position.distance_to(target_position) < 0.5:
		impact()

func impact() -> void:
	if not is_active:
		return
	is_active = false

	if _trail:
		_trail.emitting = false

	EventBus.incoming_missile_impacted.emit(global_position)

	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		projectile_manager.return_to_pool(self)
	else:
		queue_free()

func set_hit_by_generation(generation: int) -> void:
	hit_by_generation = generation

func take_hit() -> void:
	_current_health -= 1
	if _current_health <= 0:
		destroy()
	else:
		_flash_armor_hit()

func _flash_armor_hit() -> void:
	var mat = mesh.get_surface_override_material(0) if mesh else null
	if mat:
		var orig = mat.albedo_color
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		await get_tree().create_timer(0.12).timeout
		if is_inside_tree() and mat:
			mat.albedo_color = orig

func destroy() -> void:
	if not is_active:
		return
	is_active = false

	if _trail:
		_trail.emitting = false

	if missile_data:
		EventBus.enemy_destroyed.emit(global_position, missile_data.points_value)

	if missile_data != null and missile_data.special_behavior == "cluster":
		_spawn_cluster_children()
	elif missile_data != null and missile_data.special_behavior == "decoy":
		_spawn_decoy_children()

	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		var death_explosion = projectile_manager.spawn_explosion(global_position)

		if death_explosion:
			var next_generation = hit_by_generation + 1
			var chain_radius: float
			match next_generation:
				1: chain_radius = 2.5
				2: chain_radius = 1.5
				3: chain_radius = 1.0
				_: chain_radius = 0.8
			if death_explosion.has_method("set_explosion_radius"):
				death_explosion.set_explosion_radius(chain_radius)
			if death_explosion.has_method("set_chain_generation"):
				death_explosion.set_chain_generation(next_generation)

		projectile_manager.return_to_pool(self)
	else:
		var explosion_scene = load("res://scenes/entities/explosion.tscn")
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.initialize(global_position)
		explosion.set_explosion_radius(2.5)
		explosion.visible = true
		explosion.set_process(true)
		queue_free()

# ============================================================================
# VISUALS
# ============================================================================

func _apply_type_visuals() -> void:
	var mat = mesh.get_surface_override_material(0) if mesh else null
	var mtype = missile_data.missile_type if missile_data else "standard"
	match mtype:
		"armored":
			if mat: mat.albedo_color = Color(1.0, 0.35, 0.1)
			if _trail: _trail.modulate = Color(1.0, 0.35, 0.1)  # orange-red trail
		"scout":
			if mat: mat.albedo_color = Color(0.2, 0.9, 1.0)
			mesh.scale = Vector3(0.5, 1.0, 0.5)
			if _trail: _trail.modulate = Color(0.2, 0.9, 1.0)   # cyan trail
		"mirv":
			if mat: mat.albedo_color = Color(1.0, 0.9, 0.0)
			if _trail: _trail.modulate = Color(1.0, 0.9, 0.0)   # gold trail
		_:
			if _trail: _trail.modulate = Color(1.0, 0.45, 0.1)  # default orange-red

# ============================================================================
# MIRV BEHAVIOR
# ============================================================================

func _spawn_mirv_children() -> void:
	EventBus.mirv_split.emit(global_position)

	var cities = get_tree().get_nodes_in_group("city")
	var alive_cities = cities.filter(func(c): return c.is_alive)
	var targets: Array[Vector3] = []

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	if alive_cities.size() >= 3:
		alive_cities.shuffle()
		for i in range(3):
			targets.append(alive_cities[i].global_position)
	else:
		for i in range(3):
			var x = rng.randf_range(-20.0, 20.0)
			targets.append(Vector3(x, 0.0, 0.0))

	var pm = get_node_or_null("/root/Main/ProjectileManager")
	if pm == null:
		return

	for target in targets:
		pm.spawn_incoming_missile(missile_data, global_position, target, 1.2)

# ============================================================================
# CLUSTER BEHAVIOR
# ============================================================================

func _spawn_cluster_children() -> void:
	var cities = get_tree().get_nodes_in_group("city")
	if cities.is_empty():
		return
	var origin = global_position
	cities.sort_custom(func(a, b):
		return a.global_position.distance_to(origin) < b.global_position.distance_to(origin)
	)
	var targets = cities.slice(0, min(2, cities.size()))
	var spawner = get_node_or_null("/root/Main/WaveSpawner")
	if spawner == null:
		return
	var child_data = load("res://resources/missiles/basic_enemy.tres")
	for city in targets:
		spawner.spawn_incoming_missile(global_position, city.global_position, child_data)

# ============================================================================
# DECOY BEHAVIOR
# ============================================================================

func _spawn_decoy_children() -> void:
	var pm = get_node_or_null("/root/Main/ProjectileManager")
	if not pm:
		return
	var cities = get_tree().get_nodes_in_group("city")
	if cities.is_empty():
		return
	var live_cities = cities.filter(func(c): return is_instance_valid(c) and c.visible)
	live_cities.shuffle()
	for i in range(min(2, live_cities.size())):
		var child_data = MissileData.new()
		child_data.speed = 5.0
		child_data.points_value = 0
		child_data.mesh_color = Color(1.0, 0.5, 0.1, 1.0)
		child_data.trail_color = Color(1.0, 0.3, 0.0, 1.0)
		child_data.special_behavior = ""
		child_data.health = 1
		pm.spawn_incoming_missile(child_data, global_position, live_cities[i].global_position, 1.0)

# ============================================================================
# COLLISION DETECTION
# ============================================================================

func _enable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area.is_in_group("explosion"):
		take_hit()
