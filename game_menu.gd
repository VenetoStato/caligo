extends CanvasLayer

# Menu di gioco: Quit, Controlli, Camera, indicatore Amo (C)
# Accesso: ESC o pulsante Menu

@onready var menu_btn: Button = $MenuButton
@onready var scenario_selector: OptionButton = $ScenarioSelector
@onready var hook_indicator: Label = $HookIndicator
@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/MarginContainer/VBox
@onready var btn_close: Button = $Panel/MarginContainer/VBox/BtnClose
@onready var btn_controls: Button = $Panel/MarginContainer/VBox/BtnControls
@onready var btn_camera: Button = $Panel/MarginContainer/VBox/BtnCamera
@onready var label_hook: Label = $Panel/MarginContainer/VBox/HookLabel
@onready var btn_quit: Button = $Panel/MarginContainer/VBox/BtnQuit
@onready var controls_panel: PanelContainer = $Panel/MarginContainer/VBox/ControlsPanel
@onready var camera_panel: PanelContainer = $Panel/MarginContainer/VBox/CameraPanel

var _player: Node = null
var _camera: Camera2D = null
var _btn_level: Button = null
var _btn_water: Button = null
var _water_panel: PanelContainer = null
var _water_sliders: Dictionary = {}
var _water_value_labels: Dictionary = {}
var _water_nodes: Array[Node] = []
var _saved_water_tuning: Dictionary = {}
var _water_expanded := false
var _menu_tween: Tween
var _menu_transitioning := false

const DOGANA_SCENE := "res://Levels/Scenes/punta_della_dogana.tscn"
const ORIGINAL_SCENE := "res://Levels/Scenes/test_area.tscn"
const WATER_TUNING_PATH := "user://water_tuning.cfg"
const WATER_TUNING := [
	{"key": &"k", "label": "Tensione", "min": 8.0, "max": 45.0, "step": 0.5, "default": 22.0},
	{"key": &"d", "label": "Smorzamento", "min": 1.0, "max": 12.0, "step": 0.1, "default": 5.5},
	{"key": &"spread", "label": "Propagazione", "min": 10.0, "max": 70.0, "step": 1.0, "default": 42.0},
	{"key": &"impact_impulse_scale", "label": "Forza splash", "min": 0.2, "max": 1.5, "step": 0.05, "default": 0.85},
	{"key": &"character_buoyancy_acceleration", "label": "Galleggiamento", "min": 150.0, "max": 700.0, "step": 10.0, "default": 420.0},
	{"key": &"reflection_strength", "label": "Luce / riflesso", "min": 0.0, "max": 0.5, "step": 0.01, "default": 0.14},
	{"key": &"refraction_strength", "label": "Rifrazione", "min": 0.0, "max": 0.04, "step": 0.001, "default": 0.012},
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if menu_btn:
		menu_btn.pressed.connect(toggle)
		_make_discreet_glyph(menu_btn, "\u2261")
	if hook_indicator:
		var current_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		hook_indicator.visible = current_path != DOGANA_SCENE
	scenario_selector.clear()
	scenario_selector.add_item("Scenario 1", 0)
	scenario_selector.add_item("Punta Dogana", 1)
	scenario_selector.item_selected.connect(_on_scenario_selected)
	# Il selettore e' uno strumento da sviluppo: vive nel menu, non incollato
	# sopra l'inquadratura di gioco.
	_move_scenario_selector_into_menu()
	_sync_scenario_selector()
	panel.visible = false
	controls_panel.visible = false
	camera_panel.visible = false
	btn_close.pressed.connect(_on_close)
	btn_controls.pressed.connect(_on_controls)
	btn_camera.pressed.connect(_on_camera)
	btn_quit.pressed.connect(_on_quit)
	_create_level_button()
	_load_water_tuning()
	_create_water_controls()
	var vbox_cam = camera_panel.get_node_or_null("MarginContainer/VBox")
	if vbox_cam:
		var sl_follow = vbox_cam.get_node_or_null("FollowSpeedSlider") as HSlider
		var sl_look_x = vbox_cam.get_node_or_null("LookAheadXSlider") as HSlider
		var sl_look_y = vbox_cam.get_node_or_null("LookAheadYSlider") as HSlider
		if sl_follow:
			sl_follow.value_changed.connect(_on_follow_speed_changed)
		if sl_look_x:
			sl_look_x.value_changed.connect(_on_look_ahead_x_changed)
		if sl_look_y:
			sl_look_y.value_changed.connect(_on_look_ahead_y_changed)
	_apply_visual_theme()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _apply_visual_theme() -> void:
	for node in find_children("*", "Button", true, false):
		if node is Button:
			_style_menu_button(node as Button)
	_style_menu_button(scenario_selector)
	var title := $Panel/MarginContainer/VBox/Title as Label
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55, 1.0))
	title.add_theme_font_size_override("font_size", 25)


