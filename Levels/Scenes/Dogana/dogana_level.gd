extends Node2D

signal grace_activated(site_id: String)

@export var player_path: NodePath = NodePath("Player")
@export var spawn_path: NodePath = NodePath("Gameplay/Spawn")
@export var persistence_enabled := true

const GRACE_SAVE_PATH := "user://dogana_grace_sites.cfg"

var _player: CharacterBody2D
var _active_checkpoint: Vector2
var _message_tween: Tween
var _completed := false
var _nearby_interactable: Area2D
var _nearby_grace: Area2D
var _grace_sites: Dictionary = {}
var _activated_graces: Dictionary = {}
var _current_grace := ""
var _discovered_regions: Dictionary = {"arrival": true}
var _last_region := ""
var _boss_is_defeated := false
var _has_palace_seal := false
var _grab_hook_unlocked := false
var _encounter_update_timer := 0.0
var _managed_encounters: Array[CharacterBody2D] = []
var _managed_waters: Array[Node] = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	var spawn := get_node_or_null(spawn_path) as Marker2D
	if spawn:
		_active_checkpoint = spawn.global_position
	if _player:
		_apply_respawn(_active_checkpoint)
		if _player.has_signal("respawned"):
			_player.connect("respawned", _on_player_respawned)
		if _player.has_signal("locked_skill_requested"):
			_player.connect("locked_skill_requested", _on_locked_skill_requested)
		var camera := _player.get_node_or_null("Camera2D")
		if camera and camera.has_method("set_camera_target"):
			camera.call("set_camera_target", _player, 0)

	for checkpoint in get_tree().get_nodes_in_group("dogana_checkpoint"):
		if checkpoint is Area2D:
			checkpoint.body_entered.connect(_on_checkpoint_entered.bind(checkpoint))
	for finish in get_tree().get_nodes_in_group("dogana_finish"):
		if finish is Area2D:
			finish.body_entered.connect(_on_finish_entered)
	for interactable in get_tree().get_nodes_in_group("dogana_interactable"):
		if interactable is Area2D:
			interactable.body_entered.connect(_on_interactable_entered.bind(interactable))
			interactable.body_exited.connect(_on_interactable_exited.bind(interactable))
	for hidden_area in get_tree().get_nodes_in_group("dogana_hidden_reveal"):
		if hidden_area is Area2D:
			hidden_area.body_entered.connect(_on_hidden_area_entered.bind(hidden_area))
	for wall in get_tree().get_nodes_in_group("dogana_breakable"):
		if wall.has_signal("wall_broken"):
			wall.wall_broken.connect(_on_secret_wall_broken.bind(wall))
	for boss in get_tree().get_nodes_in_group("dogana_boss"):
		if boss.has_signal("boss_awakened"):
			boss.boss_awakened.connect(_on_boss_awakened)
		if boss.has_signal("boss_defeated"):
			boss.boss_defeated.connect(_on_boss_defeated)
	for grace in get_tree().get_nodes_in_group("dogana_grace"):
		if grace is Area2D:
			_grace_sites[str(grace.get("site_id"))] = grace
			grace.body_entered.connect(_on_grace_entered.bind(grace))
			grace.body_exited.connect(_on_grace_exited.bind(grace))
	if persistence_enabled:
		_load_graces()
	_restore_palace_progress()
	_restore_boss_progress()
	_apply_grab_hook_unlock()
	_restore_discovered_artwork()
	_initialize_graces()
	_configure_encounter_culling()
	for water in get_tree().get_nodes_in_group("water"):
		if water.is_ancestor_of(_player) or not water.is_inside_tree():
			continue
		_managed_waters.append(water)
	_update_water_culling()
	var map := get_node_or_null("DoganaMap")
	if map:
		map.fast_travel_requested.connect(_on_fast_travel_requested)
	_sync_map()


