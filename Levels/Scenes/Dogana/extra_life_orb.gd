extends Area2D
## Pallina bianca sospesa: una vita in più permanente.

var _time := 0.0
var _taken := false
var _home := Vector2.ZERO


func _ready() -> void:
	add_to_group("dogana_extra_life")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 8
	_home = global_position
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _taken:
		return
	global_position = _home + Vector2(sin(_time * 1.4) * 3.0, sin(_time * 2.1) * 7.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _taken or body == null or not body.is_in_group("player"):
		return
	if not body.has_method("add_life_vessel"):
		return
	_taken = true
	body.call("add_life_vessel")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var pulse := 0.7 + 0.3 * sin(_time * 4.0)
	draw_circle(Vector2.ZERO, 16.0 * pulse, Color(1.0, 1.0, 1.0, 0.1))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 1.0, 1.0, 0.92))
	draw_circle(Vector2(-2.5, -2.8), 2.4, Color(1.0, 1.0, 1.0, 0.7))
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 22, Color(1.0, 1.0, 1.0, 0.55), 1.4, true)
