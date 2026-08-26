extends Node

var _level: Node
var _player: CharacterBody2D


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
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
	_player.set_meta("arrival_locked", false)
	for lectern_name in ["RegistroMerci", "LibroLonghena", "MessaleCustode"]:
		if not await _check_lectern(lectern_name):
			return
	print("CALIGO_LECTERN_INTERACTION_OK: all lecterns detect and open lore")
	get_tree().quit(0)


func _check_lectern(lectern_name: String) -> bool:
	var lectern := _level.get_node("Gameplay/Interactions/%s" % lectern_name) as Area2D
	_player.global_position = lectern.global_position + Vector2(0.0, -28.0)
	_player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nearby: Variant = _level.get("_nearby_interactable")
	if nearby != lectern:
		return _fail("%s overlap does not become the active interaction" % lectern_name)
	_level.call("_activate_interactable", lectern)
	var overlay := _level.get_node("LoreReader/Overlay") as Control
	if not overlay.visible:
		return _fail("%s interaction does not open the lore reader" % lectern_name)
	_level.get_node("LoreReader").call("close_entry")
	_player.global_position = Vector2(0.0, 0.0)
	await get_tree().physics_frame
	return true


func _fail(message: String) -> bool:
	push_error("LECTERN_INTERACTION_FAIL: %s" % message)
	get_tree().quit(1)
	return false
