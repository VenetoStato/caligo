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
	var surface_encounters := level.get_node("Gameplay/Encounters")
	for enemy in surface_encounters.get_children():
		if enemy is CharacterBody2D and enemy.is_physics_processing():
			push_error("Distant surface encounter was not culled during the safe introduction.")
			get_tree().quit(1)
			return
	var active_waters := 0
	for water in get_tree().get_nodes_in_group("water"):
		if water.process_mode != Node.PROCESS_MODE_DISABLED:
			active_waters += 1
	if active_waters != 1:
		push_error("Off-screen water basin culling is not active.")
		get_tree().quit(1)
		return

	var outside_total_ms := 0.0
	var outside_started := Time.get_ticks_usec()
	for _frame in 180:
		await get_tree().physics_frame
		outside_total_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var outside_monitor_ms := outside_total_ms / 180.0
	var outside_average_ms := (Time.get_ticks_usec() - outside_started) / 1000.0 / 180.0

	var player := level.get_node("Player") as CharacterBody2D
	player.global_position = Vector2(2260, -190)
	level.call("_update_water_culling")
	level.call("_update_encounter_culling")
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
	for water in get_tree().get_nodes_in_group("water"):
		if water.process_mode != Node.PROCESS_MODE_DISABLED:
			push_error("Water simulation remained active while the player was inside the palace.")
			get_tree().quit(1)
			return

	var inside_total_ms := 0.0
	var inside_started := Time.get_ticks_usec()
	for _frame in 180:
		await get_tree().physics_frame
		inside_total_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var inside_monitor_ms := inside_total_ms / 180.0
	var inside_average_ms := (Time.get_ticks_usec() - inside_started) / 1000.0 / 180.0
	print("CALIGO_PALACE_PERF_SAMPLE: outside %.3f ms/tick, active %.3f ms/tick (monitor %.3f / %.3f)" % [
		outside_average_ms,
		inside_average_ms,
		outside_monitor_ms,
		inside_monitor_ms,
	])
	if outside_average_ms > 20.0 or inside_average_ms > 20.0:
		push_error("Vertical palace could not sustain the 60 Hz physics cadence.")
		get_tree().quit(1)
		return
	print(
		"CALIGO_PALACE_PERF: static shapes %d, outside %.3f ms/frame, active %.3f ms/frame"
		% [collision_body.get_child_count(), outside_average_ms, inside_average_ms]
	)
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
