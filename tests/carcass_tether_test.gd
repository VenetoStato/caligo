extends Node2D

const CARCASS_SCRIPT := preload("res://dead_enemy_carcass.gd")

var _carcass: RigidBody2D
var _frames := 0


func _ready() -> void:
	set_meta("is_test_root", true)
	var player := Node2D.new()
	add_child(player)
	_carcass = RigidBody2D.new()
	_carcass.set_script(CARCASS_SCRIPT)
	_carcass.position = Vector2(120.0, 0.0)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	_carcass.add_child(shape)
	add_child(_carcass)
	_carcass.call("set_player_reference", player)
	_carcass.gravity_scale = 0.0
	_carcass.call("set_line_tether", Vector2.ZERO, 80.0)
	_carcass.linear_velocity = Vector2(220.0, 0.0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 12:
		return
	var distance := _carcass.global_position.length()
	if distance > 80.75:
		push_error("Carcass stretched tether to %.2f px (limit 80 px)." % distance)
		get_tree().quit(1)
		return
	print("CALIGO_CARCASS_TETHER_OK: constrained at %.2f px" % distance)
	get_tree().quit(0)
