extends Node

## Audit strutturale: ogni zona principale deve avere suolo continuo, accessi
## appoggiati e nemici con spazio reale di pattuglia.

const FLOOR_SAMPLES := [
	["pontile_ovest", Vector2(0, 410), 460.0],
	["pontile_est", Vector2(940, 410), 460.0],
	["dogana_ovest", Vector2(1300, 430), 485.0],
	["dogana_grazia", Vector2(1900, 430), 485.0],
	["dogana_est", Vector2(2120, 456), 485.0],
	["dogana_banchina_sx", Vector2(2260, 420), 485.0],
	["dogana_banchina_centro", Vector2(2630, 420), 485.0],
	["dogana_banchina_dx", Vector2(3000, 420), 485.0],
	["canale", Vector2(3360, 420), 485.0],
	["seminario", Vector2(3830, 420), 485.0],
	["salute", Vector2(5180, 430), 485.0],
	["salute_interno_ovest", Vector2(4300, -590), -500.0],
	["salute_interno_arena", Vector2(5180, -590), -500.0],
	["salute_interno_est", Vector2(5900, -590), -500.0],
]


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	var level := packed.instantiate()
	level.set("persistence_enabled", false)
	add_child(level)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	for sample in FLOOR_SAMPLES:
		var id := str(sample[0])
		var at: Vector2 = sample[1]
		var expected := float(sample[2])
		var floor_y := _static_floor_y(space, at + Vector2(0, 1), 149.0)
		if not is_finite(floor_y) or absf(floor_y - expected) > 4.0:
			_fail("%s has no coherent floor: hit=%.1f expected=%.1f" % [id, floor_y, expected])
			return

	for grace in get_tree().get_nodes_in_group("dogana_grace"):
		var supported_sides := 0
		for side in [-36.0, 36.0]:
			if _has_support(space, (grace as Node2D).global_position + Vector2(side, 0), 100.0, 1):
				supported_sides += 1
		if supported_sides < 2:
			_fail("grace %s is unsupported" % grace.name)
			return

	var entrances := get_tree().get_nodes_in_group("dogana_salute_passage")
	if entrances.size() != 2:
		_fail("expected exactly two modular Salute passages, got %d" % entrances.size())
		return
	for entrance in entrances:
		if not _has_support(space, (entrance as Area2D).global_position, 90.0, 1):
			_fail("Salute passage %s is floating" % entrance.name)
			return

	var checked_enemies := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var e := enemy as CharacterBody2D
		if e == null or e.get_parent() == null or e.get_parent().name != "Encounters":
			continue
		# Gli oracoli volano; tutti gli altri richiedono suolo sotto casa e ai due
		# lati della pattuglia, per evitare flip ogni frame o blocchi sulle rampe.
		if e.get("hovering") == true:
			continue
		e.set_physics_process(false)
		var home := e.global_position
		var body_collision := e.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if body_collision and body_collision.shape is RectangleShape2D:
			var body_shape := body_collision.shape as RectangleShape2D
			home.y = body_collision.global_position.y + body_shape.size.y * absf(e.global_scale.y) * 0.5
		# Alcuni encounter possono aver gia' iniziato una caduta prima dell'audit:
		# ancoriamo il controllo al primo pavimento statico sotto la loro X.
		var settled_floor := _static_floor_y(space, Vector2(home.x, home.y - 180.0), 320.0)
		if is_finite(settled_floor):
			home.y = settled_floor
		if home.y < 100.0:
			continue
		var patrol := minf(float(e.get("patrol_range")), 90.0)
		for xoff in [0.0, -patrol, patrol]:
			if not _has_support(space, home + Vector2(xoff, -8), 150.0, 1):
				_fail("enemy %s home=%s has no patrol support at offset %.1f" % [e.name, home, xoff])
				return
		checked_enemies += 1
	if checked_enemies < 6:
		_fail("too few grounded enemy routes audited: %d" % checked_enemies)
		return

	var modules := get_tree().get_nodes_in_group("dogana_sideview_module")
	var interior := get_tree().get_first_node_in_group("dogana_salute_interior_art") as Sprite2D
	var depth_system := get_tree().get_first_node_in_group("dogana_depth_system")
	if modules.size() != 6 or interior == null or interior.texture == null:
		_fail("modular exterior or lateral Salute interior art is missing")
		return
	if depth_system == null or get_tree().get_nodes_in_group("dogana_parallax_far").size() != 1 or get_tree().get_nodes_in_group("dogana_parallax_mid").size() != 1 or get_tree().get_nodes_in_group("dogana_parallax_near").size() != 1:
		_fail("multi-plane parallax depth system is incomplete")
		return
	if get_tree().get_nodes_in_group("dogana_bokeh_layer").size() != 2:
		_fail("safe multi-plane bokeh layers are incomplete")
	if get_tree().get_nodes_in_group("dogana_atmospheric_dust").size() != 1:
		_fail("safe atmospheric dust layer is missing")
	if get_tree().get_nodes_in_group("dogana_light_motes").size() != 1:
		_fail("subtle light-mote layer is missing")
	if get_tree().get_nodes_in_group("dogana_light_layer").size() != 1:
		_fail("architectural light layer is missing")
		return
	var softfocus := load("res://Levels/Scenes/Dogana/background_softfocus.gdshader") as Shader
	if softfocus == null or softfocus.code.contains("hint_screen_texture") or softfocus.code.contains("SCREEN_UV"):
		_fail("background soft focus uses unsafe screen-space sampling")
		return
	if absf(float(interior.get_meta("visual_floor_y", INF)) - float(interior.get_parent().get_meta("floor_y", -INF))) > 1.0:
		_fail("Salute illustrated floor is not aligned with its collision")
		return
	for obsolete in ["CanalGate", "DoganaRoofSteps", "CanalPlatforms", "TowerRoute", "FortunaOssuary"]:
		if level.find_child(obsolete, true, false) != null:
			_fail("obsolete floating route survived: %s" % obsolete)
			return
	if level.find_child("TutorialGate", true, false) != null:
		_fail("procedural tutorial gate survived")
		return
	var boss_seal := level.get_node_or_null("Gameplay/Geometry/BossArena/EntranceSeal")
	if boss_seal and boss_seal.get_child_count() != 1:
		_fail("boss seal still contains procedural visual geometry")
		return
	var foundations := get_tree().get_nodes_in_group("dogana_waterline_foundation")
	if foundations.size() < 7:
		_fail("too few illustrated foundations reach the sea: %d" % foundations.size())
		return
	for foundation in foundations:
		if float(foundation.get_meta("foundation_bottom_y", -INF)) < 565.0:
			_fail("foundation %s stops above sea level" % foundation.name)
			return
	var lore_props := get_tree().get_nodes_in_group("dogana_lore_readable")
	if lore_props.size() < 3:
		_fail("expected at least three readable lore props, got %d" % lore_props.size())
		return
	for lore in lore_props:
		if absf(float(lore.get_meta("visual_bottom_local", INF))) > 1.0:
			_fail("lore prop %s visual is not grounded" % lore.name)
			return

	print("CALIGO_ZONE_COHERENCE_OK: %d floors, %d enemy routes, %d sea foundations and modular Salute" % [
		FLOOR_SAMPLES.size(), checked_enemies, foundations.size(),
	])
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _has_support(space: PhysicsDirectSpaceState2D, at: Vector2, distance: float, mask: int) -> bool:
	return is_finite(_static_floor_y(space, at + Vector2(0, -8), distance + 8.0, mask))


func _static_floor_y(
	space: PhysicsDirectSpaceState2D,
	from: Vector2,
	distance: float,
	mask := 1
) -> float:
	var excluded: Array[RID] = []
	for _attempt in 12:
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, distance), mask)
		query.exclude = excluded
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return INF
		var collider := hit.get("collider") as Node
		if collider is StaticBody2D:
			return (hit.position as Vector2).y
		if hit.has("rid"):
			excluded.append(hit.rid as RID)
	return INF


func _fail(message: String) -> void:
	push_error("ZONE_COHERENCE_FAIL: " + message)
	get_tree().quit(1)
