class_name RunSummary
extends CanvasLayer

const NEON_GREEN := Color(0.247, 1.0, 0.541)
const WIN_COLOR  := Color(0.2, 1.0, 0.4)
const LOSE_COLOR := Color(1.0, 0.3, 0.3)
const GOLD_COLOR := Color(1.0, 0.8, 0.0)
const BG_COLOR   := Color(0.0, 0.0, 0.0, 0.92)

var _header_label:   Label
var _wave_label:     Label
var _missiles_label: Label
var _combo_label:    Label
var _salvage_label:  Label
var _dismissed: bool = false

signal run_summary_dismissed

func _ready() -> void:
	layer = 11
	_build_ui()
	hide()
	GameManager.game_over.connect(_on_game_over)

func _build_ui() -> void:
	# Full-screen dimming backdrop
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 260.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	# Header (win / lose colour set in _populate_data)
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 22)
	inner.add_child(_header_label)

	inner.add_child(HSeparator.new())

	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 14)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	inner.add_child(_wave_label)

	_missiles_label = Label.new()
	_missiles_label.add_theme_font_size_override("font_size", 14)
	_missiles_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	inner.add_child(_missiles_label)

	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 14)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	inner.add_child(_combo_label)

	_salvage_label = Label.new()
	_salvage_label.add_theme_font_size_override("font_size", 14)
	_salvage_label.add_theme_color_override("font_color", GOLD_COLOR)
	inner.add_child(_salvage_label)

	inner.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "Auto-continuing in 6s..."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	inner.add_child(hint)

	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE"
	cont_btn.add_theme_color_override("font_color", NEON_GREEN)
	cont_btn.add_theme_font_size_override("font_size", 14)
	cont_btn.pressed.connect(_dismiss)
	inner.add_child(cont_btn)

func _on_game_over(_score: int, did_win: bool) -> void:
	_dismissed = false
	_populate_data(did_win)
	show()
	await get_tree().create_timer(6.0).timeout
	if not _dismissed:
		_dismiss()

func _populate_data(did_win: bool) -> void:
	if did_win:
		_header_label.text = "RUN COMPLETE"
		_header_label.add_theme_color_override("font_color", WIN_COLOR)
	else:
		_header_label.text = "CITY DESTROYED"
		_header_label.add_theme_color_override("font_color", LOSE_COLOR)

	var history := ProgressionManager.get_run_history()
	if history.size() > 0:
		var last: Dictionary = history[history.size() - 1]
		_wave_label.text     = "Wave reached:        %d"  % last.get("wave",       0)
		_missiles_label.text = "Missiles destroyed:  %d"  % last.get("missiles",   0)
		_combo_label.text    = "Peak combo:          x%d" % last.get("peak_combo", 0)
		_salvage_label.text  = "Salvage earned:      +%d" % last.get("salvage",    0)
	else:
		_wave_label.text     = "Wave reached:        0"
		_missiles_label.text = "Missiles destroyed:  0"
		_combo_label.text    = "Peak combo:          x0"
		_salvage_label.text  = "Salvage earned:      +0"

func _dismiss() -> void:
	_dismissed = true
	hide()
	run_summary_dismissed.emit()
