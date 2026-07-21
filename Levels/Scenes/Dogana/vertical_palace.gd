extends Node2D

const PLATFORM_TEXTURE := preload("res://Landscape/Dogana/Generated/quay_platform.png")
const BREAKABLE_PROP := preload("res://Levels/Scenes/Dogana/breakable_prop.tscn")
const BREAKABLE_WALL := preload("res://Levels/Scenes/Dogana/breakable_wall.tscn")
const ENEMY := preload("res://Enemies/enemy.tscn")

const PALACE_BOUNDS := Rect2(2020, -1500, 1300, 1400)
const PLATFORMS: Array[Rect2] = [
	Rect2(2160, -140, 380, 30),
	Rect2(2410, -260, 290, 30),
	Rect2(2770, -380, 360, 30),
	Rect2(2470, -500, 300, 30),
	Rect2(2110, -620, 360, 30),
	Rect2(2500, -740, 340, 30),
	Rect2(2870, -860, 280, 30),
	Rect2(2470, -980, 330, 30),
	Rect2(2110, -1100, 1040, 34),
	Rect2(3030, -610, 250, 28),
	Rect2(2110, -860, 250, 28),
]

var _palace_enemies: Array[CharacterBody2D] = []


func _ready() -> void:
	name = "VerticalPalace"
	add_to_group("dogana_vertical_palace")
	set_meta("platform_count", PLATFORMS.size())
	set_meta("static_geometry", true)
	z_index = -1
	_build_static_collision()
	_build_platform_art()
	_build_interactions()
	_build_breakables()
	_build_enemy_encounters()
	_build_secret_vault()
	queue_redraw()
	# Il palazzo è interamente statico: nessun costo di processo dopo la costruzione.
	set_process(false)
	set_physics_process(false)


func _draw() -> void:
	# Fondale esteso oltre i muri: la camera non espone mai il clear color
	# mentre segue il giocatore nelle stanze verticali.
	draw_rect(Rect2(1200, -1600, 3600, 1550), Color(0.006, 0.014, 0.018, 1.0), true)
	draw_rect(PALACE_BOUNDS, Color(0.018, 0.03, 0.035, 0.985), true)
	draw_rect(PALACE_BOUNDS.grow(-18.0), Color(0.32, 0.3, 0.24, 0.5), false, 4.0)
	draw_rect(Rect2(2060, -1460, 1220, 1320), Color(0.055, 0.075, 0.075, 0.96), true)

	# Mattoni sfalsati e cornici sottili: il palazzo resta leggibile senza
	# sovrapporre sagome geometriche alle illustrazioni dello scenario.
	for row in range(22):
		var y := -1430.0 + row * 58.0
		var offset := 45.0 if row % 2 else 0.0
		draw_line(Vector2(2075, y), Vector2(3265, y), Color(0.55, 0.52, 0.4, 0.1), 1.0)
		for x in range(2100, 3260, 115):
			draw_line(
				Vector2(x + offset, y),
				Vector2(x + offset, y + 58.0),
				Color(0.43, 0.48, 0.42, 0.08),
				1.0
			)

	# Pozzo centrale, catene dell'ascensore e indicazioni diegetiche.
	draw_rect(Rect2(2675, -1040, 86, 800), Color(0.008, 0.017, 0.02, 0.96), true)
	draw_line(Vector2(2698, -1025), Vector2(2698, -250), Color(0.5, 0.43, 0.27, 0.52), 4.0)
	draw_line(Vector2(2738, -1025), Vector2(2738, -250), Color(0.5, 0.43, 0.27, 0.52), 4.0)
	for y in range(-1010, -260, 34):
		draw_line(Vector2(2698, y), Vector2(2738, y + 17), Color(0.42, 0.48, 0.39, 0.42), 2.0)

	_draw_seal(Vector2(2640, -1054))
	_draw_lift(Vector2(2180, -626))
	_draw_lift(Vector2(3070, -866))


func _build_static_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "AggregatedCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("dogana_palace_static_collision")
	add_child(body)
	for index in PLATFORMS.size():
		var rect := PLATFORMS[index]
		_add_rect_collision(body, rect, "Platform%02d" % index)
	_add_rect_collision(body, Rect2(2020, -1160, 44, 1060), "WestWall")
	_add_rect_collision(body, Rect2(3276, -1160, 44, 1060), "EastWall")
	_add_rect_collision(body, Rect2(2020, -1160, 1300, 44), "Roof")
	# Setti interni: obbligano a cambiare lato e impediscono una salita verticale diretta.
	_add_rect_collision(body, Rect2(3140, -560, 38, 190), "MazeWallLower")
	_add_rect_collision(body, Rect2(2160, -830, 38, 180), "MazeWallMiddle")
	_add_rect_collision(body, Rect2(3085, -1060, 38, 170), "MazeWallUpper")


