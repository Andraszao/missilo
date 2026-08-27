extends Node
# GameManager: The director of the entire show
#
# Manages the high-level game state machine, score tracking, and win/loss conditions.
# This is the single source of truth for "what's happening right now."
#
# State Flow:
# READY -> (start_game) -> PLAYING -> (wave clears) -> WAVE_CLEAR -> (next wave) -> PLAYING
#                                -> (all cities/silos dead) -> GAME_OVER
#
# Listen to signals to react to state changes without polling.

# ============================================================================
# GAME STATE
# ============================================================================

enum GameState {
	READY,       # Waiting to start (initial state)
	PLAYING,     # Wave is active, player defending
	WAVE_CLEAR,  # Brief pause between waves, show stats
	GAME_OVER    # Win or loss, show final score
}

var game_state: GameState = GameState.READY

# ============================================================================
# DIFFICULTY
# ============================================================================

## 0 = Easy, 1 = Normal, 2 = Hard
var difficulty: int = 1

func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, 2)
	# Adjust combo window per difficulty tier
	match difficulty:
		0: combo_window = 1.2  # Easy: full window
		1: combo_window = 1.2  # Normal: full window
		2: combo_window = 0.9  # Hard: tighter window

# ============================================================================
# PROGRESSION TRACKING
# ============================================================================

var current_wave: int = 0
var score: int = 0
var cities_alive: int = 6  # Starts at 6, decrements when cities die
var silos_active: int = 3  # Starts at 3, decrements when silos die

# ============================================================================
# STARTING BONUSES (populated at run start from ProgressionManager)
# ============================================================================

## Explosion radius multiplier for all silos this run; silos read this on init.
var base_radius_multiplier: float = 1.0
## Extra ammo per silo granted by the unlock tree; silos read this on init.
var starting_ammo_bonus: int = 0

# ============================================================================
# P6 MUTATOR FLAGS (set at run start, read by spawners and silo logic)
# ============================================================================

## Set by the "chain_world" mutator; silo.calculate_stats() should add 1 to
## chain_depth when this is true.
var chain_world_active: bool = false

# ============================================================================
# P8 CITY TECH FLAGS (set at run start from ProgressionManager)
# ============================================================================

## True when the city_shield unlock is purchased; cities absorb one hit each.
var city_shield_active: bool = false
## Tracks which cities have already consumed their shield this run (indices 0-5).
var _city_shields_used: Array[bool] = []

# ============================================================================
# COMBO TRACKING
# ============================================================================

var _combo_count: int = 0
var _combo_timer: float = 0.0
## Combo window in seconds; adjusted by difficulty (Hard = 0.9, others = 1.2)
var combo_window: float = 1.2

# ============================================================================
# CONFIGURATION
# ============================================================================

const TOTAL_CITIES: int = 6
const TOTAL_SILOS: int = 3
const MAX_WAVES: int = 10  # Win condition: complete wave 10

# ============================================================================
# SIGNALS
# ============================================================================

# Fired when game transitions from READY -> PLAYING
signal game_started

# Fired when a new wave begins
# wave_number: 1-indexed wave number
signal wave_started(wave_number: int)

# Fired when all enemies in wave are handled
# wave_number: which wave just completed
signal wave_cleared(wave_number: int)

# Fired when game ends (win or loss)
# final_score: total points earned
signal game_over(final_score: int, did_win: bool)

# Fired whenever score changes (for UI updates)
# new_score: current total score
signal score_changed(new_score: int)

# Fired when a wave clears and an upgrade can be chosen
# wave_number: which wave just completed
signal upgrade_available(wave_number: int)

# Fired at the start of each wave on Easy difficulty so SiloManager can
# perform a full ammo reload before the next wave begins.
signal silo_reload_requested

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect to EventBus to track destruction events
	EventBus.city_destroyed.connect(_on_city_destroyed)
	EventBus.silo_destroyed.connect(_on_silo_destroyed)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.wave_complete.connect(_on_wave_complete)
	EventBus.enemy_destroyed.connect(_on_enemy_killed_combo)

func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_count = 0
			EventBus.combo_changed.emit(1)

# ============================================================================
# PUBLIC API
# ============================================================================

func start_game() -> void:
	"""Kick off a fresh game from the beginning"""
	if game_state == GameState.PLAYING or game_state == GameState.WAVE_CLEAR:
		push_warning("Tried to start game while already in progress"); return

	# Reset all state
	current_wave = 0
	score = 0
	silos_active = TOTAL_SILOS

	# Apply unlock-tree bonuses for this run
	base_radius_multiplier = ProgressionManager.get_radius_bonus() * ProgressionManager.get_prestige_radius_aura()
	starting_ammo_bonus = ProgressionManager.get_starting_ammo_bonus()
	cities_alive = ProgressionManager.get_starting_city_count()

	# P8: City tech branch — shield and extra city
	city_shield_active = ProgressionManager.get_city_shield()
	_city_shields_used = [false, false, false, false, false, false]

	game_state = GameState.PLAYING
	game_started.emit()

	# P5: Equip pre-assigned loadout modifiers to silos
	_apply_silo_loadouts()
	# P6: Apply active run mutator effects (ammo penalties, chain flag, etc.)
	_apply_mutator_effects()

	# Start first wave
	advance_wave()

