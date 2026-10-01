extends Node
## Combattimento reale contro il Custode: nessuna chiamata diretta a _awaken.
## Il player entra nella nave, il boss deve aggro-are, sigillare l'arena,
## alternare pattern, animarsi e morire lasciando la ricompensa.

const STATE_DORMANT := 0
const STATE_CHASE := 1
const STATE_WINDUP := 2
const STATE_RECOVER := 11
const STATE_DEAD := 12

const ATTACK_STATES := [3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15]

var _level: Node
var _player: CharacterBody2D
var _boss: CharacterBody2D


func _ready() -> void:
	var packed := load("res://Levels/Scenes/punta_della_dogana.tscn") as PackedScene
	if packed == null:
		_fail("could not load Punta della Dogana")
		return
	_level = packed.instantiate()
	_level.set("persistence_enabled", false)
	add_child(_level)
	await _soak(3)

	var cutscene := _level.get_node_or_null("ArrivalCutscene")
	if cutscene:
		cutscene.queue_free()
		await get_tree().process_frame

	_player = _level.get_node("Player") as CharacterBody2D
	_player.collision_layer = 2
	_player.collision_mask = 1
	_player.set_physics_process(true)
	_player.set_meta("arrival_locked", false)
	_player.set_meta("arrival_riding", false)

	_boss = get_tree().get_first_node_in_group("dogana_boss") as CharacterBody2D
	if _boss == null:
		_fail("boss missing from the level")
		return

	await _enter_the_nave()
	if not await _test_dormant_until_approach():
		return
	if not await _test_arena_lock():
		return
	if not await _test_combat_loop():
		return
	if not await _test_animation_states():
		return
	if not await _test_defeat_and_reward():
		return

	print("CALIGO_BOSS_FIGHT_OK: aggro, arena lock, pattern rotation, animations and reward verified")
	_level.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _enter_the_nave() -> void:
	for passage in get_tree().get_nodes_in_group("dogana_salute_passage"):
		if str(passage.get_meta("action", "")) == "salute_enter":
			_level.call("_activate_interactable", passage)
			break
	await _soak(4)


## Il Custode non deve svegliarsi dall'altra parte della nave, ma deve farlo da
## solo quando il player si avvicina: senza questo non esiste un incontro.
func _test_dormant_until_approach() -> bool:
	_place_player(Vector2(4560, -545))
	await _soak(20)
	if int(_boss.get("state")) != STATE_DORMANT:
		return _fail("boss woke up from across the nave")
	_place_player(Vector2(5060, -545))
	var awake := false
	for _i in 120:
		await get_tree().physics_frame
		if int(_boss.get("state")) != STATE_DORMANT:
			awake = true
			break
	if not awake:
		return _fail("boss stayed dormant with the player inside its aggro range")
	return true


## La sveglia deve chiudere l'arena dove si combatte davvero (la nave), non un
## muro rimasto sul sagrato esterno, e la porta di uscita deve sparire.
func _test_arena_lock() -> bool:
	await _soak(4)
	var floor_y := 0.0
	var interior := get_tree().get_first_node_in_group("dogana_salute_interior")
	if interior:
		floor_y = float(interior.get_meta("floor_y", 0.0))
	var blockers := 0
	for body in get_tree().get_nodes_in_group("dogana_boss_seal"):
		if not (body is StaticBody2D):
			continue
		var seal := body as StaticBody2D
		var collision := seal.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision == null or collision.disabled:
			continue
		if absf(seal.global_position.y - floor_y) > 400.0:
			return _fail(
				"arena seal sits at y=%.0f while the fight happens at y=%.0f"
				% [seal.global_position.y, floor_y]
			)
		blockers += 1
	if blockers < 2:
		return _fail("awakened boss did not seal both sides of the nave (blockers=%d)" % blockers)
	for passage in get_tree().get_nodes_in_group("dogana_salute_passage"):
		if str(passage.get_meta("action", "")) == "salute_exit" and bool(passage.get("monitoring")):
			return _fail("the player can still walk out of the boss fight")
	return true


