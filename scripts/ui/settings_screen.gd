class_name SettingsScreen
extends CanvasLayer

signal closed

const SAVE_PATH := "user://settings.cfg"
var _master_vol: float = 1.0
var _music_vol: float  = 1.0
var _sfx_vol: float    = 1.0
var _music_on: bool    = true

func _ready() -> void:
	layer = 18
	_load_settings()
	_build_ui()
	hide()

func _build_ui() -> void:
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 320)
	center.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.12, 1.0)
	style.border_color = Color(0.3, 1.0, 0.65, 0.4)
	style.border_width_left = 1; style.border_width_right  = 1
	style.border_width_top  = 1; style.border_width_bottom = 1
	style.content_margin_left  = 24; style.content_margin_right  = 24
	style.content_margin_top   = 20; style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
	vbox.add_child(title)

	vbox.add_child(_make_separator())
	vbox.add_child(_make_slider("Master Volume", _master_vol, func(v): _set_master(v)))
	vbox.add_child(_make_slider("Music Volume",  _music_vol,  func(v): _set_music(v)))
	vbox.add_child(_make_slider("SFX Volume",    _sfx_vol,    func(v): _set_sfx(v)))
	vbox.add_child(_make_toggle("Music On",      _music_on,   func(v): _set_music_on(v)))
	vbox.add_child(_make_separator())

	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(func(): hide(); closed.emit(); _save_settings())
	vbox.add_child(close_btn)

func _make_slider(label_text: String, initial: float, on_change: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row

func _make_toggle(label_text: String, initial: bool, on_change: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var btn = CheckButton.new()
	btn.button_pressed = initial
	btn.toggled.connect(on_change)
	row.add_child(btn)
	return row

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.3, 0.3, 0.3, 0.5))
	return sep

func _set_master(v: float) -> void:
	_master_vol = v
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(max(v, 0.001)))

func _set_music(v: float) -> void:
	_music_vol = v
	if AudioManager and AudioManager.has_method("set_music_volume"):
		AudioManager.set_music_volume(v)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.001)))

func _set_sfx(v: float) -> void:
	_sfx_vol = v

func _set_music_on(v: bool) -> void:
	_music_on = v
	if AudioManager:
		AudioManager._music_enabled = v

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return
	_master_vol = cfg.get_value("audio", "master", 1.0)
	_music_vol  = cfg.get_value("audio", "music",  1.0)
	_sfx_vol    = cfg.get_value("audio", "sfx",    1.0)
	_music_on   = cfg.get_value("audio", "music_on", true)
	_apply_saved()

func _apply_saved() -> void:
	_set_master(_master_vol)
	_set_music(_music_vol)
	if AudioManager: AudioManager._music_enabled = _music_on

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master",   _master_vol)
	cfg.set_value("audio", "music",    _music_vol)
	cfg.set_value("audio", "sfx",      _sfx_vol)
	cfg.set_value("audio", "music_on", _music_on)
	cfg.save(SAVE_PATH)
