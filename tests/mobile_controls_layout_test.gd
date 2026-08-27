extends Node

const MOBILE_CONTROLS := preload("res://UI/MobileControls.tscn")


func _ready() -> void:
	var controls := MOBILE_CONTROLS.instantiate() as CanvasLayer
	controls.set("force_preview", true)
	add_child(controls)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	var left := controls.get_node_or_null("Btn_ui_left") as Control
	var right := controls.get_node_or_null("Btn_ui_right") as Control
	var jump := controls.get_node_or_null("Btn_ui_accept") as Control
	var attack := controls.get_node_or_null("Btn_ui_attack") as Control
	var cast := controls.get_node_or_null("CastJoystick") as Control
	if left == null or right == null or jump == null or attack == null or cast == null:
		return _fail("primary thumb controls are missing")
	if left.size.x < 58.0 or jump.size.x < 56.0 or cast.size.x < 64.0:
		return _fail("primary touch targets are too small")
	if left.position.x >= viewport_size.x * 0.35 or jump.position.x <= viewport_size.x * 0.65:
		return _fail("movement/action clusters are not separated by thumb")
	for child in controls.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		var control_end := control.position + control.size
		if control.position.x < 0.0 or control.position.y < 0.0 or control_end.x > viewport_size.x or control_end.y > viewport_size.y:
			return _fail("%s falls outside the phone viewport" % control.name)
	left.call("_press")
	jump.call("_press")
	if not Input.is_action_pressed("ui_left") or not Input.is_action_pressed("ui_accept"):
		return _fail("multi-touch movement plus jump is not simultaneous")
	left.call("_release")
	jump.call("_release")
	print("CALIGO_MOBILE_CONTROLS_OK: safe edges, large targets and simultaneous thumb actions")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("MOBILE_CONTROLS_FAIL: %s" % message)
	get_tree().quit(1)
