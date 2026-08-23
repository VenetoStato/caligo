extends Node2D

signal grace_activated(site_id: String)

const DoganaFx := preload("res://Levels/Scenes/Dogana/dogana_fx.gd")

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
var _boss_arena_locked := false
var _grab_hook_unlocked := false
var _encounter_update_timer := 0.0
var _managed_encounters: Array[CharacterBody2D] = []
var _managed_waters: Array[Node] = []
var _grace_charge := 0.0
var _grace_charge_active := false
const GRACE_CHARGE_TIME := 3.0


func _ready() -> void:
	# Lo stato di pausa appartiene ai modal della scena corrente; non va ereditato
	# da una lettura/mappa rimasta aperta durante un reload o un test.
	get_tree().paused = false
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
	_update_passage_availability(false)
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
	_restore_boss_progress()
	_apply_grab_hook_unlock()
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
	_update_grace_charge(delta)
	_encounter_update_timer -= delta
	if _encounter_update_timer <= 0.0:
		_encounter_update_timer = 0.18
		_update_encounter_culling()
		_update_water_culling()
	var region := _get_player_region(_player.global_position)
	if region != _last_region:
		_last_region = region
		_mark_region_discovered(region)
		_notify_region_music()
	var map := get_node_or_null("DoganaMap")
	if map and map.has_method("set_player_world_position"):
		map.call("set_player_world_position", _player.global_position)


func _unhandled_input(event: InputEvent) -> void:
	if (
		_nearby_grace
		and is_instance_valid(_nearby_grace)
		and event.is_action_pressed("interact")
	):
		_grace_charge_active = true
		_grace_charge = 0.0
		get_viewport().set_input_as_handled()
		return
	if (
		_nearby_grace
		and is_instance_valid(_nearby_grace)
		and event.is_action_released("interact")
	):
		_cancel_grace_charge()
		get_viewport().set_input_as_handled()
		return
	if (
		_nearby_interactable
		and is_instance_valid(_nearby_interactable)
		and event.is_action_pressed("interact")
		and not _grace_charge_active
	):
		_activate_interactable(_nearby_interactable)
		get_viewport().set_input_as_handled()


func _update_grace_charge(delta: float) -> void:
	if not _grace_charge_active:
		return
	if (
		_nearby_grace == null
		or not is_instance_valid(_nearby_grace)
		or not Input.is_action_pressed("interact")
	):
		_cancel_grace_charge()
		return
	_grace_charge = minf(GRACE_CHARGE_TIME, _grace_charge + delta)
	var progress := _grace_charge / GRACE_CHARGE_TIME
	if _nearby_grace.has_method("set_charge_progress"):
		_nearby_grace.call("set_charge_progress", progress)
	if _grace_charge >= GRACE_CHARGE_TIME:
		var grace := _nearby_grace
		_grace_charge_active = false
		_grace_charge = 0.0
		_activate_grace(grace)
		if grace.has_method("cancel_charge"):
			grace.call("cancel_charge")


func _cancel_grace_charge() -> void:
	_grace_charge_active = false
	_grace_charge = 0.0
	if _nearby_grace and is_instance_valid(_nearby_grace) and _nearby_grace.has_method("cancel_charge"):
		_nearby_grace.call("cancel_charge")


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
	# La morte del player non rigenera i nemici. Il reset avviene soltanto
	# quando il giocatore attiva o usa volontariamente una grazia.
	# Il Custode fa eccezione: morire nell'arena deve poter far ricominciare
	# lo scontro, altrimenti resta sigillato con un boss a mezza vita.
	_reset_boss_encounter()
	_update_encounter_culling()


func _reset_enemies_at_grace() -> void:
	for attack in get_tree().get_nodes_in_group("enemy_transient_attack"):
		if is_instance_valid(attack):
			attack.queue_free()
	for corpse in get_tree().get_nodes_in_group("dead_enemy"):
		if is_instance_valid(corpse):
			corpse.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("reset_to_home"):
			enemy.call("reset_to_home")
	_reset_boss_encounter()
	_update_encounter_culling()


