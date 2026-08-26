extends Node2D

const FISH_SCENE := preload("res://fish.tscn")
const CARCASS_SCRIPT := preload("res://dead_enemy_carcass.gd")

@onready var _water: Node = $Water

var _bait: RigidBody2D
var _predator: RigidBody2D
var _frame := 0
var _expected_bait_position := Vector2(410.0, 270.0)


func _ready() -> void:
	set_meta("is_test_root", true)
	_bait = RigidBody2D.new()
	_bait.set_script(CARCASS_SCRIPT)
	_bait.position = Vector2(220.0, 280.0)
	_bait.freeze = true
	add_child(_bait)

	_predator = FISH_SCENE.instantiate() as RigidBody2D
	_predator.set_meta("bait_giant", true)
	_predator.set_meta("bait_target_position", _bait.global_position)
	_predator.set_meta("bait_target_node", _bait)
	_predator.position = Vector2(900.0, 380.0)
	_predator.call("set_water_body", _water)
	add_child(_predator)


func _physics_process(_delta: float) -> void:
	_frame += 1
	# Sposta l'esca dopo che il predatore ha già iniziato la rotta: deve
	# correggere il bersaglio vivo, non proseguire verso la posizione iniziale.
	if _frame == 18:
		_bait.position = _expected_bait_position
	if _frame < 210:
		return
	var target: Vector2 = _predator.get("_bait_target") as Vector2
	if is_instance_valid(_bait) and not _bait.is_queued_for_deletion():
		push_error("Large predator did not consume the carcass bait.")
		get_tree().quit(1)
		return
	if target.distance_to(_expected_bait_position) > 2.0:
		push_error("Predator target did not follow the moved carcass.")
		get_tree().quit(1)
		return
	if bool(_predator.get("_bait_target_active")):
		push_error("Large predator never completed the bait approach.")
		get_tree().quit(1)
		return
	print("CALIGO_BAIT_PREDATOR_OK: live target followed and carcass consumed")
	get_tree().quit(0)
