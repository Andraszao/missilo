class_name AchievementPopup
extends CanvasLayer
# AchievementPopup: Toast notifications for achievement unlocks (P7)
#
# Autoloaded CanvasLayer (layer 20) that listens for EventBus.achievement_unlocked
# and shows a brief top-right toast: "ACHIEVEMENT: {label}" for 3 s then fades out.
# Multiple unlocks are queued and displayed one at a time.

var _queue: Array[String] = []
var _showing: bool = false
var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	layer = 20
	_build_panel()
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)

func _build_panel() -> void:
	# Full-viewport Control so child anchors resolve against viewport dimensions.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_panel = PanelContainer.new()
	# Anchor to top-right and grow leftward.
	_panel.anchor_left  = 1.0
	_panel.anchor_top   = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left   = -310.0
	_panel.offset_right  = -10.0
	_panel.offset_top    = 10.0
	_panel.offset_bottom = 70.0
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",     6)
	margin.add_theme_constant_override("margin_bottom",  6)
	_panel.add_child(margin)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(_label)

	_panel.hide()

func _on_achievement_unlocked(_id: String, lbl: String) -> void:
	_queue.append(lbl)
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	_label.text = "ACHIEVEMENT: %s" % _queue.pop_front()
	_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_panel.show()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_on_fade_done)

func _on_fade_done() -> void:
	_panel.hide()
	_show_next()