func _configure_encounter_culling() -> void:
	var encounters := get_node_or_null("Gameplay/Encounters")
	if encounters == null:
		return
	for child in encounters.get_children():
		if child is CharacterBody2D and child.is_in_group("enemy"):
			var enemy := child as CharacterBody2D
			enemy.set("activation_managed", false)
			enemy.set_physics_process(true)
			enemy.set_process(true)
			_managed_encounters.append(enemy)
	# No enemy process culling: patrol e wake restano affidabili.


func _update_encounter_culling() -> void:
	# Dogana ha pochi encounter: niente culling del process, che spezzava patrol e wake.
	for enemy in _managed_encounters:
		if not is_instance_valid(enemy):
			continue
		var is_dead := int(enemy.get("state")) == 2
		enemy.visible = not is_dead
		if not is_dead:
			enemy.set_physics_process(true)
			enemy.set_process(true)
	return
	if _player == null:
		return
	var player_in_salute := _player.global_position.y < -100.0
	for enemy in _managed_encounters:
		if not is_instance_valid(enemy):
			continue
		var dead := int(enemy.get("state")) == 2
		var dist_sq := enemy.global_position.distance_squared_to(_player.global_position)
		var near_player := dist_sq <= 1600.0 * 1600.0
		# Con 11 encounter il culling dell'AI non porta un vantaggio reale, ma può congelare
		# un enemy appena entra in camera. L'AI di Dogana resta quindi sempre attiva fuori dal palazzo.
		var active := not dead and not player_in_salute
		if dead:
			enemy.visible = false
			enemy.set_physics_process(false)
			enemy.set_process(false)
			continue
		enemy.visible = near_player or dist_sq <= 2200.0 * 2200.0
		enemy.set_physics_process(active)
		enemy.set_process(active)
		if active:
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			if int(enemy.get("state")) == 0:
				var vel: Variant = enemy.get("velocity")
				if vel is Vector2 and absf((vel as Vector2).x) < 1.0:
					enemy.set("_patrol_dir", 1.0 if randf() < 0.5 else -1.0)
					enemy.set("velocity", Vector2(
						float(enemy.get("_patrol_dir")) * float(enemy.get("move_speed")) * 0.55,
						(vel as Vector2).y
					))
		else:
			enemy.process_mode = Node.PROCESS_MODE_INHERIT


func _update_water_culling() -> void:
	if _player == null:
		return
	var player_in_salute := _player.global_position.y < -100.0
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
			if near_horizontal and not player_in_salute
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
	var enabled_region := str(interactable.get_meta("enabled_region", ""))
	if enabled_region == "surface" and _player.global_position.y < -100.0:
		return
	if enabled_region == "interior" and _player.global_position.y >= -100.0:
		return
	_nearby_interactable = interactable
	_set_interactable_aura(interactable, true)
	DoganaFx.burst(
		get_tree().current_scene,
		interactable.global_position + Vector2(0, -20),
		Color(0.85, 0.75, 0.4, 0.65),
		6,
		Vector2.UP,
		10.0,
		32.0,
		0.4
	)


func _on_interactable_exited(body: Node2D, interactable: Area2D) -> void:
	if body == _player and _nearby_interactable == interactable:
		_set_interactable_aura(interactable, false)
		_nearby_interactable = null


