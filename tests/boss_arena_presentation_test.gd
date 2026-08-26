extends Node


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
	print("CALIGO_BOSS_ARENA_PRESENTATION_OK: raised boss and visible fog seals")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("BOSS_ARENA_PRESENTATION_FAIL: %s" % message)
	get_tree().quit(1)