func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	_encounter_update_timer -= delta
	if _encounter_update_timer <= 0.0:
		_encounter_update_timer = 0.18
		_update_encounter_culling()
		_update_water_culling()
	var region := _get_player_region(_player.global_position)
	if region != _last_region:
		_last_region = region
		_mark_region_discovered(region)
	var map := get_node_or_null("DoganaMap")
	if map and map.has_method("set_player_world_position"):
		map.call("set_player_world_position", _player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if (
		_nearby_grace
		and is_instance_valid(_nearby_grace)
		and event.is_action_pressed("interact")
	):
		_activate_grace(_nearby_grace)
		get_viewport().set_input_as_handled()
		return
	if (
		_nearby_interactable
		and is_instance_valid(_nearby_interactable)
		and event.is_action_pressed("interact")
	):
		_activate_interactable(_nearby_interactable)
		get_viewport().set_input_as_handled()


func _on_checkpoint_entered(body: Node2D, checkpoint: Area2D) -> void:
	if body != _player or checkpoint.get_meta("activated", false):
		return
	checkpoint.set_meta("activated", true)
	_active_checkpoint = checkpoint.global_position + Vector2(0, -42)
	_apply_respawn(_active_checkpoint)

	var beacon := checkpoint.get_node_or_null("Beacon") as Polygon2D
	if beacon:
		beacon.color = Color(0.86, 0.72, 0.39, 0.9)
	_show_message("CHECKPOINT  •  " + checkpoint.name.to_upper())


func _on_player_respawned() -> void:
	for attack in get_tree().get_nodes_in_group("enemy_transient_attack"):
		if is_instance_valid(attack):
			attack.queue_free()
	for corpse in get_tree().get_nodes_in_group("dead_enemy"):
		if is_instance_valid(corpse):
			corpse.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("reset_to_home"):
			enemy.call("reset_to_home")
	_update_encounter_culling()


func _configure_encounter_culling() -> void:
	var encounters := get_node_or_null("Gameplay/Encounters")
	if encounters == null:
		return
	for child in encounters.get_children():
		if child is CharacterBody2D and child.is_in_group("enemy"):
			var enemy := child as CharacterBody2D
			enemy.set("activation_managed", true)
			_managed_encounters.append(enemy)
	_update_encounter_culling()


func _update_encounter_culling() -> void:
	if _player == null:
		return
	var player_in_palace := _player.global_position.y < -100.0
	for enemy in _managed_encounters:
		if not is_instance_valid(enemy):
			continue
		var dead := int(enemy.get("state")) == 2
		var near_player := enemy.global_position.distance_squared_to(_player.global_position) <= 900.0 * 900.0
		enemy.set_physics_process(not dead and near_player and not player_in_palace)


func _update_water_culling() -> void:
	if _player == null:
		return
	var player_in_palace := _player.global_position.y < -100.0
	for water in _managed_waters:
		if not is_instance_valid(water) or not water.has_method("get_water_bounds_global_rect"):
			continue
		var bounds := water.call("get_water_bounds_global_rect") as Rect2
		var near_horizontal := (
			_player.global_position.x >= bounds.position.x - 720.0
			and _player.global_position.x <= bounds.end.x + 720.0
		)
		water.process_mode = (
			Node.PROCESS_MODE_INHERIT
			if near_horizontal and not player_in_palace
			else Node.PROCESS_MODE_DISABLED
		)

func _on_finish_entered(body: Node2D) -> void:
	if body != _player or _completed or not _boss_is_defeated:
		return
	_completed = true
	_show_message("PUNTA DELLA DOGANA COMPLETATA")
	if AchievementManager and AchievementManager.has_method("unlock"):
		AchievementManager.call("unlock", "dogana_fortuna")


func _on_interactable_entered(body: Node2D, interactable: Area2D) -> void:
	if body != _player:
		return
	_nearby_interactable = interactable
	var prompt := str(interactable.get_meta("prompt", "[E] Interagisci"))
	_show_message(prompt)


func _on_interactable_exited(body: Node2D, interactable: Area2D) -> void:
	if body == _player and _nearby_interactable == interactable:
		_nearby_interactable = null


func _activate_interactable(interactable: Area2D) -> void:
	var action := str(interactable.get_meta("action", "lore"))
	if action == "open_gate":
		_open_canal_gate(interactable)
	elif action in ["palace_enter", "palace_exit", "palace_lift"]:
		_use_palace_passage(interactable)
	elif action == "palace_seal":
		_collect_palace_seal(interactable)
	elif action == "bell":
		var camera := get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("add_shake"):
			camera.call("add_shake", 0.28)
		_show_message("LA CAMPANA DELLA FORTUNA RISPONDE ALLA LAGUNA")
	else:
		_show_message(str(interactable.get_meta("message", "Le pietre conservano una storia dimenticata.")))


func _open_canal_gate(interactable: Area2D) -> void:
	if interactable.get_meta("activated", false):
		_show_message("IL PASSAGGIO DEL CANALE È APERTO")
		return
	if not _has_palace_seal:
		_show_message("LA PARATIA È SIGILLATA  •  TROVA IL SIGILLO NEL PALAZZO DEI TRIBUTI")
		return
	interactable.set_meta("activated", true)
	var gate := get_node_or_null("Gameplay/Geometry/CanalGate") as StaticBody2D
	if gate:
		var collision := gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision:
			collision.set_deferred("disabled", true)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(gate, "position:y", gate.position.y - 820.0, 0.9).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(gate, "modulate:a", 0.42, 0.9)
	_mark_access_open("canal_gate")
	var lever := interactable.get_node_or_null("Lever") as Node2D
	if lever:
		create_tween().tween_property(lever, "rotation", 0.8, 0.22)
	_show_message("IL PASSAGGIO DEL CANALE È APERTO")


func _use_palace_passage(interactable: Area2D) -> void:
	if not _player:
		return
	var target := interactable.get_meta("target_position", Vector2.ZERO) as Vector2
	if target == Vector2.ZERO:
		return
	_player.global_position = target
	_player.velocity = Vector2.ZERO
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	if target.y < -100.0:
		_mark_region_discovered("palace")
		_mark_access_open("palace")
		_show_message("PALAZZO DEI TRIBUTI  •  IL PERCORSO PROSEGUE VERSO L'ALTO")
	else:
		_show_message("RITORNO ALLA DOGANA DA MAR")


func _collect_palace_seal(interactable: Area2D) -> void:
	if _has_palace_seal:
		_show_message("IL SIGILLO DELLE MAREE È GIÀ TUO")
		return
	_has_palace_seal = true
	interactable.set_meta("activated", true)
	interactable.set_meta("prompt", "[E] Il Sigillo delle Maree è stato recuperato")
	var collision := interactable.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)
	var gate_lever := get_node_or_null("Gameplay/Interactions/GateLever") as Area2D
	if gate_lever:
		gate_lever.set_meta("prompt", "[E] Usa il Sigillo e solleva la paratia")
	_mark_region_discovered("palace")
	_save_graces()
	_show_message("SIGILLO DELLE MAREE OTTENUTO  •  LA PARATIA PUÒ ESSERE APERTA")


