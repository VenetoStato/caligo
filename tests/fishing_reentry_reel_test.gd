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
	for _i in 50:
		var dir_r: Vector2 = (player.global_position - fish.global_position).normalized()
		fish.call("apply_reel_force", dir_r * 500.0)
		fish.call("pull_along_line", player.global_position, 8.0, false)
		var v: Vector2 = fish.get("velocity")
		fish.global_position += v * (1.0 / 60.0)
		fish.set("linear_velocity", v)
	var after := fish.global_position.distance_to(player.global_position)
	if after >= before - 35.0:
		_fail("reel toward player failed (%.1f -> %.1f)" % [before, after])
		return

	# 3b) Uscita: catch jump deve sollevare verso la superficie
	fish.call("set_line_tether", Vector2(250, 450), 100.0)
	fish.global_position = Vector2(300, 560)
	fish.set("in_water", true)
	fish.set("velocity", Vector2.ZERO)
	var y_before := fish.global_position.y
	fish.call("do_catch_jump")
	if fish.global_position.y >= y_before - 15.0:
		_fail("catch jump should lift fish (y %.1f -> %.1f)" % [y_before, fish.global_position.y])
		return

	# 3c) set_allow_surface_exit(false) NON deve abortire un'uscita in corso
	fish.call("do_catch_jump")
	if not bool(fish.get("_catch_jump_active")):
		_fail("catch jump inactive")
		return
	fish.call("set_allow_surface_exit", false)
	if not bool(fish.get("_catch_jump_active")):
		_fail("set_allow_surface_exit(false) aborted exit")
		return
	if not bool(fish.get("_allow_surface_exit")):
		_fail("exit allow should stay true during catch jump")
		return

	# 4) Uscita corretta: breach → sopra superficie → hang teso
	fish.call("set_line_tether", Vector2(250, 450), 140.0)
	fish.global_position = Vector2(400, 560)
	fish.set("in_water", true)
	fish.call("do_catch_jump")
	if not bool(fish.get("_catch_jump_active")):
		_fail("catch jump should start breach")
		return
	if bool(fish.call("is_hanging")):
		_fail("should not hang while still under surface")
		return
	# Simula uscita sopra la superficie (fake water surface y=500).
	fish.global_position = Vector2(320, 485)
	fish.call("_start_hanging_out_of_water")
	if bool(fish.call("is_in_water")):
		_fail("hang start should leave water")
		return
	if not bool(fish.call("is_hanging")):
		_fail("should hang after clearing surface")
		return
	var anchor := Vector2(250, 450)
	fish.call("set_line_tether", anchor, 120.0)
	fish.global_position = anchor + Vector2(200, 200)
	fish.set("velocity", Vector2(80, 120))
	fish.call("_apply_line_tether_constraint")
	var hang_dist := fish.global_position.distance_to(anchor)
	if hang_dist > 121.0 or hang_dist < 119.0:
		_fail("hanging fish must stay taut on line (dist=%.1f)" % hang_dist)
		return
	var n := (fish.global_position - anchor).normalized()
	var radial_left := absf(Vector2(fish.get("velocity")).dot(n))
	if radial_left > 5.0:
		_fail("taut constraint should remove radial velocity (left=%.1f)" % radial_left)
		return
	# 4b) Hang puo' rientrare in acqua e tornare attivo
	fish.call("set_line_tether", anchor, 80.0)
	fish.global_position = Vector2(400, 530)
	fish.set("velocity", Vector2(0, 80))
	fish.set("_hanging", true)
	fish.set("in_water", false)
	var re_from_hang: bool = bool(fish.call("_try_reenter_from_hang"))
	if not re_from_hang or not bool(fish.call("is_in_water")):
		_fail("hanging fish should re-enter water and become active")
		return
	if bool(fish.call("is_hanging")):
		_fail("should not hang after re-enter")
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
