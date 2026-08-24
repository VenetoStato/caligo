extends Node2D

const ART := preload("res://Landscape/Dogana/Generated/salute_interior_v2.png")
const LAMP_SCENE := preload("res://Levels/Scenes/Dogana/gothic_hanging_lamp.tscn")

const FLOOR_Y := -500.0
const ROOM_LEFT := 4100.0
const ROOM_RIGHT := 6150.0
const ART_FLOOR_SOURCE_Y := 707.0
const ART_SCALE := 1.155


func _ready() -> void:
	add_to_group("dogana_salute_interior")
	_build_backdrop()
	_build_room_collision()
	_build_ceiling_rings()
	_build_passages()
	set_meta("floor_y", FLOOR_Y)
	set_meta("room_bounds", Rect2(ROOM_LEFT, -1710.0, ROOM_RIGHT - ROOM_LEFT, 1280.0))
	set_process(false)
	set_physics_process(false)


func _build_backdrop() -> void:
	var blackout := Polygon2D.new()
	blackout.name = "InteriorBlackout"
	blackout.z_index = -20
	blackout.polygon = PackedVector2Array([
		Vector2(ROOM_LEFT - 300, -1760), Vector2(ROOM_RIGHT + 300, -1760),
		Vector2(ROOM_RIGHT + 300, -360), Vector2(ROOM_LEFT - 300, -360),
	])
	blackout.color = Color(0.005, 0.012, 0.016, 1.0)
	add_child(blackout)
	var art := Sprite2D.new()
	art.name = "SaluteInteriorArt"
	art.texture = ART
	# Nel PNG il bordo camminabile è a y=707: allinealo esattamente alla
	# collisione, così personaggio e boss non sembrano sospesi nel vuoto.
	art.position = Vector2(5125, FLOOR_Y - (ART_FLOOR_SOURCE_Y - ART.get_height() * 0.5) * ART_SCALE)
	# Scala uniforme: il fondale resta sostituibile senza deformazioni.
	art.scale = Vector2.ONE * ART_SCALE
	art.z_index = -10
	art.set_meta("visual_floor_y", FLOOR_Y)
	art.add_to_group("dogana_salute_interior_art")
	add_child(art)


func _build_room_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "SaluteInteriorCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("dogana_salute_interior_collision")
	add_child(body)
	_add_rect(body, "Floor", Vector2(5125, FLOOR_Y + 55), Vector2(2050, 110))
	_add_rect(body, "WestWall", Vector2(ROOM_LEFT, -950), Vector2(60, 1100))
	_add_rect(body, "EastWall", Vector2(ROOM_RIGHT, -950), Vector2(60, 1100))


## Lampade gotiche a pendolo: l'amo della canna ci si appende per uscire
## dagli attacchi che spazzano tutto il pavimento della navata.
func _build_ceiling_rings() -> void:
	var heights := [-268.0, -318.0, -292.0, -330.0, -276.0]
	for index in heights.size():
		var lamp := LAMP_SCENE.instantiate() as Node2D
		lamp.name = "CeilingLamp_%d" % index
		lamp.position = Vector2(4560.0 + index * 290.0, FLOOR_Y + float(heights[index]))
		lamp.set("chain_length", 64.0 + float(index % 3) * 8.0)
		add_child(lamp)


func _add_rect(parent: Node, node_name: String, center: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.name = node_name
	collision.position = center
	collision.shape = shape
	parent.add_child(collision)


func _build_passages() -> void:
	_add_passage(
		"SaluteReturn", Vector2(4235, FLOOR_Y - 42), "salute_exit",
		Vector2(5480, 445), "Sagrato della Salute"
	)


func _add_passage(node_name: String, at: Vector2, action: String, target: Vector2, prompt: String) -> void:
	var area := Area2D.new()
	area.name = node_name
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group("dogana_interactable")
	area.add_to_group("dogana_salute_passage")
	area.set_meta("action", action)
	area.set_meta("target_position", target)
	area.set_meta("prompt", prompt)
	area.set_meta("enabled_region", "interior")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 120)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
