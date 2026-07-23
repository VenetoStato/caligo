extends Node


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player := level.get_node("Player") as CharacterBody2D
	player.global_position = Vector2(500, 400)
	player.set_physics_process(false)
	var encounters := level.get_node("Gameplay/Encounters")
	var bloater := encounters.get_node("TideBloaterCustoms") as CharacterBody2D
	var volley := encounters.get_node("LagoonOracleWedge") as CharacterBody2D
	var barrage := encounters.get_node("LagoonOracleFortuna") as CharacterBody2D
	if (
		int(bloater.get("attack_pattern")) != 1
		or int(volley.get("attack_pattern")) != 2
		or int(barrage.get("attack_pattern")) != 3
		or bloater.get("variant_texture") == null
		or volley.get("variant_texture") == null
	):
		push_error("Enemy archetype configuration is incomplete.")
		get_tree().quit(1)
		return
	var bloater_sprite := bloater.get_node("Sprite2D") as Sprite2D
	var volley_sprite := volley.get_node("Sprite2D") as Sprite2D
	var visual_before: Vector2 = bloater_sprite.position
	bloater.call("_update_variant_animation", 0.25)
	if bloater_sprite.position.is_equal_approx(visual_before):
		push_error("Illustrated enemy variant has no visible procedural animation.")
		get_tree().quit(1)
		return
	print("CALIGO_ENEMY_VISUALS: bloater pos=%s visible=%s z=%d texture=%s; oracle pos=%s visible=%s z=%d texture=%s" % [
		bloater.global_position,
		bloater_sprite.visible,
		bloater.z_index,
		bloater_sprite.texture.resource_path,
		volley.global_position,
		volley_sprite.visible,
		volley.z_index,
		volley_sprite.texture.resource_path,
	])
	bloater.call("_fire_special_attack")
	volley.call("_fire_special_attack")
	barrage.call("_fire_special_attack")
	var attacks := get_tree().get_nodes_in_group("enemy_transient_attack")
	if attacks.size() < 16:
		push_error("Area, volley, or radial barrage did not spawn the expected telegraphed attacks.")
		get_tree().quit(1)
		return
	for _burst in 8:
		barrage.call("_fire_special_attack")
	await get_tree().process_frame
	attacks = get_tree().get_nodes_in_group("enemy_transient_attack")
	if attacks.size() > 48:
		push_error("Projectile cap did not protect the mobile frame budget.")
		get_tree().quit(1)
		return
	var home: Vector2 = bloater.get("_home_position")
	bloater.set("current_health", 1)
	bloater.call("take_damage", 1, player.global_position)
	await get_tree().process_frame
	if bool(bloater.visible) or int(bloater.get("state")) != 2:
		push_error("Defeated enemy did not enter its dormant respawn state.")
		get_tree().quit(1)
		return
	bloater.call("reset_to_home")
	await get_tree().physics_frame
	if (
		not bloater.visible
		or int(bloater.get("state")) != 0
		or not bloater.global_position.is_equal_approx(home)
		or float(bloater.get("_wake_timer")) < 3.0
	):
		push_error("Enemy did not respawn at home in non-aggro state.")
		get_tree().quit(1)
		return
	player.global_position = home + Vector2(700, 0)
	bloater.set("state", 1)
	bloater.set("player", player)
	bloater.call("_physics_process", 0.016)
	if int(bloater.get("state")) != 0:
		push_error("Enemy did not disengage outside its home zone.")
		get_tree().quit(1)
		return
	for attack in get_tree().get_nodes_in_group("enemy_transient_attack"):
		attack.queue_free()
	for corpse in get_tree().get_nodes_in_group("dead_enemy"):
		corpse.queue_free()
	await get_tree().process_frame
	print("CALIGO_ENEMY_ARCHETYPES: tide area, aimed volley, radial barrage and safe home respawn OK")
	level.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.1).timeout
	get_tree().quit(0)