func _add_rect_collision(body: StaticBody2D, rect: Rect2, node_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.name = node_name
	collision.position = rect.get_center()
	collision.shape = shape
	body.add_child(collision)


func _build_platform_art() -> void:
	var art := Node2D.new()
	art.name = "BatchedPlatformArt"
	art.add_to_group("dogana_palace_platform_art")
	add_child(art)
	for rect in PLATFORMS:
		var sprite := Sprite2D.new()
		sprite.texture = PLATFORM_TEXTURE
		sprite.centered = false
		sprite.position = rect.position
		var scale_x := rect.size.x / float(PLATFORM_TEXTURE.get_width())
		sprite.scale = Vector2(scale_x, scale_x * 0.72)
		sprite.modulate = Color(0.64, 0.72, 0.7, 1.0)
		art.add_child(sprite)
		var rim := Line2D.new()
		rim.points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
		rim.width = 2.6
		rim.default_color = Color(0.82, 0.76, 0.57, 0.82)
		rim.antialiased = true
		art.add_child(rim)
	for wall in [
		Rect2(2020, -1160, 44, 1060),
		Rect2(3276, -1160, 44, 1060),
		Rect2(3140, -560, 38, 190),
		Rect2(2160, -830, 38, 180),
		Rect2(3085, -1060, 38, 170),
	]:
		_add_vertical_wall_art(art, wall)
	# Portali costruiti con lo stesso asset illustrato delle strutture portanti.
	_add_vertical_wall_art(art, Rect2(2568, -5, 26, 105))
	_add_vertical_wall_art(art, Rect2(2666, -5, 26, 105))
	_add_ornate_lintel(art, Rect2(2568, -10, 124, 24))
	_add_vertical_wall_art(art, Rect2(2210, -264, 22, 84))
	_add_vertical_wall_art(art, Rect2(2288, -264, 22, 84))
	_add_ornate_lintel(art, Rect2(2210, -270, 100, 22))


func _add_vertical_wall_art(parent: Node2D, rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = PLATFORM_TEXTURE
	sprite.position = rect.get_center()
	sprite.rotation = PI * 0.5
	sprite.scale = Vector2(rect.size.y / float(PLATFORM_TEXTURE.get_width()), rect.size.x / float(PLATFORM_TEXTURE.get_height()))
	sprite.modulate = Color(0.58, 0.68, 0.65, 0.96)
	parent.add_child(sprite)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y),
	])
	edge.width = 2.4
	edge.default_color = Color(0.8, 0.72, 0.5, 0.72)
	parent.add_child(edge)


func _add_ornate_lintel(parent: Node2D, rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = PLATFORM_TEXTURE
	sprite.centered = false
	sprite.position = rect.position
	var scale_x := rect.size.x / float(PLATFORM_TEXTURE.get_width())
	sprite.scale = Vector2(scale_x, scale_x * 0.55)
	sprite.modulate = Color(0.63, 0.71, 0.68, 0.98)
	parent.add_child(sprite)


func _build_interactions() -> void:
	_add_interaction(
		"PalaceEntrance", Vector2(2630, 92), "palace_enter",
		"[E] Entra nel Palazzo dei Tributi", Vector2(2260, -190)
	)
	_add_interaction(
		"PalaceReturn", Vector2(2260, -190), "palace_exit",
		"[E] Torna al tetto della Dogana", Vector2(2630, 100)
	)
	_add_interaction(
		"PalaceSeal", Vector2(2640, -1050), "palace_seal",
		"[E] Recupera il Sigillo delle Maree", Vector2.ZERO
	)
	_add_interaction(
		"LiftLower", Vector2(2180, -650), "palace_lift",
		"[E] Tira la catena: scorciatoia superiore", Vector2(3050, -900)
	)
	_add_interaction(
		"LiftUpper", Vector2(3050, -900), "palace_lift",
		"[E] Discendi con l'argano", Vector2(2180, -660)
	)
	var lore := _add_interaction(
		"TributeLedger", Vector2(3010, -420), "lore",
		"[E] Leggi i tributi sommersi", Vector2.ZERO
	)
	lore.set_meta("message", "\"Ogni piano esigeva un pesce. Ogni debito lasciava una porta murata.\"")
	var vault_lore := _add_interaction(
		"VaultLedger", Vector2(2180, -940), "lore",
		"[E] Esamina il registro proibito", Vector2.ZERO
	)
	vault_lore.set_meta("message", "\"Il palazzo cresce verso l'alto perché sotto di esso la laguna continua a sognare.\"")


func _add_interaction(
	node_name: String,
	at: Vector2,
	action: String,
	prompt: String,
	target: Vector2
) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group("dogana_interactable")
	area.add_to_group("dogana_palace_interactable")
	area.set_meta("action", action)
	area.set_meta("prompt", prompt)
	if target != Vector2.ZERO:
		area.set_meta("target_position", target)
	var shape := CircleShape2D.new()
	shape.radius = 68.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	return area


func _build_breakables() -> void:
	var container := Node2D.new()
	container.name = "PalaceBreakables"
	container.add_to_group("dogana_palace_breakables")
	add_child(container)
	var caches := [
		Vector2(2450, -140), Vector2(2550, -260), Vector2(3020, -380),
		Vector2(2560, -500), Vector2(2240, -620), Vector2(2720, -740),
		Vector2(3020, -860), Vector2(2600, -980), Vector2(3120, -610),
		Vector2(2200, -860), Vector2(3000, -1100),
	]
	for index in caches.size():
		var cache := BREAKABLE_PROP.instantiate() as Node2D
		cache.name = "PalaceCache%02d" % index
		cache.position = caches[index]
		if index % 3 == 0:
			cache.set("hits_required", 2)
		container.add_child(cache)
	for wall_data in [
		[Vector2(2355, -945), 2],
		[Vector2(2848, -665), 3],
		[Vector2(3180, -505), 2],
	]:
		var wall := BREAKABLE_WALL.instantiate() as Node2D
		wall.position = wall_data[0]
		wall.set("hits_required", wall_data[1])
		container.add_child(wall)


func _build_secret_vault() -> void:
	var reveal := Area2D.new()
	reveal.name = "PalaceVaultReveal"
	reveal.position = Vector2(2215, -945)
	reveal.collision_layer = 0
	reveal.collision_mask = 2
	reveal.add_to_group("dogana_hidden_reveal")
	reveal.set_meta("secret_id", "palace_vault")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240, 160)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	reveal.add_child(collision)
	var veil := Polygon2D.new()
	veil.name = "Veil"
	veil.polygon = PackedVector2Array([
		Vector2(-120, -80), Vector2(120, -80), Vector2(120, 80), Vector2(-120, 80),
	])
	veil.color = Color(0.025, 0.05, 0.055, 0.94)
	reveal.add_child(veil)
	add_child(reveal)


