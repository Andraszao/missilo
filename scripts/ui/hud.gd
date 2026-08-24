extends Control
# HUD: Heads-up display for game state and player feedback
#
# Displays:
# - Current wave number
# - Score
# - Ammo for each silo
# - Cities remaining
# - Game over / wave clear messages
#
# Updates via signals - no polling, clean reactive architecture

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

var silo_ammo: Array[int] = [7, 7, 7]  # Track each silo's ammo

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect to GameManager signals
	GameManager.game_started.connect(_on_game_started)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_cleared.connect(_on_wave_cleared)
	GameManager.game_over.connect(_on_game_over)
	GameManager.score_changed.connect(_on_score_changed)
	
	# Connect to EventBus signals
	EventBus.silo_fired.connect(_on_silo_fired)
	EventBus.silo_destroyed.connect(_on_silo_destroyed)
	EventBus.city_destroyed.connect(_on_city_destroyed)
	
	# Initial display
	_update_display()

# ============================================================================
# DISPLAY UPDATES
# ============================================================================

func _update_display() -> void:
	"""Refresh all HUD elements"""
	wave_label.text = "Wave: %d" % GameManager.current_wave
	score_label.text = "Score: %d" % GameManager.score
	cities_label.text = "Cities: %d" % GameManager.cities_alive
	
	# Ammo display: show all three silos
	var ammo_text = "Ammo: "
	for i in range(3):
		if silo_ammo[i] < 0:  # Destroyed
			ammo_text += "[X] "
		else:
			ammo_text += "[%d] " % silo_ammo[i]
	ammo_label.text = ammo_text

func show_status_message(message: String, duration: float = 2.0) -> void:
	"""Display temporary status message"""
	status_label.text = message
	status_label.visible = true
	
	# Hide after duration
	await get_tree().create_timer(duration).timeout
	status_label.visible = false

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_game_started() -> void:
	"""Game starting - reset display"""
	silo_ammo = [7, 7, 7]
	status_label.visible = false
	_update_display()

func _on_wave_started(wave_number: int) -> void:
	"""New wave starting"""
	_update_display()
	show_status_message("Wave %d - Incoming!" % wave_number, 1.5)

func _on_wave_cleared(wave_number: int) -> void:
	"""Wave completed - reload active silos"""
	# Reset ammo for silos that aren't destroyed
	for i in range(silo_ammo.size()):
		if silo_ammo[i] >= 0:  # Not destroyed
			silo_ammo[i] = 7  # Full reload
	
	_update_display()
	show_status_message("Wave %d Clear!" % wave_number, 2.0)

func _on_game_over(final_score: int, did_win: bool) -> void:
	"""Game ended"""
	if did_win:
		show_status_message("VICTORY! Final Score: %d" % final_score, 999.0)
	else:
		show_status_message("GAME OVER - Final Score: %d" % final_score, 999.0)

func _on_score_changed(new_score: int) -> void:
	"""Score updated"""
	_update_display()

func _on_silo_fired(silo_index: int, target_position: Vector3) -> void:
	"""Silo fired - decrement ammo (if not destroyed)"""
	if silo_index >= 0 and silo_index < silo_ammo.size():
		if silo_ammo[silo_index] > 0:  # Only decrement if not destroyed
			silo_ammo[silo_index] -= 1
			_update_display()

func _on_silo_destroyed(silo_index: int) -> void:
	"""Silo destroyed"""
	if silo_index >= 0 and silo_index < silo_ammo.size():
		silo_ammo[silo_index] = -1  # Mark as destroyed
		_update_display()

func _on_city_destroyed(city_index: int) -> void:
	"""City destroyed"""
	_update_display()
