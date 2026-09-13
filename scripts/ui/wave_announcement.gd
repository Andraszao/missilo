class_name WaveAnnouncement
extends CanvasLayer

var _label: Label
var _container: Control

func _ready() -> void:
	layer = 8
	_build_ui()
	hide()
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.game_started.connect(func(): hide())

func _build_ui() -> void:
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 72)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.anchor_left   = 0.5; _label.anchor_right  = 0.5
	_label.anchor_top    = 0.5; _label.anchor_bottom = 0.5
	_label.offset_left   = -200.0; _label.offset_right  = 200.0
	_label.offset_top    = -60.0;  _label.offset_bottom = 60.0
	_container.add_child(_label)

func _on_wave_started(wave_number: int) -> void:
	_label.text = "WAVE  %d" % wave_number
	_label.scale = Vector3(0.3, 0.3, 1.0) if _label.scale is Vector3 else Vector2(0.3, 0.3)
	_label.modulate.a = 1.0
	show()
	var tw = create_tween()
	tw.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55)
	tw.tween_property(_label, "modulate:a", 0.0, 0.22)
	tw.tween_callback(hide)
