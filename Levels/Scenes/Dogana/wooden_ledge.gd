extends StaticBody2D
## Frammento di pontile: arte dipinta, alcune assi crollano se ci resti sopra.

@export var ledge_width := 110.0
@export var pile_depth := 86.0
@export var unstable := false
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

const PLANK := Color(0.52, 0.34, 0.18, 1.0)
const PLANK_LIGHT := Color(0.68, 0.48, 0.26, 1.0)
const PILE := Color(0.32, 0.2, 0.11, 1.0)
const INK := Color(0.05, 0.03, 0.02, 1.0)

var _floor: CollisionShape2D
var _sprite: Sprite2D
var _stand_area: Area2D
var _stand_time := 0.0
var _collapsed := false
var _home_y := 0.0
var _art_base := Vector2.ZERO


func _ready() -> void:
	add_to_group("dogana_platform")
	add_to_group("dogana_wooden_ledge")
	collision_layer = 1
	collision_mask = 2
	z_index = 5
	_home_y = position.y
	_build_collision()
	_build_visual()
	if unstable:
		_build_stand_zone()


func _physics_process(delta: float) -> void:
	if not unstable or _collapsed:
		return
	var standing := false
	if _stand_area:
		for body in _stand_area.get_overlapping_bodies():
			if body != null and body.is_in_group("player"):
				standing = true
				break
	if standing:
		_stand_time += delta
		var shake := clampf(_stand_time / 0.42, 0.0, 1.0)
		if _sprite:
			_sprite.position = _art_base + Vector2(sin(_stand_time * 42.0) * shake * 2.6, 0.0)
			_sprite.rotation = sin(_stand_time * 24.0) * shake * 0.045
		if _stand_time >= 0.48:
			_collapse()
	else:
		_stand_time = maxf(0.0, _stand_time - delta * 1.8)
		if _sprite:
			_sprite.position = _sprite.position.lerp(_art_base, clampf(delta * 12.0, 0.0, 1.0))
			_sprite.rotation = move_toward(_sprite.rotation, 0.0, delta * 2.4)


func _build_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ledge_width, 16.0)
	_floor = CollisionShape2D.new()
	_floor.name = "Floor"
	_floor.shape = shape
	_floor.position = Vector2(0.0, 8.0)
	add_child(_floor)


func _build_stand_zone() -> void:
	_stand_area = Area2D.new()
	_stand_area.name = "StandZone"
	_stand_area.collision_layer = 0
	_stand_area.collision_mask = 2
	_stand_area.monitoring = true
	_stand_area.monitorable = false
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ledge_width * 0.86, 18.0)
	col.shape = shape
	col.position = Vector2(0.0, -6.0)
	_stand_area.add_child(col)
	add_child(_stand_area)


func _build_visual() -> void:
	var texture := _resolve_texture()
	if texture:
		_build_painted_visual(texture)
		return
	_build_fallback_visual()


func _resolve_texture() -> Texture2D:
	if art_profile == null:
		return null
	if unstable and art_profile.pier_plank_cracked:
		return art_profile.pier_plank_cracked
	if art_profile.pier_plank:
		return art_profile.pier_plank
	if unstable and art_profile.pier_plank:
		return art_profile.pier_plank
	return null


func _build_painted_visual(texture: Texture2D) -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Art"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture = texture
	var used := _used_rect(texture)
	var src_w := maxf(float(used.size.x), 8.0)
	var fitted := ledge_width / src_w
	_sprite.scale = Vector2(fitted, fitted)
	var top_from_center := float(used.position.y) - float(texture.get_height()) * 0.5
	_art_base = Vector2(0.0, -top_from_center * fitted)
	_sprite.position = _art_base
	add_child(_sprite)


func _used_rect(texture: Texture2D) -> Rect2i:
	var image := texture.get_image()
	if image == null:
		return Rect2i(0, 0, texture.get_width(), texture.get_height())
	if image.is_compressed() and image.decompress() != OK:
		return Rect2i(0, 0, texture.get_width(), texture.get_height())
	var used := image.get_used_rect()
	if used.size.x <= 0:
		return Rect2i(0, 0, texture.get_width(), texture.get_height())
	return used


func _collapse() -> void:
	_collapsed = true
	if _floor:
		_floor.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "position:y", _home_y + 96.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.38)
	tween.tween_callback(_rebuild_later)


func _rebuild_later() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(4.4).timeout
	if not is_instance_valid(self):
		return
	position.y = _home_y
	modulate.a = 1.0
	_stand_time = 0.0
	_collapsed = false
	if _sprite:
		_sprite.position = _art_base
		_sprite.rotation = 0.0
	if _floor:
		_floor.disabled = false


func _build_fallback_visual() -> void:
	var half := ledge_width * 0.5
	var plank := Polygon2D.new()
	plank.z_index = 1
	plank.polygon = PackedVector2Array([
		Vector2(-half, 0.0), Vector2(half, 0.0),
		Vector2(half - 3.0, 15.0), Vector2(-half + 3.0, 15.0),
	])
	plank.color = PLANK
	add_child(plank)
	var rim := Line2D.new()
	rim.z_index = 2
	rim.width = 2.2
	rim.default_color = INK
	rim.closed = true
	rim.points = plank.polygon
	add_child(rim)
	var board := Line2D.new()
	board.z_index = 2
	board.width = 1.4
	board.default_color = PLANK_LIGHT
	board.points = PackedVector2Array([Vector2(-half + 6.0, 5.0), Vector2(half - 6.0, 5.0)])
	add_child(board)
	for offset in [-half + 14.0, half - 14.0]:
		var pile := Polygon2D.new()
		pile.z_index = 0
		pile.polygon = PackedVector2Array([
			Vector2(offset - 5.0, 14.0), Vector2(offset + 5.0, 14.0),
			Vector2(offset + 4.0, pile_depth), Vector2(offset - 4.0, pile_depth),
		])
		pile.color = PILE
		add_child(pile)
		var pile_ink := Line2D.new()
		pile_ink.z_index = 1
		pile_ink.width = 2.0
		pile_ink.default_color = INK
		pile_ink.closed = true
		pile_ink.points = pile.polygon
		add_child(pile_ink)
