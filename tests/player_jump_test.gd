extends Node2D

@onready var _player: CharacterBody2D = $Player

var _frame := 0
var _start_y := 0.0
var _minimum_y := INF
var _first_jump_velocity := INF
var _second_jump_velocity := INF


func _physics_process(_delta: float) -> void:
	_frame += 1
	_minimum_y = minf(_minimum_y, _player.global_position.y)

	if _frame == 30:
		if not _player.is_on_floor():
			push_error("Player did not settle on the test floor.")
			get_tree().quit(1)
			return
		_start_y = _player.global_position.y
		Input.action_press("ui_accept")
	elif _frame == 32:
		Input.action_release("ui_accept")
	elif _frame == 50:
		Input.action_press("ui_accept")
	elif _frame == 52:
		Input.action_release("ui_accept")

	if _frame >= 30 and _frame < 50:
		_first_jump_velocity = minf(_first_jump_velocity, _player.velocity.y)
	elif _frame >= 50 and _frame < 90:
		_second_jump_velocity = minf(_second_jump_velocity, _player.velocity.y)

	if _frame == 110:
		var rise := _start_y - _minimum_y
		print("CALIGO_JUMP_TEST: first %.2f, second %.2f, rise %.2f px" % [
			_first_jump_velocity,
			_second_jump_velocity,
			rise,
		])
		if _first_jump_velocity >= -120.0 or _second_jump_velocity >= -120.0 or rise < 40.0:
			push_error("Player jump or double jump is not functioning.")
			get_tree().quit(1)
			return
		set_physics_process(false)
		_finish_cleanly()


func _finish_cleanly() -> void:
	await get_tree().create_timer(1.1).timeout
	get_tree().quit(0)
