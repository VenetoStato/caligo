extends Node2D

const PLATFORM_TEXTURE := preload("res://Landscape/Dogana/Generated/quay_platform.png")
const WORLD_TOP := -1500.0
const WORLD_BOTTOM := 940.0
const LEFT_EDGE := -55.0
const RIGHT_EDGE := 6135.0


func _ready() -> void:
	add_to_group("dogana_world_bounds")
	set_meta("bounds_rect", Rect2(LEFT_EDGE, WORLD_TOP, RIGHT_EDGE - LEFT_EDGE, WORLD_BOTTOM - WORLD_TOP))
	_build_collision()
	_add_vertical_frame(LEFT_EDGE, Color(0.55, 0.64, 0.61, 0.92))
	_add_vertical_frame(RIGHT_EDGE, Color(0.55, 0.64, 0.61, 0.92))
	set_process(false)
	set_physics_process(false)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "PerimeterCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("dogana_perimeter_collision")
	add_child(body)
	var height := WORLD_BOTTOM - WORLD_TOP
	for data in [
		["WestBoundary", LEFT_EDGE, height],
		["EastBoundary", RIGHT_EDGE, height],
	]:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(70.0, float(data[2]))
		var collision := CollisionShape2D.new()
		collision.name = str(data[0])
		collision.position = Vector2(float(data[1]), WORLD_TOP + height * 0.5)
		collision.shape = shape
		body.add_child(collision)


func _add_vertical_frame(x: float, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "BoundaryFrame"
	sprite.texture = PLATFORM_TEXTURE
	sprite.position = Vector2(x, (WORLD_TOP + WORLD_BOTTOM) * 0.5)
	sprite.rotation = PI * 0.5
	sprite.scale = Vector2((WORLD_BOTTOM - WORLD_TOP) / PLATFORM_TEXTURE.get_width(), 0.13)
	sprite.modulate = tint
	sprite.z_index = 3
	add_child(sprite)
