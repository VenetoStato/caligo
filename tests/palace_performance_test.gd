extends Node


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var palace := get_tree().get_first_node_in_group("dogana_vertical_palace")
	var collision_body := get_tree().get_first_node_in_group("dogana_palace_static_collision")
	var encounters := get_tree().get_first_node_in_group("dogana_palace_encounters")
	if (
		palace == null
		or collision_body == null
		or collision_body.get_child_count() < 15
		or encounters == null
		or encounters.get_child_count() != 4
		or palace.is_processing()
		or palace.is_physics_processing()
	):
		push_error("Palace static batching or process optimization is incomplete.")
		get_tree().quit(1)
		return
	for enemy in encounters.get_children():
		if enemy.is_physics_processing():
			push_error("Off-screen palace enemy consumed physics time.")
			get_tree().quit(1)
			return

	var outside_total_ms := 0.0
	for _frame in 180:
		await get_tree().physics_frame
		outside_total_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var outside_average_ms := outside_total_ms / 180.0

	var player := level.get_node("Player") as CharacterBody2D
	player.global_position = Vector2(2260, -190)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var active_count := 0
	for enemy in encounters.get_children():
		if enemy.is_physics_processing():
			active_count += 1
	if active_count != 4:
		push_error("Palace encounter activation culling failed.")
		get_tree().quit(1)
		return

	var inside_total_ms := 0.0
	for _frame in 180:
		await get_tree().physics_frame
		inside_total_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var inside_average_ms := inside_total_ms / 180.0
	if outside_average_ms > 16.7 or inside_average_ms > 16.7:
		push_error("Vertical palace exceeded the 60 FPS CPU frame budget.")
		get_tree().quit(1)
		return
	print(
		"CALIGO_PALACE_PERF: static shapes %d, outside %.3f ms/frame, active %.3f ms/frame"
		% [collision_body.get_child_count(), outside_average_ms, inside_average_ms]
	)
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
