extends SceneTree

const OUTPUT_DIR := "res://build/visual-review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_scene("res://splash_screen.tscn", "00-splash.png", 100)
	await _capture_scene("res://controls_info.tscn", "00-controls.png", 45)
	await _capture_scene("res://poetic_text.tscn", "00-prologue.png", 55)
	print("CALIGO_INTRO_CAPTURE: intro visual review saved")
	quit(0)


func _capture_scene(scene_path: String, filename: String, settle_frames: int) -> void:
	if change_scene_to_file(scene_path) != OK:
		push_error("Could not open intro scene: " + scene_path)
		quit(1)
		return
	for _frame in settle_frames:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var result := image.save_png(OUTPUT_DIR.path_join(filename))
	if result != OK:
		push_error("Could not save intro screenshot: " + filename)