## Il boss deve muoversi e ruotare fra piu' pattern leggibili, non restare
## incollato a un solo attacco o fermo in CHASE.
func _test_combat_loop() -> bool:
	var states := {}
	var start_x := _boss.global_position.x
	var moved := 0.0
	var transients := 0
	for _i in 1400:
		_keep_player_alive()
		await get_tree().physics_frame
		var state := int(_boss.get("state"))
		states[state] = true
		moved = maxf(moved, absf(_boss.global_position.x - start_x))
		transients = maxi(transients, get_tree().get_nodes_in_group("enemy_transient_attack").size())
	if moved < 30.0:
		return _fail("boss never moved during the fight (max drift %.1fpx)" % moved)
	if not states.has(STATE_CHASE):
		return _fail("boss never chased the player")
	if not states.has(STATE_WINDUP):
		return _fail("boss never telegraphed an attack")
	var used := 0
	for state in ATTACK_STATES:
		if states.has(state):
			used += 1
	if used < 3:
		return _fail("boss only committed to %d distinct attacks in 1400 frames" % used)
	if transients <= 0:
		return _fail("boss attacks never spawned a hitbox or projectile")
	return true


## "Altre animazioni": il Custode deve cambiare posa fra riposo, inseguimento,
## carica e attacco, non solo lampeggiare di colore.
func _test_animation_states() -> bool:
	if not _boss.has_method("get_animation_state"):
		return _fail("boss exposes no animation state")
	var seen := {}
	for _i in 900:
		_keep_player_alive()
		await get_tree().physics_frame
		seen[str(_boss.call("get_animation_state"))] = true
	for required in ["chase", "windup", "attack"]:
		if not seen.has(required):
			return _fail("boss never played the '%s' animation (seen: %s)" % [required, str(seen.keys())])
	return true


## Il player deve poterlo uccidere con i suoi colpi veri, attraversando le fasi,
## e la vittoria deve riaprire l'arena e consegnare la ricompensa.
func _test_defeat_and_reward() -> bool:
	var hitbox := _player.get_node_or_null("AttackHitbox") as Area2D
	if hitbox == null:
		return _fail("player attack hitbox missing")
	_player.set("_current_attack_damage", 1)
	var phases := {}
	var guard := 0
	while int(_boss.get("state")) != STATE_DEAD and guard < 400:
		guard += 1
		_keep_player_alive()
		_boss.set("_invulnerability_timer", 0.0)
		_boss.set("_phase_transitioning", false)
		_boss.call("_on_hurtbox_area_entered", hitbox)
		phases[int(_boss.get("_phase"))] = true
		await get_tree().physics_frame
	if int(_boss.get("state")) != STATE_DEAD:
		return _fail("player hits never killed the boss (hp left %d)" % int(_boss.get("current_health")))
	if not phases.has(2) or not phases.has(3):
		return _fail("boss died without crossing its enrage phases")
	await _soak(6)
	if not bool(_level.get("_boss_is_defeated")):
		return _fail("level did not register the boss defeat")
	if not bool(_player.call("is_grab_hook_unlocked")):
		return _fail("boss defeat did not grant the traversal hook")
	for body in get_tree().get_nodes_in_group("dogana_boss_seal"):
		var collision := (body as Node).get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision and not collision.disabled:
			return _fail("arena stayed sealed after the boss died")
	var exit_open := false
	for passage in get_tree().get_nodes_in_group("dogana_salute_passage"):
		if str(passage.get_meta("action", "")) == "salute_exit" and bool(passage.get("monitoring")):
			exit_open = true
	if not exit_open:
		return _fail("the nave never reopened after the victory")
	return true


func _place_player(at: Vector2) -> void:
	_player.global_position = at
	_player.velocity = Vector2.ZERO


func _keep_player_alive() -> void:
	_player.set("current_health", 5)
	_player.set("is_dead", false)
	if _player.global_position.y > -300.0:
		_place_player(Vector2(5060, -545))


func _soak(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _fail(message: String) -> bool:
	push_error("CALIGO_BOSS_FIGHT_FAIL: " + message)
	get_tree().quit(1)
	return false
