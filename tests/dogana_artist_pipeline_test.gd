extends Node


func _ready() -> void:
	var profile := load("res://Levels/Scenes/Dogana/dogana_art_profile.tres") as DoganaArtProfile
	if profile == null:
		_fail("Dogana art profile could not be loaded.")
		return
	if (
		profile.tide_bloater_kit == null
		or profile.lagoon_oracle_kit == null
		or profile.drowned_warden_kit == null
	):
		_fail("Enemy art kits are missing from the Dogana profile.")
		return
	for texture in [profile.tide_altar, profile.cracked_urn, profile.net_bundle, profile.thorn_cluster, profile.thorn_bed]:
		if texture == null:
			_fail("An illustrator-facing prop slot is empty.")
			return
		var image: Image = texture.get_image()
		if image == null or image.get_pixel(0, 0).a > 0.02:
			_fail("Generated prop artwork still has an opaque preview background.")
			return

	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var map_art := load("res://Landscape/Dogana/Generated/dogana_map_sideview_v2.png") as Texture2D
	if map_art == null or map_art.get_width() < 1500 or map_art.get_height() < 700:
		_fail("The illustrated Punta side-view map asset is missing or too small.")
		return
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	var sideview_modules := get_tree().get_nodes_in_group("dogana_sideview_module")
	if sideview_modules.size() != 6:
		_fail("Punta architecture is not split into six artist-replaceable modules.")
		return
	var expected_order := 0
	var previous_x := -INF
	for module_node in sideview_modules:
		var module := module_node as Sprite2D
		if module == null or not is_equal_approx(absf(module.scale.x), absf(module.scale.y)):
			_fail("A Punta architecture module is horizontally or vertically stretched.")
			return
		if int(module.get_meta("module_order", -1)) != expected_order or module.position.x <= previous_x:
			_fail("Punta architecture module ordering is incoherent.")
			return
		if not is_equal_approx(float(module.get_meta("baseline_y", -1.0)), 530.0):
			_fail("Punta architecture modules do not share the same authored baseline.")
			return
		var image := module.texture.get_image()
		if image == null or image.get_pixel(0, 0).a > 0.02:
			_fail("A Punta architecture module still has an opaque preview background.")
			return
		previous_x = module.position.x
		expected_order += 1

	var grace := level.get_node("Gameplay/GraceSites/Pontile")
	var player := level.get_node("Player") as CharacterBody2D
	var altar := grace.get_node_or_null("IllustratedAltar") as Sprite2D
	if altar == null:
		_fail("The geometric altar was not replaced by the art-profile illustration.")
		return
	if player.z_index <= grace.z_index or altar.z_index >= player.z_index:
		_fail("The player is not rendered in front of the tide altar.")
		return
	if not get_tree().get_nodes_in_group("dogana_foot_lip").is_empty():
		_fail("A platform line still covers the player's feet.")
		return

	var variants: Dictionary = {}
	for prop in get_tree().get_nodes_in_group("dogana_breakable_prop"):
		variants[int(prop.get("visual_variant"))] = true
	if variants.size() < 3:
		_fail("Dogana breakables do not expose all three art variants.")
		return

	var tutorial_fishes: Array[Node2D] = []
	for fish in get_tree().get_nodes_in_group("fish"):
		if bool(fish.get_meta("tutorial_fish", false)):
			tutorial_fishes.append(fish as Node2D)
	if tutorial_fishes.size() < 3:
		_fail("The fishing tutorial did not prepare a visible fish cluster.")
		return
	for _frame in 180:
		await get_tree().physics_frame
	for fish in tutorial_fishes:
		if (
			not is_instance_valid(fish)
			or fish.global_position.x < 180.0
			or fish.global_position.x > 430.0
			or fish.global_position.y < 580.0
			or fish.global_position.y > 720.0
			or fish.get("_water_body") == null
		):
			_fail("Tutorial fish drifted away or spawned before receiving its water body.")
			return

	var hook_scene := player.get("fishing_hook_scene") as PackedScene
	var hook := hook_scene.instantiate() as RigidBody2D
	level.add_child(hook)
	hook.global_position = tutorial_fishes[0].global_position + Vector2(8, 0)
	hook.call("set_player_reference", player)
	hook.call("set_in_water", true)
	player.set("hook_instance", hook)
	player.set("line_mode", 1)
	player.set("line_extended", true)
	var rod_tip: Vector2 = player.call("get_rod_tip_position")
	var cast_distance: float = rod_tip.distance_to(hook.global_position)
	player.set("current_line_length", cast_distance + 24.0)
	player.set("target_line_length", cast_distance + 80.0)
	player.call("_init_rope_points", player.call("get_rod_tip_position"))
	for _frame in 180:
		await get_tree().physics_frame
		if bool(player.get("fish_hooked")):
			break
	if not bool(player.get("fish_hooked")):
		_fail("Hook failed: water=%s processing=%s distance=%.1f attracted=%s target=%s." % [
			hook.call("is_in_water"),
			hook.is_physics_processing(),
			hook.global_position.distance_to(tutorial_fishes[0].global_position),
			tutorial_fishes[0].get("is_attracted"),
			tutorial_fishes[0].get("target_hook") != null,
		])
		return
	var catches: Array[int] = []
	player.fish_caught.connect(func(amount: int) -> void: catches.append(amount))
	for frame in 720:
		if not bool(player.get("fish_hooked")):
			break
		if bool(player.get("fish_struggle_active")):
			player.set("reel_pulse_timer", 0.0)
			player.set("is_reeling", false)
		elif frame % 10 == 0:
			player.set("reel_pulse_timer", 0.22)
			player.set("is_reeling", true)
		await get_tree().physics_frame
	if catches.is_empty():
		var active_fish := player.get("current_fish") as Node2D
		_fail("Reel failed: hooked=%s fish=%s distance=%.1f stress=%.2f." % [
			player.get("fish_hooked"),
			active_fish != null,
			player.global_position.distance_to(active_fish.global_position) if active_fish else -1.0,
			player.get("_current_line_stress"),
		])
		return

	var boss := get_tree().get_first_node_in_group("dogana_boss")
	level.set("_boss_is_defeated", true)
	level.call("_restore_boss_progress")
	await get_tree().process_frame
	# DEAD enum value on drowned_customs_warden (last state).
	var dead_state := 12
	if boss == null or int(boss.get("state")) != dead_state or boss.is_physics_processing():
		_fail("A defeated boss was restored as an active encounter.")
		return

	print("CALIGO_ARTIST_PIPELINE: transparent props, 3 breakable variants, tutorial fish and permanent boss defeat OK")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
