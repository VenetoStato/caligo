extends RigidBody2D

## Cadavere recuperabile: resta nel mondo, può essere agganciato come esca e
## attiva un predatore più grande quando entra nella laguna.
var in_water := false
var hooked_to_player := false
var _bait_registered := false
var player_ref: Node = null

func _ready() -> void:
	add_to_group("fish")
	add_to_group("dogana_bait")
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = 1.0

func is_fish() -> bool:
	return true

func is_bait_carcass() -> bool:
	return true

func set_player_reference(player: Node) -> void:
	player_ref = player
	hooked_to_player = true
	freeze = false
	gravity_scale = 0.15

func set_line_tether(_anchor: Vector2, _length: float) -> void:
	pass

func clear_line_tether() -> void:
	pass

func is_hanging() -> bool:
	return false

func is_in_water() -> bool:
	return in_water

func start_struggle() -> void:
	# L'esca non lotta come un pesce vivo, ma resta un peso fisico.
	apply_central_impulse(Vector2(randf_range(-28.0, 28.0), -24.0))

func stop_struggle() -> void:
	pass

func set_wrong_reel(_wrong: bool) -> void:
	pass

func apply_struggle_force(force: Vector2) -> void:
	apply_central_force(force * 0.35)

func apply_reel_force(force: Vector2) -> void:
	apply_central_force(force * 1.15)

func pull_along_line(anchor: Vector2, haul: float, _allow_exit := false) -> void:
	var to_anchor := anchor - global_position
	if to_anchor.length_squared() > 1.0:
		apply_central_force(to_anchor.normalized() * haul * 0.9)

func release_from_hook() -> void:
	hooked_to_player = false
	player_ref = null
	gravity_scale = 0.15 if in_water else 1.0

func _on_hook_detected(hook: Node) -> void:
	if hooked_to_player or hook == null:
		return
	if hook.has_method("_hook_fish"):
		hook.call("_hook_fish", self)

func _physics_process(_delta: float) -> void:
	var water := get_tree().get_first_node_in_group("water")
	if water != null and water.has_method("get_surface_height"):
		var surface := float(water.call("get_surface_height", global_position.x))
		var now_in_water := global_position.y >= surface - 4.0
		if now_in_water and not in_water:
			in_water = true
			gravity_scale = 0.08
			linear_damp = 3.2
			if not _bait_registered and water.has_method("register_carcass_bait"):
				_bait_registered = true
				water.call_deferred("register_carcass_bait", global_position)
		elif not now_in_water and in_water:
			in_water = false
			gravity_scale = 1.0 if not hooked_to_player else 0.15
			linear_damp = 0.0
