extends Node2D

const CARCASS_SCRIPT := preload("res://dead_enemy_carcass.gd")

var _player := Node2D.new()
var _carcass := RigidBody2D.new()
var _start := Vector2.ZERO
var _frame := 0


func _ready() -> void:
	_player.name = "PlayerReference"
	_player.position = Vector2.ZERO
	add_child(_player)

	var floor := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(700.0, 20.0)
	floor_shape.shape = floor_rect
	floor.position = Vector2(120.0, 20.0)
	floor.add_child(floor_shape)
	add_child(floor)

	_carcass.set_script(CARCASS_SCRIPT)
	_carcass.position = Vector2(250.0, 0.0)
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(24.0, 20.0)
	body_shape.shape = body_rect
	_carcass.add_child(body_shape)
	add_child(_carcass)
	_carcass.call("set_player_reference", _player)
	_start = _carcass.position


func _physics_process(delta: float) -> void:
	_frame += 1
	_carcass.call("reel_toward", Vector2(0.0, -36.0), delta, 165.0)
	if _frame < 100:
		return
	var travel := _start.x - _carcass.position.x
	if travel < 70.0:
		push_error("Corpse reel did not overcome floor friction (travel %.2f px)." % travel)
		get_tree().quit(1)
		return
	if _carcass.position.y < -125.0:
		push_error("Corpse reel exceeded the vertical lift cap (y %.2f)." % _carcass.position.y)
		get_tree().quit(1)
		return
	print("CALIGO_CARCASS_REEL_OK: travel %.2f px, y %.2f" % [travel, _carcass.position.y])
	get_tree().quit(0)
