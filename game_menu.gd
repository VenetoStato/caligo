extends CanvasLayer

# Menu di gioco: Quit, Controlli, Camera, indicatore Amo (C)
# Accesso: ESC o pulsante Menu

@onready var menu_btn: Button = $MenuButton
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

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if menu_btn:
		menu_btn.pressed.connect(toggle)
	if hook_indicator:
		hook_indicator.visible = true
	panel.visible = false
	controls_panel.visible = false
	camera_panel.visible = false
	btn_close.pressed.connect(_on_close)
	btn_controls.pressed.connect(_on_controls)
	btn_camera.pressed.connect(_on_camera)
	btn_quit.pressed.connect(_on_quit)
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

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle():
	if panel.visible:
		_close()
	else:
		_open()

func _open():
	if menu_btn:
		menu_btn.visible = false
	panel.visible = true
	get_tree().paused = true
	_update_hook_label()
	_find_player_and_camera()
	_update_camera_sliders()

func _close():
	panel.visible = false
	controls_panel.visible = false
	camera_panel.visible = false
	if menu_btn:
		menu_btn.visible = true
	get_tree().paused = false

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

func _on_camera():
	camera_panel.visible = not camera_panel.visible
	controls_panel.visible = false

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
