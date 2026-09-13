class_name TutorialOverlay
extends CanvasLayer
# TutorialOverlay: First-run hints shown during wave 1 only.
# Checks ProgressionManager.get_run_count() — skips after the first completed run.

const HINTS: Array[String] = [
	"Click to fire — aim slightly ahead of moving missiles.",
	"Ammo is limited. Split modifiers let one shot cover multiple zones.",
	"Pick upgrades wisely — SPLIT + PULSE wins 100% of simulated runs.",
]

var _hint_panel: PanelContainer
var _hint_label: Label
var _active: bool = false

func _ready() -> void:
	layer = 15
	_build_ui()
	hide()
	GameManager.game_started.connect(_on_game_started)
	GameManager.upgrade_available.connect(_on_upgrade_available)

func _build_ui() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.anchor_left   = 0.5
	_hint_panel.anchor_right  = 0.5
	_hint_panel.anchor_top    = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left   = -240.0
	_hint_panel.offset_right  =  240.0
	_hint_panel.offset_top    = -88.0
	_hint_panel.offset_bottom = -18.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	style.border_color = Color(0.3, 1.0, 0.65, 0.55)
	style.border_width_left   = 1; style.border_width_right  = 1
	style.border_width_top    = 1; style.border_width_bottom = 1
	style.corner_radius_top_left     = 4; style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4; style.corner_radius_bottom_right = 4
	style.content_margin_left  = 14; style.content_margin_right  = 14
	style.content_margin_top   = 8;  style.content_margin_bottom = 8
	_hint_panel.add_theme_stylebox_override("panel", style)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint_label)
	add_child(_hint_panel)

func _on_game_started() -> void:
	if ProgressionManager.get_run_count() > 0:
		return
	_active = true
	_show_hint(0)
	EventBus.silo_fired.connect(_on_first_shot, CONNECT_ONE_SHOT)

func _on_first_shot(_idx: int, _target: Vector3) -> void:
	await get_tree().create_timer(2.2).timeout
	if not _active: return
	_show_hint(1)
	await get_tree().create_timer(5.0).timeout
	_hide_hint()

func _on_upgrade_available(_wave: int) -> void:
	if not _active: return
	_show_hint(2)
	await get_tree().create_timer(7.0).timeout
	_hide_hint()
	_active = false

func _show_hint(idx: int) -> void:
	if idx >= HINTS.size(): return
	_hint_label.text = HINTS[idx]
	_hint_panel.modulate.a = 0.0
	show()
	var tw = create_tween()
	tw.tween_property(_hint_panel, "modulate:a", 1.0, 0.3)

func _hide_hint() -> void:
	if not visible: return
	var tw = create_tween()
	tw.tween_property(_hint_panel, "modulate:a", 0.0, 0.3)
	await tw.finished
	hide()