func _activate_interactable(interactable: Area2D) -> void:
	var action := str(interactable.get_meta("action", "lore"))
	var origin := interactable.global_position + Vector2(0, -24)
	var scene := get_tree().current_scene
	if action in ["salute_enter", "salute_exit"]:
		_use_salute_passage(interactable)
	elif action == "read" or action == "lore":
		_open_lore(
			str(interactable.get_meta("entry_title", interactable.get_meta("prompt", "Registro"))),
			str(interactable.get_meta("message", "Le pagine sono illeggibili."))
		)
	elif action == "bell":
		var camera := get_tree().get_first_node_in_group("camera")
		if camera and camera.has_method("add_shake"):
			camera.call("add_shake", 0.28 if not DoganaFx.is_mobile() else 0.18)
		DoganaFx.pulse_ring(scene, origin, Color(0.95, 0.82, 0.4, 0.9))
		DoganaFx.burst(scene, origin, Color(0.95, 0.85, 0.45, 0.9), 14, Vector2.UP, 25.0, 90.0, 0.65)
		_show_message("LA CAMPANA DELLA FORTUNA RISPONDE ALLA LAGUNA")
	else:
		DoganaFx.pulse_ring(scene, origin, Color(0.55, 0.85, 0.8, 0.75))
		DoganaFx.burst(scene, origin, Color(0.7, 0.9, 0.85, 0.8), 10, Vector2.UP, 18.0, 55.0, 0.55)
		_open_lore(
			str(interactable.get_meta("entry_title", interactable.get_meta("prompt", "Memoria"))),
			str(interactable.get_meta("message", "Le pietre conservano una storia dimenticata."))
		)


func _set_interactable_aura(interactable: Area2D, on: bool) -> void:
	var aura := interactable.get_node_or_null("SoftAura") as CPUParticles2D
	if aura == null:
		aura = DoganaFx.make_soft_aura(
			interactable,
			Vector2(0, -18),
			Color(0.85, 0.75, 0.4, 0.5),
			7
		)
	aura.emitting = on
	_set_interactable_mark(interactable, on)


## Al posto della scritta "[E] ...": un rombo di luce che ondeggia sopra
## l'oggetto. Dice "qui si puo' agire" senza spiegare niente.
func _set_interactable_mark(interactable: Area2D, on: bool) -> void:
	var mark := interactable.get_node_or_null("ReadyMark") as Line2D
	if mark == null:
		if not on:
			return
		mark = Line2D.new()
		mark.name = "ReadyMark"
		mark.width = 1.6
		mark.z_index = 40
		mark.default_color = Color(0.88, 0.8, 0.52, 0.0)
		mark.points = PackedVector2Array([
			Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0), Vector2(0, -6)
		])
		mark.position = Vector2(0, -36)
		interactable.add_child(mark)
		var bob := mark.create_tween().set_loops()
		bob.tween_property(mark, "position:y", -42.0, 1.3).set_trans(Tween.TRANS_SINE)
		bob.tween_property(mark, "position:y", -36.0, 1.3).set_trans(Tween.TRANS_SINE)
	var fade := mark.create_tween()
	fade.tween_property(mark, "default_color:a", 0.7 if on else 0.0, 0.3)


func _use_salute_passage(interactable: Area2D) -> void:
	if not _player:
		return
	var target := interactable.get_meta("target_position", Vector2.ZERO) as Vector2
	if target == Vector2.ZERO:
		return
	_player.global_position = target
	_player.velocity = Vector2.ZERO
	_nearby_interactable = null
	_update_passage_availability(target.y < -100.0)
	var location := get_node_or_null("Interface/Location") as Label
	if location:
		location.modulate.a = 0.0
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()
	if target.y < -100.0:
		_mark_region_discovered("salute")
		_mark_access_open("salute")
		_show_message("SANTA MARIA DELLA SALUTE  •  IL CUSTODE ATTENDE NELLA NAVE")
	else:
		_show_message("RITORNO SUL SAGRATO DELLA SALUTE")


func _update_passage_availability(inside: bool) -> void:
	for passage in get_tree().get_nodes_in_group("dogana_salute_passage"):
		if not (passage is Area2D):
			continue
		var enabled_region := str(passage.get_meta("enabled_region", ""))
		var enabled := (enabled_region == "interior") == inside
		# Mentre il Custode e' sveglio la nave e' un'arena chiusa: la porta di
		# ritorno non deve offrire una via di fuga a costo zero.
		if _boss_arena_locked and enabled_region == "interior":
			enabled = false
		(passage as Area2D).monitoring = enabled
		(passage as Area2D).monitorable = enabled


