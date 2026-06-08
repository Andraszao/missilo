extends Control
# HUD: Heads-up display for game state and player feedback
#
# Displays wave, score, ammo per silo, cities remaining, and status messages.
# Reactive architecture — updates via signals, no polling.
#
# Ammo tracking sources from EventBus.silo_ammo_changed so it always
# reflects actual silo state, including modifier-boosted max ammo.

# ============================================================================
# NODES
# ============================================================================

@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var ammo_label: Label = $MarginContainer/VBoxContainer/AmmoLabel
@onready var cities_label: Label = $MarginContainer/VBoxContainer/CitiesLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

# ============================================================================
# STATE
# ============================================================================

# Indexed by silo_index. -1 = destroyed, ≥0 = current ammo count.
# Sourced from EventBus.silo_ammo_changed so modifier boosts are reflected.
var silo_ammo: Array[int] = [10, 10, 10]

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	GameManager.game_started.connect(_on_game_started)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_cleared.connect(_on_wave_cleared)
	GameManager.game_over.connect(_on_game_over)
	GameManager.score_changed.connect(_on_score_changed)

	EventBus.silo_ammo_changed.connect(_on_silo_ammo_changed)
	EventBus.silo_destroyed.connect(_on_silo_destroyed)
	EventBus.city_destroyed.connect(_on_city_destroyed)

	_update_display()

# ============================================================================
# DISPLAY
# ============================================================================

func _update_display() -> void:
	wave_label.text = "Wave: %d" % GameManager.current_wave
	score_label.text = "Score: %d" % GameManager.score
	cities_label.text = "Cities: %d" % GameManager.cities_alive

	var ammo_text: String = "Ammo: "
	for i in range(3):
		if silo_ammo[i] < 0:
			ammo_text += "[X] "
		else:
			ammo_text += "[%d] " % silo_ammo[i]
	ammo_label.text = ammo_text

func show_status_message(message: String, duration: float = 2.0) -> void:
	status_label.text = message
	status_label.visible = true
	await get_tree().create_timer(duration).timeout
	status_label.visible = false

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_game_started() -> void:
	silo_ammo = [10, 10, 10]
	status_label.visible = false
	_update_display()

func _on_wave_started(wave_number: int) -> void:
	_update_display()
	show_status_message("Wave %d — Incoming!" % wave_number, 1.5)

func _on_wave_cleared(wave_number: int) -> void:
	# silo_ammo array is already up to date from silo_ammo_changed signals
	_update_display()
	show_status_message("Wave %d Clear!" % wave_number, 2.0)

func _on_game_over(final_score: int, did_win: bool) -> void:
	if did_win:
		show_status_message("VICTORY! Final Score: %d" % final_score, 999.0)
	else:
		show_status_message("GAME OVER — Final Score: %d" % final_score, 999.0)

func _on_score_changed(_new_score: int) -> void:
	_update_display()

func _on_silo_ammo_changed(silo_index: int, new_ammo: int) -> void:
	if silo_index >= 0 and silo_index < silo_ammo.size():
		silo_ammo[silo_index] = new_ammo
		_update_display()

func _on_silo_destroyed(silo_index: int) -> void:
	if silo_index >= 0 and silo_index < silo_ammo.size():
		silo_ammo[silo_index] = -1
		_update_display()

func _on_city_destroyed(_city_index: int) -> void:
	_update_display()
