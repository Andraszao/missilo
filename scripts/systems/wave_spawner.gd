extends Node
# WaveSpawner: Orchestrates enemy missile spawning for each wave
#
# Loads WaveConfig resources and spawns enemies at specified intervals.
# Tracks how many enemies are alive and signals when wave is complete.
#
# Flow:
# 1. GameManager signals wave_started
# 2. WaveSpawner loads appropriate WaveConfig
# 3. Spawns enemies at intervals until count reached
# 4. Tracks enemy destruction via EventBus
# 5. When all enemies handled, signals wave_complete

# ============================================================================
# CONFIGURATION
# ============================================================================

# Path to wave config resources (wave_01.tres, wave_02.tres, etc)
@export var wave_configs_path: String = "res://resources/waves/"

# ============================================================================
# STATE TRACKING
# ============================================================================

var current_wave_config: WaveConfig = null
var enemies_spawned: int = 0
var enemies_remaining: int = 0
var is_spawning: bool = false

## Effective missile count after difficulty scaling is applied
var _effective_missile_count: int = 0
## Effective speed multiplier after difficulty scaling is applied
var _effective_speed_mult: float = 1.0

# ============================================================================
# ENEMY TYPE DATA
# ============================================================================

var _fast_scout_data: MissileData = preload("res://resources/missiles/fast_scout.tres")
var _cluster_data: MissileData = preload("res://resources/missiles/cluster_missile.tres")
var _decoy_data: MissileData = null

# ============================================================================
# NODES
# ============================================================================

var spawn_timer: Timer
@onready var projectile_manager: Node = get_node("/root/Main/ProjectileManager")

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	# Load decoy data (with inline fallback if resource not found)
	_decoy_data = load("res://resources/missiles/decoy.tres")
	if _decoy_data == null:
		_decoy_data = MissileData.new()
		_decoy_data.speed = 3.0
		_decoy_data.points_value = 30
		_decoy_data.mesh_color = Color(0.5, 0.5, 1.0, 1.0)
		_decoy_data.special_behavior = "decoy"
		_decoy_data.health = 1

	# Listen for game events
	GameManager.wave_started.connect(_on_wave_started)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.incoming_missile_impacted.connect(_on_enemy_impacted)

# ============================================================================
# WAVE MANAGEMENT
# ============================================================================

func start_wave(wave_number: int) -> void:
	"""Load wave config and begin spawning"""
	# Don't start new waves if game is over
	if GameManager.game_state == GameManager.GameState.GAME_OVER:
		print("Cannot start wave - game is over")
		return

	# Load wave config resource
	var config_path = wave_configs_path + "wave_%02d.tres" % wave_number
	current_wave_config = load(config_path) as WaveConfig

	if current_wave_config == null:
		push_error("Failed to load wave config: %s" % config_path)
		return

	# Apply difficulty scaling
	var diff: int = GameManager.difficulty
	var count_mult_table: Array = [0.65, 1.0, 1.2]
	var speed_mult_table: Array = [0.8,  1.0, 1.1]
	var count_mult: float = count_mult_table[diff]
	var speed_mult: float  = speed_mult_table[diff]

	_effective_missile_count = max(1, roundi(current_wave_config.missile_count * count_mult))
	_effective_speed_mult    = current_wave_config.speed_multiplier * speed_mult

	# Easy difficulty: signal SiloManager to perform a full ammo reload
	if diff == 0:
		GameManager.silo_reload_requested.emit()

	# Reset state
	enemies_spawned = 0
	enemies_remaining = _effective_missile_count
	is_spawning = true

	print("Starting wave %d: %d missiles (x%.2f) at speed x%.2f, strategy=%s" % [
		wave_number,
		_effective_missile_count,
		count_mult,
		_effective_speed_mult,
		current_wave_config.targeting_strategy
	])

	# Start spawn timer
	spawn_timer.wait_time = current_wave_config.spawn_interval
	spawn_timer.start()

	# Spawn first enemy immediately
	spawn_enemy()

func _pick_missile_data(wave: int) -> MissileData:
	"""Roll for enemy type based on current wave number (legacy wave-bracket logic)"""
	# First check if this spawn is a decoy (wave 6+)
	var decoy_roll = randf()
	var decoy_chance = 0.0
	if wave >= 10:
		decoy_chance = 0.15
	elif wave >= 8:
		decoy_chance = 0.10
	elif wave >= 6:
		decoy_chance = 0.05
	if decoy_roll < decoy_chance:
		return _decoy_data

	# Roll for remaining enemy types using existing wave brackets
	var roll = randf()
	if wave >= 9:
		if roll < 0.20: return _cluster_data
		if roll < 0.60: return _fast_scout_data
		return current_wave_config.missile_data
	elif wave >= 7:
		if roll < 0.10: return _cluster_data
		if roll < 0.40: return _fast_scout_data
		return current_wave_config.missile_data
	elif wave >= 5:
		if roll < 0.20: return _fast_scout_data
		return current_wave_config.missile_data
	return current_wave_config.missile_data