func _on_boss_awakened() -> void:
	var entrance_seal := get_node_or_null("Gameplay/Geometry/BossArena/EntranceSeal") as StaticBody2D
	if entrance_seal:
		var seal_collision := entrance_seal.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if seal_collision:
			seal_collision.set_deferred("disabled", false)
		var seal_visual := entrance_seal.get_node_or_null("Visual") as CanvasItem
		if seal_visual:
			create_tween().tween_property(seal_visual, "modulate:a", 1.0, 0.28)
	_show_message("IL CUSTODE SOMMERSO RISCOSSA IL SUO TRIBUTO")


func _on_boss_defeated() -> void:
	if _boss_is_defeated:
		return
	_boss_is_defeated = true
	_grab_hook_unlocked = true
	_apply_grab_hook_unlock()
	_save_graces()
	var entrance_seal := get_node_or_null("Gameplay/Geometry/BossArena/EntranceSeal") as StaticBody2D
	if entrance_seal:
		var seal_collision := entrance_seal.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if seal_collision:
			seal_collision.set_deferred("disabled", true)
		var seal_visual := entrance_seal.get_node_or_null("Visual") as CanvasItem
		if seal_visual:
			create_tween().tween_property(seal_visual, "modulate:a", 0.0, 0.45)
	var exit_wall := get_node_or_null("Gameplay/Geometry/BossArena/ExitWall") as StaticBody2D
	if exit_wall:
		var wall_collision := exit_wall.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if wall_collision:
			wall_collision.set_deferred("disabled", true)
		create_tween().tween_property(exit_wall, "modulate:a", 0.0, 0.7)
	var finish := get_node_or_null("Gameplay/FortunaSummit") as Area2D
	if finish:
		var finish_collision := finish.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if finish_collision:
			finish_collision.set_deferred("disabled", false)
		finish.set_deferred("monitoring", true)
	_show_message("CUSTODE SCONFITTO  •  OTTENUTO AMO DEL TRASCINAMENTO [C]")


func _on_hidden_area_entered(body: Node2D, hidden_area: Area2D) -> void:
	if body != _player or hidden_area.get_meta("revealed", false):
		return
	hidden_area.set_meta("revealed", true)
	var veil := hidden_area.get_node_or_null("Veil") as CanvasItem
	if veil:
		create_tween().tween_property(veil, "modulate:a", 0.0, 0.55)
	var secret_id := str(hidden_area.get_meta("secret_id", "archive"))
	_mark_access_open(secret_id)
	for artwork in get_tree().get_nodes_in_group("dogana_secret_artwork"):
		if str(artwork.get_meta("secret_id", "")) == secret_id:
			create_tween().tween_property(artwork, "modulate:a", 0.9, 0.8)
	_mark_region_discovered(secret_id)
	var secret_names := {
		"archive": "ARCHIVIO SOMMERSO",
		"ossuary": "OSSARIO DELLA FORTUNA",
		"palace_vault": "CAVEAU PROIBITO DEI TRIBUTI",
	}
	var secret_name := str(secret_names.get(secret_id, "STANZA DIMENTICATA"))
	_show_message("PASSAGGIO SEGRETO — " + secret_name)


