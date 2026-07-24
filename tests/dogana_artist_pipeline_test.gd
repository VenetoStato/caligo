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
	if grace.get_node_or_null("IllustratedAltar") == null:
		_fail("The geometric altar was not replaced by the art-profile illustration.")
		return

	var variants: Dictionary = {}
	for prop in get_tree().get_nodes_in_group("dogana_breakable_prop"):
		variants[int(prop.get("visual_variant"))] = true
	if variants.size() < 3:
		_fail("Dogana breakables do not expose all three art variants.")
		return

	var tutorial_fish := 0
	for fish in get_tree().get_nodes_in_group("fish"):
		if fish.global_position.x >= 360.0 and fish.global_position.x <= 710.0:
			tutorial_fish += 1
	if tutorial_fish < 3:
		_fail("The fishing tutorial did not prepare a visible fish cluster.")
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
