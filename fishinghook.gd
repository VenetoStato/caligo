extends RigidBody2D

# ===========================================
# FISHING HOOK - RigidBody2D collegato alla lenza
# ===========================================

@export_category("Line Attachment")
@export var line_attach_offset: Vector2 = Vector2(0, -5)

@export_category("Water Physics")
@export var water_gravity_scale: float = 0.1
@export var water_drag: float = 3.0

@export_category("Fish Detection")
@export var fish_detection_radius: float = 30.0

# Riferimenti
var player_ref: Node = null
var hooked_fish: Node2D = null

# Stato
var in_water: bool = false
var is_anchored: bool = false
var original_gravity_scale: float = 1.0
var hook_visible: bool = true

func _ready():
	original_gravity_scale = gravity_scale
	
	contact_monitor = true
	max_contacts_reported = 4
	
	_create_water_detection()
	_create_fish_detection()

func _create_water_detection():
	var water_area = Area2D.new()
	water_area.name = "WaterDetection"
	add_child(water_area)
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	collision.shape = circle
	water_area.add_child(collision)
	
	water_area.collision_layer = 0
	water_area.collision_mask = 2
	
	water_area.area_entered.connect(_on_water_entered)
	water_area.area_exited.connect(_on_water_exited)

func _create_fish_detection():
	var fish_area = Area2D.new()
	fish_area.name = "FishDetection"
	add_child(fish_area)
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = fish_detection_radius
	collision.shape = circle
	fish_area.add_child(collision)
	
	fish_area.collision_layer = 0
	fish_area.collision_mask = 4
	
	fish_area.body_entered.connect(_on_fish_body_entered)
	fish_area.area_entered.connect(_on_fish_area_entered)

func _physics_process(_delta: float):
	if in_water and not is_anchored:
		linear_velocity *= 0.98

# ===========================================
# WATER DETECTION
# ===========================================
func _on_water_entered(area: Area2D):
	var area_name = area.name.to_lower()
	var parent_name = area.get_parent().name.to_lower() if area.get_parent() else ""
	
	if "water" in area_name or "water" in parent_name or area.is_in_group("water"):
		_enter_water()

func _on_water_exited(area: Area2D):
	var area_name = area.name.to_lower()
	var parent_name = area.get_parent().name.to_lower() if area.get_parent() else ""
	
	if "water" in area_name or "water" in parent_name or area.is_in_group("water"):
		_exit_water()

func _enter_water():
	if not in_water:
		in_water = true
		gravity_scale = original_gravity_scale * water_gravity_scale
		linear_damp = water_drag

func _exit_water():
	if in_water:
		in_water = false
		gravity_scale = original_gravity_scale
		linear_damp = 0.0

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
	
	var is_fish = false
	
	if node.has_method("is_hooked"):
		is_fish = true
	elif node.has_method("set_player_reference"):
		is_fish = true
	elif "fish" in node.name.to_lower():
		is_fish = true
	
	if is_fish:
		_hook_fish(node as Node2D)

func _hook_fish(fish: Node2D):
	if fish == null:
		return
	
	if fish.has_method("is_hooked") and fish.call("is_hooked"):
		return
	
	hooked_fish = fish
	print("FishingHook: Fish hooked!")
	
	if player_ref != null:
		if player_ref.has_method("on_fish_hooked"):
			player_ref.call("on_fish_hooked", fish)
		elif player_ref.has_method("on_fish_spawned"):
			player_ref.call("on_fish_spawned", fish)

# ===========================================
# API PER IL PLAYER
# ===========================================
func get_line_attach_point() -> Vector2:
	return global_position + line_attach_offset

func is_in_water() -> bool:
	return in_water

func set_player_reference(player: Node):
	player_ref = player

func get_player_reference() -> Node:
	return player_ref

func anchorize():
	is_anchored = !is_anchored
	freeze = is_anchored

func hide_for_fish():
	hook_visible = false
	for child in get_children():
		if child is Sprite2D:
			child.visible = false

func show_hook():
	hook_visible = true
	for child in get_children():
		if child is Sprite2D:
			child.visible = true
