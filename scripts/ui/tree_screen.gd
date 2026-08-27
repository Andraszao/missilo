class_name TreeScreen
extends CanvasLayer

const NEON_GREEN  := Color(0.247, 1.0, 0.541)   # #3FFF8A
const GREY_LOCKED := Color(0.45, 0.45, 0.45)
const WHITE_DONE  := Color(1.0, 1.0, 1.0)
const BG_COLOR    := Color(0.0, 0.0, 0.0, 0.88)

var _salvage_label: Label
var _node_rows_container: VBoxContainer
var _prestige_btn: Button

func _ready() -> void:
	layer = 12
	_build_ui()
	hide()
	GameManager.game_over.connect(_on_game_over)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Full-screen dim background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Outer centering container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Fixed-width panel
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(480.0, 0.0)
	panel.add_theme_constant_override("separation", 10)
	center.add_child(panel)

	# Title
	var title := Label.new()
	title.text = "SALVAGE DEPOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", NEON_GREEN)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)

	# Salvage balance
	_salvage_label = Label.new()
	_salvage_label.text = "SALVAGE: 0"
	_salvage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_salvage_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_salvage_label)

	# Separator
	var sep := HSeparator.new()
	panel.add_child(sep)

	# Scrollable node list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480.0, 300.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_node_rows_container = VBoxContainer.new()
	_node_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_rows_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_node_rows_container)

	# Bottom separator
	var sep2 := HSeparator.new()
	panel.add_child(sep2)

	# Prestige button (hidden by default)
	_prestige_btn = Button.new()
	_prestige_btn.text = "PRESTIGE (reset tree, keep bonus)"
	_prestige_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	_prestige_btn.visible = false
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	panel.add_child(_prestige_btn)

	# Continue button
	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE"
	cont_btn.add_theme_color_override("font_color", NEON_GREEN)
	cont_btn.add_theme_font_size_override("font_size", 16)
	cont_btn.pressed.connect(_on_continue_pressed)
	panel.add_child(cont_btn)

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------
func _on_game_over(_score: int, _did_win: bool) -> void:
	_refresh_nodes()
	_update_salvage_label()
	_prestige_btn.visible = ProgressionManager.can_prestige()
	show()

func _on_continue_pressed() -> void:
	hide()

func _on_prestige_pressed() -> void:
	ProgressionManager.prestige()
	_refresh_nodes()
	_update_salvage_label()
	_prestige_btn.visible = ProgressionManager.can_prestige()

func _on_buy_pressed(node_id: String) -> void:
	ProgressionManager.purchase_node(node_id)
	_refresh_nodes()
	_update_salvage_label()

# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------
func _update_salvage_label() -> void:
	_salvage_label.text = "SALVAGE: %d" % ProgressionManager.get_salvage_points()

func _refresh_nodes() -> void:
	# Clear existing rows
	for child in _node_rows_container.get_children():
		child.queue_free()

	_update_salvage_label()

	for node_id in ProgressionManager.UNLOCK_TREE:
		var data: Dictionary = ProgressionManager.UNLOCK_TREE[node_id]
		var purchased: bool = ProgressionManager.is_node_purchased(node_id)
		var can_buy: bool   = ProgressionManager.can_purchase_node(node_id)

		# Determine if prerequisites are met (ignoring cost)
		var reqs_met := true
		for req in data["requires"]:
			if not ProgressionManager.is_node_purchased(req):
				reqs_met = false
				break
		var locked: bool = not reqs_met and not purchased

		# Row container
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		_node_rows_container.add_child(row)

		# Left text block
		var info_col := VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_col)

		# Node name + cost
		var name_label := Label.new()
		var display_name := node_id.replace("_", " ").to_upper()
		name_label.text = "%s  [%d sp]" % [display_name, data["cost"]]
		name_label.add_theme_font_size_override("font_size", 13)
		if purchased:
			name_label.add_theme_color_override("font_color", WHITE_DONE)
		elif locked:
			name_label.add_theme_color_override("font_color", GREY_LOCKED)
		else:
			name_label.add_theme_color_override("font_color", NEON_GREEN)
		info_col.add_child(name_label)

		# Effect description
		var effect_label := Label.new()
		effect_label.text = data["effect"]
		effect_label.add_theme_font_size_override("font_size", 11)
		effect_label.add_theme_color_override("font_color", GREY_LOCKED)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_col.add_child(effect_label)

		# Prerequisites note when locked
		if locked and data["requires"].size() > 0:
			var req_label := Label.new()
			var req_names := ", ".join(PackedStringArray(data["requires"]))
			req_label.text = "Requires: " + req_names.replace("_", " ")
			req_label.add_theme_font_size_override("font_size", 10)
			req_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
			info_col.add_child(req_label)

		# Right-side status / action
		if purchased:
			var done_lbl := Label.new()
			done_lbl.text = "PURCHASED"
			done_lbl.add_theme_font_size_override("font_size", 12)
			done_lbl.add_theme_color_override("font_color", WHITE_DONE)
			row.add_child(done_lbl)
		elif locked:
			var lock_lbl := Label.new()
			lock_lbl.text = "LOCKED"
			lock_lbl.add_theme_font_size_override("font_size", 12)
			lock_lbl.add_theme_color_override("font_color", GREY_LOCKED)
			row.add_child(lock_lbl)
		else:
			# Show BUY button; disabled if can't afford
			var buy_btn := Button.new()
			buy_btn.text = "BUY"
			buy_btn.disabled = not can_buy
			if can_buy:
				buy_btn.add_theme_color_override("font_color", NEON_GREEN)
			# Capture node_id by value in the closure
			var captured_id := node_id
			buy_btn.pressed.connect(func(): _on_buy_pressed(captured_id))
			row.add_child(buy_btn)

		# Thin separator between rows
		_node_rows_container.add_child(HSeparator.new())
