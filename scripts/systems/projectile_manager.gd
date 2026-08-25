extends Node
# ProjectileManager: Object pool manager for all projectiles and explosions

@export var player_missile_scene: PackedScene
@export var incoming_missile_scene: PackedScene
@export var explosion_scene: PackedScene

@export var initial_player_missile_pool: int = 20
@export var initial_incoming_missile_pool: int = 60
@export var initial_explosion_pool: int = 30

var player_missile_pool: Array = []
var incoming_missile_pool: Array = []
var explosion_pool: Array = []

var active_player_missiles: Array = []
var active_incoming_missiles: Array = []
var active_explosions: Array = []

@onready var player_missiles_container: Node3D = $PlayerMissiles
@onready var incoming_missiles_container: Node3D = $IncomingMissiles
@onready var explosions_container: Node3D = $Explosions

func _ready() -> void:
	_initialize_pools()

func _initialize_pools() -> void:
	for i in initial_player_missile_pool:
		var missile = player_missile_scene.instantiate()
		player_missiles_container.add_child(missile)
		_deactivate_entity(missile)
		player_missile_pool.append(missile)

	for i in initial_incoming_missile_pool:
		var missile = incoming_missile_scene.instantiate()
		incoming_missiles_container.add_child(missile)
		_deactivate_entity(missile)
		incoming_missile_pool.append(missile)

	for i in initial_explosion_pool:
		var explosion = explosion_scene.instantiate()
		explosions_container.add_child(explosion)
		_deactivate_entity(explosion)
		explosion_pool.append(explosion)

	print("ProjectileManager pools initialized: %d player, %d incoming, %d explosions" % [
		initial_player_missile_pool,
		initial_incoming_missile_pool,
		initial_explosion_pool
	])

# ── Spawning API ──────────────────────────────────────────────────────────

func spawn_player_missile(start: Vector3, target: Vector3, stats: Dictionary = {}) -> Node:
	var missile = _get_from_pool(player_missile_pool, player_missile_scene, player_missiles_container)
	missile.initialize(start, target, stats)
	missile.visible = true
	missile.set_process(true)
	active_player_missiles.append(missile)
	return missile

func spawn_incoming_missile(missile_data: MissileData, start: Vector3, target: Vector3, speed_mult: float = 1.0) -> Node:
	var missile = _get_from_pool(incoming_missile_pool, incoming_missile_scene, incoming_missiles_container)
	missile.initialize(missile_data, start, target, speed_mult)
	missile.visible = true
	missile.set_process(true)
	missile.set_physics_process(true)
	active_incoming_missiles.append(missile)
	return missile

func spawn_explosion(position: Vector3, radius: float = 6.0) -> Node:
	var explosion = _get_from_pool(explosion_pool, explosion_scene, explosions_container)
	explosion.initialize(position)
	explosion.set_explosion_radius(radius)
	explosion.visible = true
	explosion.set_process(true)
	active_explosions.append(explosion)
	return explosion

func schedule_pulse_explosions(pos: Vector3, radius: float, count: int) -> void:
	# Async: spawns count follow-up explosions at pos, 0.45 s apart.
	# Runs as a background coroutine on ProjectileManager (safe after caller
	# returns to pool).
	for p in range(count):
		await get_tree().create_timer(0.45 * (p + 1)).timeout
		if not is_inside_tree():
			return
		spawn_explosion(pos, radius * pow(0.85, p))

# ── Pooling internals ─────────────────────────────────────────────────────

func _get_from_pool(pool: Array, scene: PackedScene, container: Node) -> Node:
	var obj: Node
	if pool.is_empty():
		push_warning("Pool exhausted, creating new object")
		obj = scene.instantiate()
		container.add_child(obj)
	else:
		obj = pool.pop_back()
	return obj

func return_to_pool(entity: Node) -> void:
	_deactivate_entity(entity)
	if entity.is_in_group("player_missile"):
		player_missile_pool.append(entity)
		active_player_missiles.erase(entity)
	elif entity.is_in_group("incoming_missile"):
		incoming_missile_pool.append(entity)
		active_incoming_missiles.erase(entity)
	elif entity.is_in_group("explosion"):
		explosion_pool.append(entity)
		active_explosions.erase(entity)

func _deactivate_entity(entity: Node) -> void:
	entity.visible = false
	entity.set_process(false)
	entity.set_physics_process(false)
	for child in entity.get_children():
		if child is Area3D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)

# ── Public API ────────────────────────────────────────────────────────────

func get_active_explosions() -> Array:
	return active_explosions

func get_active_incoming_missiles() -> Array:
	return active_incoming_missiles

func get_active_player_missiles() -> Array:
	return active_player_missiles
