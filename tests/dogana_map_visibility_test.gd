extends Node

const MAP_SCENE := preload("res://Levels/Scenes/Dogana/dogana_map.tscn")


func _ready() -> void:
	var map := MAP_SCENE.instantiate() as CanvasLayer
	map.visible = false
	add_child(map)
	await get_tree().process_frame
	if not map.visible:
		_fail("runtime map CanvasLayer remained hidden by the editor authoring state")
		return
	map.call("open_map")
	var overlay := map.get_node("Overlay") as Control
	if not map.visible or not overlay.visible or overlay.modulate.a < 0.99 or not get_tree().paused:
		_fail("opening M did not show the map before pausing")
		return
	map.call("close_map")
	if overlay.visible or get_tree().paused:
		_fail("closing the map did not restore the running game")
		return
	var button := map.get_node("MapButton") as Button
	if "MAPPA" not in button.text or "[M]" not in button.text:
		_fail("the visible map button lost its keyboard hint")
		return
	print("CALIGO_MAP_VISIBILITY_OK: visible CanvasLayer, overlay and pause lifecycle")
	get_tree().quit(0)


func _fail(message: String) -> void:
	get_tree().paused = false
	push_error("DOGANA_MAP_VISIBILITY_FAIL: %s" % message)
	get_tree().quit(1)
