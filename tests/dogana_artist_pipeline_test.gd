extends Node


func _ready() -> void:
	var profile := load("res://Levels/Scenes/Dogana/dogana_art_profile.tres") as DoganaArtProfile
	if profile == null:
		_fail("Dogana art profile could not be loaded.")
		return
	for texture in [profile.tide_altar, profile.cracked_urn, profile.net_bundle]:
		if texture == null:
			_fail("An illustrator-facing prop slot is empty.")
			return
		var image: Image = texture.get_image()
		if image == null or image.get_pixel(0, 0).a > 0.02:
			_fail("Generated prop artwork still has an opaque preview background.")
			return

	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var grace := level.get_node("Gameplay/GraceSites/Pontile")
	var player := level.get_node("Player") as CharacterBody2D
	var altar := grace.get_node_or_null("IllustratedAltar") as Sprite2D
	if altar == null:
		_fail("The geometric altar was not replaced by the art-profile illustration.")
		return
	if player.z_index <= grace.z_index or altar.z_index >= player.z_index:
		_fail("The player is not rendered in front of the tide altar.")
		return
	for lip in get_tree().get_nodes_in_group("dogana_foot_lip"):
		var line := lip as Line2D
		if line == null or line.width > 2.0 or line.default_color.r > 0.35:
			_fail("A bright or oversized platform line still covers the player.")
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
			or fish.global_position.x < 360.0
			or fish.global_position.x > 710.0
			or fish.global_position.y < 590.0
			or fish.global_position.y > 700.0
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
	if boss == null or int(boss.get("state")) != 5 or boss.is_physics_processing():
		_fail("A defeated boss was restored as an active encounter.")
		return

	print("CALIGO_ARTIST_PIPELINE: transparent props, 3 breakable variants, tutorial fish and permanent boss defeat OK")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
