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

@export var wave_configs_path: String = "res://resources/waves/"

# ============================================================================
# STATE
# ============================================================================

var current_wave_config: WaveConfig = null
var enemies_spawned: int = 0
var enemies_remaining: int = 0
var is_spawning: bool = false

# ============================================================================
# NODES
# ============================================================================

var spawn_timer: Timer
@onready var projectile_manager: Node = get_node("/root/Main/ProjectileManager")

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	GameManager.wave_started.connect(_on_wave_started)
	EventBus.enemy_destroyed.connect(_on_enemy_handled)
	EventBus.incoming_missile_impacted.connect(_on_enemy_impacted)

# ============================================================================
# WAVE MANAGEMENT
# ============================================================================

func start_wave(wave_number: int) -> void:
	if GameManager.game_state == GameManager.GameState.GAME_OVER:
		return

	var config_path: String = wave_configs_path + "wave_%02d.tres" % wave_number
	current_wave_config = load(config_path) as WaveConfig

	if current_wave_config == null:
		push_error("Failed to load wave config: %s" % config_path)
		return

	enemies_spawned = 0
	enemies_remaining = current_wave_config.missile_count
	is_spawning = true

	print("Starting wave %d: %d missiles at %.2fs intervals" % [
		wave_number,
		current_wave_config.missile_count,
		current_wave_config.spawn_interval
	])

	spawn_timer.wait_time = current_wave_config.spawn_interval
	spawn_timer.start()
	_spawn_enemy()

func _spawn_enemy() -> void:
	if current_wave_config == null or not is_spawning:
		return

	if enemies_spawned >= current_wave_config.missile_count:
		spawn_timer.stop()
		is_spawning = false
		# Check here in case chain reactions cleared everything before this final tick
		_check_wave_complete()
		return

	var random_x: float = randf_range(-35.0, 35.0)
	var start_pos := Vector3(random_x, 42.0, 0)

	var target_x: float = randf_range(-30.0, 30.0)
	var target_pos := Vector3(target_x, 0.0, 0.0)

	projectile_manager.spawn_incoming_missile(
		current_wave_config.missile_data,
		start_pos,
		target_pos,
		current_wave_config.speed_multiplier
	)

	enemies_spawned += 1

func _check_wave_complete() -> void:
	if enemies_remaining <= 0 and not is_spawning:
		print("Wave complete! All enemies handled.")
		EventBus.wave_complete.emit()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_wave_started(wave_number: int) -> void:
	start_wave(wave_number)

func _on_spawn_timer_timeout() -> void:
	_spawn_enemy()

func _on_enemy_handled(_position: Vector3, _points: int) -> void:
	enemies_remaining -= 1
	_check_wave_complete()

func _on_enemy_impacted(_position: Vector3) -> void:
	enemies_remaining -= 1
	_check_wave_complete()
