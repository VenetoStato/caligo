extends SceneTree

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
	var boss := level.get_node("Gameplay/DrownedCustomsWarden") as CharacterBody2D
	boss.set_physics_process(false)

	await _capture_at(player, Vector2(560, 425), "01-arrival.png")
	await _capture_at(player, Vector2(1580, 425), "02-first-combat.png")
	await _capture_at(player, Vector2(2630, 125), "02-customs.png")
	await _capture_at(player, Vector2(2280, -190), "03-palace-entry.png")
	await _capture_at(player, Vector2(2580, -540), "03-palace-maze.png")
	await _capture_at(player, Vector2(2700, -1040), "03-palace-summit.png")
	await _capture_at(player, Vector2(3520, 360), "03-canal.png")
	await _capture_at(player, Vector2(4200, 145), "04-fortuna.png")
	await _capture_at(player, Vector2(5150, 425), "05-boss-arena.png")

	var archive_art := level.get_node("Environment/SecretArchiveArtwork") as Sprite2D
	archive_art.modulate.a = 0.9
	var archive_veil := level.get_node("Gameplay/Geometry/HiddenArchiveRoute/SecretReveal/Veil") as Polygon2D
	archive_veil.modulate.a = 0.0
	await _capture_at(player, Vector2(1580, 760), "06-hidden-archive.png")

	var map := level.get_node("DoganaMap")
	map.call("configure_regions", {
		"arrival": true,
		"customs": true,
		"palace": true,
		"canal": true,
		"fortuna": true,
		"archive": true,
		"ossuary": true,
		"palace_vault": true,
	})
	map.call("set_player_world_position", Vector2(2700, -840))
	map.call("open_map")
	await _settle(8)
	_save_viewport("07-map.png")
	map.call("close_map")
	print("CALIGO_VISUAL_CAPTURE: screenshots saved to build/visual-review")
	await create_timer(0.5, true, false, true).timeout
	quit(0)


func _capture_at(player: CharacterBody2D, world_position: Vector2, filename: String) -> void:
	player.global_position = world_position
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	await _settle(18)
	_save_viewport(filename)


func _settle(frames: int) -> void:
	for _frame in frames:
		await process_frame


func _save_viewport(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var result := image.save_png(OUTPUT_DIR.path_join(filename))
	if result != OK:
		push_error("Could not save visual review screenshot: " + filename)
