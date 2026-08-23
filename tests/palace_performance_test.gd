extends Node

## Mantiene il vecchio nome file per compatibilita' col runner, ma misura il
## nuovo interno statico della Salute e il waterfront semplificato.


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var interior := get_tree().get_first_node_in_group("dogana_salute_interior")
	var collision_body := get_tree().get_first_node_in_group("dogana_salute_interior_collision")
	var waterfront := get_tree().get_first_node_in_group("dogana_simplified_waterfront")
	if interior == null or collision_body == null or collision_body.get_child_count() != 3 or waterfront == null:
		_fail("Salute static batching is incomplete")
		return
	if interior.is_processing() or interior.is_physics_processing():
		_fail("static Salute module consumes process time")
		return
	var surface_encounters := level.get_node("Gameplay/Encounters")
	for enemy in surface_encounters.get_children():
		if enemy is CharacterBody2D and not enemy.is_physics_processing():
			_fail("surface patrol was frozen")
			return

	var outside_average_ms := await _sample_physics_ms(180)
	var player := level.get_node("Player") as CharacterBody2D
	player.global_position = Vector2(5180, -545)
	level.call("_update_water_culling")
	await get_tree().physics_frame
	for water in get_tree().get_nodes_in_group("water"):
		if water.process_mode != Node.PROCESS_MODE_DISABLED:
			_fail("water simulation remained active inside Salute")
			return
	var inside_average_ms := await _sample_physics_ms(180)
	if outside_average_ms > 20.0 or inside_average_ms > 20.0:
		_fail("Salute scene missed the 60 Hz cadence")
		return
	print("CALIGO_PALACE_PERF: legacy token; Salute outside %.3f ms/tick, inside %.3f ms/tick" % [outside_average_ms, inside_average_ms])
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _sample_physics_ms(frames: int) -> float:
	var started := Time.get_ticks_usec()
	for _frame in frames:
		await get_tree().physics_frame
	return (Time.get_ticks_usec() - started) / 1000.0 / float(frames)


func _fail(message: String) -> void:
	push_error("CALIGO_SALUTE_PERF_FAIL: " + message)
	get_tree().quit(1)
