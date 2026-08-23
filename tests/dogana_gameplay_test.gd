extends Node

## Integrazione principale del livello semplificato: waterfront, Salute, respawn,
## mappa e ciclo boss. Non devono ricomparire le vecchie deviazioni verticali.


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Punta della Dogana")
		return
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cutscene := level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame

	var player := level.get_node("Player") as CharacterBody2D
	player.collision_layer = 2
	player.collision_mask = 1
	player.set_physics_process(true)
	player.set_meta("arrival_locked", false)
	var encounters := level.get_node("Gameplay/Encounters")
	var enemies := encounters.get_children()
	var graces := get_tree().get_nodes_in_group("dogana_grace")
	var fish := get_tree().get_nodes_in_group("fish")
	var breakables := get_tree().get_nodes_in_group("dogana_breakable")
	var boss := get_tree().get_first_node_in_group("dogana_boss")
	var interior := get_tree().get_first_node_in_group("dogana_salute_interior")
	var art := get_tree().get_first_node_in_group("dogana_salute_interior_art") as Sprite2D
	var waterfront := get_tree().get_first_node_in_group("dogana_simplified_waterfront")
	var passages := get_tree().get_nodes_in_group("dogana_salute_passage")
	if (
		enemies.size() < 7 or graces.size() != 3 or fish.size() < 9
		or breakables.size() < 8 or boss == null or interior == null
		or art == null or art.texture == null or waterfront == null or passages.size() != 2
	):
		_fail("simplified Dogana gameplay structure is incomplete")
		return
	for obsolete in ["CanalGate", "DoganaRoofSteps", "CanalPlatforms", "TowerRoute", "FortunaOssuary"]:
		if level.find_child(obsolete, true, false) != null:
			_fail("obsolete floating section remains: %s" % obsolete)
			return

	var first_enemy := enemies[0] as CharacterBody2D
	var enemy_home: Vector2 = first_enemy.get("_home_position")
	first_enemy.set("current_health", 1)
	first_enemy.call("take_damage", 1, player.global_position)
	await get_tree().process_frame
	if first_enemy.visible or int(first_enemy.get("state")) != 2:
		_fail("enemy respawned before a grace rest")
		return
	var pontile := level.get_node("Gameplay/GraceSites/Pontile") as Area2D
	level.call("_activate_grace", pontile, true)
	await get_tree().physics_frame
	if int(first_enemy.get("state")) != 0 or not first_enemy.global_position.is_equal_approx(enemy_home):
		_fail("grace did not restore the defeated enemy at home")
		return

	var enter: Area2D
	var exit: Area2D
	for passage in passages:
		if str(passage.get_meta("action", "")) == "salute_enter":
			enter = passage
		else:
			exit = passage
	level.call("_activate_interactable", enter)
	await get_tree().physics_frame
	if player.global_position.distance_to(Vector2(4300, -545)) > 4.0:
		_fail("grounded Salute entrance did not reach the interior")
		return
	level.call("_activate_interactable", exit)
	await get_tree().physics_frame
	if player.global_position.distance_to(Vector2(5480, 445)) > 4.0:
		_fail("Salute return did not reach the waterfront")
		return

	var map := level.get_node("DoganaMap")
	map.call("open_map")
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("map did not pause gameplay")
		return
	map.call("close_map")
	await get_tree().process_frame
	if get_tree().paused:
		_fail("map did not close cleanly")
		return

	player.global_position = Vector2(5260, -545)
	boss.call("_awaken")
	await get_tree().physics_frame
	var seal := level.get_node("Gameplay/Geometry/BossArena/EntranceSeal/CollisionShape2D") as CollisionShape2D
	if seal.disabled:
		_fail("Salute boss arena did not lock")
		return
	boss.set("current_health", 1)
	boss.call("take_damage", 1, player.global_position)
	await get_tree().process_frame
	if not bool(level.get("_boss_is_defeated")):
		_fail("boss defeat did not complete the Salute encounter")
		return

	print("CALIGO_DOGANA_TEST: %d enemies, continuous waterfront, grounded Salute passages and interior boss OK" % enemies.size())
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("CALIGO_DOGANA_FAIL: " + message)
	get_tree().quit(1)
