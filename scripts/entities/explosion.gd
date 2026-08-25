extends Node3D
# Explosion: Area of effect that destroys incoming missiles
#
# Lifecycle: GROWING -> HOLDING -> SHRINKING -> INACTIVE -> pool
# Behaviors (set via set_behaviors after spawn):
#   chain_depth: spawn a secondary explosion at each kill position
#   magnetic:    expand hitbox to 1.35x radius during hold phase

@export var max_radius: float = 3.0
@export var growth_rate: float = 20.0
@export var hold_duration: float = 0.4
@export var shrink_rate: float = 8.0

enum Phase { GROWING, HOLDING, SHRINKING, INACTIVE }

var current_phase: Phase = Phase.INACTIVE
var current_radius: float = 0.0
var hold_timer: float = 0.0
var chain_generation: int = 0
var _behaviors: Dictionary = {}

func _get_behavior_color() -> Color:
	if chain_generation > 0:
		return Color(0.3, 0.9, 1.0)
	if _behaviors.get("magnetic", false):
		return Color(0.75, 0.2, 1.0)
	if _behaviors.get("chain_depth", 0) > 0:
		return Color(0.4, 0.85, 1.0)
	if _behaviors.get("split", 1) > 1:
		return Color(0.3, 1.0, 0.55)
	return Color(1.0, 0.9, 0.1)

@onready var visual_mesh: MeshInstance3D = $VisualMesh
@onready var hitbox: Area3D = $Hitbox
@onready var collision_shape: CollisionShape3D = $Hitbox/CollisionShape3D

func _ready() -> void:
	add_to_group("explosion")
	if hitbox:
		hitbox.area_entered.connect(_on_area_entered)

func set_behaviors(b: Dictionary) -> void:
	_behaviors = b

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("incoming_missile"):
		var missile = area.get_parent()
		if missile and missile.has_method("set_hit_by_generation"):
			missile.set_hit_by_generation(chain_generation)
		if missile and missile.has_method("destroy"):
			var kill_pos = missile.global_position
			missile.destroy()
			_spawn_chain(kill_pos)

func _spawn_chain(kill_pos: Vector3) -> void:
	var depth = _behaviors.get("chain_depth", 0)
	if depth <= 0:
		return
	var pm = get_node_or_null("/root/Main/ProjectileManager")
	if not pm:
		return
	var chain_radius = max_radius * 0.62
	var chain_exp = pm.spawn_explosion(kill_pos, chain_radius)
	if chain_exp.has_method("set_behaviors"):
		var chain_behaviors = _behaviors.duplicate()
		chain_behaviors["chain_depth"] = depth - 1
		chain_exp.set_behaviors(chain_behaviors)

func initialize(pos: Vector3) -> void:
	global_position = pos
	current_radius = 0.0
	current_phase = Phase.GROWING
	hold_timer = 0.0
	chain_generation = 0
	_behaviors = {}
	max_radius = 3.0

	if collision_shape.shape is SphereShape3D:
		var new_shape = SphereShape3D.new()
		new_shape.radius = 0.1
		collision_shape.shape = new_shape

	if hitbox:
		call_deferred("_enable_hitbox")

	_update_visuals()

func set_explosion_radius(radius: float) -> void:
	max_radius = radius

func set_chain_generation(generation: int) -> void:
	chain_generation = generation
	if generation > 0:
		growth_rate = 26.0

func _process(delta: float) -> void:
	match current_phase:
		Phase.GROWING:
			_process_growing(delta)
		Phase.HOLDING:
			_process_holding(delta)
		Phase.SHRINKING:
			_process_shrinking(delta)

func _process_growing(delta: float) -> void:
	current_radius += growth_rate * delta
	if current_radius >= max_radius:
		current_radius = max_radius
		current_phase = Phase.HOLDING
		hold_timer = 0.0
		# MAGNETIC: expand hitbox during hold to pull in nearby missiles
		if _behaviors.get("magnetic", false) and collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius = max_radius * 1.35
	_update_visuals()

func _process_holding(delta: float) -> void:
	hold_timer += delta
	if hold_timer >= hold_duration:
		current_phase = Phase.SHRINKING

func _process_shrinking(delta: float) -> void:
	current_radius -= shrink_rate * delta
	if current_radius <= 0.0:
		current_radius = 0.0
		current_phase = Phase.INACTIVE
		_return_to_pool()
	_update_visuals()

func _update_visuals() -> void:
	visual_mesh.scale = Vector3.ONE * current_radius
	if collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = current_radius
	var material = visual_mesh.get_surface_override_material(0)
	if material:
		var t = clamp(1.0 - (current_radius / max(max_radius, 0.01)), 0.0, 1.0)
		var color = _get_behavior_color().lerp(Color.ORANGE_RED, t * 0.65)
		material.albedo_color = color
		if material.has_property("emission_enabled"):
			material.emission_enabled = (current_phase == Phase.HOLDING)
			material.emission = _get_behavior_color()
			material.emission_energy_multiplier = 1.8 if current_phase == Phase.HOLDING else 0.0

func _enable_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true

func _return_to_pool() -> void:
	var projectile_manager = get_node_or_null("/root/Main/ProjectileManager")
	if projectile_manager:
		projectile_manager.return_to_pool(self)
	else:
		queue_free()
