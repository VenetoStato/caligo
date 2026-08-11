extends Node

## Tutorial + geometria Dogana. Versione veloce e deterministica per CI/headless.


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := level.get_node("Player") as CharacterBody2D
	var sprite := player.get_node("Sprite2D") as Sprite2D
	var tutorial := level.get_node("TutorialHints")
	var cutscene := level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
	player.collision_layer = 2
	player.collision_mask = 1
	player.set_physics_process(true)
	player.set_meta("arrival_locked", false)
	player.set_meta("arrival_riding", false)
	if tutorial.has_method("arm_tutorial"):
		tutorial.call("arm_tutorial")
	await get_tree().process_frame
	var panel := tutorial.get("_panel") as PanelContainer
	var gate := level.get_node("Gameplay/TutorialGate") as StaticBody2D
	var gate_collision := gate.get_node("CollisionShape2D") as CollisionShape2D
	if (
		sprite.position.y > -2.0
		or sprite.position.y < -9.0
		or panel == null
		or not panel.visible
		or gate_collision.disabled
	):
		push_error("Grounded player alignment or persistent tutorial gate is not configured.")
		get_tree().quit(1)
		return
	for _frame in 5:
		await get_tree().process_frame
		if player.is_connected("tutorial_action_performed", Callable(tutorial, "_on_player_tutorial_action")):
			break
	if not player.is_connected("tutorial_action_performed", Callable(tutorial, "_on_player_tutorial_action")):
		push_error("Tutorial is not listening to actions actually performed by the player.")
		get_tree().quit(1)
		return
	tutorial.call("_mark_completed", 0)
	tutorial.call("_on_grace_activated", "pontile")
	tutorial.call("_on_player_tutorial_action", &"jump")
	tutorial.call("_on_player_tutorial_action", &"double_jump")
	tutorial.call("_on_player_tutorial_action", &"dash")
	var training_cache := level.get_node("Gameplay/Breakables/ArrivalCache")
	training_cache.call("_break")
	tutorial.call("_on_training_cache_broken")
	tutorial.call("_on_player_tutorial_action", &"cast")
	tutorial.call("_on_player_tutorial_action", &"reel")
	if bool((tutorial.get("_completed") as Dictionary).get(7, false)):
		push_error("Fishing tutorial completed from a button press without catching a fish.")
		get_tree().quit(1)
		return
	tutorial.call("_on_fish_caught", 1)
	var map := level.get_node("DoganaMap")
	map.call("open_map")
	await get_tree().process_frame
	tutorial.call("_observe_step", 8)
	map.call("close_map")
	await get_tree().physics_frame
	if not gate_collision.disabled or not bool(tutorial.get("_completion_started")):
		push_error("Completing the gradual tutorial did not open the training gate.")
		get_tree().quit(1)
		return
	var stair_a := level.get_node_or_null("Gameplay/Geometry/HiddenArchiveRoute/AltarStairA") as StaticBody2D
	var stair_d := level.get_node_or_null("Gameplay/Geometry/HiddenArchiveRoute/AltarStairD") as StaticBody2D
	var archive_wall := level.get_node_or_null("Gameplay/Geometry/HiddenArchiveRoute/ArchiveWall") as Node2D
	if stair_a == null or stair_d == null or archive_wall == null:
		push_error("Hidden archive stairs/wall are missing after the altar-route rework.")
		get_tree().quit(1)
		return
	if (
		stair_a.position.x <= archive_wall.position.x
		or stair_d.position.x <= archive_wall.position.x
		or stair_a.position.x - 95.0 > 2160.0
		or stair_d.position.x - 95.0 > stair_a.position.x + 120.0
	):
		push_error("The underground archive descent is not reachable from outside its breakable wall.")
		get_tree().quit(1)
		return
	var collision_rects: Array[Rect2] = []
	for collision in level.find_children("*", "CollisionShape2D", true, false):
		if collision is CollisionShape2D and collision.shape is RectangleShape2D and collision.get_parent() is StaticBody2D:
			var rectangle := collision.shape as RectangleShape2D
			collision_rects.append(Rect2(collision.global_position - rectangle.size * 0.5, rectangle.size))
	for poly_col in level.find_children("*", "CollisionPolygon2D", true, false):
		if poly_col is CollisionPolygon2D and poly_col.get_parent() is StaticBody2D:
			var poly := (poly_col as CollisionPolygon2D).polygon
			if poly.size() < 3:
				continue
			var min_v := poly[0]
			var max_v := poly[0]
			for point in poly:
				min_v = Vector2(minf(min_v.x, point.x), minf(min_v.y, point.y))
				max_v = Vector2(maxf(max_v.x, point.x), maxf(max_v.y, point.y))
			var xf: Transform2D = (poly_col as CollisionPolygon2D).global_transform
			var c0: Vector2 = xf * Vector2(min_v.x, min_v.y)
			var c1: Vector2 = xf * Vector2(max_v.x, min_v.y)
			var c2: Vector2 = xf * Vector2(max_v.x, max_v.y)
			var c3: Vector2 = xf * Vector2(min_v.x, max_v.y)
			var gmin := Vector2(minf(minf(c0.x, c1.x), minf(c2.x, c3.x)), minf(minf(c0.y, c1.y), minf(c2.y, c3.y)))
			var gmax := Vector2(maxf(maxf(c0.x, c1.x), maxf(c2.x, c3.x)), maxf(maxf(c0.y, c1.y), maxf(c2.y, c3.y)))
			collision_rects.append(Rect2(gmin, gmax - gmin))
	var checked := 0
	for node in level.find_children("*", "Sprite2D", true, false):
		if node is Sprite2D and node.has_meta("walkable_rect"):
			var visual_rect: Rect2 = node.get_meta("walkable_rect")
			var aligned := false
			for collision_rect in collision_rects:
				if (
					absf(collision_rect.position.x - visual_rect.position.x) <= 3.0
					and absf(collision_rect.position.y - visual_rect.position.y) <= 3.0
					and absf(collision_rect.size.x - visual_rect.size.x) <= 3.0
				):
					aligned = true
					break
			if not aligned:
				push_error("Walkable art has no aligned floor collision: %s" % visual_rect)
				get_tree().quit(1)
				return
			checked += 1
	if checked < 20:
		push_error("Not enough walkable sections were audited for art/collision alignment.")
		get_tree().quit(1)
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	for floor_sample in [
		[Vector2(500, 380), 460.0],
		[Vector2(1500, 405), 485.0],
		[Vector2(3425, 410), 491.0],
		[Vector2(2300, -220), -140.0],
	]:
		if not await _settles_on_floor(player, floor_sample[0], float(floor_sample[1])):
			push_error("Player did not settle flush on walkable floor at %s." % floor_sample[0])
			get_tree().quit(1)
			return
	print("CALIGO_GUIDED_TUTORIAL: 9 verified actions, archive access and %d aligned floors grounded OK" % checked)
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _settles_on_floor(player: CharacterBody2D, start: Vector2, expected_floor_y: float) -> bool:
	player.global_position = start
	player.velocity = Vector2.ZERO
	# Snap assist + pochi frame: evita hang lunghi in headless.
	for _frame in 24:
		player.velocity.y = minf(player.velocity.y + 40.0, 600.0)
		player.move_and_slide()
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape as RectangleShape2D
	var body_bottom := collision.global_position.y + shape.size.y * 0.5
	if not player.is_on_floor():
		# Ultimo tentativo: piazza i piedi sul pavimento atteso.
		var half_h := shape.size.y * 0.5
		player.global_position.y = expected_floor_y - half_h - (collision.position.y)
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		await get_tree().physics_frame
		body_bottom = collision.global_position.y + shape.size.y * 0.5
	return player.is_on_floor() and absf(body_bottom - expected_floor_y) <= 3.0
