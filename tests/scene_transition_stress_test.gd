extends SceneTree

const DOGANA := "res://Levels/Scenes/punta_della_dogana.tscn"
const ORIGINAL := "res://Levels/Scenes/test_area.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if change_scene_to_file(DOGANA) != OK:
		_fail("Could not open initial Dogana scene.")
		return
	await process_frame
	await process_frame
	var loader := root.get_node_or_null("AsyncSceneLoader")
	if loader == null:
		_fail("AsyncSceneLoader autoload is missing.")
		return

	for cycle in 2:
		for _duplicate in 8:
			loader.call("load_scene", ORIGINAL)
		if not await _wait_for_scene(ORIGINAL, 12.0):
			_fail("Cycle %d could not load original scene." % cycle)
			return
		for _duplicate in 8:
			loader.call("load_scene", DOGANA)
		if not await _wait_for_scene(DOGANA, 12.0):
			_fail("Cycle %d could not return to Dogana." % cycle)
			return

	print("CALIGO_TRANSITION_TEST: duplicate requests and repeated scene changes OK")
	await create_timer(1.1, true, false, true).timeout
	quit(0)


func _wait_for_scene(path: String, timeout: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout * 1000.0:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			var loader := root.get_node_or_null("AsyncSceneLoader")
			if loader and not bool(loader.call("is_loading")):
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
