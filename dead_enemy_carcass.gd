extends RigidBody2D

## Cadavere recuperabile: resta nel mondo, può essere agganciato come esca e
## attiva un predatore più grande quando entra nella laguna.
var in_water := false
var hooked_to_player := false
var _bait_registered := false
var player_ref: Node = null

const PLAYER_WATER_GRAVITY := 0.3
const MAX_REEL_LIFT := 120.0
const MAX_REEL_UPWARD_SPEED := 185.0
const REEL_ACCELERATION := 1050.0

func _ready() -> void:
	add_to_group("fish")
	add_to_group("dogana_bait")
	contact_monitor = true
	max_contacts_reported = 4
	gravity_scale = 1.0
	var drag_material := PhysicsMaterial.new()
	drag_material.friction = 0.18
	drag_material.bounce = 0.0
	physics_material_override = drag_material

func is_fish() -> bool:
	return true

func is_bait_carcass() -> bool:
	return true

func set_player_reference(player: Node) -> void:
	player_ref = player
	hooked_to_player = true
	freeze = false
	can_sleep = false
	sleeping = false
	# Il cadavere resta un corpo fisico: il reel non annulla la gravità.
	gravity_scale = PLAYER_WATER_GRAVITY if in_water else 1.0

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
	var limited := force
	if hooked_to_player and player_ref is Node2D:
		var lift := (player_ref as Node2D).global_position.y - global_position.y
		if lift >= MAX_REEL_LIFT:
			limited.y = maxf(limited.y, 0.0)
		elif lift > MAX_REEL_LIFT * 0.55 and limited.y < 0.0:
			var remaining := inverse_lerp(MAX_REEL_LIFT, MAX_REEL_LIFT * 0.55, lift)
			limited.y *= clampf(remaining, 0.0, 1.0)
	# Peso maggiore dell'esca normale, ma abbastanza trazione da vincere la
	# gravità ridotta dell'acqua quando il giocatore la reel-a.
	apply_central_force(limited * 1.45)


func reel_toward(anchor: Vector2, delta: float, reel_speed: float) -> void:
	# Il cadavere è un RigidBody e, quando appoggiato al pontile, la sola forza
	# continua veniva assorbita da gravità, attrito e damping. Qui il reel agisce
	# come trazione controllata sulla velocità: resta pesante, ma si muove sempre.
	if not hooked_to_player:
		return
	can_sleep = false
	sleeping = false
	var offset := anchor - global_position
	if offset.length_squared() <= 1.0:
		return
	var direction := offset.normalized()
	var lift := 0.0
	if player_ref is Node2D:
		lift = (player_ref as Node2D).global_position.y - global_position.y
	if direction.y < 0.0:
		if lift >= MAX_REEL_LIFT:
			direction.y = 0.0
		elif lift > MAX_REEL_LIFT * 0.55:
			direction.y *= clampf(
				inverse_lerp(MAX_REEL_LIFT, MAX_REEL_LIFT * 0.55, lift),
				0.0,
				1.0
			)
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
	var target_speed := clampf(reel_speed * 0.92, 105.0, 205.0)
	var target_velocity := direction * target_speed
	target_velocity.y = maxf(target_velocity.y, -MAX_REEL_UPWARD_SPEED)
	linear_velocity.x = move_toward(linear_velocity.x, target_velocity.x, REEL_ACCELERATION * delta)
	if direction.y < -0.01:
		linear_velocity.y = move_toward(
			linear_velocity.y,
			target_velocity.y,
			REEL_ACCELERATION * 1.15 * delta
		)

func pull_along_line(anchor: Vector2, haul: float, _allow_exit := false) -> void:
	var to_anchor := anchor - global_position
	if to_anchor.length_squared() > 1.0:
		var direction := to_anchor.normalized()
		# Non superare la canna verso l'alto: senza un tether fisico la forza
		# continuava ad accumularsi e l'esca saliva fuori scena all'infinito.
		if to_anchor.y < -120.0:
			direction.y = 0.0
			if direction.length_squared() < 0.01:
				linear_velocity.y = move_toward(linear_velocity.y, 0.0, haul * 0.08)
			else:
				direction = direction.normalized()
		if hooked_to_player and player_ref is Node2D:
			var lift := (player_ref as Node2D).global_position.y - global_position.y
			if lift >= MAX_REEL_LIFT:
				direction.y = maxf(direction.y, 0.0)
			elif lift > MAX_REEL_LIFT * 0.55 and direction.y < 0.0:
				direction.y *= clampf(inverse_lerp(MAX_REEL_LIFT, MAX_REEL_LIFT * 0.55, lift), 0.0, 1.0)
			if direction.length_squared() > 0.01:
				direction = direction.normalized()
		apply_central_force(direction * haul * 0.9)

func release_from_hook() -> void:
	hooked_to_player = false
	player_ref = null
	can_sleep = true
	gravity_scale = PLAYER_WATER_GRAVITY if in_water else 1.0

func _on_hook_detected(hook: Node) -> void:
	if hooked_to_player or hook == null:
		return
	if hook.has_method("_hook_fish"):
		hook.call("_hook_fish", self)

func _physics_process(_delta: float) -> void:
	if hooked_to_player and player_ref is Node2D:
		var lift := (player_ref as Node2D).global_position.y - global_position.y
		if lift >= MAX_REEL_LIFT:
			# Oltre il limite il reel può muovere solo lateralmente; la gravità
			# deve riportare il peso verso il basso.
			linear_velocity.y = maxf(linear_velocity.y, 0.0)
		else:
			linear_velocity.y = maxf(linear_velocity.y, -MAX_REEL_UPWARD_SPEED)
	var water := get_tree().get_first_node_in_group("water")
	if water != null and water.has_method("get_surface_height"):
		var surface := float(water.call("get_surface_height", global_position.x))
		var now_in_water := global_position.y >= surface - 4.0
		if now_in_water and not in_water:
			in_water = true
			gravity_scale = PLAYER_WATER_GRAVITY
			linear_damp = 3.2
			if not _bait_registered and water.has_method("register_carcass_bait"):
				_bait_registered = true
				water.call_deferred("register_carcass_bait", global_position)
		elif not now_in_water and in_water:
			in_water = false
			gravity_scale = 1.0
			linear_damp = 0.0
		if in_water:
			# L'esca galleggia come una pastura pesante: scende lentamente ma non
			# può sprofondare fuori dal volume di pesca.
			var max_depth := surface + 190.0
			if global_position.y > max_depth:
				global_position.y = max_depth
				linear_velocity.y = minf(linear_velocity.y, 0.0)
			else:
				linear_velocity.y = move_toward(linear_velocity.y, 7.0, 18.0 * _delta)
