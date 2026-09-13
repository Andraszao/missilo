extends Node3D
# PlayerMissile: Defensive projectile fired by player silos
#
# Flies toward target, optionally homing onto nearest threat, then detonates.
# Detonation applies split, pulse, and chain behaviors from equipped modifiers.

@export var speed: float = 15.0

var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var current_position: Vector3 = Vector3.ZERO
var has_detonated: bool = false
var travel_progress: float = 0.0
var explosion_radius: float = 6.0
var _behaviors: Dictionary = {}

@onready var mesh: MeshInstance3D = $Mesh
var _trail: GPUParticles3D = null

func _ready() -> void:
	add_to_group("player_missile")
	_setup_trail()

func _setup_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.amount = 20
	_trail.lifetime = 0.28
	_trail.local_coords = false  # world-space so trail stays behind as missile moves
	_trail.emitting = false
	_trail.one_shot = false
	_trail.explosiveness = 0.0
	_trail.randomness = 0.15
	_trail.fixed_fps = 0

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3.ZERO
	mat.spread = 18.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.18
	mat.damping_min = 3.0
	mat.damping_max = 5.0
	mat.scale_min = 0.10
	mat.scale_max = 0.20
	mat.gravity = Vector3.ZERO

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	_trail.process_material = mat

	var sphere = SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	_trail.draw_pass_1 = sphere

	add_child(_trail)

func initialize(start: Vector3, target: Vector3, stats: Dictionary = {}) -> void:
	start_position = start
	target_position = target
	current_position = start
	global_position = start
	has_detonated = false
	travel_progress = 0.0

	if stats.has("speed"):
		speed = stats.speed
	else:
		speed = 15.0

	if stats.has("explosion_radius"):
		explosion_radius = stats.explosion_radius
	else:
		explosion_radius = 6.0

	_behaviors = stats.get("behaviors", {})

	# Color trail by active behavior — modulate tints the white base gradient
	if _trail:
		var h  = _behaviors.get("homing", 0.0)
		var sp = _behaviors.get("split", 1)
		var ch = _behaviors.get("chain_depth", 0)
		if h > 0.3:
			_trail.modulate = Color(1.0, 0.65, 0.0)   # orange — homing
		elif sp > 1:
			_trail.modulate = Color(0.3, 1.0, 0.65)   # green — split
		elif ch > 0:
			_trail.modulate = Color(0.4, 0.8, 1.0)    # cyan — chain
		else:
			_trail.modulate = Color(1.0, 1.0, 1.0)    # white — base
		_trail.emitting = true

	var direction = (target_position - start_position).normalized()
	if direction.length() > 0.01:
		var angle = atan2(direction.x, direction.y)
		rotation.z = -angle

func _process(delta: float) -> void:
	if has_detonated:
		return

	_apply_homing(delta)

	var total_distance = start_position.distance_to(target_position)
	var travel_step = (speed * delta) / total_distance
	travel_progress += travel_step

	if travel_progress >= 1.0:
		detonate()
	else:
		current_position = start_position.lerp(target_position, travel_progress)
		global_position = current_position

func _apply_homing(delta: float) -> void:
	var h = _behaviors.get("homing", 0.0)
	if h <= 0.0:
		return
	var pm = get_node_or_null("/root/Main/ProjectileManager")
	if not pm or not pm.has_method("get_active_incoming_missiles"):
		return
	var best_dist := INF
	var best_pos := target_position
	for e in pm.get_active_incoming_missiles():
		if not is_instance_valid(e) or not e.visible:
			continue
		var d = e.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best_pos = e.global_position
	if best_dist < 40.0:
		target_position = target_position.lerp(best_pos, h * delta * 2.5)

func detonate() -> void:
	if has_detonated:
		return
	has_detonated = true

	if _trail:
		_trail.emitting = false

	EventBus.player_missile_detonated.emit(target_position, explosion_radius)

	var pm = get_node_or_null("/root/Main/ProjectileManager")
	if pm:
		var split        = _behaviors.get("split", 1)
		var pulse        = _behaviors.get("pulse", 1)
		var chain_depth  = _behaviors.get("chain_depth", 0)
		var magnetic     = _behaviors.get("magnetic", false)
		var homing_frags = _behaviors.get("homing_frags", 0.0)

		var exp_behaviors = {"chain_depth": chain_depth, "magnetic": magnetic}

		# Main explosion
		var exp = pm.spawn_explosion(target_position, explosion_radius)
		if exp.has_method("set_behaviors"):
			exp.set_behaviors(exp_behaviors)

		# SPLIT: N-1 fragment explosions (homed toward enemies if HOMING active)
		if split > 1:
			_spawn_fragments(pm, split - 1, homing_frags, chain_depth, magnetic)

		# PULSE: delayed follow-up explosions (async on ProjectileManager)
		if pulse > 1 and pm.has_method("schedule_pulse_explosions"):
			pm.schedule_pulse_explosions(target_position, explosion_radius * 0.8, pulse - 1)

		pm.return_to_pool(self)
	else:
		queue_free()

func _spawn_fragments(pm: Node, count: int, homing_frags: float, chain_depth: int, magnetic: bool) -> void:
	var frag_radius = explosion_radius * 0.72
	var enemies: Array = []
	if homing_frags > 0.0 and pm.has_method("get_active_incoming_missiles"):
		enemies = pm.get_active_incoming_missiles().filter(
			func(e): return is_instance_valid(e) and e.visible
		)

	var frag_behaviors = {"chain_depth": chain_depth, "magnetic": magnetic}

	for i in range(count):
		var frag_pos: Vector3
		if i < enemies.size():
			frag_pos = enemies[i].global_position
		else:
			var angle = (float(i) / max(count, 1)) * TAU + (PI / max(count, 1))
			frag_pos = target_position + Vector3(cos(angle) * 3.5, 0.0, sin(angle) * 3.5)

		var fexp = pm.spawn_explosion(frag_pos, frag_radius)
		if fexp.has_method("set_behaviors"):
			fexp.set_behaviors(frag_behaviors)
