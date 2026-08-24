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
	var bloater := encounters.get_node("TideBloaterCanal") as CharacterBody2D
	var volley := encounters.get_node("LagoonOracleWedge") as CharacterBody2D
	var barrage := encounters.get_node("LagoonOracleFortuna") as CharacterBody2D
	var harpoon := encounters.get_node("HarpoonGambero") as CharacterBody2D
	var gambero := encounters.get_node("GamberoWedge") as CharacterBody2D
	# La pattuglia puo' aver appena girato durante i frame di bootstrap: il test
	# azzera esplicitamente il debounce prima di verificare la doppia inversione.
	gambero.set("_patrol_turn_cooldown", 0.0)
	var patrol_direction_before: float = float(gambero.get("_patrol_dir"))
	if not bool(gambero.call("_turn_patrol")):
		push_error("Enemy patrol did not accept its first deliberate turn.")
		get_tree().quit(1)
		return
	var patrol_direction_after: float = float(gambero.get("_patrol_dir"))
	if bool(gambero.call("_turn_patrol")) or float(gambero.get("_patrol_dir")) != patrol_direction_after or patrol_direction_after == patrol_direction_before:
		push_error("Enemy patrol can still reverse every frame.")
		get_tree().quit(1)
		return
	if (
		int(bloater.get("attack_pattern")) != 1
		or int(volley.get("attack_pattern")) != 2
		or int(barrage.get("attack_pattern")) != 3
		or int(harpoon.get("attack_pattern")) != 9
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
		volley_sprite.z_index,
		volley_sprite.texture.resource_path,
	])
	bloater.call("_fire_special_attack")
	volley.call("_fire_special_attack")
	barrage.call("_fire_special_attack")
	harpoon.call("_fire_special_attack")
	var attacks := get_tree().get_nodes_in_group("enemy_transient_attack")
	if attacks.size() < 8:
		push_error("Special attacks did not spawn expected telegraphs.")
		get_tree().quit(1)
		return
	for _burst in 8:
		barrage.call("_fire_special_attack")
	await get_tree().process_frame
	attacks = get_tree().get_nodes_in_group("enemy_transient_attack")
	if attacks.size() > 96:
		push_error("Projectile cap did not protect the mobile frame budget.")
		get_tree().quit(1)
		return
	var home: Vector2 = bloater.get("_home_position")
	player.set("_attack_dir", Vector2.RIGHT)
	player.global_position = volley.global_position + Vector2(-48, 0)
	volley.call("take_damage", 1, player.global_position)
	if volley.velocity.x <= 20.0 or volley.velocity.y > -20.0 or volley.velocity.y < -160.0:
		push_error("Side nail should shove away with a small hop, not launch the enemy.")
		get_tree().quit(1)
		return
	player.set("_attack_dir", Vector2.UP)
	volley.call("take_damage", 1, player.global_position)
	if volley.velocity.y > -140.0:
		push_error("Upslash should lift the enemy.")
		get_tree().quit(1)
		return
	bloater.set("current_health", 1)
	bloater.call("take_damage", 1, player.global_position)
	await get_tree().process_frame
	if bool(bloater.visible) or int(bloater.get("state")) != 2:
		push_error("Defeated enemy did not enter its dormant respawn state.")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.2).timeout
	if bool(bloater.visible) or int(bloater.get("state")) != 2:
		push_error("Defeated enemy respawned without a grace rest.")
		get_tree().quit(1)
		return
	bloater.call("reset_to_home")
	await get_tree().physics_frame
	if (
		not bloater.visible
		or int(bloater.get("state")) != 0
		or not bloater.global_position.is_equal_approx(home)
	):
		push_error("Enemy did not respawn at home in non-aggro state.")
		get_tree().quit(1)
		return
	# Dead body scale should match living visual scale (no clamp inflation).
	var live_scale := absf(gambero.scale.x) * absf((gambero.get_node("Sprite2D") as Sprite2D).scale.x)
	gambero.set("current_health", 1)
	gambero.call("take_damage", 1, player.global_position)
	await get_tree().process_frame
	var corpses := get_tree().get_nodes_in_group("dead_enemy")
	if corpses.is_empty():
		push_error("No dead enemy corpse spawned.")
		get_tree().quit(1)
		return
	var corpse_sprite := (corpses[0] as Node).get_child(1) as Sprite2D
	if corpse_sprite == null or absf(corpse_sprite.scale.x - live_scale) > 0.04:
		push_error("Dead enemy scale mismatch live=%.3f dead=%s" % [live_scale, corpse_sprite.scale if corpse_sprite else "?"])
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
	print("CALIGO_ENEMY_ARCHETYPES: tide, volley, radial, harpoon, death-scale and grace-only reset OK")
	level.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(1.1).timeout
	get_tree().quit(0)
