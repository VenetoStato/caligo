extends Node

## Il viaggio debug non deve lasciare una Grazia fantasma che intercetta E e
## rende inutilizzabili i leggii lontani.


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	var cutscene := level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame
	var player := level.get_node("Player") as CharacterBody2D
	player.set_meta("arrival_locked", false)
	player.global_position = Vector2(3830.0, 485.0)
	level.set("_nearby_grace", level.get_node("Gameplay/GraceSites/Fortuna"))
	# Simula l'arrivo al leggio via teletrasporto/debug, senza body_exited.
	player.global_position = Vector2(2430.0, 485.0)
	level.call("_refresh_nearby_grace")
	level.call("_refresh_nearby_interactable")
	if level.get("_nearby_grace") != null:
		_fail("stale grace still owns interaction after teleport")
		return
	var lectern := level.get_node("Gameplay/Interactions/RegistroMerci") as Area2D
	if level.get("_nearby_interactable") != lectern:
		_fail("lectern was not selected by fallback proximity")
		return
	level.call("_activate_interactable", lectern)
	await get_tree().process_frame
	var reader := level.get_node("LoreReader")
	var panel := reader.get_node("Overlay") as Control
	if not panel.visible:
		_fail("lectern did not open LoreReader")
		return
	print("CALIGO_LORE_LECTERN_ACCESS_OK: debug travel cannot block lectern interaction")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("LORE_LECTERN_ACCESS_FAIL: %s" % message)
	get_tree().quit(1)