func _style_menu_button(button: BaseButton) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.075, 0.085, 0.86)
	normal.border_color = Color(0.38, 0.55, 0.51, 0.62)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.06, 0.18, 0.18, 0.96)
	hover.border_color = Color(0.82, 0.7, 0.4, 0.95)
	hover.set_border_width_all(2)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.27, 0.25, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.82, 0.9, 0.86, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.55, 1.0))

## I comandi permanenti a schermo diventano glifi appena accennati: restano
## raggiungibili al tocco, ma non leggono piu' come interfaccia di sistema.
func _make_discreet_glyph(button: Button, glyph: String) -> void:
	button.text = glyph
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = ""
	button.custom_minimum_size = Vector2(30, 30)
	button.size = Vector2(30, 30)
	button.offset_right = button.offset_left + 30.0
	button.offset_bottom = button.offset_top + 30.0
	button.modulate = Color(1, 1, 1, 0.38)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.72, 0.79, 0.74, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.96, 0.86, 0.55, 1.0))
	button.mouse_entered.connect(func() -> void: button.modulate.a = 0.9)
	button.mouse_exited.connect(func() -> void: button.modulate.a = 0.38)


func _move_scenario_selector_into_menu() -> void:
	if scenario_selector == null or vbox == null:
		return
	if scenario_selector.get_parent() == vbox:
		return
	scenario_selector.get_parent().remove_child(scenario_selector)
	scenario_selector.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.add_child(scenario_selector)
	vbox.move_child(scenario_selector, btn_quit.get_index())


func _create_water_controls() -> void:
	_btn_water = Button.new()
	_btn_water.name = "BtnWaterTuning"
	_btn_water.text = "Regolazione acqua (dev)"
	_btn_water.pressed.connect(_on_water_tuning)
	vbox.add_child(_btn_water)
	vbox.move_child(_btn_water, btn_quit.get_index())

	_water_panel = PanelContainer.new()
	_water_panel.name = "WaterTuningPanel"
	_water_panel.visible = false
	_water_panel.custom_minimum_size = Vector2(0, 310)
	vbox.add_child(_water_panel)
	vbox.move_child(_water_panel, btn_quit.get_index())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_water_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var water_box := VBoxContainer.new()
	water_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(water_box)

	for setting in WATER_TUNING:
		var key: StringName = setting["key"]
		var label := Label.new()
		label.text = "%s: %.3f" % [setting["label"], setting["default"]]
		water_box.add_child(label)
		_water_value_labels[key] = label

		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(260, 0)
		slider.min_value = setting["min"]
		slider.max_value = setting["max"]
		slider.step = setting["step"]
		slider.value = _saved_water_tuning.get(key, setting["default"])
		slider.value_changed.connect(_on_water_setting_changed.bind(key))
		water_box.add_child(slider)
		_water_sliders[key] = slider

func _create_level_button() -> void:
	_btn_level = Button.new()
	_btn_level.name = "BtnDogana"
	_btn_level.focus_mode = Control.FOCUS_ALL
	_btn_level.pressed.connect(_on_change_level)
	vbox.add_child(_btn_level)
	vbox.move_child(_btn_level, btn_quit.get_index())
	_update_level_button()

