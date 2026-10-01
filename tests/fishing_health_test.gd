extends Node2D

@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	await get_tree().process_frame
	_player.set("current_health", int(_player.get("max_health")) - 2)
	var fish := Node2D.new()
	fish.name = "TestFish"
	add_child(fish)
	fish.global_position = _player.global_position + Vector2(24.0, -18.0)
	_player.set("current_fish", fish)
	_player.set("fish_hooked", true)
	_player.call("_complete_fish_catch", fish)
	await get_tree().process_frame

	var expected := int(_player.get("max_health")) - 1
	if int(_player.get("current_health")) != expected:
		push_error("Catching a fish must restore one health point.")
		get_tree().quit(1)
		return
	if get_tree().get_nodes_in_group("fish_catch_effect").is_empty():
		push_error("Catching a fish must spawn its visual/light effect.")
		get_tree().quit(1)
		return
	print("CALIGO_FISHING_TEST: catch restored 1 health and spawned VFX/light")
	await get_tree().create_timer(1.2).timeout
	get_tree().quit(0)
