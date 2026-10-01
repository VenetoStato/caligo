extends Node2D

## Il player cade lungo un muro tenendo destra: deve scivolare lento
## (wall slide), poi il salto lo stacca dal muro verso sinistra anche se
## destra resta premuta (input lock del wall jump).

@onready var _player: CharacterBody2D = $Player

var _frame := 0
var _slide_frames := 0
var _max_slide_vy := 0.0
var _jump_vx := INF
var _jump_vy := INF
var _vx_during_lock := INF


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		Input.action_press("ui_right")

	if _frame >= 30 and _frame < 70 and _player.is_wall_sliding:
		_slide_frames += 1
		_max_slide_vy = maxf(_max_slide_vy, _player.velocity.y)

	if _frame == 70:
		Input.action_press("ui_accept")
	elif _frame == 74:
		Input.action_release("ui_accept")
	if _frame >= 70 and _frame < 80:
		_jump_vx = minf(_jump_vx, _player.velocity.x)
		_jump_vy = minf(_jump_vy, _player.velocity.y)
	if _frame == 76:
		_vx_during_lock = _player.velocity.x

	if _frame == 90:
		Input.action_release("ui_right")
		print("CALIGO_WALL_JUMP_TEST: slide_frames %d max_slide_vy %.1f jump_vx %.1f jump_vy %.1f lock_vx %.1f" % [
			_slide_frames, _max_slide_vy, _jump_vx, _jump_vy, _vx_during_lock,
		])
		var ok: bool = (
			_slide_frames >= 20
			and _max_slide_vy <= _player.wall_slide_speed + 1.0
			and _jump_vx <= -180.0
			and _jump_vy <= -0.8 * _player.jump_speed * _player.wall_jump_vertical_scale
			and _vx_during_lock < 0.0
		)
		if not ok:
			push_error("CALIGO_WALL_JUMP_FAIL")
			get_tree().quit(1)
			return
		print("CALIGO_WALL_JUMP_OK")
		set_physics_process(false)
		await get_tree().create_timer(1.1).timeout
		get_tree().quit(0)
