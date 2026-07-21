extends Node2D

var _particles: Array[Dictionary] = []
var _age := 0.0
var _lifetime := 1.05
var _light: PointLight2D
var _label: Label


func _ready() -> void:
	add_to_group("fish_catch_effect")
	z_index = 90
	_create_light()
	_create_label()


func setup(health_restored: int) -> void:
	var count := 18
	for index in count:
		var angle := TAU * float(index) / float(count) + randf_range(-0.14, 0.14)
		var speed := randf_range(80.0, 190.0)
		_particles.append({
			"position": Vector2.ZERO,
			"velocity": Vector2.from_angle(angle) * speed + Vector2(0, -65),
			"radius": randf_range(1.8, 4.2),
			"gold": index % 3 == 0,
		})
	_label.text = "+%d VITA" % health_restored if health_restored > 0 else "VITA PIENA"
	_label.modulate = Color(1.0, 0.83, 0.42, 1.0) if health_restored > 0 else Color(0.55, 0.95, 0.87, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	for particle in _particles:
		var velocity: Vector2 = particle["velocity"]
		var position: Vector2 = particle["position"]
		velocity.y += 310.0 * delta
		velocity *= 1.0 - 1.2 * delta
		position += velocity * delta
		particle["velocity"] = velocity
		particle["position"] = position
	var fade := clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	_light.energy = fade * 1.35
	_label.position.y = -54.0 - _age * 26.0
	_label.modulate.a = fade
	queue_redraw()
	if _age >= _lifetime:
		queue_free()


func _draw() -> void:
	var fade := clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	draw_arc(Vector2.ZERO, 15.0 + _age * 60.0, 0.0, TAU, 34, Color(0.35, 1.0, 0.86, fade * 0.7), 2.5)
	for particle in _particles:
		var color := Color(1.0, 0.75, 0.28, fade) if particle["gold"] else Color(0.35, 1.0, 0.86, fade)
		draw_circle(particle["position"], float(particle["radius"]) * fade, color)


func _create_light() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.45, 1.0, 0.85, 0.9),
		Color(0.25, 0.8, 0.68, 0.35),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_light = PointLight2D.new()
	_light.texture = texture
	_light.color = Color(0.45, 1.0, 0.82, 1.0)
	_light.energy = 1.35
	_light.texture_scale = 1.3
	add_child(_light)


func _create_label() -> void:
	_label = Label.new()
	_label.position = Vector2(-70.0, -54.0)
	_label.size = Vector2(140.0, 32.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
