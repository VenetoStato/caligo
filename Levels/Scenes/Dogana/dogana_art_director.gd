extends Node2D

@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")


func _ready() -> void:
	if art_profile == null:
		return
	_apply_texture("IllustratedPanorama/Arrival", art_profile.arrival_background)
	_apply_texture("IllustratedPanorama/Customs", art_profile.customs_background)
	_apply_texture("IllustratedPanorama/GrandCanal", art_profile.canal_background)
	_apply_texture("IllustratedPanorama/Fortuna", art_profile.fortuna_background)
	_apply_texture("SecretArchiveArtwork", art_profile.archive_background)
	_apply_texture("SecretOssuaryArtwork", art_profile.archive_background)


func _apply_texture(node_path: NodePath, texture: Texture2D) -> void:
	if texture == null:
		return
	var sprite := get_node_or_null(node_path) as Sprite2D
	if sprite:
		sprite.texture = texture
