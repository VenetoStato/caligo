@tool
extends StaticBody2D

const PLATFORM_TEXTURE := preload("res://Landscape/Dogana/Generated/quay_platform.png")

@export var platform_size := Vector2(700.0, 96.0):
	set(value):
		platform_size = Vector2(maxf(value.x, 16.0), maxf(value.y, 12.0))
		_sync_collision()
		_sync_visual()


func _ready() -> void:
	add_to_group("dogana_platform")
	collision_layer = 1
	collision_mask = 2
	z_index = -1
	_sync_collision()
	_sync_visual()
	var editor_guide := get_node_or_null("EditorGuide") as CanvasItem
	if editor_guide:
		editor_guide.visible = Engine.is_editor_hint()


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


func _sync_visual() -> void:
	if not is_inside_tree() or PLATFORM_TEXTURE == null:
		return
	var sprite := get_node_or_null("PlatformArt") as Sprite2D
	if sprite == null:
		return
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2(
		platform_size.x / float(PLATFORM_TEXTURE.get_width()),
		platform_size.y / float(PLATFORM_TEXTURE.get_height())
	)
