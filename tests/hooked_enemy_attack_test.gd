extends Node

const ENEMY_SCENE := preload("res://Enemies/enemy.tscn")


func _ready() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(28.0, 0.0)
	add_child(player)
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody2D
	add_child(enemy)
	await get_tree().process_frame
	enemy.set_physics_process(false)
	enemy.set("state", 1)
	enemy.set("player", player)
	enemy.set("attack_timer", 0.0)
	enemy.set("_special_windup_remaining", 0.0)
	enemy.set("_charge_timer", 0.0)
	# Un attacco gia' preparato non deve essere cancellato dal primo contatto.
	enemy.set("_melee_windup_remaining", 0.11)
	if not bool(enemy.call("begin_combat_hook", player)):
		_fail("enemy refused a valid combat hook")
		return
	if float(enemy.get("_melee_windup_remaining")) < 0.1:
		_fail("hook attachment cancelled the active attack windup")
		return
	# Anche un nuovo attacco deve potersi avviare e arrivare alla hitbox mentre
	# il flag di aggancio rimane attivo.
	enemy.set("_melee_windup_remaining", 0.0)
	enemy.call("_update_melee_attack", 0.016, 28.0)
	if float(enemy.get("_melee_windup_remaining")) <= 0.0:
		_fail("hooked enemy did not start a melee attack")
		return
	enemy.set("_melee_windup_remaining", 0.001)
	enemy.call("_update_melee_attack", 0.016, 28.0)
	await get_tree().physics_frame
	var hitbox := enemy.get_node("AttackHitbox") as Area2D
	if not bool(enemy.call("is_combat_hooked")) or not hitbox.monitoring:
		_fail("hooked enemy attack never reached its active hitbox")
		return
	# Lo sgancio ripristina lo stato/player precedenti senza azzerare l'AI.
	enemy.call("release_combat_hook")
	if int(enemy.get("state")) != 1 or enemy.get("player") != player:
		_fail("release did not restore the pre-hook aggressive behavior")
		return
	print("CALIGO_HOOKED_ENEMY_ATTACK_OK: AI windup and hitbox continue on the line")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("HOOKED_ENEMY_ATTACK_FAIL: %s" % message)
	get_tree().quit(1)
