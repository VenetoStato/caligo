extends Node2D


const WATER_SURFACE_Y := 565.0
const QUAY_TOP_Y := 485.0

@export var build_continuous_collision := true


func _ready() -> void:
	# Il fronte della Punta resta una singola banchina orizzontale: i vecchi
	# rami sospesi sono stati rimossi dalla scena, non nascosti a runtime.
	if build_continuous_collision:
		_build_continuous_quay()
	_build_waterline_contact()
	_build_grounded_salute_entrance()
	_move_boss_arena_inside()
	call_deferred("_settle_surface_encounters")
	set_process(false)
	set_physics_process(false)


func _build_continuous_quay() -> void:
	var body := StaticBody2D.new()
	body.name = "ContinuousWaterfront"
	body.collision_layer = 1
	body.collision_mask = 2
	body.add_to_group("dogana_platform")
	body.add_to_group("dogana_simplified_waterfront")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(3680, 110)
	var collision := CollisionShape2D.new()
	collision.position = Vector2(3900, 540)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


## Il pontile sembrava sospeso perche' la pietra e il pelo dell'acqua non si
## toccavano mai: qui si aggiungono alga bagnata sopra la linea e ombra di
## contatto sotto, cosi' si legge dove finisce la banchina e inizia il bacino.
func _build_waterline_contact() -> void:
	var left := -900.0
	var right := 6400.0

	var wet := Sprite2D.new()
	wet.name = "WetStoneBand"
	wet.z_index = 5
	wet.centered = false
	wet.texture = _vertical_fade(
		Color(0.03, 0.09, 0.10, 0.0), Color(0.02, 0.06, 0.07, 0.78)
	)
	wet.position = Vector2(left, WATER_SURFACE_Y - 62.0)
	wet.scale = Vector2((right - left) / 8.0, 62.0 / 64.0)
	add_child(wet)

	var algae := Sprite2D.new()
	algae.name = "WaterlineAlgae"
	algae.z_index = 6
	algae.centered = false
	algae.texture = _vertical_fade(
		Color(0.10, 0.20, 0.13, 0.0), Color(0.13, 0.24, 0.15, 0.55)
	)
	algae.position = Vector2(left, WATER_SURFACE_Y - 20.0)
	algae.scale = Vector2((right - left) / 8.0, 21.0 / 64.0)
	add_child(algae)

	# Sotto la linea, ma sopra il poligono d'acqua: l'ombra proiettata dalla
	# banchina sul bacino, che e' cio' che dice all'occhio "qui poggia".
	var shadow := Sprite2D.new()
	shadow.name = "WaterlineContactShadow"
	shadow.z_index = 11
	shadow.centered = false
	shadow.texture = _vertical_fade(
		Color(0.0, 0.02, 0.03, 0.62), Color(0.0, 0.02, 0.03, 0.0)
	)
	shadow.position = Vector2(left, WATER_SURFACE_Y)
	shadow.scale = Vector2((right - left) / 8.0, 46.0 / 64.0)
	add_child(shadow)


func _vertical_fade(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 64
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


func _build_grounded_salute_entrance() -> void:
	var area := Area2D.new()
	area.name = "SaluteEntrance"
	area.position = Vector2(5480, 445)
	area.collision_layer = 0
	area.collision_mask = 2
	area.add_to_group("dogana_interactable")
	area.add_to_group("dogana_salute_passage")
	area.set_meta("action", "salute_enter")
	area.set_meta("target_position", Vector2(4300, -545))
	area.set_meta("prompt", "Basilica della Salute")
	area.set_meta("enabled_region", "surface")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(110, 120)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)


func _move_boss_arena_inside() -> void:
	var arena := get_node_or_null("../Geometry/BossArena")
	if arena == null:
		return
	var floor := arena.get_node_or_null("Floor") as StaticBody2D
	if floor:
		floor.position = Vector2(5180, -445)
	# I sigilli vivono nella scena, in navata: riposizionarli qui creava due
	# fonti di verita' che si contraddicevano a ogni modifica.
	arena.add_to_group("dogana_salute_interior_arena")


func _settle_surface_encounters() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is CharacterBody2D) or enemy.get_parent() == null or enemy.get_parent().name != "Encounters":
			continue
		if enemy.get("hovering") == true:
			continue
		(enemy as CharacterBody2D).global_position.y = 485.0
		enemy.set("_home_position", (enemy as CharacterBody2D).global_position)
