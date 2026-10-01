extends Control

## Pulsante touch multi-dito. Ogni comando conserva il proprio indice touch,
## quindi movimento, salto/attacco e lenza possono essere tenuti insieme.

var action_name := ""
var label_text := ""
var subdued := false
var locked := false
var _pressed := false
var _touch_index := -1


func configure(action: String, label: String, is_subdued: bool) -> void:
	action_name = action
	label_text = label
	subdued = is_subdued
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func set_locked(value: bool) -> void:
	locked = value
	if locked:
		_release()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0:
			_touch_index = touch.index
			_press()
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_release()
			accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_press()
		else:
			_release()
		accept_event()


func _exit_tree() -> void:
	_release()


func _press() -> void:
	if _pressed or action_name.is_empty():
		return
	_pressed = true
	Input.action_press(action_name)
	queue_redraw()


func _release() -> void:
	if not _pressed:
		return
	_pressed = false
	Input.action_release(action_name)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	var center := size * 0.5
	var fill_alpha := 0.09 if subdued else 0.13
	var border_alpha := 0.20 if subdued else 0.30
	if _pressed:
		fill_alpha = 0.66
		border_alpha = 0.95
	if locked:
		fill_alpha = 0.05
		border_alpha = 0.10
	draw_circle(center, radius, Color(0.025, 0.085, 0.1, fill_alpha))
	draw_arc(center, radius, 0.0, TAU, 40, Color(0.7, 0.9, 0.84, border_alpha), 3.0 if _pressed else 1.5, true)
	var font := ThemeDB.fallback_font
	var font_size := maxi(14, int(minf(size.x, size.y) * (0.25 if label_text.length() > 2 else 0.48)))
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var color := Color(1.0, 0.91, 0.65, 1.0) if _pressed else Color(0.88, 0.95, 0.92, 0.82)
	draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.32), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
