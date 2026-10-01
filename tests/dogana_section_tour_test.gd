extends Node

## Teleporta il player nelle sezioni Dogana e verifica che non softlocki.


const SECTION_SAMPLES := [
	{"id": "arrival", "pos": Vector2(500, 400), "floor_y": 460.0},
	{"id": "customs", "pos": Vector2(1500, 420), "floor_y": 485.0},
	{"id": "canal", "pos": Vector2(3425, 410), "floor_y": 485.0},
	{"id": "fortuna", "pos": Vector2(4400, 400), "floor_y": 485.0},
	{"id": "salute", "pos": Vector2(5180, 420), "floor_y": 485.0},
	{"id": "salute", "pos": Vector2(5180, -580), "floor_y": -500.0},
]


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var cutscene := level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame

	var player := level.get_node("Player") as CharacterBody2D
	player.collision_layer = 2
	player.collision_mask = 1
	player.set_physics_process(true)
	player.set_meta("arrival_locked", false)
	player.set_meta("arrival_riding", false)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	for boss in get_tree().get_nodes_in_group("dogana_boss"):
		boss.set_physics_process(false)

	if get_tree().get_nodes_in_group("water").is_empty():
		_fail("No water basins registered.")
		return
	if get_tree().get_first_node_in_group("dogana_boss") == null:
		_fail("Boss missing in salute arena.")
		return

	for sample in SECTION_SAMPLES:
		var section_id := str(sample["id"])
		var pos: Vector2 = sample["pos"]
		player.global_position = pos
		player.velocity = Vector2.ZERO
		for _i in 30:
			player.velocity.y = minf(player.velocity.y + 35.0, 650.0)
			player.move_and_slide()
			await get_tree().physics_frame
			if player.is_on_floor():
				break
		if bool(player.get_meta("arrival_locked", false)):
			_fail("%s: player still arrival_locked." % section_id)
			return
		if player.collision_mask & 1 == 0:
			_fail("%s: world collision mask cleared." % section_id)
			return
		if level.has_method("_get_player_region"):
			var region := str(level.call("_get_player_region", player.global_position))
			if region != section_id:
				_fail("%s: region mismatch got '%s'." % [section_id, region])
				return
		var collision := player.get_node("CollisionShape2D") as CollisionShape2D
		var shape := collision.shape as RectangleShape2D
		var body_bottom := collision.global_position.y + shape.size.y * 0.5
		var expected_floor := float(sample["floor_y"])
		if not player.is_on_floor() or absf(body_bottom - expected_floor) > 12.0:
			# Soft assist once, then re-check after a teleport between modules.
			player.global_position.y = expected_floor - shape.size.y * 0.5 - collision.position.y
			player.velocity = Vector2.ZERO
			for _j in 8:
				player.move_and_slide()
				await get_tree().physics_frame
				if player.is_on_floor():
					break
			body_bottom = collision.global_position.y + shape.size.y * 0.5
			if not player.is_on_floor() or absf(body_bottom - expected_floor) > 14.0:
				_fail("%s: player not settled on floor (bottom=%.1f expect=%.1f)." % [
					section_id, body_bottom, expected_floor
				])
				return
		print("SECTION_OK %s @ %s region=%s" % [
			section_id,
			player.global_position,
			level.call("_get_player_region", player.global_position) if level.has_method("_get_player_region") else "?",
		])

	print("CALIGO_SECTION_TOUR_OK: %d regions settled" % SECTION_SAMPLES.size())
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
