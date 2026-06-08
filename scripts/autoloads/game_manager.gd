extends Node
# GameManager: The director of the entire show
#
# Manages the high-level game state machine, score tracking, and win/loss conditions.
# This is the single source of truth for "what's happening right now."
#
# State Flow:
# READY → (start_game) → PLAYING → (wave clears) → WAVE_CLEAR → (upgrade picked) → PLAYING
#                                → (all cities/silos dead) → GAME_OVER
#                                → (wave 10 cleared) → GAME_OVER (win)
#
# Listen to signals to react to state changes without polling.

# ============================================================================
# GAME STATE
# ============================================================================

enum GameState {
	READY,       # Waiting to start (initial state)
	PLAYING,     # Wave is active, player defending
	WAVE_CLEAR,  # Upgrade selection window between waves
	GAME_OVER    # Win or loss, show final score
}

var game_state: GameState = GameState.READY

# ============================================================================
# PROGRESSION TRACKING
# ============================================================================

var current_wave: int = 0
var score: int = 0
var cities_alive: int = 6
var silos_active: int = 3

# ============================================================================
# CONFIGURATION
# ============================================================================

const TOTAL_CITIES: int = 6
const TOTAL_SILOS: int = 3
const MAX_WAVES: int = 10

# ============================================================================
# SIGNALS
# ============================================================================

# Fired when game transitions from READY/GAME_OVER → PLAYING
signal game_started

# Fired when a new wave begins
signal wave_started(wave_number: int)

# Fired when all enemies in wave are handled (always fires)
signal wave_cleared(wave_number: int)

# Fired when a non-final wave clears and an upgrade should be presented
# UpgradeManager listens to this and calls advance_when_ready() when done
signal upgrade_available(wave_number: int)

# Fired when game ends (win or loss)
signal game_over(final_score: int, did_win: bool)

# Fired whenever score changes
signal score_changed(new_score: int)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	EventBus.city_destroyed.connect(_on_city_destroyed)
	EventBus.silo_destroyed.connect(_on_silo_destroyed)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.wave_complete.connect(_on_wave_complete)

# ============================================================================
# PUBLIC API
# ============================================================================

func start_game() -> void:
	# Allow restart from GAME_OVER as well as initial READY start
	if game_state == GameState.PLAYING or game_state == GameState.WAVE_CLEAR:
		push_warning("Tried to start game while already in progress")
		return

	current_wave = 0
	score = 0
	cities_alive = TOTAL_CITIES
	silos_active = TOTAL_SILOS

	game_state = GameState.PLAYING
	game_started.emit()
	advance_wave()

func end_game(did_win: bool) -> void:
	game_state = GameState.GAME_OVER
	game_over.emit(score, did_win)

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func advance_wave() -> void:
	current_wave += 1
	game_state = GameState.PLAYING
	wave_started.emit(current_wave)

func advance_when_ready() -> void:
	# Called by UpgradeManager after the player makes their upgrade selection
	if game_state != GameState.WAVE_CLEAR:
		return
	advance_wave()

# ============================================================================
# WIN/LOSS CONDITION CHECKS
# ============================================================================

func check_loss_condition() -> bool:
	if cities_alive <= 0:
		return true
	if silos_active <= 0:
		return true
	return false

func check_win_condition() -> bool:
	return current_wave >= MAX_WAVES

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_city_destroyed(city_index: int) -> void:
	cities_alive -= 1
	print("City %d destroyed! Cities remaining: %d" % [city_index, cities_alive])
	if check_loss_condition():
		end_game(false)

func _on_silo_destroyed(silo_index: int) -> void:
	silos_active -= 1
	print("Silo %d destroyed! Silos remaining: %d" % [silo_index, silos_active])
	if check_loss_condition():
		end_game(false)

func _on_enemy_destroyed(_position: Vector3, points: int) -> void:
	add_score(points)

func _on_wave_complete() -> void:
	# Guard against double-fire: only process from PLAYING state
	if game_state != GameState.PLAYING:
		return

	print("Wave %d complete!" % current_wave)

	game_state = GameState.WAVE_CLEAR

	var city_bonus: int = cities_alive * 100
	var silo_bonus: int = silos_active * 100
	add_score(city_bonus + silo_bonus)

	# Always notify HUD/display systems
	wave_cleared.emit(current_wave)

	# Win condition: end game immediately, no upgrade screen
	if check_win_condition():
		end_game(true)
		return

	# Signal UpgradeManager to present choices.
	# UpgradeManager calls advance_when_ready() when the player is done.
	upgrade_available.emit(current_wave)
