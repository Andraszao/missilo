class_name GameOverScreen extends CanvasLayer

var _title_lbl: Label
var _score_lbl: Label
var _wave_lbl: Label
var _history_box: VBoxContainer

func _ready() -> void:
	layer = 21
	visible = false
	_build_ui()
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_started.connect(func(): visible = false)

func _build_ui() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 52)
	vbox.add_child(_title_lbl)

	_score_lbl = Label.new()
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_score_lbl)

	_wave_lbl = Label.new()
	_wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_wave_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var retry_btn = Button.new()
	retry_btn.text = "PLAY AGAIN"
	retry_btn.custom_minimum_size = Vector2(200, 52)
	retry_btn.pressed.connect(func(): visible = false; GameManager.start_game())
	vbox.add_child(retry_btn)

	_history_box = VBoxContainer.new()
	_history_box.add_theme_constant_override("separation", 4)
	_history_box.visible = false
	vbox.add_child(_history_box)

func _on_game_over(final_score: int, did_win: bool) -> void:
	_title_lbl.text = "VICTORY!" if did_win else "GAME OVER"
	_score_lbl.text = "Score: %d" % final_score
	_wave_lbl.text = "Wave reached: %d" % GameManager.current_wave
	_populate_history()
	visible = true

func _populate_history() -> void:
	for child in _history_box.get_children():
		child.queue_free()

	var history: Array = ProgressionManager.get_run_history()
	if history.is_empty():
		_history_box.visible = false
		return

	var heading = Label.new()
	heading.text = "RECENT RUNS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_history_box.add_child(heading)

	var reversed_history: Array = history.duplicate()
	reversed_history.reverse()
	for run in reversed_history:
		var lbl = Label.new()
		lbl.text = "Wave %d  —  %d pts" % [run.wave, run.score]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_history_box.add_child(lbl)

	_history_box.visible = true
