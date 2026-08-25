class_name TutorialOverlay extends CanvasLayer

const HINTS: Array[String] = [
	"Click to fire — aim ahead of moving missiles",
	"Ammo is limited. Split modifiers let one shot cover multiple zones.",
	"Pick upgrades wisely — SPLIT + PULSE wins 100% of runs in simulation.",
]

var _panel: PanelContainer = null
var _label: Label = null

func _ready() -> void:
	layer = 15
	GameManager.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	if ProgressionManager.get_run_count() > 1:
		return
	show_hint(0)
	EventBus.silo_fired.connect(_on_first_shot, CONNECT_ONE_SHOT)

func _on_first_shot(_i, _t) -> void:
	await get_tree().create_timer(2.5).timeout
	show_hint(1)
	await get_tree().create_timer(3.0).timeout
	show_hint(2)
	await get_tree().create_timer(4.0).timeout
	_clear()

func show_hint(idx: int) -> void:
	_clear()

	_panel = PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.text = HINTS[idx]
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(400, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)

	add_child(_panel)

	# Wait one frame so the panel's layout and size are computed before positioning.
	await get_tree().process_frame

	if not is_instance_valid(_panel):
		return

	var vp_size := get_viewport().get_visible_rect().size
	var panel_size := _panel.size
	_panel.position = Vector2(
		(vp_size.x - panel_size.x) * 0.5,
		vp_size.y * 0.8 - panel_size.y * 0.5
	)

	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

func _clear() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_label = null
