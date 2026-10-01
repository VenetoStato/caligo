extends Node2D

## Pogo su spine/oggetti + caduta più secca di un salto.

const PLAYER_SCENE := preload("res://Player/Scene/Player.tscn")
const THORN_SCENE := preload("res://Levels/Scenes/Dogana/pogo_thorn.tscn")


func _ready() -> void:
	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(640, 40)
	var floor_col := CollisionShape2D.new()
	floor_col.shape = floor_shape
	floor.add_child(floor_col)
	floor.position = Vector2(0, 80)
	add_child(floor)

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(-80, 40)
	add_child(player)
	await get_tree().physics_frame

	var start_y := player.global_position.y
	player.velocity = Vector2(0, 40)
	var before := player.velocity.y
	player.call("_apply_gravity", 0.1)
	if player.velocity.y - before < 100.0:
		push_error("Fall gravity is still too soft.")
		get_tree().quit(1)
		return

	var thorn := THORN_SCENE.instantiate() as Node2D
	thorn.position = Vector2(40, 60)
	add_child(thorn)
	await get_tree().physics_frame
	await get_tree().physics_frame

	player.global_position = Vector2(40, 10)
	player.velocity = Vector2(0, 180)
	player.set("_attack_dir", Vector2.DOWN)
	player.call("_apply_pogo")
	if player.velocity.y > -300.0:
		push_error("Pogo did not launch the player upward.")
		get_tree().quit(1)
		return
	if not bool(player.call("is_pogo_grace")):
		push_error("Pogo grace window missing.")
		get_tree().quit(1)
		return

	player.global_position = Vector2(40, -20)
	player.velocity = Vector2(0, 120)
	for _i in 4:
		player.move_and_slide()
		await get_tree().physics_frame
	Input.action_press("aim_down")
	Input.action_press("ui_down")
	player.call("_enable_attack_hitbox", 1)
	await get_tree().physics_frame
	player.call("_resolve_attack_overlaps")
	var attack_dir: Vector2 = player.get("_attack_dir")
	Input.action_release("aim_down")
	Input.action_release("ui_down")
	if attack_dir.y <= 0.5:
		push_error("Down slash never aimed down (on_floor=%s dir=%s)." % [player.is_on_floor(), attack_dir])
		get_tree().quit(1)
		return
	if player.velocity.y > -200.0:
		push_error("Down slash did not bounce on the thorn object.")
		get_tree().quit(1)
		return

	print("CALIGO_POGO_BOUNCE_OK: fall snap %.1f, pogo vy %.1f, rise from %.1f" % [
		player.get("fall_gravity"),
		player.velocity.y,
		start_y,
	])
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0)
