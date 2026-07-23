extends Node


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player := level.get_node("Player") as CharacterBody2D
	player.set_physics_process(false)
	player.global_position = Vector2(500, 455)
	var fishing_line := player.get_node_or_null("FishingLine") as Line2D
	if fishing_line == null or not fishing_line.top_level or fishing_line.width < 2.5:
		_fail("The fishing line is missing, too thin, or not using world coordinates.")
		return

	var hook_scene := player.get("fishing_hook_scene") as PackedScene
	var hook := hook_scene.instantiate() as RigidBody2D
	level.add_child(hook)
	hook.global_position = Vector2(500, 530)
	hook.linear_velocity = Vector2(0, 165)
	hook.call("set_player_reference", player)
	for _frame in 75:
		await get_tree().physics_frame
	if not bool(hook.call("is_in_water")) or hook.global_position.y < 575.0:
		_fail("The fishing hook did not sink below the lagoon surface.")
		return

	player.set("hook_instance", hook)
	player.set("line_mode", 1)
	player.set("line_extended", true)
	player.set("target_line_length", 300.0)
	player.set("current_line_length", 180.0)
	player.call("_init_rope_points", player.call("get_rod_tip_position"))
	for _frame in 8:
		player.call("_process_fishing", 1.0 / 60.0)
		await get_tree().process_frame
	if fishing_line.get_point_count() < 12 or fishing_line.default_color.a < 0.8:
		_fail("The cast hook is not connected to a clearly visible simulated line.")
		return

	var second_hook := hook_scene.instantiate() as RigidBody2D
	level.add_child(second_hook)
	await get_tree().process_frame
	var first_radius := ((hook.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	var second_radius := ((second_hook.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	if not is_equal_approx(first_radius, second_radius) or first_radius < 1.0:
		_fail("Fishing-hook collision shrinks across repeated casts.")
		return

	if bool(player.call("is_grab_hook_unlocked")):
		_fail("The traversal hook must remain locked before the boss reward.")
		return
	player.call("unlock_grab_hook")
	if not bool(player.call("is_grab_hook_unlocked")):
		_fail("The boss reward did not unlock the traversal hook.")
		return

	print("CALIGO_FISHING_CAST: underwater hook, visible line, repeatable collision and boss-gated traversal OK")
	level.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.1).timeout
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
