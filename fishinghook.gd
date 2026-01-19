extends RigidBody2D

# ===========================================
# FISHING HOOK SCRIPT - Per pescare
# ===========================================

@export_category("Size")
@export var hook_visual_scale: float = 0.07
@export var hook_collision_scale: float = 0.07
@export var auto_scale_body_collision: bool = true

@export_category("Line Attachment Point")
@export var line_attach_offset: Vector2 = Vector2(0, 0)
@export var use_point_light_as_attach: bool = true

@export_category("Sprite Setup")
@export var sprite_node_name: String = ""
@export var sprite_offset: Vector2 = Vector2(0, 0)

@export_category("Water Physics")
@export var water_drag: float = 4.0
@export var water_vertical_brake: float = 900.0
@export var sink_slowly_in_water: bool = false
@export var sink_speed: float = 20.0

@export_category("Fish Detection")
@export var fish_detection_radius: float = 25.0
@export var fish_group_name: String = "fish"

@export_category("Behavior")
@export var rotate_with_velocity: bool = true
@export var lock_body_rotation: bool = true

# Riferimenti
var player_ref: Node = null
var sprite: Node2D = null
var hooked_fish: Node2D = null
var point_light: PointLight2D = null

# Stato
var in_water: bool = false
var hook_type: String = "fishing"
var is_anchored: bool = false
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var is_visible: bool = true

var fish_detection_area: Area2D = null

func _ready():
	original_gravity_scale = gravity_scale
	original_linear_damp = linear_damp

	if lock_body_rotation:
		lock_rotation = true

	_find_sprite()
	_apply_visual_size()

	if sprite != null:
		sprite.position = sprite_offset
		sprite.visible = true

	if auto_scale_body_collision:
		_apply_body_collision_scale()

	_find_point_light()
	_setup_fish_detection()

	contact_monitor = true
	max_contacts_reported = 4

func _find_sprite():
	if sprite_node_name != "":
		sprite = get_node_or_null(sprite_node_name)

	if sprite == null:
		for child in get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				sprite = child
				break

	if sprite != null:
		sprite.visible = true

func _apply_visual_size():
	if sprite == null:
		return
	var s = max(0.01, hook_visual_scale)
	sprite.scale = Vector2.ONE * s

func _apply_body_collision_scale():
	var s = max(0.01, hook_collision_scale)

	for child in get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape == null:
				continue

			if cs.shape is CircleShape2D:
				var c := cs.shape as CircleShape2D
				c.radius *= s
			elif cs.shape is RectangleShape2D:
				var r := cs.shape as RectangleShape2D
				r.size *= s
			else:
				cs.scale = Vector2.ONE * s

func _find_point_light():
	point_light = null
	if not use_point_light_as_attach:
		return

	var lights = find_children("*", "PointLight2D", true, false)
	if lights.size() > 0:
		point_light = lights[0] as PointLight2D

	if point_light != null:
		center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = point_light.position

func _setup_fish_detection():
	fish_detection_area = Area2D.new()
	fish_detection_area.name = "FishDetection"
	add_child(fish_detection_area)

	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = fish_detection_radius
	collision.shape = circle
	fish_detection_area.add_child(collision)

	fish_detection_area.body_entered.connect(_on_fish_body_entered)
	fish_detection_area.area_entered.connect(_on_fish_area_entered)

	# Water detection
	fish_detection_area.area_entered.connect(_on_area_entered)
	fish_detection_area.area_exited.connect(_on_area_exited)

func _physics_process(delta: float):
	if in_water and not is_anchored:
		# In acqua: gravità 0, quindi smorza la velocità verticale verso target
		var target_vy = sink_speed if sink_slowly_in_water else 0.0
		linear_velocity.y = move_toward(linear_velocity.y, target_vy, water_vertical_brake * delta)

	_update_sprite_rotation()

func _update_sprite_rotation():
	if sprite == null:
		return
	if is_anchored:
		return
	if rotate_with_velocity and linear_velocity.length() > 10.0:
		var angle = linear_velocity.angle()
		sprite.rotation = angle + PI / 2.0

# ===========================================
# PUNTO DI ATTACCO LENZA
# ===========================================
func get_line_attach_point() -> Vector2:
	if point_light != null:
		return point_light.global_position
	# più stabile di offset.rotated(rotation)
	return global_transform * line_attach_offset

func set_line_attach_offset(offset: Vector2):
	line_attach_offset = offset
	if point_light != null:
		center_of_mass = point_light.position

func orient_to_line(line_origin: Vector2):
	if sprite == null:
		return
	var attach_point = get_line_attach_point()
	var direction = (line_origin - attach_point).normalized()
	sprite.rotation = direction.angle() + PI / 2.0

# ===========================================
# API PER IL PLAYER
# ===========================================
func set_hook_type(type: String):
	hook_type = type

func get_hook_type() -> String:
	return hook_type

func set_player_reference(player: Node):
	player_ref = player

func get_player_reference() -> Node:
	return player_ref

func anchorize():
	is_anchored = !is_anchored
	freeze = is_anchored

func hide_for_fish():
	is_visible = false
	if sprite != null:
		sprite.visible = false

func show_hook():
	is_visible = true
	if sprite != null:
		sprite.visible = true

# ===========================================
# FISH DETECTION
# ===========================================
func _on_fish_body_entered(body: Node2D):
	_check_if_fish(body)

func _on_fish_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent != null:
		_check_if_fish(parent)

func _check_if_fish(node: Node):
	if hooked_fish != null:
		return
	if node == null or node == self:
		return
	if player_ref != null and node == player_ref:
		return

	var is_fish := false
	if node.is_in_group(fish_group_name):
		is_fish = true
	elif node.has_method("is_fish") and bool(node.call("is_fish")):
		is_fish = true
	elif node.has_method("start_struggle") and node.has_method("apply_reel_force"):
		is_fish = true
	elif "fish" in node.name.to_lower():
		is_fish = true

	if is_fish:
		_hook_fish(node as Node2D)

func _hook_fish(fish: Node2D):
	if fish == null:
		return

	hooked_fish = fish

	if player_ref != null:
		if player_ref.has_method("on_fish_hooked"):
			player_ref.call("on_fish_hooked", fish)
		elif player_ref.has_method("on_fish_spawned"):
			player_ref.call("on_fish_spawned", fish)

# ===========================================
# WATER DETECTION
# ===========================================
func _enter_water():
	if in_water:
		return
	in_water = true

	# Richiesta: in acqua = NO gravità
	gravity_scale = 0.0
	linear_damp = water_drag

func _exit_water():
	if not in_water:
		return
	in_water = false

	# Fuori acqua = gravità normale
	gravity_scale = original_gravity_scale
	linear_damp = original_linear_damp

func is_in_water() -> bool:
	return in_water

func _on_area_entered(area: Area2D):
	var area_name = area.name.to_lower()
	var parent_name = area.get_parent().name.to_lower() if area.get_parent() else ""
	if "water" in area_name or "water" in parent_name or area.is_in_group("water"):
		_enter_water()

func _on_area_exited(area: Area2D):
	var area_name = area.name.to_lower()
	var parent_name = area.get_parent().name.to_lower() if area.get_parent() else ""
	if "water" in area_name or "water" in parent_name or area.is_in_group("water"):
		_exit_water()