func _build_enemy_encounters() -> void:
	var container := Node2D.new()
	container.name = "PalaceEncounters"
	container.add_to_group("dogana_palace_encounters")
	add_child(container)
	for index in 4:
		var enemy := ENEMY.instantiate() as CharacterBody2D
		enemy.name = "PalaceGambero%02d" % index
		enemy.position = [
			Vector2(2570, -290),
			Vector2(3000, -410),
			Vector2(2240, -650),
			Vector2(2980, -890),
		][index]
		enemy.scale = Vector2(0.036, 0.036)
		enemy.set("wake_delay", 1.45 + index * 0.2)
		container.add_child(enemy)
		enemy.set_physics_process(false)
		_palace_enemies.append(enemy)

	var activation := Area2D.new()
	activation.name = "PalaceActivation"
	activation.position = Vector2(2670, -630)
	activation.collision_layer = 0
	activation.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1260, 1040)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	activation.add_child(collision)
	activation.body_entered.connect(_on_palace_activation_entered)
	activation.body_exited.connect(_on_palace_activation_exited)
	add_child(activation)


func _on_palace_activation_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	for enemy in _palace_enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(true)


func _on_palace_activation_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	for enemy in _palace_enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)


func _draw_door(at: Vector2, scale_factor: float) -> void:
	var half_width := 38.0 * scale_factor
	var height := 88.0 * scale_factor
	draw_rect(Rect2(at.x - half_width, at.y - height, half_width * 2.0, height), Color(0.025, 0.055, 0.06, 0.98), true)
	draw_arc(Vector2(at.x, at.y - height), half_width, PI, TAU, 24, Color(0.56, 0.51, 0.36, 0.9), 5.0, true)
	draw_line(Vector2(at.x - half_width, at.y), Vector2(at.x - half_width, at.y - height), Color(0.56, 0.51, 0.36, 0.8), 5.0)
	draw_line(Vector2(at.x + half_width, at.y), Vector2(at.x + half_width, at.y - height), Color(0.56, 0.51, 0.36, 0.8), 5.0)


func _draw_seal(at: Vector2) -> void:
	draw_circle(at, 28.0, Color(0.12, 0.38, 0.36, 0.96))
	draw_arc(at, 28.0, 0, TAU, 32, Color(0.75, 0.64, 0.34, 0.92), 4.0, true)
	for ray in 8:
		var direction := Vector2.from_angle(ray * TAU / 8.0)
		draw_line(at + direction * 8.0, at + direction * 23.0, Color(0.35, 0.9, 0.76, 0.82), 2.0)


func _draw_lift(at: Vector2) -> void:
	draw_line(at + Vector2(-32, -70), at + Vector2(-32, 4), Color(0.55, 0.48, 0.3, 0.72), 3.0)
	draw_line(at + Vector2(32, -70), at + Vector2(32, 4), Color(0.55, 0.48, 0.3, 0.72), 3.0)
	draw_rect(Rect2(at.x - 44, at.y, 88, 10), Color(0.28, 0.31, 0.27, 1.0), true)
