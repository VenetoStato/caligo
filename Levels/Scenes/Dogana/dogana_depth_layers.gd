extends Node2D

## Parallasse world-space: sei piani con velocita' distinte, sempre ancorati alla
## camera. I layer architettonici giocabili restano fermi e sostituibili.
##
## I piani frontali sono silhouette PIENE, non veli trasparenti: un primo piano
## in trasparenza legge come una macchia sporca sopra la scena, mentre una massa
## opaca in indaco profondo separa davvero le profondita'.

## Palette dei piani: dal viola pallido della distanza all'indaco del davanti.
const FORE_WOOD := Color(0.3, 0.36, 0.42, 1.0)
const FORE_CLOSE := Color(0.18, 0.22, 0.28, 1.0)
const FOREGROUND_POLE := preload("res://Landscape/Dogana/bricola_foreground.svg")
const DISTANT_FOG_DOGANA := preload("res://Landscape/Dogana/Generated/Parallax/dogana_distant_fog_v2.png")
const DISTANT_SHIP_SHEET := preload("res://Landscape/Dogana/Generated/Parallax/distant_velieri_sheet_v1.png")
const DISTANT_LAGOON_FOG := preload("res://Landscape/Dogana/Generated/Parallax/distant_lagoon_fog_v1.png")
const DISTANT_SOFT_FOCUS := preload("res://Levels/Scenes/Dogana/background_softfocus.gdshader")
const CITY_RAIN_SHADER := preload("res://Levels/Scenes/Dogana/city_rain.gdshader")

@export_category("Distant atmosphere")
@export_range(0.0, 40.0, 0.5) var distant_dogana_blur := 18.0
@export_range(0.0, 40.0, 0.5) var distant_ships_blur := 22.0
@export_range(0.0, 40.0, 0.5) var distant_fog_blur := 28.0
@export_range(0.0, 1.0, 0.01) var fog_opacity := 1.0
@export_range(0.0, 0.5, 0.01) var fog_opacity_pulse := 0.07
@export_range(0.0, 30.0, 0.5) var fog_vertical_drift := 9.0
@export var rain_enabled := false
@export_range(0.0, 1.0, 0.01) var rain_intensity := 0.62
@export_range(0.1, 3.0, 0.05) var rain_speed := 1.0
@export_range(-1.0, 1.0, 0.01) var rain_wind := 0.16
@export_range(2.0, 60.0, 1.0) var rain_collision_rate := 32.0

var _camera: Camera2D
var _origin := Vector2.ZERO
var _last_camera := Vector2.ZERO

var _horizon: Node2D
var _far: Node2D
var _mid: Node2D
var _mid_near: Node2D
var _near: Node2D
var _fore: Node2D
var _fore_close: Node2D
var _distant_dogana: Node2D
var _distant_ships: Node2D
var _distant_fog: Node2D
var _rain_overlay: ColorRect
var _rain_surface_fx: Node2D
var _rain_collision_accumulator := 0.0
var _rain_water_body: Node2D
var _fore_motes: CPUParticles2D
var _moon: Node2D
var _interior_overlay: Polygon2D
var _bokeh_far: CPUParticles2D
var _bokeh_near: CPUParticles2D
var _atmospheric_dust: CPUParticles2D
var _light_motes: CPUParticles2D
var _world_lights: Node2D


