extends Node2D
## Lampada gotica appesa: fisica a pendolo, l'amo della canna ci si agganci.

const ART := preload("res://Landscape/Dogana/Generated/gothic_hanging_lamp.png")

@export var chain_length := 78.0
@export var lamp_mass := 2.4

var _anchor: StaticBody2D
var _body: RigidBody2D
var _chain: Line2D


func _ready() -> void:
	add_to_group("dogana_hanging_lamp")
	z_index = 4
	_build()


func get_grapple_point() -> Vector2:
	return _body.global_position if _body else global_position


func _build() -> void:
	_anchor = StaticBody2D.new()
	_anchor.name = "CeilingPin"
	_anchor.collision_layer = 0
	_anchor.collision_mask = 0
	var pin_col := CollisionShape2D.new()
	var pin_shape := CircleShape2D.new()
	pin_shape.radius = 2.0
	pin_col.shape = pin_shape
	pin_col.disabled = true
	_anchor.add_child(pin_col)
	add_child(_anchor)

	_body = RigidBody2D.new()
	_body.name = "LampBody"
	_body.position = Vector2(0.0, chain_length)
	_body.collision_layer = 8
	_body.collision_mask = 0
	_body.mass = lamp_mass
	_body.gravity_scale = 0.92
	_body.linear_damp = 0.35
	_body.angular_damp = 1.4
	_body.can_sleep = false
	_body.add_to_group("dogana_grapple_point")
	var body_shape := CircleShape2D.new()
	body_shape.radius = 14.0
	var body_col := CollisionShape2D.new()
	body_col.shape = body_shape
	_body.add_child(body_col)
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ART:
		var fitted := 72.0 / maxf(float(ART.get_height()), 1.0)
		sprite.scale = Vector2(fitted, fitted)
		sprite.position.y = 8.0
	sprite.z_index = 1
	_body.add_child(sprite)
	var glow := PointLight2D.new()
	glow.energy = 0.55
	glow.texture_scale = 0.55
	glow.color = Color(1.0, 0.82, 0.42, 1.0)
	_body.add_child(glow)
	add_child(_body)

	_chain = Line2D.new()
	_chain.name = "Chain"
	_chain.width = 2.4
	_chain.default_color = Color(0.12, 0.1, 0.08, 0.95)
	_chain.antialiased = true
	_chain.z_index = 0
	add_child(_chain)

	var joint := PinJoint2D.new()
	joint.name = "Hinge"
	joint.node_a = _anchor.get_path()
	joint.node_b = _body.get_path()
	joint.softness = 0.55
	add_child(joint)


func _process(_delta: float) -> void:
	if _chain == null or _body == null:
		return
	_chain.points = PackedVector2Array([Vector2.ZERO, to_local(_body.global_position)])
