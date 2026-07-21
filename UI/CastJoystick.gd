extends Control
## Joystick virtuale per il lancio: tieni premuto e trascina. Direzione diretta, senza ritardo.

@export var deadzone: float = 20.0
@export var default_direction: Vector2 = Vector2(1, -0.3)
@export var stick_lerp_speed: float = 18.0

var _tracking: bool = false
var _display_stick_dir: Vector2 = Vector2(1, -0.3).normalized()
var _stick_offset: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_priority = -200
	_center = size / 2.0

func _resized() -> void:
	_center = size / 2.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_start_track(_to_local(e.position))
		else:
			_end_track()
	elif event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_start_track(e.position)
		elif not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_end_track()

func _input(event: InputEvent) -> void:
	if not _tracking:
		return
	var local: Vector2
	if event is InputEventScreenDrag:
		local = _to_local((event as InputEventScreenDrag).position)
		_last_pos = local
		_update_direction(local)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			local = event.position
			_last_pos = local
			_update_direction(local)

func _process(delta: float) -> void:
	if _tracking:
		var pos := get_local_mouse_position()
		if pos != Vector2.ZERO:
			_last_pos = pos
		_update_direction(_last_pos)
		# Lerp fluido per lo stick visivo
		var target := MobileControlsManager.cast_joystick_direction
		if target.length_squared() > 0.01:
			var t := 1.0 - exp(-stick_lerp_speed * delta)
			_display_stick_dir = _display_stick_dir.lerp(target.normalized(), clampf(t, 0.0, 1.0))
			if _display_stick_dir.length_squared() < 0.001:
				_display_stick_dir = target.normalized()
	else:
		MobileControlsManager.cast_joystick_direction = Vector2.ZERO
		# Ritorno fluido allo zero (stick nascosto)
		var t := 1.0 - exp(-stick_lerp_speed * delta)
		_display_stick_dir = _display_stick_dir.lerp(Vector2.ZERO, clampf(t, 0.0, 1.0))
		queue_redraw()

func _to_local(global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_pos

func _start_track(pos: Vector2) -> void:
	_tracking = true
	_last_pos = pos
	MobileControlsManager.cast_joystick_active = true
	_send_cast(true)
	_update_direction(pos)
	_display_stick_dir = MobileControlsManager.cast_joystick_direction if MobileControlsManager.cast_joystick_direction.length_squared() > 0.01 else default_direction.normalized()

func _end_track() -> void:
	if not _tracking:
		return
	_tracking = false
	MobileControlsManager.cast_joystick_active = false
	_stick_offset = Vector2.ZERO
	_send_cast(false)
	queue_redraw()
	# Non azzerare subito la direzione: il player deve leggerla in cast_hook_charged prima

func _update_direction(local_pos: Vector2) -> void:
	var d := local_pos - _center
	var dist := d.length()
	if dist < deadzone:
		MobileControlsManager.cast_joystick_direction = default_direction.normalized()
		_stick_offset = d
	else:
		var dir := d.normalized()
		MobileControlsManager.cast_joystick_direction = dir
		_stick_offset = dir * minf(dist, _center.length() - 4)
	queue_redraw()

func _send_cast(pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = "cast"
	e.pressed = pressed
	Input.parse_input_event(e)

func _draw() -> void:
	var r := size
	var cen := _center
	# Base circolare
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.1, 0.15, 0.5)
	style.border_color = Color(0.88, 0.74, 0.32, 0.68)
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(minf(r.x, r.y) / 2.0))
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 2
	draw_style_box(style, Rect2(Vector2.ZERO, r))
	# Icona lancio esca: canna + lenza + pallino (bobber)
	var s := minf(r.x, r.y) * 0.22
	var col := Color(1.0, 0.98, 0.88, 0.78)
	# Canna: da manico a punta
	var p0 := cen + Vector2(-s * 0.8, s * 0.6)
	var p1 := cen + Vector2(s * 0.5, -s * 0.9)
	draw_line(p0, p1, col)
	# Lenza + pallino
	var p2 := cen + Vector2(s * 0.85, -s * 0.4)
	draw_line(p1, p2, col)
	draw_circle(p2, s * 0.22, col)
	# Stick: direzione lerpata per movimento fluido
	var dir := _display_stick_dir
	if dir.length_squared() > 0.01:
		var stick_len := (_center.length() - 4) * 0.9
		var stick_end := cen + dir * stick_len
		draw_line(cen, stick_end, Color(0.95, 0.85, 0.4, 0.78))
		draw_circle(stick_end, 8, Color(0.95, 0.85, 0.5, 0.82))