func _update_level_button() -> void:
	if _btn_level == null:
		return
	var current_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	_btn_level.text = "Torna all'area originale" if current_path == DOGANA_SCENE else "Punta della Dogana"


func _sync_scenario_selector() -> void:
	var current_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	scenario_selector.select(1 if current_path == DOGANA_SCENE else 0)


func _on_scenario_selected(index: int) -> void:
	var target := DOGANA_SCENE if index == 1 else ORIGINAL_SCENE
	var current_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if target == current_path:
		return
	_change_to_scene(target)


func _on_change_level() -> void:
	var current_path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	var target := ORIGINAL_SCENE if current_path == DOGANA_SCENE else DOGANA_SCENE
	_change_to_scene(target)


func _change_to_scene(target: String) -> void:
	get_tree().paused = false
	if ResourceLoader.exists(target):
		if AsyncSceneLoader and AsyncSceneLoader.has_method("load_scene"):
			AsyncSceneLoader.load_scene(target)
		elif autoload_transition and autoload_transition.has_method("transition_to_scene"):
			autoload_transition.transition_to_scene(target)
		else:
			get_tree().change_scene_to_file(target)
	else:
		push_error("Livello non trovato: " + target)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle():
	if _menu_transitioning:
		return
	if panel.visible:
		_close()
	else:
		_open()

func _open():
	_menu_transitioning = true
	if menu_btn:
		menu_btn.visible = false
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.96
	get_tree().paused = true
	_update_level_button()
	_sync_scenario_selector()
	_update_hook_label()
	_find_player_and_camera()
	_update_camera_sliders()
	_menu_tween = create_tween().set_parallel(true)
	_menu_tween.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	_menu_tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_menu_tween.finished.connect(func() -> void: _menu_transitioning = false, CONNECT_ONE_SHOT)

