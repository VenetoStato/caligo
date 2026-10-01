extends Node2D

var _droplets: Array[Dictionary] = []
var _age := 0.0
var _lifetime := 0.72
var _ring_radius := 4.0
var _color := Color(0.8, 0.96, 1.0, 0.9)


func setup(impulse: float, color: Color) -> void:
	_color = color
	var strength := clampf(absf(impulse) / 300.0, 0.35, 1.4)
	var count := clampi(roundi(7.0 + strength * 6.0), 8, 16)
	for index in count:
		var spread := lerpf(-1.0, 1.0, float(index) / float(maxi(count - 1, 1)))
		_droplets.append({
			"position": Vector2(spread * randf_range(3.0, 15.0), randf_range(-3.0, 2.0)),
			"velocity": Vector2(
				spread * randf_range(75.0, 185.0) * strength,
				-randf_range(130.0, 285.0) * strength
			),
			"radius": randf_range(1.0, 2.4) * strength,
		})
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	_ring_radius += 150.0 * delta
	for droplet in _droplets:
		var velocity: Vector2 = droplet["velocity"]
		var position: Vector2 = droplet["position"]
		velocity.y += 720.0 * delta
		position += velocity * delta
		droplet["velocity"] = velocity
		droplet["position"] = position
	queue_redraw()
	if _age >= _lifetime:
		queue_free()


func _draw() -> void:
	var alpha := clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	var draw_color := Color(_color.r, _color.g, _color.b, _color.a * alpha * 0.68)
	for droplet in _droplets:
		draw_circle(droplet["position"], droplet["radius"], draw_color)
	draw_arc(Vector2.ZERO, _ring_radius, PI * 1.12, PI * 1.88, 22, draw_color, 1.45)
	var wake_color := Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.48)
	_draw_surface_arc(_ring_radius * 1.35, maxf(1.0, _ring_radius * 0.1), PI * 1.03, PI * 1.38, wake_color, 1.0)
	_draw_surface_arc(_ring_radius * 1.35, maxf(1.0, _ring_radius * 0.1), PI * 1.62, PI * 1.97, wake_color, 1.0)
	draw_line(Vector2(-25.0, 1.0), Vector2(-7.0, 1.0), wake_color, 1.2)
	draw_line(Vector2(7.0, 1.0), Vector2(25.0, 1.0), wake_color, 1.2)


func _draw_surface_arc(
	radius_x: float,
	radius_y: float,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	for index in 13:
		var angle := lerpf(start_angle, end_angle, float(index) / 12.0)
		points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)
