extends CanvasLayer
## Finestra chiudibile per il feel di salto. F3 apre/chiude. Salva solo se premi Salva.

const USER_SAVE := "user://feel_tuning.cfg"
const PROJECT_SAVE := "res://Player/feel_tuning.cfg"

const TUNING := [
	{"key": "move_speed", "label": "Camminata", "min": 80.0, "max": 220.0, "step": 1.0},
	{"key": "gravity", "label": "Gravita salita", "min": 400.0, "max": 1800.0, "step": 10.0},
	{"key": "fall_gravity", "label": "Gravita caduta", "min": 600.0, "max": 3200.0, "step": 20.0},
	{"key": "max_fall_speed", "label": "Vel. max caduta", "min": 220.0, "max": 800.0, "step": 10.0},
	{"key": "jump_speed", "label": "Forza salto", "min": 220.0, "max": 720.0, "step": 5.0},
	{"key": "jump_acceleration", "label": "Doppio salto", "min": 260.0, "max": 820.0, "step": 5.0},
	{"key": "jump_cut_multiplier", "label": "Taglio rilascio", "min": 0.2, "max": 0.9, "step": 0.05},
	{"key": "var_jump_time", "label": "Tieni salto (s)", "min": 0.0, "max": 0.35, "step": 0.01},
	{"key": "apex_hang_time", "label": "Hang apice (s)", "min": 0.0, "max": 0.25, "step": 0.01},
	{"key": "apex_gravity_scale", "label": "Gravita apice", "min": 0.15, "max": 1.0, "step": 0.05},
	{"key": "half_grav_threshold", "label": "Soglia apice", "min": 10.0, "max": 120.0, "step": 2.0},
	{"key": "pogo_speed_scale", "label": "Forza pogo", "min": 0.45, "max": 1.1, "step": 0.05},
]

const GRAPHICS_TUNING := [
	{"key": "contrast", "label": "Contrasto", "min": 0.8, "max": 1.2, "step": 0.01},
	{"key": "exposure", "label": "Esposizione", "min": 0.7, "max": 1.2, "step": 0.01},
	{"key": "grade_strength", "label": "Filtro colore", "min": 0.0, "max": 0.8, "step": 0.02},
	{"key": "palette_unify", "label": "Uniforma palette", "min": 0.0, "max": 1.0, "step": 0.02},
	{"key": "bloom", "label": "Bagliore (bloom)", "min": 0.0, "max": 0.4, "step": 0.01},
	{"key": "chroma", "label": "Frange cromatiche", "min": 0.0, "max": 1.0, "step": 0.02},
	{"key": "ink_strength", "label": "Contorni scuri", "min": 0.0, "max": 0.4, "step": 0.01},
	{"key": "sharpen", "label": "Nitidezza contorni", "min": 0.0, "max": 0.3, "step": 0.01},
]

const ATMOSPHERE_TUNING := [
	{"key": "distant_dogana_blur", "label": "Blur Dogana lontana", "min": 0.0, "max": 40.0, "step": 0.5},
	{"key": "distant_ships_blur", "label": "Blur velieri", "min": 0.0, "max": 40.0, "step": 0.5},
	{"key": "distant_fog_blur", "label": "Blur nebbia", "min": 0.0, "max": 40.0, "step": 0.5},
	{"key": "fog_opacity", "label": "Opacita nebbia", "min": 0.0, "max": 1.0, "step": 0.01},
	{"key": "fog_opacity_pulse", "label": "Respiro nebbia", "min": 0.0, "max": 0.5, "step": 0.01},
	{"key": "fog_vertical_drift", "label": "Deriva nebbia", "min": 0.0, "max": 30.0, "step": 0.5},
	{"key": "rain_intensity", "label": "Intensita pioggia", "min": 0.0, "max": 1.0, "step": 0.01},
	{"key": "rain_speed", "label": "Velocita pioggia", "min": 0.1, "max": 3.0, "step": 0.05},
	{"key": "rain_wind", "label": "Vento pioggia", "min": -1.0, "max": 1.0, "step": 0.01},
]

