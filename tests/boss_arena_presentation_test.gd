extends Node


class DamageDummy extends CharacterBody2D:
	var damage_taken := 0

	func take_damage(amount: int = 1, _source_position := Vector2.ZERO) -> void:
		damage_taken += amount


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	var initial_sprite_y := float(level.get_node("Gameplay/DrownedCustomsWarden/Sprite2D").position.y)
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().process_frame
	var boss := level.get_node("Gameplay/DrownedCustomsWarden") as CharacterBody2D
	var sprite := boss.get_node("Sprite2D") as Sprite2D
	var image := sprite.texture.get_image()
	if absf(sprite.scale.x - 0.161) > 0.002 or absf(sprite.scale.y - 0.161) > 0.002:
		_fail("Boss visual is not half-size: %s" % sprite.scale)
		return
	if image.get_pixel(315, 510).a < 0.95 or image.get_pixel(440, 505).a < 0.95:
		_fail("Boss eye backing is still transparent")
		return
	if not boss.has_node("ContactDamage"):
		_fail("Boss has no close-contact damage area")
		return
	var dummy := DamageDummy.new()
	add_child(dummy)
	dummy.add_to_group("player")
	boss.set("state", 1)
	boss.set("_contact_damage_timer", 0.0)
	var contact_triggered := bool(boss.call("_try_contact_damage", dummy))
	await get_tree().process_frame
	if not contact_triggered or dummy.damage_taken != 1:
		_fail("Walking into the active boss still deals no damage (state=%s timer=%s group=%s method=%s damage=%s)" % [boss.get("state"), boss.get("_contact_damage_timer"), dummy.is_in_group("player"), dummy.has_method("take_damage"), dummy.damage_taken])
		return
	boss.set("state", 0)
	# L'asset contiene una velatura alpha quasi impercettibile fino ai bordi;
	# get_used_rect() vede l'intero 1024. Il piede dipinto termina a y~946.
	var opaque_bottom_local := 946.0 - float(image.get_height()) * 0.5
	var visual_bottom := boss.global_position.y + sprite.position.y + opaque_bottom_local * absf(sprite.scale.y)
	var floor_y := -500.0
	if visual_bottom > floor_y - 18.0:
		_fail("Boss artwork is still buried in the arena floor: initial sprite %.1f body %.1f sprite %.1f bottom %.1f floor %.1f" % [initial_sprite_y, boss.global_position.y, sprite.position.y, visual_bottom, floor_y])
		return
	if visual_bottom < floor_y - 42.0:
		_fail("Boss artwork was raised too far above the floor: bottom %.1f floor %.1f" % [visual_bottom, floor_y])
		return
	level.call("_set_boss_arena_sealed", true)
	await get_tree().physics_frame
	for seal_name in ["EntranceSeal", "ExitWall"]:
		var seal := level.get_node("Gameplay/Geometry/BossArena/%s" % seal_name)
		var collision := seal.get_node("CollisionShape2D") as CollisionShape2D
		var fog := seal.get_node("FogSealVisual") as ColorRect
		if collision.disabled or not fog.visible or fog.material == null:
			_fail("%s does not show a solid fog boundary while sealed" % seal_name)
			return
	level.call("_set_boss_arena_sealed", false)
	await get_tree().physics_frame
	for seal_name in ["EntranceSeal", "ExitWall"]:
		var seal := level.get_node("Gameplay/Geometry/BossArena/%s" % seal_name)
		if not (seal.get_node("CollisionShape2D") as CollisionShape2D).disabled:
			_fail("%s collision remained active after opening" % seal_name)
			return
		if (seal.get_node("FogSealVisual") as ColorRect).visible:
			_fail("%s fog remained visible after opening" % seal_name)
			return
	print("CALIGO_BOSS_ARENA_PRESENTATION_OK: half-size boss, opaque eyes, contact damage, and fog seals")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("BOSS_ARENA_PRESENTATION_FAIL: %s" % message)
	get_tree().quit(1)
