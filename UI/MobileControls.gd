extends CanvasLayer
## HUD touch compatto: movimento a sinistra, azioni a destra, pesca contestuale.

const MOVE_SIZE := 72.0
const ACTION_SIZE := 68.0
const SMALL_SIZE := 50.0
const CAST_SIZE := 72.0
const EDGE := 24.0
const GAP := 10.0

const BUTTON_LABELS := {
	"ui_left": "‹",
	"ui_right": "›",
	"ui_accept": "SALTO",
	"ui_attack": "ATT",
	"ui_attack_strong": "FORTE",
	"dash": "DASH",
	"reel": "TIRA",
	"grab": "USA",
	"change_hook": "AMO",
	"interact": "AZIONE",
}

var _buttons: Dictionary = {}
var _cast_joystick: Control
var _player: Node
@export var force_preview := false


func _ready() -> void:
	if not _is_mobile():
		queue_free()
		return
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS
	_remove_mouse_from_attack_actions()
	get_viewport().size_changed.connect(_build_controls)
	_build_controls()
	set_process(true)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	_update_context()


func _build_controls() -> void:
	_release_all_actions()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_cast_joystick = null

	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.72, 1.08)
	var move_size := roundf(MOVE_SIZE * scale_factor)
	var action_size := roundf(ACTION_SIZE * scale_factor)
	var small_size := roundf(SMALL_SIZE * scale_factor)
	var cast_size := roundf(CAST_SIZE * scale_factor)
	var gap := roundf(GAP * scale_factor)
	var edge := maxf(14.0, EDGE * scale_factor)
	var bottom := viewport_size.y - edge

	# Pad movimento: due tasti vicini, entrambi sotto lo stesso pollice.
	_place("ui_left", edge, bottom - move_size, move_size, false)
	_place("ui_right", edge + move_size + gap, bottom - move_size, move_size, false)
	_place("interact", edge + (move_size * 2.0 + gap - small_size) * 0.5, bottom - move_size - gap - small_size, small_size, true)

	# Cluster azioni: salto principale sul bordo, attacco al suo fianco, dash/forte sopra.
	var jump_x := viewport_size.x - edge - action_size
	var action_y := bottom - action_size
	var attack_x := jump_x - gap - action_size
	_place("ui_attack", attack_x, action_y, action_size, false)
	_place("ui_accept", jump_x, action_y, action_size, false)
	_place("ui_attack_strong", attack_x, action_y - gap - small_size, small_size, true)
	_place("dash", jump_x + (action_size - small_size) * 0.5, action_y - gap - small_size, small_size, true)

	# Pesca: il lancio resta disponibile; gli altri tasti compaiono solo quando servono.
	var cast_x := attack_x - gap - cast_size
	_place_cast_joystick(cast_x, bottom - cast_size, cast_size)
	_place("reel", cast_x - gap - small_size, bottom - small_size, small_size, true)
	_place("grab", cast_x - gap - small_size, bottom - small_size * 2.0 - gap, small_size, true)
	_place("change_hook", cast_x - gap - small_size, bottom - small_size * 3.0 - gap * 2.0, small_size, true)
	# Evita un flash di tutti i comandi di pesca prima che il player sia rilevato.
	_set_control_state(_buttons.get("reel"), false, 0.86)
	_set_control_state(_buttons.get("grab"), true, 0.52)
	_set_control_state(_buttons.get("change_hook"), false, 0.52)


func _place_cast_joystick(px: float, py: float, size_px: float) -> void:
	_cast_joystick = Control.new()
	_cast_joystick.name = "CastJoystick"
	_cast_joystick.set_script(load("res://UI/CastJoystick.gd") as GDScript)
	_cast_joystick.position = Vector2(px, py)
	_cast_joystick.custom_minimum_size = Vector2(size_px, size_px)
	_cast_joystick.size = Vector2(size_px, size_px)
	_cast_joystick.modulate.a = 0.64
	add_child(_cast_joystick)


func _place(action: String, px: float, py: float, size_px: float, subdued: bool) -> void:
	var button := Button.new()
	button.name = "Btn_%s" % action
	button.text = str(BUTTON_LABELS.get(action, "?"))
	button.position = Vector2(px, py)
	button.size = Vector2(size_px, size_px)
	button.custom_minimum_size = button.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", maxi(13, int(size_px * (0.26 if button.text.length() > 2 else 0.46))))
	button.add_theme_color_override("font_color", Color(0.86, 0.93, 0.91, 0.76 if subdued else 0.88))
	button.add_theme_color_override("font_pressed_color", Color(0.98, 0.91, 0.68, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(size_px, subdued, false))
	button.add_theme_stylebox_override("hover", _make_button_style(size_px, subdued, false))
	button.add_theme_stylebox_override("pressed", _make_button_style(size_px, subdued, true))
	button.add_theme_stylebox_override("disabled", _make_button_style(size_px, true, false))
	button.button_down.connect(_on_down.bind(action))
	button.button_up.connect(_on_up.bind(action))
	button.tree_exiting.connect(_release_action.bind(action))
	_buttons[action] = button
	add_child(button)


func _make_button_style(size_px: float, subdued: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base_alpha := 0.2 if subdued else 0.27
	style.bg_color = Color(0.025, 0.075, 0.09, 0.54 if pressed else base_alpha)
	style.border_color = Color(0.72, 0.88, 0.82, 0.82 if pressed else (0.38 if subdued else 0.48))
	style.set_border_width_all(2 if pressed else 1)
	style.set_corner_radius_all(int(size_px * 0.5))
	style.shadow_color = Color(0, 0, 0, 0.18 if pressed else 0.08)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


func _update_context() -> void:
	if _player == null:
		return
	var locked := bool(_player.get_meta("arrival_locked", false))
	var line_extended := bool(_player.get("line_extended"))
	var charging := bool(_player.get("is_charging"))
	var grab_unlocked := bool(_player.get("grab_hook_unlocked"))
	var fishing_context := line_extended or charging
	_set_control_state(_buttons.get("reel"), line_extended, 0.86)
	_set_control_state(_buttons.get("grab"), not line_extended, 0.52)
	_set_control_state(_buttons.get("change_hook"), grab_unlocked and not line_extended, 0.52)
	if _cast_joystick:
		_cast_joystick.modulate.a = 0.88 if fishing_context else 0.58
		_cast_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	for action in ["ui_left", "ui_right", "ui_accept", "ui_attack", "ui_attack_strong", "dash", "interact"]:
		var button := _buttons.get(action) as Button
		if button:
			button.disabled = locked
			button.modulate.a = 0.22 if locked else 1.0


func _set_control_state(control: Control, show: bool, alpha: float) -> void:
	if control == null:
		return
	control.visible = show
	control.modulate.a = alpha
	control.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE


func _remove_mouse_from_attack_actions() -> void:
	for action_name in ["ui_attack", "ui_attack_strong"]:
		for event in InputMap.action_get_events(action_name):
			if event is InputEventMouseButton:
				InputMap.action_erase_event(action_name, event)


func _is_mobile() -> bool:
	return force_preview or OS.get_name() == "Android" or OS.has_feature("mobile")


func _on_down(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _on_up(action: String) -> void:
	_release_action(action)


func _release_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)


func _release_all_actions() -> void:
	for action in BUTTON_LABELS:
		_release_action(str(action))