var _player: CharacterBody2D
var _camera: Camera2D
var _depth: Node2D
var _window: PanelContainer
var _open_btn: Button
var _status: Label
var _labels: Dictionary = {}
var _sliders: Dictionary = {}
var _defaults: Dictionary = {}
var _graphics_defaults: Dictionary = {}
var _atmosphere_defaults: Dictionary = {}
var _dirty := false
var _bind_retry_left := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO
var _rain_check: CheckButton


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_open_button()
	_build_window()
	call_deferred("_bind_targets")
	_show_window(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_show_window(not _window.visible)
		get_viewport().set_input_as_handled()


func _bind_targets() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player:
			for setting in TUNING:
				var key: String = setting["key"]
				if key in _player:
					_defaults[key] = _player.get(key)
	if _camera == null:
		_camera = get_tree().get_first_node_in_group("camera") as Camera2D
		if _camera:
			for setting in GRAPHICS_TUNING:
				var key: String = setting["key"]
				if key in _camera:
					_graphics_defaults[key] = _camera.get(key)
	if _depth == null:
		_depth = get_tree().get_first_node_in_group("dogana_depth_system") as Node2D
		if _depth:
			for setting in ATMOSPHERE_TUNING:
				var key: String = setting["key"]
				if key in _depth:
					_atmosphere_defaults[key] = _depth.get(key)
	if _player or _camera or _depth:
		_load_tuning()
		_sync_sliders()
		_set_status("Regola movimento e grafica in tempo reale. Premi Salva per conservarli.")


func _process(delta: float) -> void:
	if _player != null and _camera != null and _depth != null:
		return
	_bind_retry_left -= delta
	if _bind_retry_left <= 0.0:
		_bind_retry_left = 0.5
		_bind_targets()


func _build_open_button() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	_open_btn = Button.new()
	_open_btn.text = "Feel"
	_open_btn.focus_mode = Control.FOCUS_NONE
	_open_btn.tooltip_text = "Apri parametri di movimento e grafica (F3)"
	_open_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_open_btn.position = Vector2(12, 12)
	_open_btn.size = Vector2(72, 28)
	_open_btn.pressed.connect(func() -> void: _show_window(true))
	host.add_child(_open_btn)


func _build_window() -> void:
	_window = PanelContainer.new()
	_window.name = "FeelDebugOverlay"
	_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_window.position = Vector2(12, 48)
	_window.size = Vector2(300, 470)
	_window.custom_minimum_size = Vector2(260, 360)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.008, 0.02, 0.03, 0.96)
	panel_style.border_color = Color(0.35, 0.82, 0.76, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	_window.add_theme_stylebox_override("panel", panel_style)
	add_child(_window)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var drag_handle := Label.new()
	drag_handle.text = "FEEL  ·  trascina qui"
	drag_handle.custom_minimum_size.y = 24
	drag_handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_handle.add_theme_font_size_override("font_size", 12)
	drag_handle.add_theme_color_override("font_color", Color(0.58, 0.9, 0.84, 1.0))
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	vbox.add_child(drag_handle)

	var hint := Label.new()
	hint.text = "F3 o Chiudi nascondono il pannello. I numeri si tengono solo se premi Salva."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	scroll.add_child(box)

	for setting in TUNING:
		_add_slider(box, setting, false)

	var graphics_title := Label.new()
	graphics_title.text = "GRAFICA — riduci contorni bianchi qui"
	graphics_title.add_theme_font_size_override("font_size", 13)
	graphics_title.add_theme_color_override("font_color", Color(0.55, 0.9, 0.85, 1.0))
	box.add_child(graphics_title)
	for setting in GRAPHICS_TUNING:
		_add_slider(box, setting, true)

	var atmosphere_title := Label.new()
	atmosphere_title.text = "ATMOSFERA — nebbia e sfocatura lontana"
	atmosphere_title.add_theme_font_size_override("font_size", 13)
	atmosphere_title.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0, 1.0))
	box.add_child(atmosphere_title)
	_rain_check = CheckButton.new()
	_rain_check.text = "Pioggia — City of Tears"
	_rain_check.focus_mode = Control.FOCUS_NONE
	_rain_check.toggled.connect(_on_rain_toggled)
	box.add_child(_rain_check)
	for setting in ATMOSPHERE_TUNING:
		_add_atmosphere_slider(box, setting)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	var save_btn := Button.new()
	save_btn.text = "Salva"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(_save_tuning)
	buttons.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.pressed.connect(_reset_defaults)
	buttons.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Chiudi"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: _show_window(false))
	buttons.add_child(close_btn)


func _add_slider(box: VBoxContainer, setting: Dictionary, graphics: bool) -> void:
	var key: String = setting["key"]
	var label := Label.new()
	label.text = "%s: —" % setting["label"]
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	_labels[key] = label
	var slider := HSlider.new()
	slider.min_value = setting["min"]
	slider.max_value = setting["max"]
	slider.step = setting["step"]
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider.bind(key, setting["label"], graphics))
	box.add_child(slider)
	_sliders[key] = slider


func _add_atmosphere_slider(box: VBoxContainer, setting: Dictionary) -> void:
	var key: String = setting["key"]
	var label := Label.new()
	label.text = "%s: —" % setting["label"]
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	_labels[key] = label
	var slider := HSlider.new()
	slider.min_value = setting["min"]
	slider.max_value = setting["max"]
	slider.step = setting["step"]
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_atmosphere_slider.bind(key, setting["label"]))
	box.add_child(slider)
	_sliders[key] = slider


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = event.global_position - _window.global_position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_window.global_position = event.global_position - _drag_offset
		get_viewport().set_input_as_handled()


func _show_window(open: bool) -> void:
	if _window == null:
		return
	_window.visible = open
	if _open_btn:
		_open_btn.visible = not open