func _ready() -> void:
	add_to_group("dogana_depth_system")
	# Luna sul piano piu' lontano visibile (davanti al cielo opaco, dietro
	# fog e moduli). I poligoni geometrici di skyline/tetti/quinte sono
	# stati rimossi: i nodi restano vuoti per i gruppi di parallasse.
	_moon = _build_moon()
	_horizon = _build_empty_layer("HorizonViolet", -22, "dogana_parallax_horizon")
	_far = _build_empty_layer("FarLagoonSilhouettes", -19, "dogana_parallax_far")
	_distant_dogana = _build_distant_dogana()
	_distant_ships = _build_distant_ships()
	_distant_fog = _build_distant_fog()
	_rain_overlay = _build_rain_effect()
	_rain_surface_fx = _build_rain_surface_fx()
	apply_atmosphere_tuning()
	_mid = _build_mid_reflections()
	_mid_near = _build_empty_layer("MidNearRooftops", -5, "dogana_parallax_mid_near")
	_near = _build_empty_layer("NearAtmosphericFrames", 12, "dogana_parallax_near")
	_fore = _build_foreground_veils()
	_fore_close = _build_foreground_close()
	_world_lights = _build_world_lights()
	if OS.has_feature("mobile") or OS.get_name() == "Android":
		pass
	else:
		_fore_motes = _build_foreground_motes()
		_bokeh_far = _build_bokeh_layer("FarBokeh", -16, 18, Color(0.42, 0.72, 0.75, 0.18), 0.65)
		_bokeh_near = _build_bokeh_layer("NearBokeh", 11, 11, Color(0.72, 0.78, 0.62, 0.12), 1.25)
		_atmospheric_dust = _build_atmospheric_dust()
		_light_motes = _build_light_motes()
	_interior_overlay = _build_interior_depth()
	set_process(true)


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_tree().get_first_node_in_group("camera") as Camera2D
		if _camera:
			_last_camera = _camera.global_position
		return
	var camera_pos := _camera.global_position
	var delta_cam := camera_pos - _last_camera
	_last_camera = camera_pos
	# Più lontano = spostamento minore. Il foreground anticipa leggermente.
	_horizon.position += delta_cam * 0.05
	_far.position += delta_cam * 0.12
	_distant_dogana.position += delta_cam * 0.08
	_distant_ships.position += delta_cam * 0.10
	_distant_fog.position += delta_cam * 0.09
	_mid.position += delta_cam * 0.26
	_mid_near.position += delta_cam * 0.42
	_near.position += delta_cam * 0.58
	# I piani frontali si muovono contro la camera: scorrono piu' veloci del mondo.
	_fore.position -= delta_cam * 0.3
	_fore_close.position -= delta_cam * 0.62
	# Deriva organica minima: profondità viva, non fondale statico.
	var t := Time.get_ticks_msec() * 0.001
	_horizon.position.y = sin(t * 0.09) * 2.5
	_far.position.y = sin(t * 0.13) * 4.0
	_mid.position.y = sin(t * 0.22 + 1.4) * 7.0
	_mid_near.position.y = sin(t * 0.27 + 2.2) * 8.5
	_near.position.y = sin(t * 0.31 + 0.7) * 10.0
	if _bokeh_far:
		_bokeh_far.position.x = sin(t * 0.08) * 22.0
	if _bokeh_near:
		_bokeh_near.position.x = sin(t * 0.12 + 2.0) * 32.0
	if _distant_ships:
		for ship in _distant_ships.get_children():
			ship.position.x += float(ship.get_meta("sail_speed", 0.0)) * delta
			if ship.position.x > 6900.0:
				ship.position.x = -900.0
	if _distant_fog:
		_distant_fog.position.x += sin(t * 0.11) * delta * 5.0
		_distant_fog.position.y = sin(t * 0.17 + 0.8) * fog_vertical_drift
		_distant_fog.modulate.a = clampf(fog_opacity + sin(t * 0.13) * fog_opacity_pulse, 0.0, 1.0)
	if rain_enabled:
		_update_rain_water_clip()
		_update_rain_collision_fx(delta)
	var inside := camera_pos.y < -100.0
	_interior_overlay.modulate.a = move_toward(_interior_overlay.modulate.a, 0.5 if inside else 0.0, delta * 0.7)
	if _moon:
		# Quasi fissa sul cielo: 1% di deriva, lontanissima, non appiccicata.
		_moon.global_position = Vector2(
			780.0 + camera_pos.x * 0.01,
			96.0 + camera_pos.y * 0.006
		)
		_moon.modulate.a = move_toward(_moon.modulate.a, 0.0 if inside else 1.0, delta * 1.4)


