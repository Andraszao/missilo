class_name WaveEndScreen extends CanvasLayer
# WaveEndScreen: Programmatic UI for wave-end upgrade selection
#
# Built entirely in GDScript — no .tscn file required.
# Shows 3 upgrade cards, a silo selector, and confirm/skip buttons.
# Auto-skips after 20 seconds if the player does not choose.

signal upgrade_confirmed(modifier: MissileModifier, silo_index: int)
signal upgrade_skipped

var _selected_modifier: MissileModifier = null
var _selected_silo: int = 1  # default center
var _modifier_cards: Array[Button] = []
var _silo_buttons: Array[Button] = []
var _confirm_btn: Button
var _title_label: Label
var _timer: Timer

func _ready() -> void:
	layer = 10
	visible = false
	_build_layout()

func _build_layout() -> void:
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	# Label: Pick an upgrade
	var pick_label = Label.new()
	pick_label.text = "Select an upgrade for one silo:"
	pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pick_label)

	# 3 upgrade card buttons in HBox
	var cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 12)
	vbox.add_child(cards_box)

	for i in range(3):
		var card = Button.new()
		card.custom_minimum_size = Vector2(200, 100)
		card.text = "..."
		card.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.pressed.connect(_on_card_pressed.bind(i))
		cards_box.add_child(card)
		_modifier_cards.append(card)

	# Silo selector
	var silo_label = Label.new()
	silo_label.text = "Apply to silo:"
	silo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(silo_label)

	var silo_box = HBoxContainer.new()
	silo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	silo_box.add_theme_constant_override("separation", 8)
	vbox.add_child(silo_box)

	var silo_names = ["LEFT", "CENTER", "RIGHT"]
	for i in range(3):
		var btn = Button.new()
		btn.text = silo_names[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 1)  # default center
		btn.pressed.connect(_on_silo_btn_pressed.bind(i))
		silo_box.add_child(btn)
		_silo_buttons.append(btn)

	# Confirm + Skip buttons
	var action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 16)
	vbox.add_child(action_box)

	_confirm_btn = Button.new()
	_confirm_btn.text = "CONFIRM"
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	action_box.add_child(_confirm_btn)

	var skip_btn = Button.new()
	skip_btn.text = "SKIP"
	skip_btn.pressed.connect(_on_skip)
	action_box.add_child(skip_btn)

	# Auto-skip timer (20s)
	_timer = Timer.new()
	_timer.wait_time = 20.0
	_timer.one_shot = true
	_timer.timeout.connect(_on_skip)
	add_child(_timer)

func present_choices(wave: int, choices: Array[MissileModifier]) -> void:
	_title_label.text = "WAVE %d COMPLETE!" % wave
	_selected_modifier = null
	_selected_silo = 1
	_confirm_btn.disabled = true

	for i in range(_modifier_cards.size()):
		if i < choices.size():
			var mod = choices[i]
			_modifier_cards[i].text = "%s\n%s" % [mod.modifier_name, mod.description]
			_modifier_cards[i].set_meta("modifier", mod)
			_modifier_cards[i].disabled = false
			_modifier_cards[i].button_pressed = false
		else:
			_modifier_cards[i].text = "(none)"
			_modifier_cards[i].disabled = true

	# Reset silo buttons, then disable buttons for destroyed silos
	for btn in _silo_buttons:
		btn.disabled = false
		btn.button_pressed = false
	_silo_buttons[1].button_pressed = true

	var silos = get_tree().get_nodes_in_group("player_silo")
	for silo in silos:
		if not silo.is_active:
			_silo_buttons[silo.silo_index].disabled = true

	visible = true
	_timer.start()

func _on_card_pressed(index: int) -> void:
	for i in range(_modifier_cards.size()):
		if i != index:
			_modifier_cards[i].button_pressed = false
	if _modifier_cards[index].has_meta("modifier"):
		_selected_modifier = _modifier_cards[index].get_meta("modifier")
	_confirm_btn.disabled = (_selected_modifier == null)

func _on_silo_btn_pressed(index: int) -> void:
	_selected_silo = index
	for i in range(_silo_buttons.size()):
		if i != index:
			_silo_buttons[i].button_pressed = false

func _on_confirm() -> void:
	if _selected_modifier == null:
		return
	_timer.stop()
	visible = false
	upgrade_confirmed.emit(_selected_modifier, _selected_silo)

func _on_skip() -> void:
	_timer.stop()
	visible = false
	upgrade_skipped.emit()
