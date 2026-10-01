extends Node2D

@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")


func _ready() -> void:
	if art_profile == null:
		return
	_apply_texture("ModularArchitecture/TorreFortuna", art_profile.torre_fortuna)
	_apply_texture("ModularArchitecture/DoganaOvest", art_profile.dogana_ovest)
	_apply_texture("ModularArchitecture/DoganaEst", art_profile.dogana_est)
	_apply_texture("ModularArchitecture/Seminario", art_profile.seminario)
	_apply_texture("ModularArchitecture/CollegamentoSalute", art_profile.collegamento_salute)
	_apply_texture("ModularArchitecture/SantaMariaDellaSalute", art_profile.salute)
	var interior := get_tree().get_first_node_in_group("dogana_salute_interior_art") as Sprite2D
	if interior and art_profile.salute_interior:
		interior.texture = art_profile.salute_interior
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
			continue
		var kit := _kit_for_slot(key)
		if kit and enemy.has_method("apply_art_kit"):
			enemy.call("apply_art_kit", kit)
			continue
		var tex := _texture_for_slot(key)
		if tex == null:
			continue
		if enemy.has_method("apply_variant_art"):
			enemy.call("apply_variant_art", tex)
	var boss := get_tree().get_first_node_in_group("dogana_boss")
	if boss == null:
		return
	if art_profile.drowned_warden_kit and boss.has_method("apply_art_kit"):
		boss.call("apply_art_kit", art_profile.drowned_warden_kit)
	elif art_profile.drowned_warden:
		if boss.has_method("apply_variant_art"):
			boss.call("apply_variant_art", art_profile.drowned_warden)
		elif "variant_texture" in boss:
			boss.set("variant_texture", art_profile.drowned_warden)
		var boss_sprite := boss.get_node_or_null("Sprite2D") as Sprite2D
		if boss_sprite:
			boss_sprite.texture = art_profile.drowned_warden


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


func _kit_for_slot(slot: String) -> EnemyArtKit:
	match slot:
		"tide_bloater":
			return art_profile.tide_bloater_kit
		"lagoon_oracle":
			return art_profile.lagoon_oracle_kit
		"drowned_warden":
			return art_profile.drowned_warden_kit
		_:
			return null
