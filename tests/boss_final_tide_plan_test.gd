extends Node

## Contratto del redesign: solo tre azioni normali, poi una marea una volta
## sola. Il test e' intenzionalmente isolato dalla lunga scena della Dogana.

const WARDEN_SCENE := preload("res://Levels/Scenes/Dogana/drowned_customs_warden.tscn")


func _ready() -> void:
	var boss := WARDEN_SCENE.instantiate() as CharacterBody2D
	add_child(boss)
	boss.global_position = Vector2(5100.0, -500.0)
	await get_tree().physics_frame
	boss.set("current_health", 8)
	boss.set("_phase", 3)
	boss.set("_attack_chain_step", 0)
	boss.set("_flood_used", false)

	var normal_pick := int(boss.call("_pick_attack", Vector2(90.0, 0.0)))
	var tide_pick := int(boss.call("_pick_attack", Vector2(90.0, 0.0)))
	var after_tide_pick := int(boss.call("_pick_attack", Vector2(90.0, 0.0)))
	if normal_pick > 2 or tide_pick != 10 or after_tide_pick > 2:
		_fail("attack pool was not normal -> one final tide -> normal (%d, %d, %d)" % [normal_pick, tide_pick, after_tide_pick])
		return

	boss.call("_begin_flood")
	await get_tree().process_frame
	var tides := get_tree().get_nodes_in_group("boss_environment_attack")
	if tides.size() != 1:
		_fail("final tide did not create exactly one environmental attack")
		return
	var tide := tides[0]
	if absf(float(tide.get("windup")) - 1.5) > 0.01 or absf(float(tide.get("active_time")) - 4.0) > 0.01:
		_fail("final tide timings are not 1.5s warning / 4.0s active")
		return
	if float(tide.get("span").x) < 1200.0:
		_fail("final tide does not span the arena")
		return
	print("CALIGO_BOSS_FINAL_TIDE_PLAN_OK: limited pool, one final tide, arena span and timings")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("BOSS_FINAL_TIDE_PLAN_FAIL: %s" % message)
	get_tree().quit(1)