func _player_is_inside_nave() -> bool:
	return _player != null and is_instance_valid(_player) and _player.global_position.y < -100.0


## I sigilli vivono nella nave insieme al boss: prima erano rimasti sul sagrato
## esterno, quindi l'arena non si chiudeva mai davvero.
func _set_boss_arena_sealed(sealed: bool) -> void:
	_boss_arena_locked = sealed
	for seal in get_tree().get_nodes_in_group("dogana_boss_seal"):
		var collision := (seal as Node).get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision:
			collision.set_deferred("disabled", not sealed)
		if seal is CanvasItem:
			(seal as CanvasItem).modulate.a = 1.0
	_update_passage_availability(_player_is_inside_nave())


func _reset_boss_encounter() -> void:
	if _boss_is_defeated:
		return
	_set_boss_arena_sealed(false)
	for boss in get_tree().get_nodes_in_group("dogana_boss"):
		if boss.has_method("reset_encounter"):
			boss.call("reset_encounter")


func _on_boss_awakened() -> void:
	_set_boss_arena_sealed(true)
	_show_message("IL CUSTODE SOMMERSO RISCOSSA IL SUO TRIBUTO")


func _on_boss_defeated() -> void:
	if _boss_is_defeated:
		return
	_boss_is_defeated = true
	_grab_hook_unlocked = true
	_apply_grab_hook_unlock()
	_save_graces()
	_set_boss_arena_sealed(false)
	var finish := get_node_or_null("Gameplay/FortunaSummit") as Area2D
	if finish:
		var finish_collision := finish.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if finish_collision:
			finish_collision.set_deferred("disabled", false)
		finish.set_deferred("monitoring", true)
	_show_message("CUSTODE SCONFITTO  •  OTTENUTO AMO DEL TRASCINAMENTO [C]")


func _mark_access_open(access_id: String) -> void:
	for marker in get_tree().get_nodes_in_group("dogana_access_marker"):
		if str(marker.get("access_id")) == access_id and marker.has_method("mark_open"):
			marker.call("mark_open")


func _on_grace_entered(body: Node2D, grace: Area2D) -> void:
	if body != _player:
		return
	_nearby_grace = grace


func _on_grace_exited(body: Node2D, grace: Area2D) -> void:
	if body == _player and _nearby_grace == grace:
		_cancel_grace_charge()
		_nearby_grace = null


func _activate_grace(grace: Area2D, show_message := true) -> void:
	var site_id := str(grace.get("site_id"))
	var already := bool(_activated_graces.get(site_id, false))
	_activated_graces[site_id] = true
	_current_grace = site_id
	grace.call("set_activated", true)
	_apply_respawn(grace.call("get_respawn_position"))
	if _player.has_method("heal"):
		_player.call("heal", int(_player.get("max_health")))
	if show_message:
		_reset_enemies_at_grace()
	_save_graces()
	_sync_map()
	if show_message:
		if already and grace.has_method("play_rest_fx"):
			grace.call("play_rest_fx")
			_show_message("RIPOSO  •  %s" % str(grace.get("display_name")).to_upper())
		else:
			if grace.has_method("play_activation_fx"):
				grace.call("play_activation_fx")
			grace_activated.emit(site_id)
			_show_message("ALTARE RISVEGLIATO  •  %s" % str(grace.get("display_name")).to_upper())
		var tutorial := get_node_or_null("TutorialHints")
		if tutorial and tutorial.has_method("notify_altar_used"):
			tutorial.call("notify_altar_used")


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


