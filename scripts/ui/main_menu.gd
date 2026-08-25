class_name MainMenu extends CanvasLayer

var _diff_buttons: Array[Button] = []

func _ready() -> void:
	layer = 20
	_build_ui()
	# Show main menu on start; hide when game begins
	GameManager.game_started.connect(func(): visible = false)
	GameManager.game_over.connect(_on_game_over)

func _build_ui() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.08, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "MISSILO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Defend or Die"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	vbox.add_child(sub)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(spacer)

	var start_btn = Button.new()
	start_btn.text = "START MISSION"
	start_btn.custom_minimum_size = Vector2(240, 56)
	start_btn.pressed.connect(func(): GameManager.start_game())
	vbox.add_child(start_btn)

	# Difficulty row
	var diff_hbox = HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(diff_hbox)

	var diff_label = Label.new()
	diff_label.text = "Difficulty:"
	diff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	diff_hbox.add_child(diff_label)

	var diff_names: Array[String] = ["EASY", "NORMAL", "HARD"]
	for i in range(3):
		var btn = Button.new()
		btn.text = diff_names[i]
		btn.custom_minimum_size = Vector2(90, 40)
		var idx := i  # capture index for closure
		btn.pressed.connect(func(): _on_difficulty_selected(idx))
		diff_hbox.add_child(btn)
		_diff_buttons.append(btn)

	# Highlight the current default difficulty (NORMAL)
	_update_difficulty_visuals(GameManager.difficulty)

func _on_difficulty_selected(idx: int) -> void:
	GameManager.set_difficulty(idx)
	_update_difficulty_visuals(idx)

func _update_difficulty_visuals(selected: int) -> void:
	"""Highlight the selected button; dim the others."""
	for i in range(_diff_buttons.size()):
		if i == selected:
			_diff_buttons[i].modulate = Color(1.0, 0.85, 0.2, 1.0)  # golden highlight
		else:
			_diff_buttons[i].modulate = Color(1.0, 1.0, 1.0, 0.5)   # dimmed

func _on_game_over(_score: int, _win: bool) -> void:
	pass  # GameOverScreen handles the game over state