func _on_secret_wall_broken(wall: Node2D) -> void:
	_mark_access_open("ossuary" if wall.global_position.x > 3500.0 else "archive")
	_show_message("UN VARCO NASCOSTO SI È APERTO")


func _mark_access_open(access_id: String) -> void:
	for marker in get_tree().get_nodes_in_group("dogana_access_marker"):
		if str(marker.get("access_id")) == access_id and marker.has_method("mark_open"):
			marker.call("mark_open")


func _on_grace_entered(body: Node2D, grace: Area2D) -> void:
	if body != _player:
		return
	_nearby_grace = grace
	var verb := "Riposa" if bool(grace.get("activated")) else "Risveglia"
	_show_message("[E] %s — %s" % [verb, str(grace.get("display_name"))])


func _on_grace_exited(body: Node2D, grace: Area2D) -> void:
	if body == _player and _nearby_grace == grace:
		_nearby_grace = null


func _activate_grace(grace: Area2D, show_message := true) -> void:
	var site_id := str(grace.get("site_id"))
	_activated_graces[site_id] = true
	_current_grace = site_id
	grace.call("set_activated", true)
	_apply_respawn(grace.call("get_respawn_position"))
	if _player.has_method("heal"):
		_player.call("heal", int(_player.get("max_health")))
	_save_graces()
	_sync_map()
	if show_message:
		grace_activated.emit(site_id)
		_show_message("ALTARE RISVEGLIATO  •  %s" % str(grace.get("display_name")).to_upper())


func _initialize_graces() -> void:
	if _grace_sites.is_empty():
		return
	if _activated_graces.is_empty():
		var first := _grace_sites.get("pontile") as Area2D
		if first:
			_activate_grace(first, false)
	for site_id in _grace_sites:
		var site := _grace_sites[site_id] as Area2D
		site.call("set_activated", bool(_activated_graces.get(site_id, false)))
	if not _grace_sites.has(_current_grace) or not bool(_activated_graces.get(_current_grace, false)):
		_current_grace = "pontile"
	var current := _grace_sites.get(_current_grace) as Area2D
	if current:
		_apply_respawn(current.call("get_respawn_position"))


func _sync_map() -> void:
	var map := get_node_or_null("DoganaMap")
	if not map:
		return
	var sites: Array[Dictionary] = []
	for site_id in ["pontile", "dogana", "fortuna"]:
		var site := _grace_sites.get(site_id) as Area2D
		if site:
			sites.append({
				"id": site_id,
				"name": str(site.get("display_name")),
				"activated": bool(_activated_graces.get(site_id, false)),
			})
	map.call("configure_sites", sites, _current_grace)
	if map.has_method("configure_regions"):
		map.call("configure_regions", _discovered_regions)


func _on_fast_travel_requested(site_id: String) -> void:
	if not bool(_activated_graces.get(site_id, false)):
		return
	var grace := _grace_sites.get(site_id) as Area2D
	if not grace:
		return
	var travel := func() -> void:
		_current_grace = site_id
		_player.global_position = grace.call("get_respawn_position")
		_player.velocity = Vector2.ZERO
		_activate_grace(grace, false)
		_show_message("VIAGGIO  •  %s" % str(grace.get("display_name")).to_upper())
	if autoload_transition and autoload_transition.has_method("transition_with_callback"):
		autoload_transition.call("transition_with_callback", travel)
	else:
		travel.call()


func _load_graces() -> void:
	var config := ConfigFile.new()
	if config.load(GRACE_SAVE_PATH) != OK:
		return
	_current_grace = str(config.get_value("graces", "current", ""))
	for site_id in ["pontile", "dogana", "fortuna"]:
		if bool(config.get_value("graces", site_id, false)):
			_activated_graces[site_id] = true
	for region_id in ["arrival", "customs", "palace", "canal", "fortuna", "archive", "ossuary", "palace_vault"]:
		if bool(config.get_value("map", region_id, region_id == "arrival")):
			_discovered_regions[region_id] = true
	_has_palace_seal = bool(config.get_value("progress", "palace_seal", false))
	_grab_hook_unlocked = bool(config.get_value("progress", "grab_hook_unlocked", false))
	_boss_is_defeated = bool(config.get_value("progress", "boss_defeated", false))


