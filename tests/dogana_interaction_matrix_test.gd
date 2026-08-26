extends Node

var _level: Node
var _player: CharacterBody2D
var _failed := false


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	if packed == null:
		_fail("level scene missing")
		return
	_level = packed.instantiate()
	_level.set("persistence_enabled", false)
	add_child(_level)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cutscene := _level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame
	_player = _level.get_node("Player") as CharacterBody2D
	_player.set_physics_process(false)
	_player.set_meta("arrival_locked", false)

	_check_continuous_sea()
	if _failed: return
	_check_ground_support()
	_check_visual_ground_contact()
	if _failed: return
	await _check_real_hook_detection()
	if _failed: return
	_check_light_enemy_pull_and_launch()
	if _failed: return
	_check_heavy_enemy_resistance()
	if _failed: return
	_check_timed_power_attack()
	if _failed: return
	_check_collision_visuals_hidden()
	if _failed: return

	print("CALIGO_INTERACTION_MATRIX_OK: continuous sea, grounded props, light/heavy hook, timed strike and hidden hitboxes")
	_level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _check_continuous_sea() -> void:
	var waters := get_tree().get_nodes_in_group("water")
	if waters.size() != 1:
		_fail("expected one seamless water body, got %d" % waters.size())
		return
	var water := waters[0]
	if not water.has_method("get_water_bounds_global_rect"):
		_fail("water bounds API missing")
		return
	var bounds := water.call("get_water_bounds_global_rect") as Rect2
	if bounds.position.x > -1200.0 or bounds.end.x < 7000.0:
		_fail("water stops inside camera travel: %s" % bounds)
		return
	for x in [-1100.0, 0.0, 3172.0, 3180.0, 3188.0, 6000.0, 6900.0]:
		var y := float(water.call("get_surface_height", x))
		if absf(y - 565.0) > 14.0:
			_fail("water surface escaped its physical band at x=%.1f y=%.1f" % [x, y])
			return
	var seam_left := float(water.call("get_surface_height", 3172.0))
	var seam_mid := float(water.call("get_surface_height", 3180.0))
	var seam_right := float(water.call("get_surface_height", 3188.0))
	if absf(seam_left - seam_mid) > 3.0 or absf(seam_right - seam_mid) > 3.0:
		_fail("water has a visible seam around former basin boundary")


