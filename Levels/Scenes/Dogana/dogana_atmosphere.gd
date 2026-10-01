extends Node2D
## Nebbia ambientale Dogana: soli veli world-space morbidi, senza particelle.
## Interazione: solo apertura soft vicino al player — niente scie blu.

const FOG_SHADER := preload("res://Levels/Scenes/Dogana/dogana_fog.gdshader")

var _player: CharacterBody2D
var _fog_mats: Array[ShaderMaterial] = []
var _mobile := false

const WORLD_RECT := Rect2(-700.0, -1500.0, 7200.0, 2600.0)


func _ready() -> void:
	z_index = 0
	_mobile = OS.get_name() == "Android" or OS.has_feature("mobile")
	_build_fog_volumes()
	set_process(true)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_update_fog_interaction()


func _build_fog_volumes() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var white_tex := ImageTexture.create_from_image(img)
	# Un velo unico su mobile: tre quad FBM a schermo intero sono troppo per GLES.
	var layers: Array = [
		{
			"name": "FogFar",
			"z": -19,
			"density": 0.42 if _mobile else 0.52,
			"scale": 0.0018,
			"wind": Vector2(0.012, 0.003),
			"color": Color(0.60, 0.76, 0.80, 0.58 if _mobile else 0.62),
			"layer": 0.0,
			"disturb": 0.16,
			"radius": 110.0,
			"octaves": 2 if _mobile else 3,
		},
	]
	if not _mobile:
		layers.append({
			"name": "FogMid",
			"z": -9,
			"density": 0.38,
			"scale": 0.0026,
			"wind": Vector2(0.02, 0.005),
			"color": Color(0.68, 0.82, 0.84, 0.36),
			"layer": 0.45,
			"disturb": 0.26,
			"radius": 95.0,
			"octaves": 3,
		})
		layers.append({
			"name": "FogNear",
			"z": 3,
			"density": 0.22,
			"scale": 0.0038,
			"wind": Vector2(0.028, 0.006),
			"color": Color(0.76, 0.88, 0.9, 0.28),
			"layer": 1.0,
			"disturb": 0.32,
			"radius": 80.0,
			"octaves": 2,
		})
	for cfg in layers:
		var poly := Polygon2D.new()
		poly.name = str(cfg.name)
		poly.z_as_relative = false
		poly.z_index = int(cfg.z)
		poly.polygon = PackedVector2Array([
			WORLD_RECT.position,
			Vector2(WORLD_RECT.end.x, WORLD_RECT.position.y),
			WORLD_RECT.end,
			Vector2(WORLD_RECT.position.x, WORLD_RECT.end.y),
		])
		poly.uv = PackedVector2Array([
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(1, 1),
			Vector2(0, 1),
		])
		poly.color = Color.WHITE
		poly.texture = white_tex
		var mat := ShaderMaterial.new()
		mat.shader = FOG_SHADER
		mat.set_shader_parameter("u_color", cfg.color)
		mat.set_shader_parameter("u_density", cfg.density)
		mat.set_shader_parameter("u_scale", cfg.scale)
		mat.set_shader_parameter("u_wind", cfg.wind)
		mat.set_shader_parameter("u_layer", cfg.layer)
		mat.set_shader_parameter("u_disturb_strength", cfg.disturb)
		mat.set_shader_parameter("u_disturb_radius", cfg.radius)
		mat.set_shader_parameter("u_octaves", cfg.octaves)
		mat.set_shader_parameter("u_ground_y", 560.0)
		mat.set_shader_parameter("u_ceiling_y", -900.0)
		mat.set_shader_parameter("u_height_soft", 0.62)
		poly.material = mat
		add_child(poly)
		_fog_mats.append(mat)


func _update_fog_interaction() -> void:
	# Solo uniforms: apre un foro soft. Nessuna scia di particelle dietro al player.
	var player_pos := Vector2(-99999.0, -99999.0)
	var player_vel := Vector2.ZERO
	if _player:
		player_pos = _player.global_position
		player_vel = _player.velocity
	for mat in _fog_mats:
		mat.set_shader_parameter("u_player_world", player_pos)
		mat.set_shader_parameter("u_player_vel", player_vel)
