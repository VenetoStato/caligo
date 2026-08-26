@tool
extends Node2D
## Spine da pontile. L'arte è sostituibile dalla disegnatrice: hitbox restano qui.

enum Kind { CLUSTER, BED }

@export var kind := Kind.CLUSTER
@export var bed_width := 96.0
@export var vertical := false
@export var damage := 1
@export var snap_to_ground := true
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

const OUTLINE_PX := 2.5
const OUTLINE_DIRS := [
	Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
	Vector2(-0.72, -0.72), Vector2(0.72, -0.72),
	Vector2(-0.72, 0.72), Vector2(0.72, 0.72),
]

var _hazard: Area2D
var _pogo_box: Area2D
var _sprite: Sprite2D
var _flash := 0.0
var _hurt_cd := 0.0
var _bounce_cd := 0.0


func _ready() -> void:
	add_to_group("pogoable")
	add_to_group("dogana_thorn")
	z_as_relative = false
	z_index = 12
	if get_node_or_null("Art") == null:
		_build_visual()
	# Mostra le spine nella viewport senza eseguire snap, danno o pogo mentre
	# l'autore sta spostando gli elementi della scena.
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return
	_build_hurtboxes()
	call_deferred("_snap_to_ground")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	_bounce_cd = maxf(0.0, _bounce_cd - delta)
	if _sprite and _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		var glow := 1.0 + _flash * 0.55
		_sprite.modulate = Color(glow, glow, 1.08, 1.0)


func on_pogo_hit() -> void:
	_flash = 1.0


func _build_hurtboxes() -> void:
	var pogo_size := _pogo_size()
	_pogo_box = Area2D.new()
	_pogo_box.name = "PogoHurtbox"
	_pogo_box.collision_layer = 2
	_pogo_box.collision_mask = 4
	_pogo_box.monitorable = true
	_pogo_box.monitoring = false
	_pogo_box.add_to_group("pogoable")
	_pogo_box.add_to_group("dogana_thorn")
	var pogo_col := CollisionShape2D.new()
	var pogo_shape := RectangleShape2D.new()
	pogo_shape.size = pogo_size
	pogo_col.shape = pogo_shape
	pogo_col.position = Vector2(0.0, -pogo_size.y * 0.5)
	_pogo_box.add_child(pogo_col)
	add_child(_pogo_box)

	var hazard_size := _hazard_size()
	_hazard = Area2D.new()
	_hazard.name = "Hazard"
	_hazard.collision_layer = 0
	_hazard.collision_mask = 2
	_hazard.monitoring = true
	_hazard.monitorable = false
	var hazard_col := CollisionShape2D.new()
	var hazard_shape := RectangleShape2D.new()
	hazard_shape.size = hazard_size
	hazard_col.shape = hazard_shape
	hazard_col.position = Vector2(0.0, -hazard_size.y * 0.5)
	_hazard.add_child(hazard_col)
	_hazard.body_entered.connect(_on_hazard_body)
	add_child(_hazard)


func _physics_process(_delta: float) -> void:
	if _hazard == null:
		return
	for body in _hazard.get_overlapping_bodies():
		_try_hurt(body)


func _on_hazard_body(body: Node2D) -> void:
	_try_hurt(body)