## I piani lontani non hanno piu' poligoni: skyline a denti, isole triangolari,
## tetti-rettangolo e quinte ai bordi leggevano come geometria di debug sopra
## l'architettura dipinta. I nodi restano vuoti perche' il test di coerenza
## conta i gruppi di parallasse.
func _build_empty_layer(layer_name: String, z: int, group_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = z
	layer.add_to_group(group_name)
	add_child(layer)
	return layer


## Luna sul piano piu' lontano visibile: dietro fog e moduli, davanti al cielo
## opaco del fondale. Disco minuscolo, alone enorme, cosi' legge come un corpo
## sfuocato nella foschia e non come un cerchio appoggiato sugli edifici.
func _build_moon() -> Node2D:
	var moon := Node2D.new()
	moon.name = "Moon"
	moon.z_index = -17
	moon.z_as_relative = false
	moon.add_to_group("dogana_moon")
	add_child(moon)
	var outer := Sprite2D.new()
	outer.texture = _make_moon_glow(0.18)
	outer.scale = Vector2(14.0, 11.0)
	outer.modulate = Color(0.72, 0.78, 0.92, 0.42)
	moon.add_child(outer)
	var halo := Sprite2D.new()
	halo.texture = _make_moon_glow(0.22)
	halo.scale = Vector2(7.2, 7.2)
	halo.modulate = Color(0.84, 0.88, 0.96, 0.5)
	moon.add_child(halo)
	var disc := Sprite2D.new()
	disc.texture = _make_moon_glow(0.2)
	disc.scale = Vector2(3.4, 3.4)
	disc.modulate = Color(0.94, 0.96, 1.0, 0.42)
	moon.add_child(disc)
	return moon


func _make_moon_glow(core: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, core * 0.45, core, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.18),
		Color(1, 1, 1, 0.04),
		Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


## Riflessi di fondo sulla laguna. Erano Line2D nette e leggevano come
## "lineette" disegnate sull'acqua: ora sono smerigliature morbide additive.
func _build_mid_reflections() -> Node2D:
	# I riflessi allungati leggevano come rettangoli in parallasse sull'acqua.
	# La superficie ha gia' caustiche e schiuma nello shader: questo piano resta
	# vuoto, il gruppo serve al test di coerenza.
	return _build_empty_layer("MidLagoonGlints", -8, "dogana_parallax_mid")


## Copia lontana della Dogana: stessa architettura, molto più piccola e
## raffreddata dalla foschia. È scenografia pura e resta dietro alla Dogana
## giocabile, ma davanti al cielo e alla luna.
func _build_distant_dogana() -> Node2D:
	var layer := Node2D.new()
	layer.name = "DistantFogDogana"
	# Stesso piano dell'architettura, ma questo nodo compare prima nell'albero:
	# rimane dietro alla Dogana senza finire nascosto dal fondale.
	layer.z_as_relative = false
	layer.z_index = -17
	layer.add_to_group("dogana_parallax_distant_architecture")
	# L'immagine è larga poco più di una schermata: la ripetiamo con una lieve
	# sovrapposizione per coprire tutta la Dogana senza interruzioni nel parallax.
	for index in 6:
		var sprite := Sprite2D.new()
		sprite.texture = DISTANT_FOG_DOGANA
		sprite.position = Vector2(620.0 + index * 1220.0, 286.0)
		# +30% rispetto al primo passaggio: deve leggere come città lontana,
		# non come una striscia sul fondo.
		sprite.scale = Vector2(0.936, 0.936)
		sprite.material = _make_distant_soft_focus(distant_dogana_blur, 0.10)
		sprite.modulate = Color(0.72, 0.86, 1.0, 1.0)
		sprite.z_index = 0
		layer.add_child(sprite)
	add_child(layer)
	return layer


## Velieri lontani ricavati dallo sprite-sheet raster: tre scale e velocità
## diverse danno profondità senza introdurre collisioni.
func _build_distant_ships() -> Node2D:
	var layer := Node2D.new()
	layer.name = "DistantSailingShips"
	layer.z_as_relative = false
	layer.z_index = -17
	layer.add_to_group("dogana_parallax_distant_ships")
	var fleet := [
		[Vector2(-230, 390), 7.0, 0.64, 0],
		[Vector2(150, 438), 4.0, 0.44, 1],
		[Vector2(720, 418), 6.0, 0.52, 3],
		[Vector2(4350, 353), 9.0, 0.72, 2],
		[Vector2(5880, 418), 5.5, 0.52, 3],
	]
	for entry in fleet:
		var ship := _make_distant_ship(float(entry[2]), int(entry[3]))
		ship.position = entry[0]
		ship.set_meta("sail_speed", float(entry[1]))
		layer.add_child(ship)
	add_child(layer)
	return layer


func _make_distant_ship(scale_mul: float, sheet_index: int) -> Node2D:
	var ship := Node2D.new()
	ship.scale = Vector2(scale_mul, scale_mul)
	var sprite := Sprite2D.new()
	sprite.texture = DISTANT_SHIP_SHEET
	sprite.region_enabled = true
	var frame_width := float(DISTANT_SHIP_SHEET.get_width()) / 4.0
	sprite.region_rect = Rect2(frame_width * sheet_index, 0.0, frame_width, float(DISTANT_SHIP_SHEET.get_height()))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = _make_distant_soft_focus(distant_ships_blur, 0.12)
	sprite.modulate = Color(0.66, 0.82, 0.95, 1.0)
	ship.add_child(sprite)
	return ship


## Nebbia raster semitrasparente: attraversa lentamente la Dogana lontana e
## i velieri, senza coprire la Dogana giocabile in primo piano.
func _build_distant_fog() -> Node2D:
	var layer := Node2D.new()
	layer.name = "DistantLagoonFog"
	layer.z_as_relative = false
	layer.z_index = -17
	layer.modulate = Color(0.72, 0.85, 1.0, 1.0)
	layer.add_to_group("dogana_parallax_distant_fog")
	for index in 5:
		var sprite := Sprite2D.new()
		sprite.texture = DISTANT_LAGOON_FOG
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.material = _make_distant_soft_focus(distant_fog_blur, 0.08)
		sprite.position = Vector2(360.0 + index * 1420.0, 430.0)
		sprite.scale = Vector2(0.78, 0.78)
		layer.add_child(sprite)
	add_child(layer)
	return layer


## Sfocatura applicata alle texture raster lontane: non genera forme, filtra
## soltanto gli asset già esistenti con il materiale di background del progetto.
func _make_distant_soft_focus(blur_radius: float, tint_strength: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DISTANT_SOFT_FOCUS
	material.set_shader_parameter("blur_radius", blur_radius)
	material.set_shader_parameter("edge_fade", 0.04)
	material.set_shader_parameter("atmosphere_tint", Color(0.58, 0.76, 0.9, 1.0))
	material.set_shader_parameter("tint_strength", tint_strength)
	return material


func apply_atmosphere_tuning() -> void:
	_set_layer_blur(_distant_dogana, distant_dogana_blur)
	_set_layer_blur(_distant_ships, distant_ships_blur)
	_set_layer_blur(_distant_fog, distant_fog_blur)
	if _distant_fog:
		_distant_fog.modulate.a = fog_opacity
	if _rain_overlay:
		_rain_overlay.visible = rain_enabled
		var rain_material := _rain_overlay.material as ShaderMaterial
		if rain_material:
			rain_material.set_shader_parameter("intensity", rain_intensity)
			rain_material.set_shader_parameter("fall_speed", rain_speed)
			rain_material.set_shader_parameter("wind", rain_wind)
			var viewport_size := get_viewport_rect().size
			if viewport_size.y > 0.0:
				rain_material.set_shader_parameter("aspect_ratio", viewport_size.x / viewport_size.y)
		_update_rain_water_clip()
	if _rain_surface_fx:
		_rain_surface_fx.visible = rain_enabled
		if not rain_enabled:
			_rain_collision_accumulator = 0.0


func _set_layer_blur(layer: Node2D, blur_radius: float) -> void:
	if layer == null:
		return
	for child in layer.find_children("*", "Sprite2D", true, false):
		if child.material is ShaderMaterial:
			(child.material as ShaderMaterial).set_shader_parameter("blur_radius", blur_radius)


func _build_rain_effect() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.name = "CityRain"
	layer.layer = 5
	add_child(layer)
	var rain := ColorRect.new()
	rain.name = "RainOverlay"
	rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rain.visible = rain_enabled
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rain.color = Color(0, 0, 0, 0)
	var material := ShaderMaterial.new()
	material.shader = CITY_RAIN_SHADER
	rain.material = material
	layer.add_child(rain)
	return rain


func _build_rain_surface_fx() -> Node2D:
	var root := Node2D.new()
	root.name = "RainCollisionImpacts"
	root.z_as_relative = false
	root.z_index = 13
	root.visible = rain_enabled
	add_child(root)
	return root


func _update_rain_water_clip() -> void:
	if _rain_overlay == null or not rain_enabled:
		return
	var rain_material := _rain_overlay.material as ShaderMaterial
	if rain_material == null:
		return
	if _rain_water_body == null or not is_instance_valid(_rain_water_body):
		_rain_water_body = get_tree().get_first_node_in_group("water") as Node2D
	if _rain_water_body == null or not _rain_water_body.has_method("get_surface_height"):
		# Values below the viewport leave the whole screen raining until the
		# water node has completed its own _ready().
		rain_material.set_shader_parameter("waterline_uv", 2.0)
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.y <= 0.0:
		return
	var sample_x := _camera.global_position.x if _camera != null else _rain_water_body.global_position.x
	var surface_y := float(_rain_water_body.call("get_surface_height", sample_x))
	var screen_surface := get_viewport().get_canvas_transform() * Vector2(sample_x, surface_y)
	rain_material.set_shader_parameter("waterline_uv", screen_surface.y / viewport_size.y)


func _update_rain_collision_fx(delta: float) -> void:
	if _camera == null or _rain_surface_fx == null:
		return
	var mobile_ratio := 0.62 if OS.has_feature("mobile") else 1.0
	_rain_collision_accumulator += delta * rain_collision_rate * rain_intensity * mobile_ratio
	var spawned := 0
	while _rain_collision_accumulator >= 1.0 and spawned < 4:
		_rain_collision_accumulator -= 1.0
		_spawn_collision_rain_drop()
		spawned += 1


func _spawn_collision_rain_drop() -> void:
	var viewport_size := get_viewport_rect().size
	var zoom := maxf(absf(_camera.zoom.x), 0.01)
	var half_width := viewport_size.x / zoom * 0.62
	var half_height := viewport_size.y / zoom * 0.66
	var start := Vector2(
		_camera.global_position.x + randf_range(-half_width, half_width),
		_camera.global_position.y - half_height
	)
	var fall_vector := Vector2(rain_wind * 150.0, half_height * 2.05)
	var finish := start + fall_vector
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters2D.create(start, finish)
	query.collision_mask = 1
	# WaterBody is an Area2D. Including areas lets rain hit its true dynamic
	# surface instead of disappearing through the basin.
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	var target := finish
	var did_hit := not hit.is_empty()
	var normal := Vector2.UP
	var collider: Object = null
	if did_hit:
		target = hit.position as Vector2
		normal = hit.normal as Vector2
		collider = hit.get("collider") as Object

	var drop := Line2D.new()
	drop.name = "RainDrop"
	drop.width = randf_range(1.0, 1.8)
	drop.default_color = Color(0.58, 0.82, 0.86, randf_range(0.22, 0.48))
	drop.points = PackedVector2Array([Vector2(-rain_wind * 8.0, -randf_range(20.0, 34.0)), Vector2.ZERO])
	drop.global_position = start
	_rain_surface_fx.add_child(drop)
	var travel_time := start.distance_to(target) / maxf(760.0, 1040.0 * rain_speed)
	var tween := create_tween()
	tween.tween_property(drop, "global_position", target, maxf(0.05, travel_time))
	if did_hit:
		tween.tween_callback(_spawn_rain_impact.bind(target, normal, collider))
	tween.tween_callback(drop.queue_free)


func _spawn_rain_impact(at: Vector2, normal: Vector2, collider: Object = null) -> void:
	if _rain_surface_fx == null or not rain_enabled:
		return
	if collider != null and is_instance_valid(collider) and collider is Node:
		var hit_node := collider as Node
		if hit_node.is_in_group("water") and hit_node.has_method("rain_impact_at"):
			hit_node.call("rain_impact_at", at.x, rain_intensity)
			return
	var particles := CPUParticles2D.new()
	particles.name = "SurfaceSplash"
	particles.one_shot = true
	particles.amount = 3 if not OS.has_feature("mobile") else 2
	particles.lifetime = 0.24
	particles.explosiveness = 0.96
	particles.randomness = 0.72
	particles.direction = normal.normalized()
	particles.spread = 76.0
	particles.gravity = Vector2(0, 190)
	particles.initial_velocity_min = 18.0
	particles.initial_velocity_max = 42.0
	particles.scale_amount_min = 0.07
	particles.scale_amount_max = 0.18
	particles.color = Color(0.54, 0.78, 0.82, 0.38)
	particles.texture = _make_rain_splash_texture()
	_rain_surface_fx.add_child(particles)
	particles.global_position = at + normal * 2.0
	particles.emitting = true
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 0.55
	cleanup.autostart = true
	cleanup.timeout.connect(particles.queue_free)
	particles.add_child(cleanup)


func _make_rain_splash_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0.72), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 4
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	return texture


## Piano frontale: pali d'ormeggio in massa piena che passano davanti al
## personaggio. Sono opachi di proposito - una silhouette netta legge come
## "vicino", un velo semitrasparente legge come vetro sporco.
func _build_foreground_veils() -> Node2D:
	var layer := Node2D.new()
	layer.name = "ForegroundPoles"
	layer.z_as_relative = false
	layer.z_index = 15
	layer.add_to_group("dogana_parallax_foreground")
	add_child(layer)
	if OS.has_feature("mobile"):
		return layer
	# Radi: con un palo ogni schermata il primo piano diventa una palizzata che
	# nasconde il gioco invece di dargli profondita'.
	for index in 3:
		var x := 640.0 + index * 2350.0
		layer.add_child(_make_foreground_pole(x, 675.0, 1.05, 1.5, FORE_WOOD))
	return layer


## Piano piu' vicino di tutti: pochissimi elementi, molto grandi, che sfiorano i
## bordi dell'inquadratura. Scorre quasi al doppio della velocita' del mondo.
func _build_foreground_close() -> Node2D:
	var layer := Node2D.new()
	layer.name = "ForegroundClose"
	layer.z_as_relative = false
	layer.z_index = 17
	layer.add_to_group("dogana_parallax_foreground_close")
	add_child(layer)
	if OS.has_feature("mobile"):
		return layer
	for index in 3:
		var x := 1200.0 + index * 2050.0
		layer.add_child(_make_foreground_pole(x, 760.0, 1.5, 2.1, FORE_CLOSE))
	return layer


## Palo d'ormeggio in primo piano: la briccola dipinta, ingrandita e portata in
## ombra profonda ma OPACA. Un poligono costruito a mano leggeva come una barra;
## la texture vera conserva venature, cerchiature e testa tagliata.
func _make_foreground_pole(
	x: float,
	y: float,
	scale_x: float,
	scale_y: float,
	tint: Color
) -> Sprite2D:
	var pole := Sprite2D.new()
	pole.texture = FOREGROUND_POLE
	pole.position = Vector2(x, y)
	pole.scale = Vector2(scale_x, scale_y)
	pole.modulate = tint
	return pole


## Pulviscolo grande e vicinissimo: passa davanti a tutto e vende la profondita'.
func _build_foreground_motes() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "ForegroundMotes"
	particles.z_as_relative = false
	particles.z_index = 16
	particles.amount = 6 if OS.has_feature("mobile") else 14
	particles.lifetime = 6.0
	particles.preprocess = 6.0
	particles.emitting = true
	particles.randomness = 0.9
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 420)
	particles.position = Vector2(3250, 330)
	particles.direction = Vector2(0.4, -1.0)
	particles.spread = 42.0
	particles.gravity = Vector2(3.0, -1.5)
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 18.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.85
	particles.color = Color(0.5, 0.66, 0.66, 0.1)
	particles.texture = _make_bokeh_texture()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.24, 0.7, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.6),
		Color(1, 1, 1, 0.32), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_foreground_motes")
	add_child(particles)
	return particles


