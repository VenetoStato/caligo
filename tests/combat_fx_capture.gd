extends SceneTree

## Screenshot del feedback di combattimento in post-FX (va lanciato con un
## renderer vero, non --headless): base, onda del colpo subito, impatto,
## ultima vita. Output in build/visual-review/fx-*.png.

const DOGANA := "res://Levels/Scenes/punta_della_dogana.tscn"
const OUTPUT_DIR := "res://build/visual-review"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if change_scene_to_file(DOGANA) != OK:
		quit(1)
		return
	await _settle(45)
	var level := current_scene
	level.set("persistence_enabled", false)
	var player := level.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	var arrival := level.get_node_or_null("ArrivalCutscene")
	if arrival and arrival.has_method("_skip_to_end"):
		arrival.call("_skip_to_end")
	var tutorial := level.get_node_or_null("TutorialHints")
	if tutorial:
		tutorial.set_process(false)
		var panel := tutorial.get("_panel") as Control
		if panel:
			panel.visible = false
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	player.global_position = Vector2(1580, 400)
	camera.call("set_camera_target", player, 0)
	camera.reset_smoothing()
	await _settle(40)
	_save("fx-0-base.png")

	camera.call("add_combat_pulse", &"hurt")
	await _settle(5)
	_save("fx-1-hurt-early.png")
	await _settle(8)
	_save("fx-2-hurt-wave.png")
	await _settle(40)

	camera.call("add_combat_pulse", &"impact", 1.0)
	await _settle(1)
	_save("fx-3-impact.png")
	await _settle(30)

	player.set("current_health", 1)
	await _settle(90)
	_save("fx-4-low-health.png")
	print("CALIGO_COMBAT_FX_CAPTURE_OK")
	quit(0)


func _settle(frames: int) -> void:
	for _frame in frames:
		await process_frame


func _save(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(OUTPUT_DIR.path_join(filename))
