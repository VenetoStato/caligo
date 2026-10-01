extends Area2D

@export var entry_title := "REGISTRO DELLA DOGANA"
@export_multiline var entry_text := "Le pagine sono gonfie di acqua salata."
@export var enabled_region := "surface"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("dogana_interactable")
	add_to_group("dogana_lore_readable")
	add_to_group("dogana_grounded_prop")
	set_meta("action", "read")
	set_meta("prompt", entry_title)
	set_meta("entry_title", entry_title)
	set_meta("message", entry_text)
	set_meta("enabled_region", enabled_region)
	_snap_visual_to_floor_anchor()


func _snap_visual_to_floor_anchor() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite == null or sprite.texture == null:
		return
	var image := sprite.texture.get_image()
	if image == null:
		return
	var used := image.get_used_rect()
	var bottom_from_center := float(used.end.y) - float(image.get_height()) * 0.5
	sprite.position.y = -bottom_from_center * absf(sprite.scale.y)
	set_meta("visual_bottom_local", 0.0)