func _close():
	_menu_transitioning = true
	_menu_tween = create_tween().set_parallel(true)
	_menu_tween.tween_property(panel, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	_menu_tween.tween_property(panel, "scale", Vector2.ONE * 0.97, 0.14).set_trans(Tween.TRANS_SINE)
	_menu_tween.finished.connect(_finish_close, CONNECT_ONE_SHOT)


func _finish_close() -> void:
	panel.visible = false
	panel.modulate.a = 1.0
	panel.scale = Vector2.ONE
	controls_panel.visible = false
	camera_panel.visible = false
	if _water_panel:
		_water_panel.visible = false
	_set_water_panel_size(false)
	if menu_btn:
		menu_btn.visible = true
	get_tree().paused = false
	_menu_transitioning = false

func _find_player_and_camera():
	if _player != null and is_instance_valid(_player):
		return
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if "using_fishing_hook" in p:
			_player = p
			break
	# Camera: cerca nel player o nei suoi figli
	if _player != null:
		_camera = _player.get_node_or_null("Camera2D") as Camera2D
		if _camera == null:
			_camera = _player.find_child("Camera2D", true, false) as Camera2D

func _process(_delta):
	if not panel.visible and hook_indicator:
		_update_hook_indicator()

func _update_hook_indicator():
	_find_player_and_camera()
	if _player != null and "using_fishing_hook" in _player:
		var fishing = _player.get("using_fishing_hook")
		hook_indicator.text = "Amo: " + ("Pesca" if fishing else "Lancio") + " [C]"

func _update_hook_label():
	_find_player_and_camera()
	if _player != null and "using_fishing_hook" in _player:
		var fishing = _player.get("using_fishing_hook")
		label_hook.text = "Amo: " + ("Pesca" if fishing else "Lancio") + "  [C per cambiare]"
	else:
		label_hook.text = "Amo: —"

func _on_close():
	_close()

func _on_controls():
	controls_panel.visible = not controls_panel.visible
	camera_panel.visible = false
	if _water_panel:
		_water_panel.visible = false
	_set_water_panel_size(false)

func _on_camera():
	camera_panel.visible = not camera_panel.visible
	controls_panel.visible = false
	if _water_panel:
		_water_panel.visible = false
	_set_water_panel_size(false)

func _on_water_tuning() -> void:
	if _water_panel == null:
		return
	var show := not _water_panel.visible
	controls_panel.visible = false
	camera_panel.visible = false
	_water_panel.visible = show
	_set_water_panel_size(show)
	if show:
		_find_water_nodes()
		_sync_water_sliders()

func _set_water_panel_size(expanded: bool) -> void:
	_water_expanded = expanded
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if panel == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	var panel_width := clampf(viewport_size.x - 24.0, 280.0, 360.0)
	var desired_height := 660.0 if _water_expanded else 320.0
	var panel_height := minf(desired_height, viewport_size.y - 24.0)
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.pivot_offset = Vector2(panel_width, panel_height) * 0.5
	if _water_panel:
		_water_panel.custom_minimum_size.y = minf(310.0, viewport_size.y * 0.42)
	for slider in _water_sliders.values():
		(slider as HSlider).custom_minimum_size.x = 190.0 if compact else 260.0

func _find_water_nodes() -> void:
	_water_nodes = get_tree().get_nodes_in_group("water")
	for water in _water_nodes:
		if not is_instance_valid(water) or not water.has_method("set_tuning_parameter"):
			continue
		for key in _saved_water_tuning:
			water.call("set_tuning_parameter", key, _saved_water_tuning[key])

func _sync_water_sliders() -> void:
	if _water_nodes.is_empty():
		return
	var water := _water_nodes[0]
	if not is_instance_valid(water):
		return
	for key in _water_sliders:
		if key in water:
			var value := float(water.get(key))
			(_water_sliders[key] as HSlider).set_value_no_signal(value)
			_update_water_value_label(key, value)

func _on_water_setting_changed(value: float, key: StringName) -> void:
	_saved_water_tuning[key] = value
	_update_water_value_label(key, value)
	for water in _water_nodes:
		if is_instance_valid(water) and water.has_method("set_tuning_parameter"):
			water.call("set_tuning_parameter", key, value)
	_save_water_tuning()

func _update_water_value_label(key: StringName, value: float) -> void:
	var label := _water_value_labels.get(key) as Label
	if label == null:
		return
	for setting in WATER_TUNING:
		if setting["key"] == key:
			label.text = "%s: %.3f" % [setting["label"], value]
			return

func _load_water_tuning() -> void:
	var config := ConfigFile.new()
	if config.load(WATER_TUNING_PATH) != OK:
		return
	for setting in WATER_TUNING:
		var key: StringName = setting["key"]
		_saved_water_tuning[key] = float(config.get_value("water", String(key), setting["default"]))

func _save_water_tuning() -> void:
	var config := ConfigFile.new()
	for key in _saved_water_tuning:
		config.set_value("water", String(key), _saved_water_tuning[key])
	config.save(WATER_TUNING_PATH)

func _update_camera_sliders():
	if camera_panel == null:
		return
	var vbox_cam = camera_panel.get_node_or_null("MarginContainer/VBox")
	if vbox_cam == null:
		return
	var sl_follow = vbox_cam.get_node_or_null("FollowSpeedSlider") as HSlider
	var sl_look_x = vbox_cam.get_node_or_null("LookAheadXSlider") as HSlider
	var sl_look_y = vbox_cam.get_node_or_null("LookAheadYSlider") as HSlider
	if _camera != null:
		if sl_follow and "follow_speed" in _camera:
			sl_follow.value = _camera.get("follow_speed")
		if sl_look_x and "look_ahead_x" in _camera:
			sl_look_x.value = _camera.get("look_ahead_x")
		if sl_look_y and "look_ahead_y" in _camera:
			sl_look_y.value = _camera.get("look_ahead_y")

func _on_quit():
	get_tree().paused = false
	get_tree().quit()

func _on_follow_speed_changed(val: float):
	if _camera != null and "follow_speed" in _camera:
		_camera.set("follow_speed", val)

func _on_look_ahead_x_changed(val: float):
	if _camera != null and "look_ahead_x" in _camera:
		_camera.set("look_ahead_x", val)

func _on_look_ahead_y_changed(val: float):
	if _camera != null and "look_ahead_y" in _camera:
		_camera.set("look_ahead_y", val)
