extends SceneTree
## Test isolato: attrazione, reel verso player, uscita e rientro acqua.

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
	water.set("bounds", Rect2(0, 500, 800, 300))

	var fish_scene := load("res://fish.tscn") as PackedScene
	if fish_scene == null:
		_fail("Missing fish.tscn")
		return
	var fish := fish_scene.instantiate() as RigidBody2D
	root.add_child(fish)
	await process_frame
	fish.global_position = Vector2(400, 620)
	fish.set("in_water", true)
	fish.set("_water_body", water)

	var player := Node2D.new()
	player.name = "Player"
	root.add_child(player)
	player.global_position = Vector2(250, 600)

	# 1) Attrazione
	fish.call("attract_to", Vector2(350, 600))
	if not bool(fish.get("is_attracted")):
		_fail("attract_to failed")
		return

	# 2) Aggancio + lotta
	fish.call("set_player_reference", player)
	if not bool(fish.call("is_hooked")):
		_fail("hook failed")
		return
	fish.call("start_struggle")
	if not bool(fish.get("is_struggling")):
		_fail("struggle failed")
		return
	fish.call("stop_struggle")

	# 3) Reel verso player (stesso bacino)
	var before := fish.global_position.distance_to(player.global_position)
	for _i in 40:
		fish.call("pull_along_line", player.global_position, 8.0, false)
		fish.call("apply_reel_force", (player.global_position - fish.global_position).normalized() * 500.0)
	var after := fish.global_position.distance_to(player.global_position)
	if after >= before - 40.0:
		_fail("reel toward player failed (%.1f -> %.1f)" % [before, after])
		return

	# 4) Uscita → rientro
	fish.call("do_catch_jump")
	if bool(fish.call("is_in_water")):
		_fail("catch jump should leave water")
		return
	fish.global_position = Vector2(400, 530)
	var reentered: bool = bool(fish.call("_try_reenter_water"))
	if not reentered or not bool(fish.call("is_in_water")):
		_fail("re-enter water failed")
		return

	print("FISHING_REENTRY_REEL_TEST_OK")
	quit(0)


func _fail(msg: String) -> void:
	push_error("FISHING_REENTRY_REEL_TEST_FAIL: " + msg)
	quit(1)