func _on_fast_travel_requested(site_id: String, debug_unlock := false) -> void:
	if not bool(_activated_graces.get(site_id, false)) and not debug_unlock:
		return
	var grace := _grace_sites.get(site_id) as Area2D
	if not grace:
		return
	var travel := func() -> void:
		if debug_unlock:
			_activated_graces[site_id] = true
			grace.call("set_activated", true)
			_save_graces()
		_current_grace = site_id
		_player.global_position = grace.call("get_respawn_position")
		_player.velocity = Vector2.ZERO
		_activate_grace(grace, false)
		_sync_map()
		_show_message("DEBUG - VIAGGIO ALLA GRAZIA - %s" % str(grace.get("display_name")).to_upper())
	if debug_unlock:
		# Il percorso debug deve essere immediato e deterministico anche con scena
		# in pausa; evita che una dissolvenza editoriale trattenga il callback.
		travel.call()
	elif autoload_transition and autoload_transition.has_method("transition_with_callback"):
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
	for region_id in ["arrival", "customs", "canal", "fortuna", "salute"]:
		if bool(config.get_value("map", region_id, region_id == "arrival")):
			_discovered_regions[region_id] = true
	_grab_hook_unlocked = bool(config.get_value("progress", "grab_hook_unlocked", false))
	_boss_is_defeated = bool(config.get_value("progress", "boss_defeated", false))


func _save_graces() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("graces", "current", _current_grace)
	for site_id in ["pontile", "dogana", "fortuna"]:
		config.set_value("graces", site_id, bool(_activated_graces.get(site_id, false)))
	for region_id in ["arrival", "customs", "canal", "fortuna", "salute"]:
		config.set_value("map", region_id, bool(_discovered_regions.get(region_id, false)))
	config.set_value("progress", "grab_hook_unlocked", _grab_hook_unlocked)
	config.set_value("progress", "boss_defeated", _boss_is_defeated)
	config.save(GRACE_SAVE_PATH)


func _restore_boss_progress() -> void:
	if not _boss_is_defeated:
		return
	for boss in get_tree().get_nodes_in_group("dogana_boss"):
		if boss.has_method("restore_defeated"):
			boss.call("restore_defeated")
	_set_boss_arena_sealed(false)


func _apply_grab_hook_unlock() -> void:
	if _grab_hook_unlocked and _player and _player.has_method("unlock_grab_hook"):
		_player.call("unlock_grab_hook")


func _on_locked_skill_requested() -> void:
	_show_message("AMO DEL TRASCINAMENTO SIGILLATO  •  SCONFIGGI IL CUSTODE")


func _get_player_region(world_position: Vector2) -> String:
	if world_position.y < -100.0 and world_position.x > 4000.0:
		return "salute"
	if world_position.x < 1200.0:
		return "arrival"
	if world_position.x < 2850.0:
		return "customs"
	if world_position.x < 3800.0:
		return "canal"
	# Torre Fortuna + nartece fino al sigillo d'ingresso arena (~4580).
	# Nave della Salute (boss): oltre l'EntranceSeal.
	if world_position.x < 4580.0:
		return "fortuna"
	return "salute"


func _mark_region_discovered(region_id: String) -> void:
	if region_id.is_empty() or bool(_discovered_regions.get(region_id, false)):
		return
	_discovered_regions[region_id] = true
	_save_graces()
	_sync_map()


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


func _notify_region_music() -> void:
	var director := get_node_or_null("RegionMusicDirector")
	if director == null:
		director = get_tree().get_first_node_in_group("region_music_director")
	if director and director.has_method("set_region"):
		director.call("set_region", _last_region if not _last_region.is_empty() else "arrival")
	if director and director.has_method("set_boss_active"):
		var boss_alive := false
		for boss in get_tree().get_nodes_in_group("dogana_boss"):
			if is_instance_valid(boss) and not bool(boss.get("is_defeated")):
				var st = boss.get("state")
				# Awake/combat states duck BGM.
				if st != null and int(st) > 0 and int(st) < 10:
					boss_alive = true
					break
		director.call("set_boss_active", boss_alive and _last_region == "salute")


func _open_lore(title: String, body: String) -> void:
	var reader := get_node_or_null("LoreReader")
	if reader and reader.has_method("show_entry"):
		reader.call("show_entry", title, body)
	else:
		_show_message(body)


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
