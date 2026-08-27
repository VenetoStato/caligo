extends Area2D

const TILE_SHEET := preload("res://Art/Editable/VFX/salute_tile_fragments.png")

## Frammento di piastrella della Salute: traiettoria balistica corta, due
## rimbalzi pesanti e leggibili. Non e' una pallina elastica.
var velocity := Vector2.ZERO
var damage := 1
var fall_gravity := 760.0
var floor_y := 0.0
var bounces_left := 2
var lifetime := 3.2
var _age := 0.0
var _hit_player := false


func setup(start_velocity: Vector2, floor_height: float, attack_damage: int) -> void:
	velocity = start_velocity
	floor_y = floor_height
	damage = attack_damage


func _ready() -> void:
	add_to_group("enemy_transient_attack")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 10
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	var tile_sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = TILE_SHEET
	var cell := Vector2(float(TILE_SHEET.get_width()) / 3.0, float(TILE_SHEET.get_height()) / 2.0)
	var choice := randi() % 6
	atlas.region = Rect2(Vector2(float(choice % 3) * cell.x, float(choice / 3) * cell.y), cell)
	tile_sprite.texture = atlas
	tile_sprite.scale = Vector2.ONE * (30.0 / maxf(cell.y, 1.0))
	tile_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(tile_sprite)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	rotation += velocity.x * delta * 0.012
	if global_position.y >= floor_y:
		global_position.y = floor_y
		if bounces_left <= 0:
			queue_free()
			return
		bounces_left -= 1
		velocity.y = -absf(velocity.y) * (0.36 if bounces_left == 0 else 0.44)
		velocity.x *= 0.58
	for body in get_overlapping_bodies():
		if _hit_player or not (body is Node2D) or not body.is_in_group("player"):
			continue
		_hit_player = true
		if body.has_method("take_damage"):
			body.call_deferred("take_damage", damage, global_position)
		queue_free()
		return

