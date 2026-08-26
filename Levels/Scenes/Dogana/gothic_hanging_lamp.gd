extends Node2D
## Lampada gotica appesa: fisica a pendolo, l'amo della canna ci si agganci.

const ART := preload("res://Landscape/Dogana/Generated/gothic_hanging_lamp.png")
const DoganaFx := preload("res://Levels/Scenes/Dogana/dogana_fx.gd")

@export var chain_length := 104.0
@export var lamp_mass := 2.4
@export var droppable := false
@export var reel_time_to_drop := 0.58
@export var boss_impact_damage := 10

var _anchor: StaticBody2D
var _body: RigidBody2D
var _chain: Line2D
var _joint: PinJoint2D
var _reel_stress := 0.0
var _dropped := false
var _boss_hit := false


func _ready() -> void:
	add_to_group("dogana_hanging_lamp")
	z_index = 4
	_build()


func get_grapple_point() -> Vector2:
	return _body.global_position if _body else global_position


func reel_grapple(player: Node2D, delta: float) -> bool:
	if not droppable:
		return false
	if _dropped or _body == null:
		return _dropped
	_reel_stress = minf(reel_time_to_drop, _reel_stress + delta)
	var pull_direction := (player.global_position - _body.global_position).normalized()
	_body.apply_central_force(pull_direction * 920.0)
	_body.apply_torque(160.0 * signf(pull_direction.x if not is_zero_approx(pull_direction.x) else 1.0))
	var progress := clampf(_reel_stress / maxf(reel_time_to_drop, 0.01), 0.0, 1.0)
	_chain.width = lerpf(3.2, 5.8, progress)
	_chain.default_color = Color(0.12, 0.1, 0.08, 0.95).lerp(Color(0.72, 0.86, 0.82, 1.0), progress)
	if _reel_stress >= reel_time_to_drop:
		_drop_lamp(player.global_position)
	return _dropped


func is_dropped() -> bool:
	return _dropped


func can_be_pulled_down() -> bool:
	return droppable and not _dropped


func apply_grapple_tension(player: Node2D, delta: float, reeling: bool) -> void:
	if _dropped or _body == null or player == null:
		return
	var direction := (player.global_position - _body.global_position).normalized()
	var tension := 520.0 if reeling else 210.0
	_body.apply_central_force(direction * tension)
	# La componente laterale del peso del player mette davvero in moto il
	# pendolo sul PinJoint, invece di lasciare il lampadario scenograficamente fermo.
	_body.apply_torque(direction.x * 95.0 * delta * 60.0)


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
	_body.set_meta("grapple_owner", self)
	_body.add_to_group("dogana_grapple_point")
	var body_shape := CircleShape2D.new()
	body_shape.radius = 24.0
	var body_col := CollisionShape2D.new()
	body_col.shape = body_shape
	_body.add_child(body_col)
	var sprite := Sprite2D.new()
	sprite.texture = ART
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ART:
		var fitted := 104.0 / maxf(float(ART.get_height()), 1.0)
		sprite.scale = Vector2(fitted, fitted)
		sprite.position.y = 8.0
	sprite.z_index = 1
	_body.add_child(sprite)
	var glow := PointLight2D.new()
	glow.energy = 0.9
	glow.texture_scale = 0.78
	glow.color = Color(1.0, 0.82, 0.42, 1.0)
	_body.add_child(glow)
	add_child(_body)

	_chain = Line2D.new()
	_chain.name = "Chain"
	_chain.width = 3.2
	_chain.default_color = Color(0.16, 0.3, 0.31, 0.95) if droppable else Color(0.12, 0.1, 0.08, 0.95)
	_chain.antialiased = true
	_chain.z_index = 0
	add_child(_chain)

	_joint = PinJoint2D.new()
	_joint.name = "Hinge"
	_joint.node_a = _anchor.get_path()
	_joint.node_b = _body.get_path()
	_joint.softness = 0.55
	add_child(_joint)


func _drop_lamp(player_position: Vector2) -> void:
	if _dropped or _body == null:
		return
	_dropped = true
	if _joint and is_instance_valid(_joint):
		_joint.queue_free()
	_chain.visible = false
	_body.collision_mask = 1
	_body.linear_damp = 0.08
	_body.angular_damp = 0.3
	var fall_direction := (player_position - _body.global_position).normalized()
	fall_direction.y = maxf(fall_direction.y, 0.72)
	fall_direction = fall_direction.normalized()
	_body.apply_central_impulse(fall_direction * 285.0)
	_body.apply_torque_impulse(signf(fall_direction.x if not is_zero_approx(fall_direction.x) else 1.0) * 240.0)
	DoganaFx.burst(get_tree().current_scene, global_position, Color(0.55, 0.88, 0.86, 0.82), 13, Vector2.DOWN, 24.0, 88.0, 0.7)
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.28)


func _process(_delta: float) -> void:
	if _chain == null or _body == null:
		return
	if not _dropped:
		_chain.points = PackedVector2Array([Vector2.ZERO, to_local(_body.global_position)])
	else:
		_try_damage_boss()


func _try_damage_boss() -> void:
	if _boss_hit or _body == null:
		return
	for boss_node in get_tree().get_nodes_in_group("dogana_boss"):
		if not (boss_node is Node2D) or not is_instance_valid(boss_node):
			continue
		var boss := boss_node as Node2D
		var offset := boss.global_position - _body.global_position
		if absf(offset.x) > 138.0 or absf(offset.y) > 168.0 or not boss.has_method("take_damage"):
			continue
		var health_before := int(boss.get("current_health"))
		boss.call("take_damage", boss_impact_damage, _body.global_position)
		if int(boss.get("current_health")) >= health_before:
			continue
		_boss_hit = true
		_body.linear_velocity *= 0.28
		_body.apply_central_impulse(Vector2(0.0, -145.0))
		DoganaFx.burst(get_tree().current_scene, _body.global_position, Color(1.0, 0.76, 0.36, 0.95), 22, Vector2.UP, 45.0, 150.0, 0.85)
		var camera := get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("add_shake"):
			camera.call("add_shake", 0.62)
		return