func _save_graces() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("graces", "current", _current_grace)
	for site_id in ["pontile", "dogana", "fortuna"]:
		config.set_value("graces", site_id, bool(_activated_graces.get(site_id, false)))
	for region_id in ["arrival", "customs", "palace", "canal", "fortuna", "archive", "ossuary", "palace_vault"]:
		config.set_value("map", region_id, bool(_discovered_regions.get(region_id, false)))
	config.set_value("progress", "palace_seal", _has_palace_seal)
	config.set_value("progress", "grab_hook_unlocked", _grab_hook_unlocked)
	config.set_value("progress", "boss_defeated", _boss_is_defeated)
	config.save(GRACE_SAVE_PATH)


func _restore_palace_progress() -> void:
	if not _has_palace_seal:
		return
	var palace_seal := get_node_or_null("Gameplay/VerticalPalace/PalaceSeal") as Area2D
	if palace_seal:
		palace_seal.set_meta("activated", true)
		palace_seal.set_meta("prompt", "[E] Il Sigillo delle Maree è stato recuperato")
		var collision := palace_seal.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision:
			collision.set_deferred("disabled", true)
	var gate_lever := get_node_or_null("Gameplay/Interactions/GateLever") as Area2D
	if gate_lever:
		gate_lever.set_meta("prompt", "[E] Usa il Sigillo e solleva la paratia")


func _restore_boss_progress() -> void:
	if not _boss_is_defeated:
		return
	for boss in get_tree().get_nodes_in_group("dogana_boss"):
		if boss.has_method("restore_defeated"):
			boss.call("restore_defeated")
	var entrance_seal := get_node_or_null("Gameplay/Geometry/BossArena/EntranceSeal") as StaticBody2D
	if entrance_seal:
		var collision := entrance_seal.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision:
			collision.set_deferred("disabled", true)
		var visual := entrance_seal.get_node_or_null("Visual") as CanvasItem
		if visual:
			visual.hide()


func _apply_grab_hook_unlock() -> void:
	if _grab_hook_unlocked and _player and _player.has_method("unlock_grab_hook"):
		_player.call("unlock_grab_hook")


func _on_locked_skill_requested() -> void:
	_show_message("AMO DEL TRASCINAMENTO SIGILLATO  •  SCONFIGGI IL CUSTODE")


func _get_player_region(world_position: Vector2) -> String:
	if world_position.y < -100.0 and world_position.x > 2000.0 and world_position.x < 3340.0:
		return "palace"
	if world_position.y > 620.0 and world_position.x > 1080.0 and world_position.x < 2160.0:
		return "archive"
	if world_position.y < 265.0 and world_position.x > 3580.0 and world_position.x < 4070.0:
		return "ossuary"
	if world_position.x < 1200.0:
		return "arrival"
	if world_position.x < 2850.0:
		return "customs"
	if world_position.x < 3800.0:
		return "canal"
	return "fortuna"


func _mark_region_discovered(region_id: String) -> void:
	if region_id.is_empty() or bool(_discovered_regions.get(region_id, false)):
		return
	_discovered_regions[region_id] = true
	_save_graces()
	_sync_map()


func _restore_discovered_artwork() -> void:
	for artwork in get_tree().get_nodes_in_group("dogana_secret_artwork"):
		var secret_id := str(artwork.get_meta("secret_id", ""))
		if bool(_discovered_regions.get(secret_id, false)):
			artwork.modulate.a = 0.9
	for hidden_area in get_tree().get_nodes_in_group("dogana_hidden_reveal"):
		var secret_id := str(hidden_area.get_meta("secret_id", ""))
		if bool(_discovered_regions.get(secret_id, false)):
			hidden_area.set_meta("revealed", true)
			var veil := hidden_area.get_node_or_null("Veil") as CanvasItem
			if veil:
				veil.modulate.a = 0.0


func get_current_grace_name() -> String:
	var grace := _grace_sites.get(_current_grace) as Area2D
	return str(grace.get("display_name")) if grace else "Altare non scoperto"


func _apply_respawn(point: Vector2) -> void:
	if not _player:
		return
	if _player.has_method("set_checkpoint"):
		_player.call("set_checkpoint", point)
	if "initial_spawn_position" in _player:
		_player.set("initial_spawn_position", point)


func _show_message(text: String) -> void:
	var label := get_node_or_null("Interface/Location") as Label
	if not label:
		return
	if _message_tween:
		_message_tween.kill()
	label.text = text
	label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.8)
	_message_tween.tween_property(label, "modulate:a", 0.0, 1.2)