func _on_slider(value: float, key: String, label_text: String, graphics: bool) -> void:
	var target: Object = _camera if graphics else _player
	if target and key in target:
		target.set(key, value)
		if graphics and _camera:
			_camera.call("apply_postfx_tuning")
	var label := _labels.get(key) as Label
	if label:
		label.text = "%s: %s" % [label_text, _fmt(value)]
	_dirty = true
	_set_status("Modificato, non salvato. Premi Salva per tenerlo.")


func _on_atmosphere_slider(value: float, key: String, label_text: String) -> void:
	if _depth and key in _depth:
		_depth.set(key, value)
		_depth.call("apply_atmosphere_tuning")
	var label := _labels.get(key) as Label
	if label:
		label.text = "%s: %s" % [label_text, _fmt(value)]
	_dirty = true
	_set_status("Atmosfera modificata, non salvata. Premi Salva per tenerla.")


func _on_rain_toggled(enabled: bool) -> void:
	if _depth:
		_depth.set("rain_enabled", enabled)
		_depth.call("apply_atmosphere_tuning")
	_dirty = true
	_set_status("Pioggia modificata, non salvata. Premi Salva per tenerla.")


func _sync_sliders() -> void:
	_sync_slider_group(TUNING, _player)
	_sync_slider_group(GRAPHICS_TUNING, _camera)
	_sync_slider_group(ATMOSPHERE_TUNING, _depth)
	if _rain_check and _depth and "rain_enabled" in _depth:
		_rain_check.set_pressed_no_signal(bool(_depth.get("rain_enabled")))


func _sync_slider_group(settings: Array, target: Object) -> void:
	if target == null:
		return
	for setting in settings:
		var key: String = setting["key"]
		if not (key in target):
			continue
		var value := float(target.get(key))
		var slider := _sliders.get(key) as HSlider
		if slider:
			slider.set_value_no_signal(value)
		var label := _labels.get(key) as Label
		if label:
			label.text = "%s: %s" % [setting["label"], _fmt(value)]


func _reset_defaults() -> void:
	if _player == null:
		return
	for key in _defaults.keys():
		_player.set(key, _defaults[key])
	for key in _graphics_defaults.keys():
		_camera.set(key, _graphics_defaults[key])
	for key in _atmosphere_defaults.keys():
		_depth.set(key, _atmosphere_defaults[key])
	if _depth:
		_depth.set("rain_enabled", false)
		_depth.call("apply_atmosphere_tuning")
	_sync_sliders()
	_dirty = true
	_set_status("Ripristinati i parametri precedenti. Premi Salva per tenerli.")


func _save_tuning() -> void:
	if _player == null:
		return
	var cfg := ConfigFile.new()
	for setting in TUNING:
		var key: String = setting["key"]
		if key in _player:
			cfg.set_value("feel", key, _player.get(key))
	for setting in GRAPHICS_TUNING:
		var key: String = setting["key"]
		if _camera and key in _camera:
			cfg.set_value("graphics", key, _camera.get(key))
	for setting in ATMOSPHERE_TUNING:
		var key: String = setting["key"]
		if _depth and key in _depth:
			cfg.set_value("atmosphere", key, _depth.get(key))
	if _depth:
		cfg.set_value("atmosphere", "rain_enabled", _depth.get("rain_enabled"))
	cfg.save(USER_SAVE)
	cfg.save(PROJECT_SAVE)
	_dirty = false
	_set_status("Salvato. Resta anche al prossimo avvio.")


func _load_tuning() -> void:
	if _player == null:
		return
	var cfg := ConfigFile.new()
	var loaded := cfg.load(USER_SAVE)
	if loaded != OK:
		loaded = cfg.load(PROJECT_SAVE)
	if loaded != OK:
		return
	for setting in TUNING:
		var key: String = setting["key"]
		if key in _player and cfg.has_section_key("feel", key):
			_player.set(key, cfg.get_value("feel", key))
	for setting in GRAPHICS_TUNING:
		var key: String = setting["key"]
		if _camera and key in _camera and cfg.has_section_key("graphics", key):
			_camera.set(key, cfg.get_value("graphics", key))
	if _camera:
		_camera.call("apply_postfx_tuning")
	for setting in ATMOSPHERE_TUNING:
		var key: String = setting["key"]
		if _depth and key in _depth and cfg.has_section_key("atmosphere", key):
			_depth.set(key, cfg.get_value("atmosphere", key))
	if _depth and cfg.has_section_key("atmosphere", "rain_enabled"):
		_depth.set("rain_enabled", cfg.get_value("atmosphere", "rain_enabled"))
	if _depth:
		_depth.call("apply_atmosphere_tuning")


func _set_status(text: String) -> void:
	if _status:
		_status.text = text


func _fmt(value: float) -> String:
	if absf(value) >= 10.0:
		return "%.0f" % value
	return "%.2f" % value