func _build_bokeh_layer(
	layer_name: String,
	z: int,
	amount: int,
	tint: Color,
	scale_mul: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = layer_name
	particles.z_as_relative = false
	particles.z_index = z
	particles.amount = amount if not OS.has_feature("mobile") else maxi(5, amount / 2)
	particles.lifetime = 10.0
	particles.preprocess = 10.0
	particles.emitting = true
	particles.randomness = 0.86
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 520)
	particles.position = Vector2(3250, 160)
	particles.direction = Vector2(0.18, -1.0)
	particles.spread = 38.0
	particles.gravity = Vector2(2.0, -3.0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 7.0
	# La texture e' 48 px: sopra ~1.0 di scala diventano dischi bianchi piatti
	# in cielo, che leggono come palloni e non come sfocato atmosferico.
	particles.scale_amount_min = 0.18 * scale_mul
	particles.scale_amount_max = 0.52 * scale_mul
	particles.color = tint
	particles.texture = _make_bokeh_texture()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.22, 0.72, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.8),
		Color(1, 1, 1, 0.5), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_bokeh_layer")
	add_child(particles)
	return particles


func _build_atmospheric_dust() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "AtmosphericDust"
	particles.z_as_relative = false
	particles.z_index = 9
	particles.amount = 38 if not OS.has_feature("mobile") else 18
	particles.lifetime = 8.5
	particles.preprocess = 8.5
	particles.emitting = true
	particles.randomness = 0.92
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 500)
	particles.position = Vector2(3250, 120)
	particles.direction = Vector2(0.35, -1.0)
	particles.spread = 48.0
	particles.gravity = Vector2(1.4, -2.2)
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 10.0
	particles.scale_amount_min = 0.055
	particles.scale_amount_max = 0.18
	particles.color = Color(0.58, 0.78, 0.76, 0.2)
	particles.texture = _make_bokeh_texture()
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.18, 0.76, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.72),
		Color(1, 1, 1, 0.38), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_atmospheric_dust")
	add_child(particles)
	return particles


