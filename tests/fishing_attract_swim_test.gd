extends SceneTree
## Valida: pesci nuotano liberamente e si avvicinano all'amo.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node2D.new()
	root.name = "TestRoot"
	root.set_meta("is_test_root", true)
	get_root().add_child(root)

	var water_script := load("res://tests/fake_water_body.gd")
	var water := Node2D.new()
	water.set_script(water_script)
	water.name = "Water"
	water.add_to_group("water")
	root.add_child(water)
	water.global_position = Vector2(0, 500)
	water.set("target_height", 0.0)
	water.set("bounds", Rect2(0, 500, 900, 320))

	var fish_scene := load("res://fish.tscn") as PackedScene
	if fish_scene == null:
		_fail("Missing fish.tscn")
		return
	var fish := fish_scene.instantiate() as RigidBody2D
	root.add_child(fish)
	await process_frame
	fish.global_position = Vector2(500, 620)
	fish.set("in_water", true)
	fish.set("_water_body", water)
	fish.set("home_position", fish.global_position)

	# 1) Nuoto libero: deve spostarsi
	var start_pos := fish.global_position
	for _i in 90:
		fish.call("_process_swimming", 1.0 / 60.0)
		fish.global_position += Vector2(fish.get("velocity")) * (1.0 / 60.0)
	var free_travel := fish.global_position.distance_to(start_pos)
	if free_travel < 8.0:
		_fail("free swim locked (travel=%.1f)" % free_travel)
		return
	if bool(fish.call("is_hanging")):
		_fail("free fish should not hang")
		return

	# 2) Attrazione verso amo
	var hook := Node2D.new()
	hook.name = "FakeHook"
	root.add_child(hook)
	hook.global_position = Vector2(350, 600)
	fish.global_position = Vector2(520, 640)
	fish.set("velocity", Vector2.ZERO)
	fish.set("target_hook", hook)
	fish.call("attract_to", hook.global_position)
	if not bool(fish.get("is_attracted")):
		_fail("attract_to did not arm attraction")
		return

	var before := fish.global_position.distance_to(hook.global_position)
	for _i in 80:
		fish.call("_process_swimming", 1.0 / 60.0)
		fish.global_position += Vector2(fish.get("velocity")) * (1.0 / 60.0)
	var after := fish.global_position.distance_to(hook.global_position)
	if after >= before - 25.0:
		_fail("fish did not swim toward hook (%.1f -> %.1f)" % [before, after])
		return

	print("FISHING_ATTRACT_SWIM_TEST_OK")
	quit(0)


func _fail(msg: String) -> void:
	push_error("FISHING_ATTRACT_SWIM_TEST_FAIL: " + msg)
	quit(1)
