extends Control
# WaveEndScreen: Roguelike upgrade selection overlay shown between waves
#
# Fully programmatic — no .tscn required.
# Presents 3 modifier cards. Player selects one and assigns it to a silo.
# Emits upgrade_confirmed or upgrade_skipped for UpgradeManager to act on.

# ============================================================================
# SIGNALS
# ============================================================================

signal upgrade_confirmed(modifier: MissileModifier, silo_index: int)
signal upgrade_skipped

# ============================================================================
# CONSTANTS
# ============================================================================

const CARD_MIN_SIZE := Vector2(200.0, 140.0)
const SILO_LABELS: Array = ["LEFT", "CENTER", "RIGHT"]

# ============================================================================
# STATE
# ============================================================================

var _selected_modifier: MissileModifier = null
var _selected_silo_index: int = 1
var _card_buttons: Array[Button] = []
var _silo_buttons: Array[Button] = []

# ============================================================================
# NODES (built programmatically)
# ============================================================================

var _title_label: Label
var _cards_row: HBoxContainer
var _silo_row: HBoxContainer
var _confirm_button: Button

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_build_layout()
	hide()
	EventBus.silo_destroyed.connect(_on_silo_destroyed)

func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_add_background_overlay()

	var panel := _create_center_panel()
	var vbox := _create_vbox_inside(panel)

	_title_label = _add_title(vbox)
	_add_subtitle(vbox)
	_cards_row = _add_cards_row(vbox)
	_add_silo_prompt(vbox)
	_silo_row = _add_silo_row(vbox)
	_add_action_row(vbox)

func _add_background_overlay() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.08, 0.88)
	add_child(bg)

func _create_center_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720.0, 440.0)
	panel.offset_left = -360.0
	panel.offset_top = -220.0
	panel.offset_right = 360.0
	panel.offset_bottom = 220.0
	add_child(panel)
	return panel

func _create_vbox_inside(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set("theme_override_constants/margin_left", 24)
	margin.set("theme_override_constants/margin_right", 24)
	margin.set("theme_override_constants/margin_top", 20)
	margin.set("theme_override_constants/margin_bottom", 20)
	parent.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 16)
	margin.add_child(vbox)
	return vbox

func _add_title(parent: Control) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set("theme_override_font_sizes/font_size", 30)
	parent.add_child(lbl)
	return lbl

func _add_subtitle(parent: Control) -> void:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set("theme_override_font_sizes/font_size", 16)
	lbl.text = "Choose an upgrade for your arsenal:"
	parent.add_child(lbl)

func _add_cards_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set("theme_override_constants/separation", 14)
	parent.add_child(row)
	return row

func _add_silo_prompt(parent: Control) -> void:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set("theme_override_font_sizes/font_size", 15)
	lbl.text = "Assign to silo:"
	parent.add_child(lbl)

func _add_silo_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set("theme_override_constants/separation", 12)
	parent.add_child(row)
	return row

func _add_action_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set("theme_override_constants/separation", 20)
	parent.add_child(row)

	_confirm_button = Button.new()
	_confirm_button.text = "Equip Upgrade"
	_confirm_button.custom_minimum_size = Vector2(160.0, 44.0)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	row.add_child(_confirm_button)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(100.0, 44.0)
	skip_btn.pressed.connect(_on_skip_pressed)
	row.add_child(skip_btn)

# ============================================================================
# PUBLIC API
# ============================================================================

func present_choices(wave_number: int, choices: Array[MissileModifier]) -> void:
	_selected_modifier = null
	_selected_silo_index = _find_default_silo()
	_confirm_button.disabled = true
	_title_label.text = "WAVE %d CLEAR!" % wave_number

	_populate_cards(choices)
	_populate_silo_buttons()
	show()

# ============================================================================
# CARD POPULATION
# ============================================================================

func _populate_cards(choices: Array[MissileModifier]) -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_card_buttons.clear()

	for modifier in choices:
		var card := _create_card(modifier)
		_cards_row.add_child(card)
		_card_buttons.append(card)

func _create_card(modifier: MissileModifier) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CARD_MIN_SIZE
	btn.toggle_mode = true
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.text = "%s\n\n%s\n\n[%s]" % [modifier.modifier_name, modifier.description, modifier.category]
	btn.pressed.connect(func(): _on_card_pressed(modifier, btn))
	return btn

# ============================================================================
# SILO BUTTON POPULATION
# ============================================================================

func _populate_silo_buttons() -> void:
	for child in _silo_row.get_children():
		child.queue_free()
	_silo_buttons.clear()

	var states: Array[bool] = _query_silo_states()

	for i in range(3):
		var btn := Button.new()
		btn.text = SILO_LABELS[i]
		btn.custom_minimum_size = Vector2(110.0, 40.0)
		btn.toggle_mode = true
		btn.disabled = not states[i]
		btn.button_pressed = (i == _selected_silo_index and states[i])

		var idx: int = i  # capture for closure
		btn.pressed.connect(func(): _on_silo_pressed(idx, btn))
		_silo_row.add_child(btn)
		_silo_buttons.append(btn)

func _query_silo_states() -> Array[bool]:
	var states: Array[bool] = [true, true, true]
	var container: Node = get_node_or_null("/root/Main/Silos")
	if container == null:
		return states
	for child in container.get_children():
		if "silo_index" in child and "is_active" in child:
			var idx: int = child.silo_index
			if idx >= 0 and idx < 3:
				states[idx] = child.is_active
	return states

func _find_default_silo() -> int:
	var states: Array[bool] = _query_silo_states()
	for preferred in [1, 0, 2]:
		if states[preferred]:
			return preferred
	return 0

# ============================================================================
# INPUT HANDLERS
# ============================================================================

func _on_card_pressed(modifier: MissileModifier, pressed_btn: Button) -> void:
	for btn in _card_buttons:
		btn.button_pressed = false
	pressed_btn.button_pressed = true
	_selected_modifier = modifier
	_confirm_button.disabled = false

func _on_silo_pressed(index: int, pressed_btn: Button) -> void:
	for btn in _silo_buttons:
		btn.button_pressed = false
	pressed_btn.button_pressed = true
	_selected_silo_index = index

func _on_confirm_pressed() -> void:
	if _selected_modifier == null:
		return
	upgrade_confirmed.emit(_selected_modifier, _selected_silo_index)

func _on_skip_pressed() -> void:
	upgrade_skipped.emit()

func _on_silo_destroyed(_silo_index: int) -> void:
	if is_visible():
		_populate_silo_buttons()
