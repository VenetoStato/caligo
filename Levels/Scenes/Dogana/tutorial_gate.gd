extends StaticBody2D

var _time := 0.0
var _unlocked := false
var _collision: CollisionShape2D


func _ready() -> void:
	add_to_group("dogana_tutorial_gate")
	collision_layer = 1
	collision_mask = 2
	_collision = CollisionShape2D.new()
	_collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34.0, 420.0)
	_collision.shape = shape
	add_child(_collision)
	z_index = 4


func _process(delta: float) -> void:
	if _unlocked:
		return
	_time += delta
	if fmod(_time, 1.0 / 30.0) < delta:
		queue_redraw()


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	_collision.set_deferred("disabled", true)
	_spawn_unlock_particles()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position:y", position.y - 90.0, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if _unlocked:
		return
	var pulse := 0.65 + sin(_time * 2.8) * 0.2
	draw_rect(Rect2(-17, -210, 34, 420), Color(0.015, 0.05, 0.055, 0.82), true)
	for x in [-12.0, 0.0, 12.0]:
		draw_line(Vector2(x, -205), Vector2(x, 205), Color(0.58, 0.52, 0.34, 0.82), 3.0, true)
	for y in range(-180, 200, 42):
		draw_line(Vector2(-14, y), Vector2(14, y + 18), Color(0.3, 0.82, 0.7, 0.3 + pulse * 0.25), 1.5, true)
	draw_arc(Vector2.ZERO, 27.0 + pulse * 5.0, 0.0, TAU, 32, Color(0.34, 0.94, 0.78, pulse), 3.0, true)
	draw_circle(Vector2.ZERO, 7.0, Color(0.72, 0.86, 0.55, pulse))


func _spawn_unlock_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "TutorialGateRelease"
	particles.one_shot = true
	particles.amount = 28
	particles.lifetime = 1.2
	particles.explosiveness = 0.92
	particles.direction = Vector2.UP
	particles.spread = 150.0
	particles.initial_velocity_min = 55.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 65)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.32, 0.95, 0.78, 0.86)
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = 1.5
	cleanup_timer.autostart = true
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.add_child(cleanup_timer)
