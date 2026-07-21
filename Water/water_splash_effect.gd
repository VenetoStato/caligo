extends Node2D

var _droplets: Array[Dictionary] = []
var _age := 0.0
var _lifetime := 0.72
var _ring_radius := 4.0
var _color := Color(0.8, 0.96, 1.0, 0.9)


func setup(impulse: float, color: Color) -> void:
	_color = color
	var strength := clampf(absf(impulse) / 300.0, 0.35, 1.4)
	var count := clampi(roundi(9.0 + strength * 9.0), 10, 22)
	for index in count:
		var spread := lerpf(-1.0, 1.0, float(index) / float(maxi(count - 1, 1)))
		_droplets.append({
			"position": Vector2(spread * randf_range(3.0, 15.0), randf_range(-3.0, 2.0)),
			"velocity": Vector2(
				spread * randf_range(75.0, 185.0) * strength,
				-randf_range(130.0, 285.0) * strength
			),
			"radius": randf_range(1.7, 3.8) * strength,
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
	var draw_color := Color(_color.r, _color.g, _color.b, _color.a * alpha)
	for droplet in _droplets:
		draw_circle(droplet["position"], droplet["radius"], draw_color)
	draw_arc(Vector2.ZERO, _ring_radius, PI * 1.08, PI * 1.92, 26, draw_color, 2.4)
	draw_line(Vector2(-28.0, 1.0), Vector2(28.0, 1.0), draw_color, 3.0)
