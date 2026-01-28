extends RigidBody2D

# Barca "still" presente nella scena: galleggia + permette entra/esci (E)
# Quando entri: nasconde Player e Barca, spawna la scena ship_movig.tscn controllabile.

@export_category("Buoyancy")
@export var float_offset: float = 8.0
@export var buoyancy_strength: float = 35.0
@export var max_up_force: float = 2500.0
@export var water_drag: float = 0.96
@export var surface_margin: float = 30.0

@export_category("Interaction")
@export var interaction_action: StringName = &"interact" # tasto E
@export var player_exit_offset: Vector2 = Vector2(0, -60)
@export var ship_moving_scene: PackedScene

var _cached_water: Node = null
var _nearby_player: Node2D = null
var _is_active: bool = true

func _ready():
	add_to_group("ship")
	lock_rotation = true
	gravity_scale = 1.0
	# La barca deve stare dietro l'acqua
	var spr := get_node_or_null("Barca") as Sprite2D
	if spr != null:
		spr.z_index = 0
	if ship_moving_scene == null:
		ship_moving_scene = load("res://ship_movig.tscn") as PackedScene
	_setup_detection_area()

func _physics_process(_delta: float):
	lock_rotation = true
	rotation = 0.0
	if _is_active:
		_apply_buoyancy()

func _unhandled_input(event):
	if not _is_active:
		return
	if _nearby_player == null:
		return
	if event.is_action_pressed(interaction_action):
		_enter_ship(_nearby_player)

func _apply_buoyancy():
	var water = _get_water()
	if water == null:
		return
	var surface_y_v = _get_water_surface_y(water)
	if surface_y_v == null:
		return
	var surface_y := float(surface_y_v)
	var target_y = surface_y - float_offset
	var dy = global_position.y - target_y
	if dy < -surface_margin:
		return
	var force = clamp(dy * buoyancy_strength, -max_up_force, max_up_force)
	apply_central_force(Vector2(0, -force))
	linear_velocity *= water_drag

func _enter_ship(player: Node2D):
	if ship_moving_scene == null:
		return
	var moving_root = ship_moving_scene.instantiate()
	if moving_root == null:
		return

	# La scena ship_movig.tscn ha root Node2D e dentro un RigidBody2D (ship controllabile)
	var moving_body: RigidBody2D = moving_root.get_node_or_null("RigidBody2D")
	if moving_body == null:
		# fallback: se root è già un RigidBody2D
		if moving_root is RigidBody2D:
			moving_body = moving_root
	
	get_tree().current_scene.add_child(moving_root)
	if moving_body != null:
		moving_body.global_position = global_position
		if moving_body.has_method("setup"):
			moving_body.call("setup", player, self)
	else:
		moving_root.global_position = global_position

	# Disattiva player
	player.visible = false
	player.set_process_input(false)
	player.set_physics_process(false)
	if player is CharacterBody2D:
		player.velocity = Vector2.ZERO

	# Disattiva questa barca
	_is_active = false
	visible = false
	sleeping = true

func exit_from_moving(player: Node2D, at_pos: Vector2):
	# Chiamato dalla ship_moving_controller quando si esce
	global_position = at_pos
	visible = true
	sleeping = false
	_is_active = true

	if player != null:
		# Spawn sopra la barca
		player.global_position = global_position + player_exit_offset
		player.visible = true
		player.set_process_input(true)
		player.set_physics_process(true)

func _setup_detection_area():
	var area = get_node_or_null("PlayerDetectionArea") as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "PlayerDetectionArea"
		area.monitoring = true
		area.monitorable = true
		add_child(area)
		
		var cs = CollisionShape2D.new()
		var r = RectangleShape2D.new()
		r.size = Vector2(80, 50)
		cs.shape = r
		cs.position = Vector2(0, -10)
		area.add_child(cs)

	if not area.body_entered.is_connected(_on_area_body_entered):
		area.body_entered.connect(_on_area_body_entered)
	if not area.body_exited.is_connected(_on_area_body_exited):
		area.body_exited.connect(_on_area_body_exited)

func _on_area_body_entered(body: Node2D):
	if body != null and body.is_in_group("player"):
		_nearby_player = body

func _on_area_body_exited(body: Node2D):
	if body == _nearby_player:
		_nearby_player = null

func _get_water() -> Node:
	if _cached_water != null and is_instance_valid(_cached_water):
		return _cached_water
	var waters = get_tree().get_nodes_in_group("water")
	if waters.size() > 0:
		_cached_water = waters[0]
		return _cached_water
	var scene = get_tree().current_scene
	if scene == null:
		return null
	var found = _find_water_recursive(scene)
	_cached_water = found
	return found

func _find_water_recursive(n: Node) -> Node:
	if n is Area2D and "water" in n.name.to_lower():
		return n
	for c in n.get_children():
		var r = _find_water_recursive(c)
		if r != null:
			return r
	return null

func _get_water_surface_y(water: Node) -> Variant:
	if not ("target_height" in water):
		return null
	var surface_y = water.global_position.y + float(water.target_height)
	if "springs" in water and water.springs is Array and water.springs.size() > 0:
		var closest = water.springs[0]
		var best = abs(closest.global_position.x - global_position.x)
		for s in water.springs:
			if s == null or not is_instance_valid(s):
				continue
			var d = abs(s.global_position.x - global_position.x)
			if d < best:
				best = d
				closest = s
		if closest != null and is_instance_valid(closest):
			surface_y = closest.global_position.y
	return surface_y

