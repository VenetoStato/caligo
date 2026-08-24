extends Node
## Mira verso l'alto + lampade a pendolo + vita extra.

const PLAYER_SCENE := preload("res://Player/Scene/Player.tscn")
const LAMP_SCENE := preload("res://Levels/Scenes/Dogana/gothic_hanging_lamp.tscn")
const INTERIOR := preload("res://Levels/Scenes/Dogana/salute_interior.tscn")
const ORB_SCRIPT := preload("res://Levels/Scenes/Dogana/extra_life_orb.gd")


func _ready() -> void:
	var interior := INTERIOR.instantiate() as Node2D
	add_child(interior)
	await get_tree().process_frame
	await get_tree().physics_frame
	var lamps := get_tree().get_nodes_in_group("dogana_hanging_lamp")
	var grapples := get_tree().get_nodes_in_group("dogana_grapple_point")
	if lamps.size() < 5 or grapples.size() < 5:
		push_error("Ceiling lamps missing (lamps=%d grapples=%d)." % [lamps.size(), grapples.size()])
		get_tree().quit(1)
		return

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(80, 80)
	player.facing_right = true
	add_child(player)
	await get_tree().process_frame
	player.set("cast_aim_max_up", 88.0)
	# Simula il mouse in alto: get_global_mouse_position non e' affidabile in headless.
	var angle: float = player.call("_aim_angle_from_vector", Vector2(8.0, -220.0))
	if angle < deg_to_rad(70.0):
		push_error("Upward aim is too shallow: %.1f deg" % rad_to_deg(angle))
		get_tree().quit(1)
		return
	player.set("_cast_aim_angle", angle)
	var dir: Vector2 = player.call("_direction_from_aim_angle")
	if dir.y > -0.85:
		push_error("Cast direction is not upward enough: %s" % dir)
		get_tree().quit(1)
		return

	var before := int(player.get("max_health"))
	var orb := Area2D.new()
	orb.set_script(ORB_SCRIPT)
	add_child(orb)
	orb.global_position = player.global_position
	orb.set("_home", orb.global_position)
	orb.call("_on_body_entered", player)
	await get_tree().process_frame
	if int(player.get("max_health")) != before + 1:
		push_error("Extra life orb did not add a heart.")
		get_tree().quit(1)
		return

	print("CALIGO_BOSS_LAMP_AIM_OK: lamps=%d aim=%.1fdeg dir=%s life=%d" % [
		lamps.size(),
		rad_to_deg(angle),
		dir,
		int(player.get("max_health")),
	])
	get_tree().quit(0)
