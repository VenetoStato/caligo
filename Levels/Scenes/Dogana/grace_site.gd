extends Area2D

@export var site_id := "pontile"
@export var display_name := "Pontile della Dogana"
@export var activated := false

var _time := 0.0
var _player_near := false
var _light: PointLight2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("dogana_grace")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_light()
	_update_prompt()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _light:
		var base_energy := 0.88 if activated else 0.12
		_light.energy = base_energy + sin(_time * 2.2) * (0.13 if activated else 0.025)
	queue_redraw()


func set_activated(value: bool) -> void:
	activated = value
	_update_prompt()
	queue_redraw()


func get_respawn_position() -> Vector2:
	return global_position + Vector2(0.0, -58.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_update_prompt()


func _update_prompt() -> void:
	var prompt := get_node_or_null("Prompt") as Label
	if prompt:
		prompt.visible = _player_near
		prompt.text = "E / ✦  RIPOSA" if activated else "E / ✦  RISVEGLIA L'ALTARE"


func _create_light() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.35, 1.0, 0.86, 0.8),
		Color(0.1, 0.5, 0.45, 0.22),
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
	_light.position = Vector2(0.0, -32.0)
	_light.texture = texture
	_light.texture_scale = 1.65
	_light.color = Color(0.42, 1.0, 0.86, 1.0)
	add_child(_light)


func _draw() -> void:
	var glow := Color(0.34, 0.9, 0.84, 0.82) if activated else Color(0.48, 0.52, 0.5, 0.44)
	var gold := Color(0.9, 0.72, 0.34, 0.95) if activated else Color(0.36, 0.38, 0.36, 0.8)
	var pulse := 1.0 + sin(_time * 2.4) * 0.08

	draw_polygon(
		PackedVector2Array([
			Vector2(-30, 2), Vector2(-22, -9), Vector2(-12, -14),
			Vector2(12, -14), Vector2(22, -9), Vector2(30, 2),
			Vector2(24, 10), Vector2(-24, 10),
		]),
		PackedColorArray([Color(0.17, 0.21, 0.21, 1.0)])
	)
	draw_arc(Vector2(0, -8), 25.0 * pulse, PI, TAU, 30, glow, 3.0)
	draw_arc(Vector2(0, -8), 17.0 * pulse, PI, TAU, 24, gold, 2.0)
	draw_line(Vector2(-20, 6), Vector2(20, 6), gold, 2.0)

	for index in 5:
		var phase := _time * (1.2 + index * 0.11) + index * 1.37
		var x := sin(phase) * (6.0 + index * 2.0)
		var y := -20.0 - fmod(_time * (14.0 + index * 2.0) + index * 12.0, 54.0)
		var alpha := 0.25 + 0.5 * (1.0 - absf(y + 47.0) / 32.0)
		draw_circle(Vector2(x, y), 2.2 + index * 0.25, Color(glow.r, glow.g, glow.b, alpha))

	if activated:
		var flame := PackedVector2Array()
		for index in 15:
			var t := float(index) / 14.0
			flame.append(Vector2(
				sin(_time * 3.0 + t * 7.0) * (5.0 * (1.0 - t)),
				-16.0 - t * 37.0
			))
		draw_polyline(flame, glow, 3.5, true)