func _check_ground_support() -> void:
	var checked := 0
	for node in get_tree().get_nodes_in_group("dogana_breakable") + get_tree().get_nodes_in_group("dogana_grace") + get_tree().get_nodes_in_group("enemy"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		if node.is_in_group("enemy") and node.get("hovering") == true:
			continue
		if node.is_in_group("enemy") and node.get("activation_managed") == true:
			continue
		var item := node as Node2D
		var query := PhysicsRayQueryParameters2D.create(
			item.global_position + Vector2(0, -36),
			item.global_position + Vector2(0, 180),
			1
		)
		if item is CollisionObject2D:
			query.exclude = [(item as CollisionObject2D).get_rid()]
		var hit := item.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			_fail("unsupported object %s at %s" % [item.name, item.global_position])
			return
		checked += 1
	if checked < 18:
		_fail("ground support audit too small: %d" % checked)


func _check_visual_ground_contact() -> void:
	# Controlla i pixel opachi, non soltanto l'origine del nodo: un asset con
	# padding o offset errato non deve sembrare sospeso pur avendo supporto fisico.
	for node in get_tree().get_nodes_in_group("dogana_breakable_prop"):
		var prop := node as Node2D
		var sprite := prop.get_node_or_null("Visual") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var visual_bottom := _opaque_sprite_bottom(sprite)
		if absf(visual_bottom - prop.global_position.y) > 1.5:
			_fail("prop %s visual bottom %.1f misses floor anchor %.1f" % [prop.name, visual_bottom, prop.global_position.y])
			return
	for grace_node in get_tree().get_nodes_in_group("dogana_grace"):
		var grace := grace_node as Node2D
		var sprite := grace.get_node_or_null("IllustratedAltar") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var visual_bottom := _opaque_sprite_bottom(sprite)
		if absf(visual_bottom - grace.global_position.y) > 1.5:
			_fail("grace %s visual bottom %.1f misses floor anchor %.1f" % [grace.name, visual_bottom, grace.global_position.y])
			return
	for collectible_node in get_tree().get_nodes_in_group("dogana_collectible_grounded"):
		var collectible := collectible_node as Node2D
		var sprite := collectible.get_node_or_null("Sprite2D") as Sprite2D
		if sprite and absf(_opaque_sprite_bottom(sprite) - collectible.global_position.y) > 1.5:
			_fail("collectible %s is visually floating: bottom=%.1f anchor=%.1f local_sprite=%.1f" % [collectible.name, _opaque_sprite_bottom(sprite), collectible.global_position.y, sprite.position.y])
			return
	var bricole := get_tree().get_nodes_in_group("dogana_bricole")
	if bricole.size() != 3:
		_fail("expected three restrained seabed bricole, got %d" % bricole.size())
		return
	# Piantate sul fondale ma ben fuori dall'acqua: ancorandole soltanto al
	# fondale erano finite quasi interamente sommerse e invisibili.
	var water_surface := 565.0
	for bricola_node in bricole:
		var bricola := bricola_node as Node2D
		if not bool(bricola.get_meta("seabed_anchored", false)) or absf(bricola.global_position.y - 900.0) > 1.0:
			_fail("bricola %s is not planted on the basin floor" % bricola.name)
			return
		var pole := bricola.get_node_or_null("Sprite2D") as Sprite2D
		if pole == null or pole.texture == null:
			_fail("bricola %s lost its artwork" % bricola.name)
			return
		var emerged := water_surface - _opaque_sprite_top(pole)
		if emerged < 80.0 or emerged > 220.0:
			_fail("bricola %s emerges %.0fpx above the water, outside the mooring-pole range" % [bricola.name, emerged])
			return
		if pole.modulate.a < 0.85:
			_fail("bricola %s is faded to alpha %.2f" % [bricola.name, pole.modulate.a])
			return


func _opaque_sprite_bottom(sprite: Sprite2D) -> float:
	var image := sprite.texture.get_image()
	if image == null:
		return INF
	var used := image.get_used_rect()
	if used.size.y <= 0:
		return INF
	var local_bottom := float(used.end.y) - float(image.get_height()) * 0.5
	return sprite.global_position.y + local_bottom * absf(sprite.global_scale.y)


func _opaque_sprite_top(sprite: Sprite2D) -> float:
	var image := sprite.texture.get_image()
	if image == null:
		return INF
	var used := image.get_used_rect()
	if used.size.y <= 0:
		return INF
	var local_top := float(used.position.y) - float(image.get_height()) * 0.5
	return sprite.global_position.y + local_top * absf(sprite.global_scale.y)


func _check_real_hook_detection() -> void:
	var light := _level.get_node("Gameplay/Encounters/GamberoWedge") as CharacterBody2D
	light.set_physics_process(false)
	_player.global_position = light.global_position + Vector2(-180, 0)
	var hook := (load("res://fishinghook.tscn") as PackedScene).instantiate() as RigidBody2D
	get_tree().current_scene.add_child(hook)
	hook.call("set_player_reference", _player)
	_player.set("hook_instance", hook)
	_player.set("line_extended", true)
	_player.set("line_mode", 1)
	hook.call("_check_if_enemy", light)
	await get_tree().process_frame
	await get_tree().process_frame
	if not bool(_player.get("enemy_hooked")) or _player.get("current_hooked_enemy") != light:
		_fail("fishing hook did not attach through real enemy detection")
		return
	_player.call("_release_hooked_enemy", false)
	await get_tree().process_frame
	light.call("reset_to_home")
	light.set_physics_process(false)


func _check_light_enemy_pull_and_launch() -> void:
	var light := _level.get_node("Gameplay/Encounters/GamberoWedge") as CharacterBody2D
	_player.global_position = light.global_position + Vector2(-190, 0)
	if not bool(light.call("begin_combat_hook", _player)):
		_fail("light enemy refused hook")
		return
	var pulled := bool(light.call("apply_combat_hook_pull", _player.global_position, 430.0))
	var pull_velocity := light.get("_combat_hook_pull_velocity") as Vector2
	if not pulled or pull_velocity.length() < 400.0:
		_fail("light enemy did not receive physical pull")
		return
	light.call("release_combat_hook", Vector2(-1.0, -0.25), false)
	if bool(light.call("is_combat_hooked")) or light.velocity.length() < 500.0:
		_fail("light enemy was not launched on release")


func _check_heavy_enemy_resistance() -> void:
	var heavy := _level.get_node("Gameplay/Encounters/TideBloaterCanal") as CharacterBody2D
	heavy.set_physics_process(false)
	heavy.velocity = Vector2.ZERO
	if not bool(heavy.call("begin_combat_hook", _player)):
		_fail("heavy enemy refused valid hook")
		return
	var moved := bool(heavy.call("apply_combat_hook_pull", _player.global_position, 430.0))
	heavy.call("release_combat_hook", Vector2.LEFT, true)
	if moved or heavy.velocity.length() > 1.0:
		_fail("heavy enemy was moved by fishing combat")
		return
	# Il pesante non si muove: e' il player a essere lanciato verso di lui.
	heavy.call("begin_combat_hook", _player)
	_player.global_position = heavy.global_position + Vector2(-190.0, 0.0)
	_player.velocity = Vector2.ZERO
	_player.set("current_hooked_enemy", heavy)
	_player.set("enemy_hooked", true)
	_player.set("is_reeling", true)
	_player.call("_reel_enemy_to_player", 0.1)
	if _player.velocity.length() < 100.0 or heavy.velocity.length() > 1.0:
		_fail("heavy reel did not launch player toward stationary enemy")
		return
	# Lo sgancio deve essere sempre disponibile: nessun soft-lock della lenza.
	_player.call("_release_hooked_enemy", false)
	_player.set("is_reeling", false)
	if bool(_player.get("enemy_hooked")) or bool(heavy.call("is_combat_hooked")):
		_fail("heavy enemy could not be detached")


func _check_timed_power_attack() -> void:
	var light := _level.get_node("Gameplay/Encounters/GamberoQuay") as CharacterBody2D
	light.set_physics_process(false)
	light.call("reset_to_home")
	light.set_physics_process(false)
	_player.global_position = light.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	var health_before := int(light.get("current_health"))
	_player.call("on_enemy_hooked", light, null)
	_player.call("_reel_enemy_to_player", 0.016)
	if float(_player.get("_power_strike_left")) <= 0.0:
		_fail("reel finish did not open highlighted power window")
		return
	if int(light.get("current_health")) != health_before:
		_fail("reel dealt automatic damage before the timed follow-up hit")
		return
	_player.call("_enable_attack_hitbox", int(_player.get("enemy_power_damage")))
	_player.call("_try_hit_enemy", light)
	if int(light.get("current_health")) != health_before - int(_player.get("enemy_power_damage")):
		_fail("highlighted follow-up hit did not deal powered damage")
		return
	if bool(_player.get("enemy_hooked")):
		_fail("power window kept the enemy attached")


func _check_collision_visuals_hidden() -> void:
	var player_hitbox := _player.get_node_or_null("AttackHitbox") as Area2D
	if player_hitbox == null or player_hitbox.visible:
		_fail("player attack hitbox is visible")
		return
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var hitbox := enemy.get_node_or_null("AttackHitbox")
		var hurtbox := enemy.get_node_or_null("Hurtbox")
		for area in [hitbox, hurtbox]:
			if area == null:
				_fail("enemy collision area missing on %s" % enemy.name)
				return
			for child in area.get_children():
				if child is Sprite2D or child is Polygon2D or child is Line2D:
					_fail("visible hitbox artwork found on %s" % enemy.name)
					return


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("INTERACTION_MATRIX_FAIL: %s" % message)
	get_tree().quit(1)
