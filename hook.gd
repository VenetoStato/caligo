extends RigidBody2D

@export_category("Hook Type")
@export var hook_type: String = "fishing" # "fishing" o "grab"

@export_category("Fishing Params")
@export var fishing_mass: float = 1.0
@export var fishing_gravity_scale: float = 1.0
@export var fishing_color: Color = Color(1.0, 0.35, 0.35) # rosso

@export_category("Grab Params")
@export var grab_mass: float = 4.0
@export var grab_gravity_scale: float = 1.0
@export var grab_color: Color = Color(0.35, 0.55, 1.0)    # blu

@export_category("Grab Anchor Behavior")
@export var anchor_freeze: bool = true
@export var anchor_disable_gravity: bool = true

var _visual: CanvasItem = null

func _ready():
	_visual = _find_visual()
	apply_type_settings()

func set_hook_type(t: String) -> void:
	hook_type = t
	apply_type_settings()

func apply_type_settings() -> void:
	# reset stato base
	freeze = false
	sleeping = false

	if hook_type == "grab":
		mass = grab_mass
		gravity_scale = grab_gravity_scale
		if _visual != null:
			_visual.modulate = grab_color
	else:
		mass = fishing_mass
		gravity_scale = fishing_gravity_scale
		if _visual != null:
			_visual.modulate = fishing_color

func anchorize() -> void:
	# usato solo per il GRAB: resta dov'è e non si muove più
	if hook_type != "grab":
		return

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	if anchor_disable_gravity:
		gravity_scale = 0.0

	if anchor_freeze:
		freeze = true
		sleeping = true

func _find_visual() -> CanvasItem:
	# prende Sprite2D se c'è
	var s := get_node_or_null("Sprite2D") as CanvasItem
	if s != null:
		return s

	# fallback: primo CanvasItem figlio
	for c in get_children():
		if c is CanvasItem:
			return c as CanvasItem

	return null

# Restituisce la posizione globale del punto di attacco della lenza (centro visivo)
func get_line_attach_point() -> Vector2:
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		# Il centro dello sprite è la sua posizione globale (considerando anche lo scale)
		# Se lo sprite ha uno scale, il centro visivo è ancora la sua posizione globale
		return sprite.global_position
	
	# Fallback: usa la posizione globale del nodo
	return global_position
