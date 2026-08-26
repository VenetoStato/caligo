extends Node

const INTERIOR := preload("res://Levels/Scenes/Dogana/salute_interior.tscn")
const FISHING_HOOK := preload("res://fishinghook.tscn")


class MockBoss extends Node2D:
	var current_health := 28
	func take_damage(amount: int, _source := Vector2.ZERO) -> void:
		current_health = maxi(0, current_health - amount)


class MockPlayer extends Node2D:
	var latched := false
	func on_grapple_latched(_hook: Node) -> void:
		latched = true


func _ready() -> void:
	var interior := INTERIOR.instantiate() as Node2D
	add_child(interior)
	await get_tree().process_frame
	await get_tree().physics_frame
	var lamps := get_tree().get_nodes_in_group("dogana_hanging_lamp")
	var droppable_lamps: Array[Node] = []
	var fixed_lamps: Array[Node] = []
	for lamp in lamps:
		if bool(lamp.get("droppable")):
			droppable_lamps.append(lamp)
		else:
			fixed_lamps.append(lamp)
	if droppable_lamps.size() != 2 or fixed_lamps.size() != 3:
		_fail("expected 2 falling and 3 fixed lamps, got %d/%d" % [droppable_lamps.size(), fixed_lamps.size()])
		return

	# Lo stesso amo da pesca deve riconoscere direttamente il corpo pendolare.
	var mock_player := MockPlayer.new()
	add_child(mock_player)
	var hook := FISHING_HOOK.instantiate() as RigidBody2D
	add_child(hook)
	hook.call("set_player_reference", mock_player)
	var falling_lamp := droppable_lamps[0]
	var lamp_body := falling_lamp.get_node("LampBody") as RigidBody2D
	hook.call("_latch_grapple", lamp_body)
	if not mock_player.latched or hook.call("get_grapple_owner") != falling_lamp:
		_fail("the standard fishing hook did not latch the lamp owner")
		return

	# R accumulato: il giunto cede, ma solo sul lampadario fragile.
	mock_player.global_position = lamp_body.global_position + Vector2(80.0, 180.0)
	if not bool(falling_lamp.call("reel_grapple", mock_player, 0.8)):
		_fail("droppable lamp did not break after a strong reel")
		return
	if not bool(falling_lamp.call("is_dropped")) or (falling_lamp.get_node("Chain") as Line2D).visible:
		_fail("dropped lamp kept its ceiling chain")
		return
	var fixed_lamp := fixed_lamps[0]
	if bool(fixed_lamp.call("reel_grapple", mock_player, 2.0)) or bool(fixed_lamp.call("is_dropped")):
		_fail("a fixed traversal lamp was allowed to fall")
		return

	# Impatto ambientale: 10 HP, un premio evidente per un appiglio rischioso.
	var boss := MockBoss.new()
	boss.add_to_group("dogana_boss")
	add_child(boss)
	boss.global_position = lamp_body.global_position
	falling_lamp.call("_try_damage_boss")
	if boss.current_health != 18:
		_fail("falling lamp dealt %d damage instead of 10" % (28 - boss.current_health))
		return
	print("CALIGO_BOSS_LAMP_DROP_OK: standard hook, 2 fragile pendulums, 10 boss damage")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("BOSS_LAMP_DROP_FAIL: %s" % message)
	get_tree().quit(1)
