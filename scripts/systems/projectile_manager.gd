extends Node
# ProjectileManager: Object pool manager for all projectiles and explosions
#
# Why pooling?
# - Instantiating/destroying nodes every frame causes garbage collection spikes
# - With 50+ missiles and 10+ explosions, performance matters
# - Pool once, reuse forever = smooth 60 FPS
#
# How it works:
# - Pre-instantiate a pool of objects on startup
# - When spawning, grab from pool and activate
# - When done, deactivate and return to pool
# - Pool grows if needed (but shouldn't in normal play)

# ============================================================================
# SCENE REFERENCES
# ============================================================================

@export var player_missile_scene: PackedScene
@export var incoming_missile_scene: PackedScene
@export var explosion_scene: PackedScene

# ============================================================================
# POOL CONFIGURATION
# ============================================================================

# Initial pool sizes (tune based on expected max simultaneous)
@export var initial_player_missile_pool: int = 20
@export var initial_incoming_missile_pool: int = 60
@export var initial_explosion_pool: int = 15

# ============================================================================
# POOLS
# ============================================================================

var player_missile_pool: Array = []
var incoming_missile_pool: Array = []
var explosion_pool: Array = []

# Active entity tracking (for systems that need to iterate)
var active_player_missiles: Array = []
var active_incoming_missiles: Array = []
var active_explosions: Array = []

# ============================================================================
# CONTAINER NODES
# ============================================================================

@onready var player_missiles_container: Node3D = $PlayerMissiles
@onready var incoming_missiles_container: Node3D = $IncomingMissiles
@onready var explosions_container: Node3D = $Explosions

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Pre-populate pools
	_initialize_pools()

func _initialize_pools() -> void:
	"""Create initial pool objects"""
	# Player missiles
	for i in initial_player_missile_pool:
		var missile = player_missile_scene.instantiate()
		player_missiles_container.add_child(missile)
		_deactivate_entity(missile)
		player_missile_pool.append(missile)
	
	# Incoming missiles
	for i in initial_incoming_missile_pool:
		var missile = incoming_missile_scene.instantiate()
		incoming_missiles_container.add_child(missile)
		_deactivate_entity(missile)
		incoming_missile_pool.append(missile)
	
	# Explosions
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

# ============================================================================
# SPAWNING API
# ============================================================================

func spawn_player_missile(start: Vector3, target: Vector3, stats: Dictionary = {}) -> Node:
	"""Get a player missile from pool and activate it"""
	var missile = _get_from_pool(player_missile_pool, player_missile_scene, player_missiles_container)
	
	missile.initialize(start, target, stats)
	missile.visible = true
	missile.set_process(true)
	
	active_player_missiles.append(missile)
	return missile

func spawn_incoming_missile(missile_data: MissileData, start: Vector3, target: Vector3, speed_mult: float = 1.0) -> Node:
	"""Get an incoming missile from pool and activate it"""
	var missile = _get_from_pool(incoming_missile_pool, incoming_missile_scene, incoming_missiles_container)
	
	missile.initialize(missile_data, start, target, speed_mult)
	missile.visible = true
	missile.set_process(true)
	missile.set_physics_process(true)
	
	active_incoming_missiles.append(missile)
	return missile

func spawn_explosion(position: Vector3, radius: float = 6.0) -> Node:
	"""Get an explosion from pool and activate it"""
	var explosion = _get_from_pool(explosion_pool, explosion_scene, explosions_container)
	
	explosion.initialize(position)
	explosion.set_explosion_radius(radius)
	explosion.visible = true
	explosion.set_process(true)
	
	active_explosions.append(explosion)
	return explosion

# ============================================================================
# POOLING INTERNALS
# ============================================================================

func _get_from_pool(pool: Array, scene: PackedScene, container: Node) -> Node:
	"""Get an object from pool, or create new if empty"""
	var obj: Node
	
	if pool.is_empty():
		# Pool exhausted, create new (should be rare)
		push_warning("Pool exhausted, creating new object")
		obj = scene.instantiate()
		container.add_child(obj)
	else:
		obj = pool.pop_back()
	
	return obj

func return_to_pool(entity: Node) -> void:
	"""Deactivate entity and return to appropriate pool"""
	_deactivate_entity(entity)
	
	# Determine which pool this belongs to
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
	"""Fully deactivate an entity for pooling (including hitboxes)"""
	entity.visible = false
	entity.set_process(false)
	entity.set_physics_process(false)
	
	# Disable any Area3D hitboxes to prevent phantom collisions
	# Use call_deferred to avoid physics query flush conflicts
	for child in entity.get_children():
		if child is Area3D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_active_explosions() -> Array:
	"""Returns list of currently active explosions (for collision checks)"""
	return active_explosions

func get_active_incoming_missiles() -> Array:
	"""Returns list of currently active incoming missiles"""
	return active_incoming_missiles

func get_active_player_missiles() -> Array:
	"""Returns list of currently active player missiles"""
	return active_player_missiles