func end_game(did_win: bool) -> void:
	"""Transition to game over state"""
	game_state = GameState.GAME_OVER
	game_over.emit(score, did_win)

func add_score(points: int) -> void:
	"""Add points to current score and notify listeners"""
	score += points
	score_changed.emit(score)

func advance_wave() -> void:
	"""Move to next wave and signal systems to prepare"""
	current_wave += 1
	game_state = GameState.PLAYING
	wave_started.emit(current_wave)

func advance_when_ready() -> void:
	"""Called by UpgradeManager after upgrade is chosen or skipped"""
	if game_state != GameState.WAVE_CLEAR:
		return
	advance_wave()

func get_missile_spawn_multiplier() -> int:
	"""Returns the wave missile count multiplier (P6 double_missiles mutator)."""
	return 2 if ProgressionManager.has_mutator("double_missiles") else 1

# ============================================================================
# WIN/LOSS CONDITION CHECKS
# ============================================================================

func check_loss_condition() -> bool:
	"""Returns true if player has lost"""
	# Loss condition: All cities destroyed OR all silos destroyed
	if cities_alive <= 0:
		print("GAME OVER: All cities destroyed")
		return true

	if silos_active <= 0:
		print("GAME OVER: All silos destroyed")
		return true

	return false

func check_win_condition() -> bool:
	"""Returns true if player has won"""
	# Win condition: Complete wave 10
	return current_wave >= MAX_WAVES

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_city_destroyed(city_index: int) -> void:
	"""React to a city being destroyed"""
	# P8: city_shield absorbs the first hit per city before counting as a loss.
	if city_shield_active \
			and city_index >= 0 and city_index < _city_shields_used.size() \
			and not _city_shields_used[city_index]:
		_city_shields_used[city_index] = true
		print("City %d shield absorbed hit!" % city_index)
		return

	cities_alive -= 1
	print("City %d destroyed! Cities remaining: %d" % [city_index, cities_alive])

	if check_loss_condition():
		end_game(false)

func _on_silo_destroyed(silo_index: int) -> void:
	"""React to a silo being destroyed"""
	silos_active -= 1
	print("Silo %d destroyed! Silos remaining: %d" % [silo_index, silos_active])

	if check_loss_condition():
		end_game(false)

func _on_enemy_destroyed(position: Vector3, points: int) -> void:
	"""React to an enemy missile being killed by explosion"""
	add_score(points)

func _on_enemy_killed_combo(_pos: Vector3, base_pts: int) -> void:
	"""Track kill-streak combo and award bonus points"""
	_combo_count += 1
	_combo_timer = combo_window
	var mult: int = min(_combo_count, 5)
	if mult > 1:
		# Bonus points on top of whatever was already added by the existing kill handler
		score += base_pts * (mult - 1)
		score_changed.emit(score)
	EventBus.combo_changed.emit(mult)

func _on_wave_complete() -> void:
	"""React to all enemies being handled"""
	# Don't process wave complete if game is already over
	if game_state == GameState.GAME_OVER:
		return

	print("Wave %d complete!" % current_wave)

	# Reset combo between waves
	_combo_count = 0
	_combo_timer = 0.0

	game_state = GameState.WAVE_CLEAR
	wave_cleared.emit(current_wave)

	# Calculate wave bonuses
	var city_bonus = cities_alive * 100
	var silo_bonus = silos_active * 100
	add_score(city_bonus + silo_bonus)

	# Check win condition and emit upgrade signal
	if check_win_condition():
		end_game(true)
		return

	upgrade_available.emit(current_wave)  # UpgradeManager will call advance_when_ready()

# ============================================================================
# P5/P6 RUN SETUP HELPERS
# ============================================================================

func _apply_silo_loadouts() -> void:
	"""Equip pre-assigned modifiers to silos based on unlock-tree loadout slots (P5).

	Called after game_started so silo nodes are in the scene tree.  For each
	silo the ProgressionManager returns a modifier stem (resource filename
	without extension); if the matching .tres exists it is appended to the
	silo's equipped_modifiers array before the first wave begins.
	"""
	for silo in get_tree().get_nodes_in_group("player_silo"):
		var idx: int = silo.silo_index
		var stem: String = ProgressionManager.get_silo_loadout(idx)
		if stem != "":
			var mod_path: String = "res://resources/modifiers/%s.tres" % stem
			if ResourceLoader.exists(mod_path):
				var mod = load(mod_path)
				silo.equipped_modifiers.append(mod)
				print("Silo %d loadout: equipped %s" % [idx, stem])

func _apply_mutator_effects() -> void:
	"""Apply active run mutator effects to silos and game-wide flags (P6).

	- chain_world  -> sets chain_world_active flag; silo.calculate_stats()
	                 should honour this flag to add 1 chain_depth.
	- half_ammo    -> halves each silo's max_ammo and current_ammo.
	- double_missiles -> no per-silo work; spawners call get_missile_spawn_multiplier().
	"""
	chain_world_active = ProgressionManager.has_mutator("chain_world")

	if ProgressionManager.has_mutator("half_ammo"):
		for silo in get_tree().get_nodes_in_group("player_silo"):
			silo.max_ammo = max(1, silo.max_ammo / 2)
			silo.current_ammo = max(1, silo.current_ammo / 2)
			EventBus.silo_ammo_changed.emit(silo.silo_index, silo.current_ammo)
