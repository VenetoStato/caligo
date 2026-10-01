extends Node2D

const FISH_SCENE := preload("res://fish.tscn")


func _ready() -> void:
	var fish_nodes: Array[Node2D] = []
	var starts: Array[Vector2] = []
	for index in 3:
		var fish := FISH_SCENE.instantiate() as Node2D
		fish.position = Vector2(index * 90.0, 100.0 + index * 18.0)
		add_child(fish)
		fish_nodes.append(fish)
		starts.append(fish.position)

	for frame in 150:
		await get_tree().physics_frame

	var speed_scales: Dictionary = {}
	for index in fish_nodes.size():
		var fish := fish_nodes[index]
		var travelled := fish.position.distance_to(starts[index])
		var direction: Vector2 = fish.get("_target_swim_direction")
		var speed_scale := snappedf(float(fish.get("_individual_speed_scale")), 0.01)
		speed_scales[speed_scale] = true
		var sprite := fish.get_node("Fishes") as Sprite2D
		if travelled < 12.0 or absf(direction.x) < 0.85 or absf(sprite.rotation) > 0.14:
			push_error("Fish movement is not smooth, predominantly horizontal, and naturally pitched.")
			get_tree().quit(1)
			return
	if speed_scales.size() < 2:
		push_error("Fish instances do not have enough individual speed variation.")
		get_tree().quit(1)
		return
	print("CALIGO_FISH_NATURAL_TEST: smooth wandering, pitch and individual speed variation OK")
	get_tree().quit(0)
