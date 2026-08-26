@tool
extends StaticBody2D

const PLATFORM_TEXTURE := preload("res://Landscape/Dogana/Generated/quay_platform.png")

@export var platform_size := Vector2(700.0, 96.0):
	set(value):
		platform_size = Vector2(maxf(value.x, 16.0), maxf(value.y, 12.0))
		_sync_collision()
		queue_redraw()


func _ready() -> void:
	add_to_group("dogana_platform")
	collision_layer = 1
	collision_mask = 2
	z_index = 45 if Engine.is_editor_hint() else -1
	_sync_collision()
	queue_redraw()


func _draw() -> void:
	if PLATFORM_TEXTURE == null:
		return
	# Questa e' la piattaforma reale: il medesimo nodo contiene immagine e
	# collisione. Spostando il nodo nella viewport si spostano entrambe.
	draw_texture_rect(
		PLATFORM_TEXTURE,
		Rect2(Vector2.ZERO, platform_size),
		false,
		Color.WHITE
	)


func _sync_collision() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision.shape = rectangle
	rectangle.size = platform_size
	collision.position = platform_size * 0.5
