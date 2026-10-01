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
	var arrival := level.get_node_or_null("ArrivalCutscene")
	if arrival and arrival.has_method("_skip_to_end"):
		arrival.call("_skip_to_end")
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera and camera.has_method("set_camera_target"):
		camera.call("set_camera_target", player, 0)
	await _settle(4)
	var boss := level.get_node("Gameplay/DrownedCustomsWarden") as CharacterBody2D
	boss.set_physics_process(false)

	await _capture_arrival_landing_fx(player, level)
	await _capture_footstep_fx(player)
	await _capture_at(player, Vector2(430, 425), "01-guided-tutorial.png")
	var tutorial := level.get_node("TutorialHints")
	await _capture_tutorial_mark(tutorial)
	(tutorial.get("_panel") as PanelContainer).visible = false
	tutorial.set_process(false)
	tutorial.set_process_unhandled_input(false)
	await _capture_at(player, Vector2(860, 425), "01-arrival-training.png")
	await _capture_fishing(player, level)
	await _capture_at(player, Vector2(1580, 425), "02-first-combat.png")
	var bloater := level.get_node("Gameplay/Encounters/TideBloaterCanal") as CharacterBody2D
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
	await _capture_at(player, Vector2(5480, 425), "03-salute-entrance.png")
	await _capture_at(player, Vector2(4300, -545), "03-salute-interior-entry.png")
	await _capture_at(player, Vector2(5180, -545), "03-salute-interior-arena.png")
	await _capture_at(player, Vector2(3520, 360), "03-canal.png")
	await _capture_at(player, Vector2(4200, 425), "04-fortuna.png")
	await _capture_at(player, Vector2(5150, -545), "05-boss-arena.png")
	await _capture_at(player, Vector2(430, 425), "14-bricole-pontile.png")
	await _capture_at(player, Vector2(1180, 425), "15-bricole-punta.png")
	await _capture_boss_animations(player, boss)
	for module_capture in [
		[Vector2(250, 420), "08-module-torre.png"],
		[Vector2(1300, 420), "09-module-dogana-ovest.png"],
		[Vector2(2800, 330), "10-module-dogana-est.png"],
		[Vector2(3900, 330), "11-module-seminario.png"],
		[Vector2(4700, 420), "12-module-collegamento.png"],
		[Vector2(5400, 420), "13-module-salute.png"],
	]:
		await _capture_at(player, module_capture[0], module_capture[1])

	var map := level.get_node("DoganaMap")
	map.call("configure_regions", {
		"arrival": true,
		"customs": true,
		"canal": true,
		"fortuna": true,
		"salute": true,
	})
	map.call("set_player_world_position", Vector2(5180, -545))
	map.call("open_map")
	var debug_toggle := map.get_node("Overlay/Frame/DebugTravel") as CheckButton
	debug_toggle.button_pressed = true
	await _settle(8)
	_save_viewport("07-map.png")
	map.call("close_map")
	await _capture_mobile_controls_preview()
	print("CALIGO_VISUAL_CAPTURE: screenshots saved to build/visual-review")
	await create_timer(0.5, true, false, true).timeout
	quit(0)


func _capture_arrival_landing_fx(player: CharacterBody2D, level: Node) -> void:
	player.global_position = Vector2(70, 447)
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		if camera.has_method("set_camera_target"):
			camera.call("set_camera_target", player, 0)
		camera.reset_smoothing()
	await _settle(18)
	var ambient := level.get_node_or_null("Gameplay/ArrivalAmbient")
	if ambient and ambient.has_method("play_landing_effect"):
		ambient.call("play_landing_effect", player.global_position)
	if camera and camera.has_method("add_zoom_pulse"):
		camera.call("add_zoom_pulse", 0.018, 0.3)
	await _settle(5)
	_save_viewport("00-arrival-landing-fx.png")


func _capture_footstep_fx(player: CharacterBody2D) -> void:
	player.global_position = Vector2(430, 425)
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	await _settle(12)
	# La polvere esce solo se il player e' davvero a terra: con la fisica spenta
	# is_on_floor() resta falso e la cattura mostrerebbe una scena senza effetto.
	player.set_physics_process(true)
	for _frame in 26:
		player.velocity.x = 150.0
		player.set("move_particle_timer", 0.0)
		await process_frame
	player.set_physics_process(false)
	await _settle(3)
	_save_viewport("00-player-footstep-fx.png")
	player.velocity = Vector2.ZERO


## Il suggerimento compare solo dopo qualche secondo di stallo: qui l'attesa
## viene forzata, altrimenti la cattura mostrerebbe sempre lo schermo pulito.
func _capture_tutorial_mark(tutorial: Node) -> void:
	tutorial.set("_hint_wait", 99.0)
	var panel := tutorial.get("_panel") as PanelContainer
	if panel:
		panel.visible = true
		panel.modulate.a = 0.85
	await _settle(10)
	_save_viewport("01-tutorial-mark.png")


## Il Custode e' un solo sprite dipinto: queste pose servono a controllare a
## occhio che le animazioni procedurali si distinguano davvero fra loro.
func _capture_boss_animations(player: CharacterBody2D, boss: CharacterBody2D) -> void:
	player.global_position = Vector2(5060, -545)
	player.velocity = Vector2.ZERO
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		if camera.has_method("set_camera_target"):
			camera.call("set_camera_target", player, 0)
		camera.reset_smoothing()
	boss.set_physics_process(true)
	boss.set("player", player)
	await _settle(6)
	for wanted in ["chase", "windup", "attack"]:
		var captured := false
		for _frame in 900:
			player.set("current_health", 5)
			player.set("is_dead", false)
			await process_frame
			if str(boss.call("get_animation_state")) == wanted:
				_save_viewport("16-boss-%s.png" % wanted)
				captured = true
				break
		if not captured:
			push_error("Boss never reached the '%s' pose during capture" % wanted)
	boss.set_physics_process(false)


func _capture_mobile_controls_preview() -> void:
	var controls_scene := load("res://UI/MobileControls.tscn") as PackedScene
	var controls := controls_scene.instantiate()
	controls.set("force_preview", true)
	root.add_child(controls)
	await _settle(5)
	_save_viewport("06-mobile-controls-preview.png")
	controls.queue_free()
	await process_frame


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
		if camera.has_method("set_camera_target"):
			camera.call("set_camera_target", player, 0)
		camera.reset_smoothing()
	await _settle(32)
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
