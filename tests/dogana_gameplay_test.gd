extends Node


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	if packed == null:
		push_error("Could not load Punta della Dogana.")
		get_tree().quit(1)
		return
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cutscene := level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
	var player_boot := level.get_node_or_null("Player") as CharacterBody2D
	if player_boot:
		player_boot.collision_layer = 2
		player_boot.collision_mask = 1
		player_boot.set_physics_process(true)
		player_boot.set_meta("arrival_locked", false)

	var enemies := get_tree().get_nodes_in_group("dogana_encounters")[0].get_children()
	var interactions := get_tree().get_nodes_in_group("dogana_interactable")
	var secrets := get_tree().get_nodes_in_group("dogana_hidden_reveal")
	var graces := get_tree().get_nodes_in_group("dogana_grace")
	var fish := get_tree().get_nodes_in_group("fish")
	var selector := level.get_node_or_null("GameMenu/ScenarioSelector")
	var map := level.get_node_or_null("DoganaMap")
	var map_canvas := level.get_node_or_null("DoganaMap/Overlay/Frame/MapCanvas")
	var hud := level.get_node_or_null("MetroidvaniaHUD/HUD")
	var eldritch_props := get_tree().get_nodes_in_group("dogana_eldritch_props")
	var illustrated_background := get_tree().get_nodes_in_group("dogana_illustrated_background")
	var foreground_decor := get_tree().get_nodes_in_group("dogana_foreground_decor")
	var platform_art := get_tree().get_nodes_in_group("dogana_generated_platform_art")
	var breakables := get_tree().get_nodes_in_group("dogana_breakable")
	var palace := get_tree().get_first_node_in_group("dogana_vertical_palace")
	var palace_encounters := get_tree().get_first_node_in_group("dogana_palace_encounters")
	var world_bounds := get_tree().get_first_node_in_group("dogana_world_bounds")
	var boss := get_tree().get_first_node_in_group("dogana_boss")
	var mobile_controls := get_tree().root.find_child("MobileControls", true, false)
	var pontile_button := level.get_node_or_null("DoganaMap/Overlay/Frame/MapCanvas/Pontile") as Button
	var player := level.get_node_or_null("Player")
	var checkpoint := Vector2(2345.0, 432.0)
	player.call("set_checkpoint", checkpoint)
	var respawn: Vector2 = player.call("_find_respawn_position")
	if (
		enemies.size() < 8
		or interactions.size() < 12
		or secrets.size() < 3
		or graces.size() != 3
		or fish.size() < 9
		or selector == null
		or map == null
		or map_canvas == null
		or not map_canvas.has_method("set_map_state")
		or hud == null
		or eldritch_props.is_empty()
		or illustrated_background.is_empty()
		or foreground_decor.is_empty()
		or platform_art.is_empty()
		or breakables.size() < 25
		or palace == null
		or palace_encounters == null
		or world_bounds == null
		or palace_encounters.get_child_count() < 4
		or int(palace.get_meta("platform_count", 0)) < 10
		or palace.is_processing()
		or palace.is_physics_processing()
		or boss == null
		or mobile_controls != null
		or pontile_button == null
		or pontile_button.disabled
		or not respawn.is_equal_approx(checkpoint)
	):
		push_error("Dogana gameplay structure is incomplete.")
		get_tree().quit(1)
		return
	if (palace_encounters.get_child(0) as CharacterBody2D).is_physics_processing():
		push_error("Off-screen palace encounters must remain disabled for performance.")
		get_tree().quit(1)
		return
	var first_enemy := enemies[0] as Node2D
	var gate := level.get_node("Gameplay/Geometry/CanalGate") as StaticBody2D
	var gate_shape := gate.get_node("CollisionShape2D").shape as RectangleShape2D
	var fishing_hint := level.get_node("TutorialHints").get("_fishing_panel") as PanelContainer
	var perimeter := world_bounds.get_node("PerimeterCollision") as StaticBody2D
	var camera := level.get_node("Player/Camera2D") as Camera2D
	var architecture := level.get_node("Environment/Architecture") as Node2D
	var old_decor := level.get_node("Gameplay/DoganaForegroundDecor") as Node2D
	if (
		first_enemy.global_position.x < 1800.0
		or gate_shape.size.y < 700.0
		or not bool(gate.get_meta("mandatory", false))
		or fishing_hint == null
		or perimeter.get_child_count() != 2
		or camera.zoom.x < 1.1
		or architecture.visible
		or old_decor.visible
	):
		push_error("Safe introduction, perimeter clarity, camera framing, or mandatory flow is incomplete.")
		get_tree().quit(1)
		return
	var gate_lever := level.get_node("Gameplay/Interactions/GateLever") as Area2D
	level.call("_open_canal_gate", gate_lever)
	await get_tree().physics_frame
	if (gate.get_node("CollisionShape2D") as CollisionShape2D).disabled:
		push_error("Mandatory canal gate opened before the palace seal was collected.")
		get_tree().quit(1)
		return
	var palace_entrance := level.get_node("Gameplay/VerticalPalace/PalaceEntrance") as Area2D
	level.call("_activate_interactable", palace_entrance)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if player.global_position.y >= -100.0:
		push_error("Palace entrance did not move the player into the vertical maze.")
		get_tree().quit(1)
		return
	var palace_enemy := palace_encounters.get_child(0) as CharacterBody2D
	if not palace_enemy.is_physics_processing():
		push_error("Palace encounters did not activate only after entering the vertical zone.")
		get_tree().quit(1)
		return
	var palace_seal := level.get_node("Gameplay/VerticalPalace/PalaceSeal") as Area2D
	level.call("_activate_interactable", palace_seal)
	level.call("_open_canal_gate", gate_lever)
	await get_tree().physics_frame
	if not (gate.get_node("CollisionShape2D") as CollisionShape2D).disabled:
		push_error("Mandatory canal gate did not open after collecting the palace seal.")
		get_tree().quit(1)
		return
	var mock_attack := Area2D.new()
	mock_attack.add_to_group("player_attack")
	add_child(mock_attack)
	var breakable_prop := get_tree().get_first_node_in_group("dogana_breakable_prop")
	breakable_prop.call("_on_hurtbox_entered", mock_attack)
	breakable_prop.call("_on_hurtbox_entered", mock_attack)
	var secret_wall := level.get_node("Gameplay/Geometry/HiddenArchiveRoute/ArchiveWall")
	secret_wall.call("_on_hurtbox_entered", mock_attack)
	secret_wall.call("_on_hurtbox_entered", mock_attack)
	await get_tree().physics_frame
	if (
		not (breakable_prop.get_node("CollisionShape2D") as CollisionShape2D).disabled
		or not (secret_wall.get_node("CollisionShape2D") as CollisionShape2D).disabled
	):
		push_error("Breakable props or hidden walls did not release their collision.")
		get_tree().quit(1)
		return
	var dogana_grace := level.get_node("Gameplay/GraceSites/Dogana")
	dogana_grace.call("_on_body_entered", player)
	var grace_prompt := dogana_grace.get_node("Prompt") as Label
	if not grace_prompt.visible or ("RISVEGLIA" not in grace_prompt.text and "RIPOSA" not in grace_prompt.text):
		push_error("Grace activation prompt is not explicit.")
		get_tree().quit(1)
		return
	dogana_grace.call("_on_body_exited", player)
	var archive_reveal := level.get_node("Gameplay/Geometry/HiddenArchiveRoute/SecretReveal") as Area2D
	level.call("_on_hidden_area_entered", player, archive_reveal)
	var discovered_regions: Dictionary = map.get("_regions")
	if not bool(archive_reveal.get_meta("revealed", false)) or not bool(discovered_regions.get("archive", false)):
		push_error("Hidden archive discovery did not update the area map.")
		get_tree().quit(1)
		return
	map.call("open_map")
	var overlay := level.get_node("DoganaMap/Overlay") as Control
	if not get_tree().paused or not overlay.visible:
		push_error("Dogana map did not open and pause gameplay.")
		get_tree().quit(1)
		return
	map.call("close_map")
	if get_tree().paused or overlay.visible:
		push_error("Dogana map did not close cleanly.")
		get_tree().quit(1)
		return
	boss.call("_awaken")
	await get_tree().physics_frame
	var arena_seal := level.get_node("Gameplay/Geometry/BossArena/EntranceSeal/CollisionShape2D") as CollisionShape2D
	if arena_seal.disabled:
		push_error("Boss arena did not lock when the boss awakened.")
		get_tree().quit(1)
		return
	boss.set("current_health", 1)
	boss.call("take_damage", 1, player.global_position)
	await get_tree().process_frame
	if not bool(level.get("_boss_is_defeated")):
		push_error("Boss defeat did not unlock the level exit.")
		get_tree().quit(1)
		return
	print("CALIGO_DOGANA_TEST: %d enemies, %d fish, %d breakables, vertical palace maze, seal gate, boss and map OK" % [
		enemies.size(),
		fish.size(),
		breakables.size(),
	])
	level.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.1).timeout
	get_tree().quit(0)
