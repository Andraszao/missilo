extends Control
# HUD: Heads-up display for game state and player feedback

@onready var wave_label: Label   = $MarginContainer/VBoxContainer/WaveLabel
@onready var score_label: Label  = $MarginContainer/VBoxContainer/ScoreLabel
@onready var ammo_label: Label   = $MarginContainer/VBoxContainer/AmmoLabel
@onready var cities_label: Label = $MarginContainer/VBoxContainer/CitiesLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var silo_ammo: Array[int] = [7, 7, 7]
var _combo_mult: int = 1
var _combo_label: Label
var _behaviors_label: Label
var _refresh_timer: Timer

func _ready() -> void:
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 22)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.anchor_left   = 0.5
	_combo_label.anchor_right  = 0.5
	_combo_label.anchor_top    = 0.0
	_combo_label.anchor_bottom = 0.0
	_combo_label.offset_left   = -150.0
	_combo_label.offset_right  =  150.0
	_combo_label.offset_top    =  12.0
	_combo_label.offset_bottom =  50.0
	_combo_label.visible = false
	add_child(_combo_label)

	_behaviors_label = Label.new()
	_behaviors_label.add_theme_font_size_override("font_size", 10)
	_behaviors_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
	_behaviors_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_behaviors_label.anchor_left   = 0.0
	_behaviors_label.anchor_right  = 1.0
	_behaviors_label.anchor_top    = 1.0
	_behaviors_label.anchor_bottom = 1.0
	_behaviors_label.offset_top    = -38.0
	_behaviors_label.offset_bottom = -10.0
	add_child(_behaviors_label)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 2.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_behavior_chips)
	add_child(_refresh_timer)

	GameManager.game_started.connect(_on_game_started)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_cleared.connect(_on_wave_cleared)
	GameManager.game_over.connect(_on_game_over)
	GameManager.score_changed.connect(_on_score_changed)
	EventBus.silo_ammo_changed.connect(_on_silo_ammo_changed)
	EventBus.silo_destroyed.connect(_on_silo_destroyed)
	EventBus.city_destroyed.connect(_on_city_destroyed)
	EventBus.combo_changed.connect(_on_combo_changed)

	_update_display()

func _refresh_behavior_chips() -> void:
	var silos = get_tree().get_nodes_in_group("player_silo")
	if silos.is_empty():
		return
	silos.sort_custom(func(a, b): return a.silo_index < b.silo_index)
	var parts: Array = []
	for silo in silos:
		if not silo.is_active:
			parts.append("[DEAD]")
			continue
		var stats = silo.calculate_stats()
		var b = stats.get("behaviors", {})
		var chips: Array = []
		if b.get("split", 1) > 1:       chips.append("SPLIT x%d" % b["split"])
		if b.get("homing", 0.0) > 0.1:  chips.append("HOME")
		if b.get("chain_depth", 0) > 0: chips.append("CHAIN x%d" % b["chain_depth"])
		if b.get("pulse", 1) > 1:       chips.append("PULSE x%d" % b["pulse"])
		if b.get("magnetic", false):     chips.append("MAG")
		if b.get("amplify", false):      chips.append("AMP")
		if chips.is_empty():
			parts.append("base")
		else:
			parts.append(" ".join(chips))
	_behaviors_label.text = "  |  ".join(parts)

func _update_display() -> void:
	wave_label.text  = "Wave: %d" % GameManager.current_wave
	score_label.text = "Score: %d" % GameManager.score
	cities_label.text = "Cities: %d" % GameManager.cities_alive

	var ammo_text = "Ammo: "
	for i in range(3):
		if silo_ammo[i] < 0:
			ammo_text += "[X] "
		else:
			ammo_text += "[%d] " % silo_ammo[i]
	ammo_label.text = ammo_text

	if _combo_mult > 1:
		_combo_label.text = "x%d COMBO" % _combo_mult
		_combo_label.visible = true
	else:
		_combo_label.visible = false

func show_status_message(message: String, duration: float = 2.0) -> void:
	status_label.text = message
	status_label.visible = true
	await get_tree().create_timer(duration).timeout
	status_label.visible = false

func _on_game_started() -> void:
	# Use actual starting ammo (base 7 + any tree bonus) rather than hardcoding
	var base_ammo = 7 + GameManager.starting_ammo_bonus
	silo_ammo = [base_ammo, base_ammo, base_ammo]
	status_label.visible = false
	_update_display()
	_refresh_behavior_chips()

func _on_wave_started(wave_number: int) -> void:
	_update_display()
	show_status_message("Wave %d - Incoming!" % wave_number, 1.5)

func _on_wave_cleared(wave_number: int) -> void:
	# Read actual max_ammo from each silo so modifier-boosted ammo counts correctly
	var silos = get_tree().get_nodes_in_group("player_silo")
	silos.sort_custom(func(a, b): return a.silo_index < b.silo_index)
	for silo in silos:
		var idx = silo.silo_index
		if idx >= 0 and idx < silo_ammo.size() and silo_ammo[idx] >= 0:
			silo_ammo[idx] = silo.max_ammo
	_update_display()
	show_status_message("Wave %d Clear!" % wave_number, 2.0)

func _on_game_over(final_score: int, did_win: bool) -> void:
	if did_win:
		show_status_message("VICTORY! Final Score: %d" % final_score, 999.0)
	else:
		show_status_message("GAME OVER - Final Score: %d" % final_score, 999.0)

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

func _on_combo_changed(mult: int) -> void:
	_combo_mult = mult
	_update_display()
