extends CanvasLayer
## Controlli touch Android. Pulsante lancio = joystick (tieni premuto e trascina per direzionare).

const BTN := 84
const GAP := 18
const MARGIN_H := 12   # margine orizzontale minimo sui bordi
const MARGIN_BOTTOM := 6  # pulsanti lungo il bordo basso
const CAST_SIZE := 96

## Loghi pulsanti: action → icona Unicode (modifica qui per cambiare tutte le icone)
const BUTTON_LABELS := {
	"ui_left": "◀",
	"ui_right": "▶",
	"ui_accept": "↑",
	"ui_attack": "⚔",
	"ui_attack_strong": "◆",
	"dash": "⚡",
	"reel": "↙",
	"grab": "✧",
	"change_hook": "⇄",
	"interact": "✦",
}

func _ready() -> void:
	if not _is_mobile():
		queue_free()
		return
	layer = 500
	_remove_mouse_from_attack_actions()
	var v := get_viewport().get_visible_rect().size
	var w := v.x
	var h := v.y
	# Pulsanti lungo il bordo basso
	var r0 := h - MARGIN_BOTTOM - BTN
	var r1 := r0 - GAP - BTN
	# --- SINISTRA (r0): sinistra e salto ---
	_place("ui_left", MARGIN_H, r0, BTN, BTN, false)
	_place("ui_accept", MARGIN_H + BTN + GAP, r0, BTN, BTN, false)
	_place("interact", MARGIN_H + BTN + GAP, r1, BTN, BTN, true)
	# --- DESTRA: destra (r1) + combattimento ---
	var c4 := w - MARGIN_H - BTN
	var c3 := c4 - BTN - GAP
	var c2 := c3 - BTN - GAP
	var c1 := c2 - BTN - GAP
	_place("ui_attack", c1, r1, BTN, BTN, false)
	_place("ui_attack_strong", c2, r1, BTN, BTN, false)
	_place("dash", c3, r1, BTN, BTN, false)
	_place("ui_right", c4, r1, BTN, BTN, false)
	# --- PESCA (r0, bordo basso): cast, reel, grab, change ---
	var fish_y := r0
	var f4 := c4
	var f3 := f4 - BTN - GAP
	var f2 := f3 - BTN - GAP
	var f1 := f2 - CAST_SIZE - GAP
	_place_cast_joystick(f1, fish_y, CAST_SIZE)
	_place("reel", f2, fish_y, BTN, BTN, true)
	_place("grab", f3, fish_y, BTN, BTN, true)
	_place("change_hook", f4, fish_y, BTN, BTN, true)

func _apply_pressed_gradient(s: StyleBoxFlat, bg: Color, border: Color, rad: int, bw: int) -> void:
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.border_blend = true
	s.shadow_color = Color(0.3, 0.5, 0.65, 0.25)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 1)

func _place_cast_joystick(px: float, py: float, sz: float) -> void:
	var joy := Control.new()
	joy.set_script(load("res://UI/CastJoystick.gd") as GDScript)
	joy.position = Vector2(px, py)
	joy.custom_minimum_size = Vector2(sz, sz)
	joy.size = Vector2(sz, sz)
	add_child(joy)

func _remove_mouse_from_attack_actions() -> void:
	for action_name in ["ui_attack", "ui_attack_strong"]:
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(action_name, ev)

func _is_mobile() -> bool:
	return OS.get_name() == "Android"

func _place(action: String, px: float, py: float, sz: float, sz_y: float, is_fish: bool) -> void:
	var label: String = BUTTON_LABELS.get(action, "?")
	var btn := Button.new()
	btn.name = "Btn_%s" % action
	btn.text = label
	btn.position = Vector2(px, py)
	btn.custom_minimum_size = Vector2(sz, sz_y)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	var style_n := StyleBoxFlat.new()
	var style_p := StyleBoxFlat.new()
	var radius := int(sz / 2.0)
	if action == "cast":
		style_n.bg_color = Color(0.04, 0.14, 0.24, 0.94)
		style_n.border_color = Color(0.88, 0.74, 0.32, 0.95)
		style_n.set_border_width_all(4)
		style_n.set_corner_radius_all(48)
		style_n.shadow_color = Color(0, 0, 0, 0.4)
		style_n.shadow_size = 5
		style_n.shadow_offset = Vector2(0, 2)
		_apply_pressed_gradient(style_p, Color(0.35, 0.55, 0.7, 1.0), Color(0.9, 0.8, 0.4, 1.0), 48, 4)
		btn.add_theme_font_size_override("font_size", 46)
		btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.95, 1))
	elif is_fish:
		style_n.bg_color = Color(0.025, 0.1, 0.13, 0.5)
		style_n.border_color = Color(0.48, 0.78, 0.7, 0.62)
		style_n.set_border_width_all(2)
		style_n.set_corner_radius_all(radius)
		style_n.shadow_color = Color(0, 0, 0, 0.18)
		style_n.shadow_size = 2
		_apply_pressed_gradient(style_p, Color(0.16, 0.38, 0.43, 0.82), Color(0.65, 0.9, 0.85, 0.9), radius, 2)
		btn.add_theme_font_size_override("font_size", 38)
		btn.add_theme_color_override("font_color", Color(0.98, 1.0, 0.95, 0.78))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1))
	else:
		style_n.bg_color = Color(0.035, 0.055, 0.1, 0.48)
		style_n.border_color = Color(0.45, 0.58, 0.82, 0.62)
		style_n.set_border_width_all(2)
		style_n.set_corner_radius_all(radius)
		style_n.shadow_color = Color(0, 0, 0, 0.18)
		style_n.shadow_size = 2
		_apply_pressed_gradient(style_p, Color(0.25, 0.35, 0.65, 0.82), Color(0.7, 0.85, 1.0, 0.9), radius, 2)
		btn.add_theme_font_size_override("font_size", 38)
		btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.78))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1))
	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.button_down.connect(_on_down.bind(action))
	btn.button_up.connect(_on_up.bind(action))
	add_child(btn)

func _on_down(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)

func _on_up(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = false
	Input.parse_input_event(e)