func _try_hurt(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if body.has_method("is_pogo_grace") and bool(body.call("is_pogo_grace")):
		return
	if body.has_method("is_thorn_grace") and bool(body.call("is_thorn_grace")):
		return
	if "is_dashing" in body and bool(body.get("is_dashing")):
		return
	if _hurt_cd <= 0.0 and body.has_method("take_damage"):
		body.call("take_damage", damage, Vector2.ZERO)
		_hurt_cd = 0.55
	_launch_player(body)


func _launch_player(body: Node) -> void:
	if _bounce_cd > 0.0:
		return
	if body.has_method("apply_thorn_bounce"):
		body.call("apply_thorn_bounce", global_position)
	elif "velocity" in body and body is Node2D:
		var away: Vector2 = (body as Node2D).global_position - global_position
		if away.length_squared() < 4.0:
			away = Vector2.UP
		away.y = minf(away.y, -0.35)
		body.set("velocity", away.normalized() * 280.0)
	_bounce_cd = 0.32


func _pogo_size() -> Vector2:
	if vertical:
		return Vector2(32.0, 88.0)
	if kind == Kind.BED:
		return Vector2(bed_width * 0.78, 24.0)
	return Vector2(34.0, 48.0)


func _hazard_size() -> Vector2:
	if vertical:
		return Vector2(36.0, 80.0)
	if kind == Kind.BED:
		return Vector2(bed_width * 0.88, 26.0)
	return Vector2(38.0, 42.0)


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Art"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture := _resolve_texture()
	if texture == null:
		return
	_sprite.texture = texture
	if kind == Kind.BED:
		var target_h := art_profile.thorn_bed_height if art_profile else 40.0
		_sprite.scale = Vector2(
			bed_width / float(texture.get_width()),
			target_h / float(texture.get_height())
		)
	else:
		var s: Vector2 = art_profile.thorn_cluster_scale if art_profile else Vector2(0.08, 0.08)
		# Se lo scale del profilo è relativo al placeholder: adatta all'altezza ~68px.
		if texture.get_height() > 0:
			var target_h := 96.0 if vertical else 68.0
			var fitted := target_h / float(texture.get_height())
			_sprite.scale = Vector2(fitted, fitted)
		else:
			_sprite.scale = s
	_seat_visual_on_anchor()
	_add_cartoon_outline()
	add_child(_sprite)


func _resolve_texture() -> Texture2D:
	if art_profile:
		if kind == Kind.BED and art_profile.thorn_bed:
			return art_profile.thorn_bed
		if kind == Kind.CLUSTER and art_profile.thorn_cluster:
			return art_profile.thorn_cluster
	return null


func _seat_visual_on_anchor() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var image := _sprite.texture.get_image()
	if image == null:
		_sprite.position.y = -(_sprite.texture.get_height() * absf(_sprite.scale.y)) * 0.5
		return
	if image.is_compressed() and image.decompress() != OK:
		_sprite.position.y = -(_sprite.texture.get_height() * absf(_sprite.scale.y)) * 0.5
		return
	var used := image.get_used_rect()
	if used.size.y <= 0:
		_sprite.position.y = -(_sprite.texture.get_height() * absf(_sprite.scale.y)) * 0.5
		return
	var bottom_from_center := float(used.end.y) - float(image.get_height()) * 0.5
	_sprite.position.y = -bottom_from_center * absf(_sprite.scale.y)


func _add_cartoon_outline() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	for dir in OUTLINE_DIRS:
		var rim := Sprite2D.new()
		rim.texture = _sprite.texture
		rim.centered = true
		rim.texture_filter = _sprite.texture_filter
		rim.scale = _sprite.scale
		rim.position = _sprite.position + dir * OUTLINE_PX
		rim.modulate = Color(0.02, 0.02, 0.05, 1.0)
		rim.z_index = -1
		add_child(rim)


func _snap_to_ground() -> void:
	if not snap_to_ground:
		return
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -260.0),
		global_position + Vector2(0.0, 300.0)
	)
	query.collision_mask = 1
	for node in get_tree().get_nodes_in_group("dogana_bricole"):
		if node is CollisionObject2D:
			query.exclude.append((node as CollisionObject2D).get_rid())
	var hit := space.intersect_ray(query)
	if hit.is_empty() or _is_bricola(hit.get("collider")):
		return
	global_position.y = (hit.position as Vector2).y


func _is_bricola(node: Variant) -> bool:
	var current := node as Node
	while current:
		if current.is_in_group("dogana_bricole"):
			return true
		current = current.get_parent()
	return false
