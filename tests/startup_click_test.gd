extends SceneTree

const SPLASH := "res://splash_screen.tscn"
const POETIC := "res://poetic_text.tscn"
const DOGANA := "res://Levels/Scenes/punta_della_dogana.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file(SPLASH) != OK:
		_fail("Could not open splash.")
		return
	await process_frame
	await process_frame
	var splash_group := current_scene.get("title_group") as Control
	if (
		not _fits_viewport(splash_group)
		or float(current_scene.get("fade_in_duration")) < 3.5
		or float(current_scene.get("skip_fade_duration")) < 1.8
	):
		_fail("Splash layout exceeds the current viewport.")
		return
	_click_burst(12)
	# Il tutorial tasti (controls_info) è stato rimosso dal flusso di avvio.
	if not await _wait_for_scene(POETIC, 6.0):
		_fail("Repeated splash clicks did not reach poetic screen safely.")
		return
	if not _fits_viewport(current_scene.get("_frame") as Control):
		_fail("Prologue layout exceeds the current viewport.")
		return
	if float(current_scene.get("fade_duration")) < 3.0 or float(current_scene.get("auto_advance_time")) < 16.0:
		_fail("Prologue transition timing is still too fast.")
		return
	var original_lines := [
		["PoeticTextEnglish", "From the mist of the marsh, a bundle took life"],
		["PoeticTextVeneto", "Un manuin in te la paude, in mexo al caligo, taco a movarse"],
		["PoeticTextEnglishNormal", "From the fog of the swamp, a bundle began to move"],
	]
	for line in original_lines:
		var label := current_scene.find_child(str(line[0]), true, false) as Label
		if label == null or label.text != str(line[1]):
			_fail("The original three-line prologue was not preserved.")
			return

	_click_burst(12)
	if not await _wait_for_scene(DOGANA, 20.0):
		_fail("Async loading did not reach Dogana.")
		return

	print("CALIGO_STARTUP_TEST: repeated clicks and async Dogana loading OK")
	await create_timer(1.1, true, false, true).timeout
	quit(0)


func _click_burst(count: int) -> void:
	for _index in count:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		Input.parse_input_event(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		Input.parse_input_event(up)


func _wait_for_scene(path: String, timeout: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout * 1000.0:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			return true
	return false


func _fits_viewport(control: Control) -> bool:
	if control == null:
		return false
	var viewport_size := root.get_visible_rect().size
	return (
		control.custom_minimum_size.x <= viewport_size.x + 1.0
		and control.custom_minimum_size.y <= viewport_size.y + 1.0
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
