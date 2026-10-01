extends Node2D

@onready var _player: CharacterBody2D = $Player
@onready var _enemy: CharacterBody2D = $Enemy


func _ready() -> void:
	_player.set_physics_process(false)
	_enemy.set_physics_process(false)
	await get_tree().create_timer(1.2).timeout
	_player.set("is_invincible", false)

	var initial_health := int(_player.get("current_health"))
	_enemy.call("_on_attack_hit_body", _player)
	await get_tree().process_frame
	await get_tree().process_frame
	if int(_player.get("current_health")) != initial_health - 1:
		push_error("Enemy impact did not apply exactly one damage safely.")
		get_tree().quit(1)
		return

	for _index in initial_health - 1:
		_enemy.set("_attack_has_hit", false)
		_player.set("is_invincible", false)
		_enemy.call("_on_attack_hit_body", _player)
		await get_tree().process_frame
		await get_tree().process_frame

	var death_anim := _player.get_node("anim") as AnimationPlayer
	if (
		not bool(_player.get("is_dead"))
		or death_anim.current_animation != "Falling"
		or death_anim.get_playing_speed() > 0.65
	):
		push_error("Lethal contact did not enter the slow looping fall animation.")
		get_tree().quit(1)
		return
	await get_tree().create_timer(4.5, true, false, true).timeout
	if bool(_player.get("is_dead")) or int(_player.get("current_health")) <= 0:
		push_error("Player did not recover after lethal enemy contact.")
		get_tree().quit(1)
		return
	print("CALIGO_ENEMY_COLLISION_TEST: impact, lethal damage and respawn OK")
	await get_tree().create_timer(1.1, true, false, true).timeout
	get_tree().quit(0)
