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

	await _capture_at(player, Vector2(430, 425), "01-guided-tutorial.png")
	var tutorial := level.get_node("TutorialHints")
	(tutorial.get("_panel") as PanelContainer).visible = false
	tutorial.set_process(false)
	tutorial.set_process_unhandled_input(false)
	var tutorial_gate := level.get_node("Gameplay/TutorialGate")
	tutorial_gate.call("unlock")
	await _capture_at(player, Vector2(860, 425), "01-arrival-training.png")
	await _capture_fishing(player, level)
	await _capture_at(player, Vector2(1580, 425), "02-first-combat.png")
	var bloater := level.get_node("Gameplay/Encounters/TideBloaterCustoms") as CharacterBody2D
	bloater.set_physics_process(false)
	bloater.global_position = Vector2(2360, 330)
	bloater.set("_special_windup_remaining", 0.42)
	bloater.queue_redraw()
	await _capture_at(player, Vector2(2460, 350), "02-area-enemy.png")
	var oracle := level.get_node("Gameplay/Encounters/LagoonOracleWedge") as CharacterBody2D
	oracle.set_physics_process(false)
	oracle.global_position = Vector2(2800, 110)
	oracle.set("_special_windup_remaining", 0.42)
	oracle.queue_redraw()
	await _capture_at(player, Vector2(2730, 125), "02-volley-enemy.png")
	await _capture_at(player, Vector2(2280, -190), "03-palace-entry.png")
	await _capture_at(player, Vector2(2580, -540), "03-palace-maze.png")
	await _capture_at(player, Vector2(2700, -1040), "03-palace-summit.png")
	await _capture_at(player, Vector2(3520, 360), "03-canal.png")
	await _capture_at(player, Vector2(4200, 145), "04-fortuna.png")
	await _capture_at(player, Vector2(5150, 425), "05-boss-arena.png")

	var archive_art := level.get_node("Environment/SecretArchiveArtwork") as Sprite2D
	await _capture_at(player, Vector2(1870, 660), "06-archive-access.png")
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
	var query := PhysicsRayQueryParameters2D.create(
		world_position + Vector2(0, -90),
		world_position + Vector2(0, 190),
		1
	)
	query.exclude = [player.get_rid()]
	var hit := root.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collision := player.get_node("CollisionShape2D") as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		player.global_position.y = (hit.position as Vector2).y - collision.position.y - shape.size.y * 0.5
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	await _settle(18)
	_save_viewport(filename)


func _capture_fishing(player: CharacterBody2D, level: Node) -> void:
	player.global_position = Vector2(500, 455)
	var hook_scene := player.get("fishing_hook_scene") as PackedScene
	var hook := hook_scene.instantiate() as RigidBody2D
	level.add_child(hook)
	hook.global_position = Vector2(705, 630)
	hook.call("set_player_reference", player)
	hook.call("set_in_water", true)
	player.set("hook_instance", hook)
	player.set("line_mode", 1)
	player.set("line_extended", true)
	player.set("target_line_length", 300.0)
	player.set("current_line_length", 245.0)
	player.call("_init_rope_points", player.call("get_rod_tip_position"))
	for _frame in 16:
		player.call("_process_fishing", 1.0 / 60.0)
		await process_frame
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	await _settle(8)
	_save_viewport("01-fishing-line.png")
	player.call("retract_line")
	await process_frame


func _settle(frames: int) -> void:
	for _frame in frames:
		await process_frame


func _save_viewport(filename: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var result := image.save_png(OUTPUT_DIR.path_join(filename))
	if result != OK:
		push_error("Could not save visual review screenshot: " + filename)