func _build_light_motes() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = "LightMotes"
	particles.z_as_relative = false
	particles.z_index = 6
	particles.amount = 10 if OS.has_feature("mobile") else 24
	particles.lifetime = 7.2
	particles.preprocess = 7.2
	particles.emitting = true
	particles.randomness = 0.95
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(3900, 470)
	particles.position = Vector2(3250, 70)
	particles.direction = Vector2(0.2, -1.0)
	particles.spread = 58.0
	particles.gravity = Vector2(0.8, -3.6)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 8.0
	particles.scale_amount_min = 0.045
	particles.scale_amount_max = 0.13
	particles.color = Color(0.66, 0.94, 0.84, 0.24)
	particles.texture = _make_bokeh_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.72, 1.0])
	fade.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.7),
		Color(1, 1, 1, 0.42), Color(1, 1, 1, 0),
	])
	particles.color_ramp = fade
	particles.add_to_group("dogana_light_motes")
	add_child(particles)
	return particles


func _build_world_lights() -> Node2D:
	var layer := Node2D.new()
	layer.name = "ArchitecturalGlowPools"
	layer.add_to_group("dogana_light_layer")
	add_child(layer)
	if OS.get_name() == "Android" or OS.has_feature("mobile"):
		return layer
	var texture := _make_light_texture()
	var positions := [
		Vector2(650, 375), Vector2(1550, 365), Vector2(2700, 320),
		Vector2(4200, 365), Vector2(5480, 375),
	]
	for index in positions.size():
		var light := PointLight2D.new()
		light.name = "Glow_%02d" % index
		light.position = positions[index]
		light.texture = texture
		light.texture_scale = 2.5
		light.energy = 0.1 if OS.has_feature("mobile") else 0.16
		light.color = Color(0.56, 0.78, 0.72, 1.0) if index % 2 == 0 else Color(0.84, 0.69, 0.43, 1.0)
		light.shadow_enabled = false
		layer.add_child(light)
	return layer


func _make_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.74), Color(1, 1, 1, 0.25),
		Color(1, 1, 1, 0.045), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_bokeh_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.76, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.38),
		Color(1, 1, 1, 0.08), Color(1, 1, 1, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 48
	texture.height = 48
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _build_interior_depth() -> Polygon2D:
	var overlay := Polygon2D.new()
	overlay.name = "InteriorDepthWash"
	overlay.z_index = -2
	overlay.polygon = PackedVector2Array([
		Vector2(4000, -1750), Vector2(6250, -1750),
		Vector2(6250, -430), Vector2(4000, -430),
	])
	overlay.color = Color(0.035, 0.075, 0.085, 0.34)
	overlay.modulate.a = 0.0
	add_child(overlay)
	return overlay
