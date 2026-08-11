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
	call_deferred("_apply_character_art")


func _apply_texture(node_path: NodePath, texture: Texture2D) -> void:
	if texture == null:
		return
	var sprite := get_node_or_null(node_path) as Sprite2D
	if sprite:
		sprite.texture = texture


func _apply_character_art() -> void:
	# Applica i ritratti del profilo ai nemici già in scena (per nome / meta).
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null:
			continue
		var key := str(enemy.get_meta("art_slot", "")).strip_edges()
		if key.is_empty():
			key = _guess_art_slot(str(enemy.name))
		var tex := _texture_for_slot(key)
		if tex == null:
			continue
		if "variant_texture" in enemy:
			enemy.set("variant_texture", tex)
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.texture = tex
	var boss := get_tree().get_first_node_in_group("dogana_boss")
	if boss and art_profile.drowned_warden:
		if "variant_texture" in boss:
			boss.set("variant_texture", art_profile.drowned_warden)
		var boss_sprite := boss.get_node_or_null("Sprite2D") as Sprite2D
		if boss_sprite:
			boss_sprite.texture = art_profile.drowned_warden


func _guess_art_slot(node_name: String) -> String:
	var lower := node_name.to_lower()
	if "oracle" in lower or "lagoon" in lower:
		return "lagoon_oracle"
	if "warden" in lower or "boss" in lower or "custode" in lower:
		return "drowned_warden"
	if "bloater" in lower or "gamber" in lower or "tide" in lower:
		return "tide_bloater"
	return ""


func _texture_for_slot(slot: String) -> Texture2D:
	match slot:
		"tide_bloater":
			return art_profile.tide_bloater
		"lagoon_oracle":
			return art_profile.lagoon_oracle
		"drowned_warden":
			return art_profile.drowned_warden
		_:
			return null