func spawn_enemy() -> void:
	"""Create a single incoming missile"""
	if current_wave_config == null or not is_spawning:
		return

	if enemies_spawned >= _effective_missile_count:
		# All enemies spawned, stop timer
		spawn_timer.stop()
		is_spawning = false
		return

	# Calculate spawn position just above camera view
	# Camera at (0, 15, 35) with FOV 60 can see up to about Y=40
	# Spawn at Y=42 so they appear from top of screen
	var random_x = randf_range(-35.0, 35.0)
	var start_pos = Vector3(random_x, 42.0, 0)  # Just above visible area

	# Calculate target using wave's targeting strategy
	var target_pos: Vector3 = _pick_target(current_wave_config.targeting_strategy)

	# Pick missile type using wave config (falls back to legacy logic when allowed_missile_types is empty)
	var chosen_data: MissileData = _pick_missile_data_for_wave(current_wave_config)

	# Spawn through ProjectileManager using difficulty-scaled speed
	projectile_manager.spawn_incoming_missile(
		chosen_data,
		start_pos,
		target_pos,
		_effective_speed_mult
	)

	enemies_spawned += 1

func spawn_incoming_missile(start: Vector3, target: Vector3, data: MissileData) -> void:
	"""Spawn an incoming missile with an explicit start position and data.
	Used by cluster missiles to create child missiles on death.
	Increments enemies_remaining so the wave counter stays accurate."""
	enemies_remaining += 1
	projectile_manager.spawn_incoming_missile(
		data,
		start,
		target,
		1.0
	)

func check_wave_complete() -> void:
	"""Check if all enemies are handled and signal if so"""
	if enemies_remaining <= 0 and not is_spawning:
		print("Wave complete! All enemies handled.")
		EventBus.wave_complete.emit()

# ============================================================================
# TARGETING STRATEGIES
# ============================================================================

func _pick_target(strategy: String) -> Vector3:
	"""Return a target ground position based on the wave's targeting strategy"""
	match strategy:
		"city_hunter":
			# Pick a random alive city
			var cities = get_tree().get_nodes_in_group("city")
			var alive = cities.filter(func(c): return c.is_alive)
			if alive.is_empty():
				return _pick_random_ground_pos()
			return alive[randi() % alive.size()].global_position
		"silo_hunter":
			# Pick a random active player silo
			var silos = get_tree().get_nodes_in_group("player_silo")
			var active = silos.filter(func(s): return s.is_active)
			if active.is_empty():
				return _pick_random_ground_pos()
			return active[randi() % active.size()].global_position + Vector3(0, 0.2, 0)
		"mixed":
			# 50% city, 30% silo, 20% random
			var r = randf()
			if r < 0.5:
				return _pick_target("city_hunter")
			elif r < 0.8:
				return _pick_target("silo_hunter")
			else:
				return _pick_random_ground_pos()
		_:  # "spread", "random", or any unknown value
			return _pick_random_ground_pos()

func _pick_random_ground_pos() -> Vector3:
	"""Return a random ground-level target position (existing spread logic)"""
	var target_x = randf_range(-30.0, 30.0)
	return Vector3(target_x, 0, 0)

# ============================================================================
# MISSILE TYPE SELECTION (wave-config-driven)
# ============================================================================

func _pick_missile_data_for_wave(wave_config) -> MissileData:
	"""Select missile type using wave_config.allowed_missile_types with weighted random.
	Falls back to legacy wave-bracket logic when allowed_missile_types is empty."""
	var allowed: Array = wave_config.allowed_missile_types if wave_config else []

	# Empty list = use legacy per-wave-number bracket logic
	if allowed.is_empty():
		return _pick_missile_data(GameManager.current_wave)

	# Weighted random selection (armored/mirv intentionally rare)
	var weights: Dictionary = {"standard": 60, "scout": 25, "armored": 10, "mirv": 5}
	var total: int = 0
	for t in allowed:
		total += weights.get(t, 10)
	var roll: int = randi() % max(total, 1)
	var acc: int = 0
	for t in allowed:
		acc += weights.get(t, 10)
		if roll < acc:
			return _load_missile_data(t)
	return _load_missile_data("standard")

func _load_missile_data(type_name: String) -> MissileData:
	"""Load a MissileData resource by logical type name, with graceful fallback"""
	var path: String = "res://resources/missiles/%s.tres" % type_name
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback to standard missile
	var fallback: String = "res://resources/missiles/standard.tres"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	# Last resort: use the wave config's own missile_data
	if current_wave_config and current_wave_config.missile_data:
		return current_wave_config.missile_data
	return null

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_wave_started(wave_number: int) -> void:
	"""React to GameManager starting a new wave"""
	start_wave(wave_number)

func _on_spawn_timer_timeout() -> void:
	"""Timer tick - spawn next enemy"""
	spawn_enemy()

func _on_enemy_destroyed(position: Vector3, points: int) -> void:
	"""Enemy killed by explosion"""
	enemies_remaining -= 1
	check_wave_complete()

func _on_enemy_impacted(position: Vector3) -> void:
	"""Enemy reached target (city/silo/ground)"""
	enemies_remaining -= 1
	check_wave_complete()
