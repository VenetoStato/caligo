extends RigidBody2D

# Barca "still" presente nella scena: galleggia + permette entra/esci (E)
# Quando entri: nasconde Player e Barca, spawna la scena ship_movig.tscn controllabile.

@export_category("Buoyancy")
@export var float_offset: float = 38.0
@export var buoyancy_strength: float = 35.0
@export var max_up_force: float = 2500.0
@export var water_drag: float = 0.96
@export var surface_margin: float = 30.0

@export_category("Interaction")
@export var interaction_action: StringName = &"interact" # tasto E
@export var player_exit_offset: Vector2 = Vector2(0, -60)
@export var ship_moving_scene: PackedScene
@export var clamp_to_water_bounds: bool = true  # barca resta sull'orlo dell'acqua (entro X)
@export var water_bounds_margin: float = 40.0

var _cached_water: Node = null
var _nearby_player: Node2D = null
var _is_active: bool = true
var _pending_exit_player: Node2D = null
var _pending_exit_pos: Vector2 = Vector2.ZERO

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

	# Barca sull'orlo dell'acqua: resta entro i limiti X dell'acqua
	if clamp_to_water_bounds and water.has_method("get_water_bounds_global_x"):
		var bounds: Vector2 = water.call("get_water_bounds_global_x")
		var min_x: float = bounds.x + water_bounds_margin
		var max_x: float = bounds.y - water_bounds_margin
		if max_x > min_x:
			var px = global_position.x
			if px < min_x:
				global_position.x = min_x
				linear_velocity.x = 0.0
			elif px > max_x:
				global_position.x = max_x
				linear_velocity.x = 0.0

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
		# Riparenta Camera2D, PostFX, PointLight, Overlay dal player alla barca così la camera segue la barca
		for c in player.get_children():
			var name_lower = c.name.to_lower()
			if name_lower == "camera2d" or name_lower == "postfx" or "pointlight" in name_lower or name_lower == "overlay":
				player.remove_child(c)
				moving_body.add_child(c)
				# La camera deve seguire la barca, non il player nascosto
				if name_lower == "camera2d" and c.has_method("set_camera_target"):
					c.call("set_camera_target", moving_body)
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
	# Barca still e player rispawanno esattamente dove era la moving ship (stesso punto)
	# Usiamo call_deferred così le posizioni si applicano dopo che la moving ship è stata rimossa
	_pending_exit_player = player
	_pending_exit_pos = at_pos
	call_deferred("_apply_exit_positions")

func _setup_detection_area():
	var area = get_node_or_null("PlayerDetectionArea") as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "PlayerDetectionArea"
		area.monitoring = true
		area.monitorable = true
		area.collision_mask = 2  # player è su layer 2
		add_child(area)
		
		var cs = CollisionShape2D.new()
		var r = RectangleShape2D.new()
		r.size = Vector2(80, 50)
		cs.shape = r
		cs.position = Vector2(0, -10)
		area.add_child(cs)
	else:
		area.collision_mask |= 2

	if not area.body_entered.is_connected(_on_area_body_entered):
		area.body_entered.connect(_on_area_body_entered)
	if not area.body_exited.is_connected(_on_area_body_exited):
		area.body_exited.connect(_on_area_body_exited)

func _apply_exit_positions():
	# Eseguito in deferred: barca e player nella posizione esatta della moving ship
	var at_pos := _pending_exit_pos
	var player := _pending_exit_player
	_pending_exit_player = null
	_pending_exit_pos = Vector2.ZERO

	global_position = at_pos
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	visible = true
	sleeping = false
	_is_active = true

	if player != null and is_instance_valid(player):
		# Camera2D/PostFX vengono ripristinati da ship_moving_controller prima del queue_free
		# Ripristina il target della camera sul player
		var cam = player.get_node_or_null("Camera2D")
		if cam != null and cam.has_method("set_camera_target"):
			cam.call("set_camera_target", player)
		# Player nello stesso punto della barca (leggermente sopra per non sovrapporsi)
		player.global_position = at_pos + player_exit_offset
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.visible = true
		player.set_process_input(true)
		player.set_physics_process(true)

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

