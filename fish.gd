extends RigidBody2D

# ===========================================
# FISH - Pesce che nuota e può essere pescato
# ===========================================
# Quando scappa dall'amo, torna a nuotare liberamente
# invece di sparire

@export_category("Movement")
@export var natural_swim_speed: float = 85.0
@export var attraction_speed: float = 72.0
@export var swim_change_interval: float = 1.8
@export var escape_speed: float = 65.0
@export var escape_duration: float = 2.2
@export_range(0.0, 0.5) var vertical_wander := 0.22
@export_range(0.0, 1.0) var turn_chance := 0.28

@export_category("Swim Area")
## Area di nuoto orizzontale attorno alla casa
@export var swim_bounds_x: float = 160.0
## Area di nuoto verticale attorno alla casa
@export var swim_bounds_y: float = 60.0
## Offset della casa rispetto allo spawn (Y negativo = più su)
@export var home_offset: Vector2 = Vector2(0, -50)
## Quanto possono stare sotto la superficie (limite massimo in profondità)
@export var max_depth_from_top: float = 180.0
## Distanza minima dalla superficie: i pesci restano più in giù, lontani dal bordo (px sotto superficie)
@export var min_depth_from_top: float = 70.0
## Raggio della "reel zone": vicino al player il pesce ignora limiti acqua e viene solo reelato / può uscire
@export var reel_zone_radius: float = 160.0
## Sotto questa profondità dalla superficie il pesce è "vicino al bordo" e può uscire (salto)
@export var near_surface_depth: float = 70.0

@export_category("Physics")
@export var swim_response: float = 3.0
@export var water_damping: float = 0.98
@export var boundary_push: float = 80.0
## Fuori acqua: stessa gravita' del mondo, niente tetto sulla caduta.
const AIR_GRAVITY := 980.0

@export_category("Struggle")
@export var struggle_strength: float = 320.0
@export var struggle_duration: float = 1.5
@export var reel_resistance: float = 1.0
## Resistenza costante verso l'amo quando agganciato (nuota via)
@export var hooked_resist_strength: float = 22.0
## Velocità max quando agganciato (più alta in reel così la tirata si sente)
@export var hooked_max_speed: float = 160.0
## Damping più forte quando agganciato (movimento più fluido)
@export var hooked_damping: float = 0.94

@export_category("Visual")
## Colore normale del pesce
@export var normal_color: Color = Color(1, 1, 1, 1)
## Colore quando sta lottando
@export var struggle_color: Color = Color(1, 0.6, 0.6, 1)
## Colore quando scappa
@export var escape_color: Color = Color(0.8, 0.8, 1, 1)
## Colore quando tiri durante la lotta (lenza e pesce rossi, poi scappa)
@export var wrong_reel_color: Color = Color(1, 0.25, 0.2, 1)

# Riferimenti
var player_ref: Node = null
var target_hook: Node = null
var sprite: Node2D = null
var _underwater_material: ShaderMaterial = null

# Stato movimento
var velocity: Vector2 = Vector2.ZERO
var swim_direction: Vector2 = Vector2.RIGHT
var swim_timer: float = 0.0
var home_position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO

# Stato pesca
var in_water: bool = true
var is_hooked_to_player: bool = false
var is_attracted: bool = false
var attraction_target: Vector2 = Vector2.ZERO

# Stato lotta
var is_struggling: bool = false
var struggle_timer: float = 0.0
var struggle_direction: Vector2 = Vector2.ZERO

# Stato fuga (dopo essere scappato)
var is_escaping: bool = false
var escape_timer: float = 0.0
var escape_direction: Vector2 = Vector2.ZERO

# Forze esterne
var reel_force: Vector2 = Vector2.ZERO
var _reel_force_smoothed: Vector2 = Vector2.ZERO  # per ridurre tremolio
const REEL_FORCE_SMOOTH: float = 2.2

# Cooldown per essere ri-agganciato dopo aver scappato (breve: può essere ripescato)
var hook_cooldown: float = 0.0
var hook_cooldown_time: float = 1.2

# Evitare flip casuali: soglia velocità e cooldown tra un flip e l'altro
var _flip_cooldown: float = 0.0
const FLIP_VELOCITY_THRESHOLD: float = 10.0   # flip solo se |velocity.x| > questa soglia
const FLIP_COOLDOWN_TIME: float = 0.35       # secondi tra un flip e l'altro

# Sprite variante (boops/sarago): disegnati con la testa dall'altra parte, serve invertire il flip
var _variant_sprite: bool = false
# Tirare durante la lotta = pesce rosso (segnalato dal player)
var _wrong_reel: bool = false
## Se false (default in lotta): il pesce resta sotto la superficie — niente levitazione.
var _allow_surface_exit: bool = false
## True dopo do_catch_jump finche' non rientra in acqua o viene catturato.
var _catch_jump_active: bool = false
## Fuori acqua: origine = bocca sull'amo, sprite corpo a penzoloni sotto.
var _hanging: bool = false
var _hooked_wander_angle: float = 0.0
## Offset bocca in nuoto (verso la testa). Se < 0 usa meta' larghezza sprite.
@export var mouth_offset: float = -1.0
## Quanto il corpo scende sotto la bocca quando e' appeso.
@export var hang_body_drop: float = 28.0
## Lenza: ancora (punta canna) + lunghezza corrente per pendolo fuori acqua.
var _tether_anchor: Vector2 = Vector2.ZERO
var _tether_length: float = 80.0
var _has_tether: bool = false
# Riferimento al water body per restare nei limiti dell'acqua
var _water_body: Node = null
## Margine dai bordi: i pesci restano distanti dai bordi dell'acqua
const WATER_BOUNDS_MARGIN: float = 38.0
var _breath_timer: float = 0.0
var _fish_base_scale: float = 0.1  # Salvata per evitare che il respiro faccia sparire il pesce
var _individual_speed_scale := 1.0
var _next_swim_change := 1.8
var _target_swim_direction := Vector2.RIGHT
var _swim_animation_time := 0.0
var _bait_target_active := false
var _bait_target := Vector2.ZERO
var _bait_linger_timer := 0.0
var _bait_target_node: Node2D = null
var _bitten_bait: Node2D = null
var _bait_bite_timer := 0.0

func _ready():
	add_to_group("fish")
	if bool(get_meta("tutorial_fish", false)):
		_configure_tutorial_fish()
	# Sopra l'acqua (10), sotto le briccole di primissimo piano (15/17).
	z_index = 12
	# Configurazione RigidBody2D per pesci
	lock_rotation = true
	rotation = 0.0
	gravity_scale = 0.0  # I pesci non cadono, nuotano
	# Nessuna risposta fisica alle collisioni: evita tremolio/glitch quando toccano qualcosa
	collision_mask = 0
	# Layer 8 (bit 128): la barca può rilevarci per il rinculo quando ci impatta
	collision_layer = 128

	# Trova water body per limiti acqua (se non già assegnato da set_water_body allo spawn)
	if _water_body == null:
		var waters = get_tree().get_nodes_in_group("water")
		for w in waters:
			if w.has_method("get_water_bounds_global_rect"):
				var r: Rect2 = w.call("get_water_bounds_global_rect")
				if r.has_point(global_position):
					_water_body = w
					break
		if _water_body == null and waters.size() > 0 and waters[0].has_method("get_water_bounds_global_rect"):
			_water_body = waters[0]

	spawn_position = global_position
	home_position = global_position + home_offset
	_find_sprite()
	if sprite != null:
		_fish_base_scale = abs(sprite.scale.x) if abs(sprite.scale.x) > 0.001 else 0.1
	_setup_underwater_shader()
	_setup_detection_area()
	_individual_speed_scale = randf_range(0.78, 1.18)
	if bool(get_meta("bait_giant", false)):
		_setup_bait_predator_fx()
		_bait_target = get_meta("bait_target_position", Vector2.ZERO) as Vector2
		var target_candidate: Variant = get_meta("bait_target_node", null)
		if target_candidate is Node2D and is_instance_valid(target_candidate):
			_bait_target_node = target_candidate as Node2D
			_bait_target = _bait_target_node.global_position
		_bait_target_active = _bait_target_node != null or _bait_target != Vector2.ZERO
		_bait_linger_timer = 0.0
	_next_swim_change = swim_change_interval * randf_range(0.72, 1.45)
	_pick_new_swim_direction()
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player:
		# L'animazione viene avanzata direttamente: evita cache invalide durante i cambi scena rapidi.
		animation_player.active = false


func _setup_bait_predator_fx() -> void:
	# Predatore attirato dalla carcassa: particelle sottili, blu-verdi, attorno
	# alla sagoma senza trasformarlo in un alone pieno.
	var motes := CPUParticles2D.new()
	motes.name = "BaitPredatorMotes"
	motes.amount = 10 if not OS.has_feature("mobile") else 5
	motes.lifetime = 0.9
	motes.preprocess = 0.25
	motes.explosiveness = 0.05
	motes.randomness = 0.8
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(34.0, 10.0)
	motes.direction = Vector2.UP
	motes.spread = 180.0
	motes.gravity = Vector2(0.0, -8.0)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 22.0
	motes.scale_amount_min = 0.22
	motes.scale_amount_max = 0.55
	motes.color = Color(0.38, 0.9, 0.84, 0.46)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	motes.texture = tex
	add_child(motes)


func _configure_tutorial_fish() -> void:
	# Il branco didattico resta visibile sotto il pontile e raggiunge rapidamente
	# l'amo: il tutorial deve insegnare la pesca, non cercare pesci fuori camera.
	natural_swim_speed = 32.0
	attraction_speed = 118.0
	swim_bounds_x = 48.0
	swim_bounds_y = 22.0
	home_offset = Vector2.ZERO
	min_depth_from_top = 36.0
	max_depth_from_top = 88.0
	turn_chance = 0.12
	vertical_wander = 0.12

func _setup_underwater_shader():
	# Applica distorsione leggera ai pesci quando sono in acqua
	if sprite is CanvasItem:
		var sh = load("res://fish_underwater_distort.gdshader") as Shader
		if sh != null:
			_underwater_material = ShaderMaterial.new()
			_underwater_material.shader = sh

func _find_sprite():
	sprite = get_node_or_null("Fishes")
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = get_node_or_null("Sprite")

## Chiamato dal water_body che spawna: il pesce deve restare dentro QUESTO water body
func set_water_body(wb: Node) -> void:
	if wb != null and wb.has_method("get_water_bounds_global_rect"):
		_water_body = wb

## Chiamato dall'acqua per usare uno sprite diverso (livrea). scale_sprite = stessa dimensione degli altri = 0.1
func set_fish_texture(tex: Texture2D, scale_sprite: float = 0.1) -> void:
	if tex == null:
		return
	_variant_sprite = true  # le varianti hanno la testa dall'altra parte, _update_sprite_direction inverte il flip
	_find_sprite()
	if sprite == null:
		return
	_fish_base_scale = scale_sprite
	if sprite is Sprite2D:
		var s = sprite as Sprite2D
		s.texture = tex
		s.hframes = 1
		s.vframes = 1
		s.frame = 0
		s.scale = Vector2(scale_sprite, scale_sprite)
	# Bocca: ricalcola da meta' texture (testa dall'altra parte gia' gestita da _variant_sprite).
	mouth_offset = -1.0
	hang_body_drop = maxf(22.0, absf(scale_sprite) * 220.0)

func _setup_detection_area():
	var existing_area = get_node_or_null("Area2D")
	var area: Area2D

	if existing_area == null:
		area = Area2D.new()
		area.name = "Area2D"
		add_child(area)

		var collision = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 25.0
		collision.shape = circle
		area.add_child(collision)
	else:
		area = existing_area

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.area_entered.is_connected(_on_area_entered):
		area.area_entered.connect(_on_area_entered)
	if not area.area_exited.is_connected(_on_area_exited):
		area.area_exited.connect(_on_area_exited)

func _physics_process(delta: float):
	# During a scene swap the old physics frame can still finish after current_scene
	# has changed. Do not touch transforms or rendering resources while our scene exits.
	var active_scene := get_tree().current_scene
	var under_active := active_scene != null and active_scene.is_ancestor_of(self)
	if not under_active and not _is_under_test_root():
		return
	_swim_animation_time += delta * _individual_speed_scale
	if hook_cooldown > 0:
		hook_cooldown -= delta
	if _flip_cooldown > 0:
		_flip_cooldown -= delta

	lock_rotation = true
	rotation = 0.0
	freeze = false
	collision_mask = 0
	gravity_scale = 0.0

	# Rientro acqua: anche da hang (puo' ricadere e tornare attivo).
	if _hanging:
		if _try_reenter_from_hang():
			pass
	elif not _catch_jump_active:
		_try_reenter_water()

	var above_surface: bool = _is_above_water_surface()
	# Sopra superficie in fase sbarco → hang (dopo il saltino).
	if (
		is_hooked_to_player
		and not _hanging
		and above_surface
		and (_catch_jump_active or _allow_surface_exit)
		and in_water
	):
		_start_hanging_out_of_water()

	if _hanging:
		_process_hooked_out_of_water(delta)
	elif in_water:
		if is_escaping and not _catch_jump_active:
			_process_escaping(delta)
		else:
			_process_swimming(delta)
			if _catch_jump_active:
				_process_surface_breach(delta)
	elif is_hooked_to_player:
		_start_hanging_out_of_water()
		_process_hooked_out_of_water(delta)
	elif _bait_target_active:
		# Il predatore nasce fuori dai limiti della laguna: resta comunque in
		# modalità nuoto mentre raggiunge la carcassa, senza essere fatto cadere
		# dal ramo "fuori acqua" o bloccato dal clamp dei bordi.
		in_water = true
		_set_hanging(false)
		_process_swimming(delta)
	else:
		_set_hanging(false)
		_process_falling(delta)

	linear_velocity = velocity
	if _hanging:
		_update_hanging_visual(delta)
	else:
		_update_sprite_direction()
	_update_sprite_color()
	_update_breathing(delta)
	_keep_near_top()

	if in_water and not _hanging and is_hooked_to_player and not _allow_surface_exit and not _catch_jump_active:
		_clamp_to_water_bounds()
		_clamp_below_surface(8.0)
	elif in_water and not _hanging and not is_hooked_to_player:
		_clamp_to_water_bounds()


func _is_under_test_root() -> bool:
	var n: Node = self
	while n != null:
		if n.has_meta("is_test_root"):
			return true
		n = n.get_parent()
	return false


## Rientro acqua: sotto superficie + dentro bacino → nuoto normale.
func _try_reenter_water() -> bool:
	var surface_y := _get_water_surface_y()
	if surface_y >= INF:
		return false
	if not _is_inside_water_bounds():
		return false
	if global_position.y < surface_y + 10.0:
		return false
	in_water = true
	_catch_jump_active = false
	_set_hanging(false)
	gravity_scale = 0.0
	freeze = false
	return true


## Da hang: se ricade sotto la superficie torna attivo in acqua (ancora agganciato).
func _try_reenter_from_hang() -> bool:
	if not _hanging:
		return false
	var surface_y := _get_water_surface_y()
	if surface_y >= INF:
		return false
	if not _is_inside_water_bounds():
		return false
	# Abbastanza sotto: rientra e nuota di nuovo.
	if global_position.y < surface_y + 16.0:
		return false
	in_water = true
	_catch_jump_active = false
	_allow_surface_exit = true
	_set_hanging(false)
	velocity.y = minf(velocity.y, 60.0)
	velocity.x *= 0.7
	gravity_scale = 0.0
	freeze = false
	return true

func _process_swimming(delta: float):
	var desired = Vector2.ZERO

	if is_hooked_to_player:
		var reeling_now := reel_force.length_squared() > 0.01
		# Reel smooth: verso la canna, senza scatti.
		if reeling_now:
			_reel_force_smoothed = _reel_force_smoothed.lerp(reel_force, delta * REEL_FORCE_SMOOTH)
			var reel_dir := _reel_force_smoothed.normalized()
			if _catch_jump_active or _allow_surface_exit:
				# Solo in uscita: piu' forza verso l'alto.
				reel_dir = Vector2(reel_dir.x * 0.55, minf(reel_dir.y, -0.7)).normalized()
				var exit_speed := clampf(_reel_force_smoothed.length() * 0.22, 90.0, 200.0)
				desired += reel_dir * exit_speed * reel_resistance
			else:
				reel_dir = Vector2(reel_dir.x, clampf(reel_dir.y, -0.4, 0.7)).normalized()
				var reel_speed := clampf(_reel_force_smoothed.length() * 0.12, 28.0, 85.0)
				desired += reel_dir * reel_speed * reel_resistance
		else:
			_reel_force_smoothed = _reel_force_smoothed.lerp(Vector2.ZERO, delta * 3.0)
		reel_force = reel_force.lerp(Vector2.ZERO, delta * 2.0)

		# Resistenza leggera (meno mentre reeli).
		var resist_mul := 0.15 if reeling_now else 0.7
		var resist_from: Vector2 = global_position
		if player_ref != null and is_instance_valid(player_ref):
			resist_from = (player_ref as Node2D).global_position
		elif target_hook != null and is_instance_valid(target_hook):
			resist_from = (target_hook as Node2D).global_position
		var away := global_position - resist_from
		away.y *= 0.2
		if away.length_squared() > 0.01:
			desired += away.normalized() * hooked_resist_strength * resist_mul

		# Dimenio orizzontale solo quando NON stai reelando (altrimenti scatta).
		if not reeling_now:
			_hooked_wander_angle += delta * 2.2
			desired.x += cos(_hooked_wander_angle) * 45.0 * resist_mul
			desired.y += sin(_hooked_wander_angle * 0.6) * 12.0 * resist_mul

		if is_struggling:
			struggle_timer -= delta
			if struggle_timer > 0.0:
				var sdir := Vector2(struggle_direction.x, struggle_direction.y * 0.3)
				if sdir.length_squared() > 0.01:
					desired += sdir.normalized() * struggle_strength * 0.7
			else:
				is_struggling = false

	elif _bait_target_active:
		# Il predatore entra dalla profondità/fuori campo e punta rapidamente alla
		# carcassa, senza richiedere un amo per restare in inseguimento.
		if _bait_target_node != null and is_instance_valid(_bait_target_node):
			_bait_target = _bait_target_node.global_position
		elif _bait_target_node != null:
			_bait_target_node = null
		var bait_dir := (_bait_target - global_position).normalized()
		# Arrivo prioritario: il predatore deve attraversare rapidamente il bordo
		# fuori campo, senza essere rallentato dal normale nuoto.
		var bait_speed := maxf(attraction_speed * 4.2, 300.0)
		desired = bait_dir * bait_speed
		if global_position.distance_to(_bait_target) < 34.0:
			_bait_target_active = false
			var transferred := false
			if _bait_target_node != null and is_instance_valid(_bait_target_node):
				_bitten_bait = _bait_target_node
				if _bait_target_node.has_method("on_predator_bite"):
					transferred = bool(_bait_target_node.call("on_predator_bite", self))
			if transferred:
				_bitten_bait = null
				_bait_bite_timer = 0.0
			else:
				_bait_bite_timer = 8.0
			_bait_linger_timer = 6.0
			home_position = _bait_target
			_pick_new_swim_direction()

	elif _bitten_bait != null and is_instance_valid(_bitten_bait) and _bait_bite_timer > 0.0:
		# Morso visibile anche se la carcassa è stata sganciata: il pesce resta
		# con la bocca sull'esca e la segue, invece di limitarsi a passarle vicino.
		_bait_bite_timer = maxf(0.0, _bait_bite_timer - delta)
		_bait_target = _bitten_bait.global_position
		var to_bitten_bait := _bait_target - global_position
		if to_bitten_bait.length() > 18.0:
			desired = to_bitten_bait.normalized() * maxf(attraction_speed * 2.1, 150.0)
		else:
			var bite_tangent := Vector2(-to_bitten_bait.y, to_bitten_bait.x).normalized() if to_bitten_bait.length_squared() > 1.0 else Vector2.RIGHT
			desired = to_bitten_bait * 4.2 + bite_tangent * 10.0

	elif _bait_linger_timer > 0.0:
		# Dopo l'ingresso resta in zona esca abbastanza a lungo da poter
		# abboccare: orbita lentamente invece di invertire e sparire.
		_bait_linger_timer = maxf(0.0, _bait_linger_timer - delta)
		var to_bait := _bait_target - global_position
		var orbit := Vector2(-to_bait.y, to_bait.x).normalized() if to_bait.length_squared() > 1.0 else Vector2.RIGHT
		desired = to_bait.normalized() * attraction_speed * 0.72 + orbit * natural_swim_speed * 0.5

	elif is_attracted and attraction_target != Vector2.ZERO:
		# Se l'amo/pastura è stata distrutta, torna a nuotare normale (così il pesce resta pescabile)
		if target_hook == null or not is_instance_valid(target_hook):
			is_attracted = false
			target_hook = null
			attraction_target = Vector2.ZERO
		else:
			# Aggiorna il target ogni frame se è un hook (così il pesce segue l'amo in movimento)
			attraction_target = target_hook.global_position
		var dir = (attraction_target - global_position).normalized()
		desired = dir * attraction_speed

		if attraction_target != Vector2.ZERO and global_position.distance_to(attraction_target) < 30.0:
			is_attracted = false
			# Hook solo con l'amo vero (fishing hook RigidBody2D), non con la pastura
			if target_hook != null and is_instance_valid(target_hook) and target_hook is RigidBody2D and target_hook.has_method("get_hook_type") and str(target_hook.call("get_hook_type")) == "fishing":
				_try_hook_to_player()
				# target_hook resta impostato: serve per la resistenza quando agganciato
			else:
				# Era pastura o amo distrutto: libera il ref così il pesce può abboccare a un nuovo amo
				target_hook = null
				attraction_target = Vector2.ZERO

	else:
		# Nuoto normale (movimento libero)
		swim_timer += delta
		if swim_timer >= _next_swim_change:
			swim_timer = 0.0
			_next_swim_change = swim_change_interval * randf_range(0.72, 1.45)
			_pick_new_swim_direction()

		swim_direction = swim_direction.slerp(_target_swim_direction, minf(1.0, delta * 1.35)).normalized()
		desired = swim_direction * natural_swim_speed * _individual_speed_scale

	# Boundary home: disattivato se agganciato, altrimenti combatte il reel e il pesce resta appeso.
	if not is_hooked_to_player:
		var offset = global_position - home_position
		if offset.x > swim_bounds_x:
			desired.x -= boundary_push
		elif offset.x < -swim_bounds_x:
			desired.x += boundary_push
		if offset.y > swim_bounds_y:
			desired.y -= boundary_push
		elif offset.y < -swim_bounds_y:
			desired.y += boundary_push

	# Reel: risposta calma (niente strattone eccessivo).
	var reeling_hooked := is_hooked_to_player and reel_force.length_squared() > 0.01
	var response := swim_response * (0.9 if reeling_hooked else 1.0)
	velocity = velocity.lerp(desired, delta * response)
	if is_hooked_to_player:
		velocity *= 0.96
		var speed_cap := hooked_max_speed * (1.05 if reeling_hooked else 0.9)
		if velocity.length() > speed_cap:
			velocity = velocity.normalized() * speed_cap
	else:
		velocity *= water_damping

func _get_water_bounds_rect() -> Rect2:
	if _water_body != null and is_instance_valid(_water_body) and _water_body.has_method("get_water_bounds_global_rect"):
		var r: Rect2 = _water_body.get_water_bounds_global_rect()
		# Margine interno così il pesce non sta sul bordo
		return Rect2(r.position.x + WATER_BOUNDS_MARGIN, r.position.y + WATER_BOUNDS_MARGIN, r.size.x - WATER_BOUNDS_MARGIN * 2, r.size.y - WATER_BOUNDS_MARGIN * 2)
	# Fallback: limiti attorno a home (comportamento precedente)
	return Rect2(home_position.x - swim_bounds_x, home_position.y - swim_bounds_y, swim_bounds_x * 2, swim_bounds_y * 2)

func _clamp_to_water_bounds():
	if _bait_target_active:
		return
	var r := _get_water_bounds_rect()
	var p := global_position
	p.x = clampf(p.x, r.position.x, r.position.x + r.size.x)
	p.y = clampf(p.y, r.position.y, r.position.y + r.size.y)
	global_position = p


func _clamp_below_surface(min_depth: float = 10.0) -> void:
	var water_area = _find_water_area()
	if water_area == null:
		return
	var surface_y: float = water_area.global_position.y
	if "target_height" in water_area:
		surface_y += water_area.target_height
	var floor_y := surface_y + min_depth
	if global_position.y < floor_y:
		global_position.y = floor_y
		if velocity.y < 0.0:
			velocity.y = 0.0
		if linear_velocity.y < 0.0:
			linear_velocity.y = 0.0

func _process_escaping(delta: float):
	# Nuota via nella direzione di fuga ma RESTA nei limiti del water body
	escape_timer -= delta
	
	var desired = escape_direction * escape_speed
	
	# Rallenta gradualmente e torna a nuotare normale
	var escape_progress = 1.0 - (escape_timer / escape_duration)
	desired = desired.lerp(Vector2.ZERO, escape_progress * 0.6)
	
	# Boundary verso interno se ci avviciniamo al bordo del water body
	var r := _get_water_bounds_rect()
	var p := global_position
	if p.x >= r.position.x + r.size.x - 5:
		desired.x -= boundary_push
	elif p.x <= r.position.x + 5:
		desired.x += boundary_push
	if p.y >= r.position.y + r.size.y - 5:
		desired.y -= boundary_push
	elif p.y <= r.position.y + 5:
		desired.y += boundary_push
	
	velocity = velocity.lerp(desired, delta * swim_response * 1.2)
	velocity *= water_damping
	
	# Clamp: pesce non esce mai dai limiti del water body
	_clamp_to_water_bounds()
	
	if escape_timer <= 0:
		is_escaping = false
		# Aggiorna la home position alla nuova posizione
		home_position = global_position
		_pick_new_swim_direction()

## Fuori acqua: gravita' + lenza a raggio MAX (niente allungo / snap lungo).
func _process_hooked_out_of_water(delta: float):
	_set_hanging(true)
	in_water = false

	var reeling_hang := reel_force.length_squared() > 0.01 and _has_tether

	velocity.y += AIR_GRAVITY * delta
	velocity.x *= 0.999

	if reeling_hang:
		_reel_force_smoothed = _reel_force_smoothed.lerp(reel_force, delta * 2.2)
		var to_rod := _tether_anchor - global_position
		var dist := to_rod.length()
		if dist > 0.01:
			var radial := to_rod / dist
			var hang_speed := clampf(_reel_force_smoothed.length() * 0.045, 28.0, 70.0)
			var radial_v := velocity.dot(radial)
			velocity += radial * maxf(0.0, hang_speed - radial_v) * delta * 4.0
	else:
		_reel_force_smoothed = _reel_force_smoothed.lerp(Vector2.ZERO, delta * 2.0)

	reel_force = reel_force.lerp(Vector2.ZERO, delta * 1.8)
	# Solo limite massimo: se la lenza e' piu' lunga non "stirarla" fino al raggio.
	_constrain_hanging_to_line(false)


## Punto di attacco lenza = bocca (Marker2D "Mouth" se presente).
func get_line_attach_point() -> Vector2:
	var mouth_mark := get_node_or_null("Mouth") as Node2D
	if mouth_mark != null:
		return mouth_mark.global_position
	if _hanging:
		return global_position
	return global_position + _mouth_offset_swim()


func get_hang_tether_length() -> float:
	return _tether_length if _has_tether else 0.0


func is_catch_jump_active() -> bool:
	return _catch_jump_active


func is_hanging() -> bool:
	return _hanging


func _head_facing_x() -> float:
	# +1 = testa a destra, -1 = testa a sinistra.
	if sprite == null:
		return -1.0
	var facing_right := sprite.scale.x < 0.0
	if _variant_sprite:
		facing_right = not facing_right
	return 1.0 if facing_right else -1.0


func _computed_mouth_offset() -> float:
	if mouth_offset > 0.0:
		return mouth_offset
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		if s.texture != null:
			var frame_w := float(s.texture.get_width()) / maxf(1.0, float(s.hframes))
			return frame_w * absf(s.scale.x) * 0.38
	return 14.0


func _mouth_offset_swim() -> Vector2:
	return Vector2(_head_facing_x() * _computed_mouth_offset(), -2.0)


func _mouth_local_from_center() -> Vector2:
	# Offset bocca dal centro texture (spazio locale, senza flip).
	var ox := _computed_mouth_offset()
	if _variant_sprite:
		# sarago/boops: bocca a destra nella texture.
		return Vector2(ox, -1.0)
	# fishes.png: bocca a sinistra.
	return Vector2(-ox, -1.0)


func _mouth_to_tail_local() -> Vector2:
	# Direzione testa→coda nella texture (lato lungo del pesce).
	return Vector2.LEFT if _variant_sprite else Vector2.RIGHT


func _set_hanging(enabled: bool) -> void:
	if _hanging == enabled:
		return
	if enabled:
		var mouth_mark := get_node_or_null("Mouth") as Node2D
		if mouth_mark != null:
			global_position = mouth_mark.global_position
		else:
			global_position += _mouth_offset_swim()
		_hanging = true
		_apply_hanging_pose(Vector2.DOWN)
	else:
		if sprite != null:
			global_position += sprite.position
			sprite.position = Vector2.ZERO
			sprite.rotation = 0.0
		_hanging = false


func _apply_hanging_pose(body_dir: Vector2) -> void:
	if sprite == null:
		return
	var base := absf(_fish_base_scale)
	sprite.scale = Vector2(base, base)
	var dir := body_dir.normalized() if body_dir.length_squared() > 0.0001 else Vector2.DOWN
	var axis := _mouth_to_tail_local()
	sprite.rotation = dir.angle() - axis.angle()
	# Origine nodo = bocca: sposta lo sprite cosi' la bocca resta sull'amo.
	sprite.position = -_mouth_local_from_center().rotated(sprite.rotation)


func _update_hanging_visual(_delta: float) -> void:
	if sprite == null or not _hanging:
		return
	var body_dir := Vector2.DOWN
	if _has_tether:
		var along := global_position - _tether_anchor
		if along.length_squared() > 4.0:
			body_dir = along.normalized()
	_apply_hanging_pose(body_dir)


func set_line_tether(anchor: Vector2, length: float) -> void:
	_tether_anchor = anchor
	_tether_length = maxf(length, 18.0)
	_has_tether = true


func clear_line_tether() -> void:
	_has_tether = false


## Bocca agganciata: lenza TESA (raggio fisso) → dondola come pendolo.
func _constrain_hanging_to_line(taut: bool = false) -> void:
	if not _has_tether:
		return
	var offset := global_position - _tether_anchor
	var dist := offset.length()
	var len := _tether_length
	if dist < 0.001:
		global_position = _tether_anchor + Vector2(0.0, len)
		velocity.x *= 0.98
		return
	var n := offset / dist
	# Appeso: sempre tesa. Altrimenti solo limite massimo.
	if taut or dist > len:
		global_position = _tether_anchor + n * len
		# Togli solo la velocita' radiale: resta lo swing tangenziale.
		var radial_v := velocity.dot(n)
		velocity -= n * radial_v


func _apply_line_tether_constraint() -> void:
	_constrain_hanging_to_line(true)


func _apply_soft_line_tether(_delta: float) -> void:
	_constrain_hanging_to_line(true)


## Fuori acqua (non agganciato): ricade / rientra nel bacino.
func _process_falling(delta: float):
	velocity.y += AIR_GRAVITY * delta
	velocity.x *= 0.999
	if _try_reenter_water():
		velocity.y = minf(velocity.y, 40.0)
		_clamp_to_water_bounds()


func _get_water_surface_y() -> float:
	var water_area = _find_water_area()
	if water_area == null:
		return INF
	var surface_y: float = water_area.global_position.y
	if "target_height" in water_area:
		surface_y += water_area.target_height
	return surface_y


func _is_inside_water_bounds() -> bool:
	var r := _get_water_bounds_rect()
	var expanded := Rect2(r.position - Vector2(20, 12), r.size + Vector2(40, 24))
	return expanded.has_point(global_position)


func _pick_new_swim_direction():
	# Conserva una rotta coerente e cambia lato solo occasionalmente.
	# La vecchia formula produceva quasi sempre angoli verso sinistra e scatti innaturali.
	var horizontal_sign := signf(swim_direction.x)
	if is_zero_approx(horizontal_sign):
		horizontal_sign = -1.0 if randf() < 0.5 else 1.0
	if randf() < turn_chance:
		horizontal_sign *= -1.0
	var vertical := randf_range(-vertical_wander, vertical_wander)
	_target_swim_direction = Vector2(horizontal_sign, vertical).normalized()
	if swim_direction.length_squared() < 0.1:
		swim_direction = _target_swim_direction

func _update_sprite_direction():
	if sprite == null:
		return
	
	# Una lieve inclinazione segue la traiettoria; resta contenuta per non sembrare rotazione rigida.
	var target_pitch := clampf(velocity.y / maxf(1.0, natural_swim_speed) * 0.12, -0.12, 0.12)
	sprite.rotation = lerpf(sprite.rotation, target_pitch, 0.08)
	if sprite is Sprite2D:
		var fish_sprite := sprite as Sprite2D
		if fish_sprite.hframes * fish_sprite.vframes >= 5:
			fish_sprite.frame = 1 + int(_swim_animation_time * 8.0) % 4

	# Flip solo se la velocità è chiara e non siamo in cooldown (evita "impazzire" a destra/sinistra)
	if _flip_cooldown > 0:
		return
	# Sprite varianti (boops/sarago) sono disegnati con la testa dall'altra parte: inverti il flip
	var flip_right: float = -abs(sprite.scale.x)
	var flip_left: float = abs(sprite.scale.x)
	if _variant_sprite:
		flip_right = abs(sprite.scale.x)
		flip_left = -abs(sprite.scale.x)
	if velocity.x > FLIP_VELOCITY_THRESHOLD:
		sprite.scale.x = flip_right
		_flip_cooldown = FLIP_COOLDOWN_TIME
	elif velocity.x < -FLIP_VELOCITY_THRESHOLD:
		sprite.scale.x = flip_left
		_flip_cooldown = FLIP_COOLDOWN_TIME

func _update_breathing(delta: float):
	if sprite == null or _hanging:
		return
	_breath_timer += delta
	var t = sin(_breath_timer * 2.6)
	var breath_y = 1.0 + 0.02 * t
	var breath_x = 1.0 - 0.025 * t
	var base = _fish_base_scale
	var sign_x = 1.0 if sprite.scale.x >= 0 else -1.0
	sprite.scale.x = sign_x * base * breath_x
	sprite.scale.y = base * breath_y
	# In hang non toccare position (corpo gia' sotto la bocca).

func _update_sprite_color():
	if sprite == null:
		return
	
	# Shader distorsione solo quando in acqua
	if sprite is CanvasItem and _underwater_material != null:
		(sprite as CanvasItem).material = _underwater_material if in_water else null
	
	var target_color = normal_color
	
	if _wrong_reel:
		target_color = wrong_reel_color
	elif is_escaping:
		target_color = escape_color
	elif is_struggling:
		target_color = struggle_color
	elif is_hooked_to_player:
		target_color = normal_color.lerp(struggle_color, 0.3)
	
	sprite.modulate = sprite.modulate.lerp(target_color, 0.15)

func _try_hook_to_player():
	# Non può essere agganciato durante il cooldown
	if hook_cooldown > 0:
		return
	
	if player_ref != null:
		if player_ref.has_method("on_fish_hooked"):
			player_ref.call("on_fish_hooked", self)
		elif player_ref.has_method("on_fish_spawned"):
			player_ref.call("on_fish_spawned", self)
		is_hooked_to_player = true

# ===========================================
# COLLISION
# ===========================================
func _on_body_entered(body: Node2D):
	if is_hooked_to_player or is_escaping or hook_cooldown > 0:
		return

	if body is RigidBody2D:
		if body.has_method("get_line_attach_point") or "hook" in body.name.to_lower():
			_on_hook_detected(body)

func _on_area_entered(area: Area2D):
	if is_hooked_to_player or is_escaping or hook_cooldown > 0:
		return

	var an = area.name.to_lower()
	var pn = area.get_parent().name.to_lower() if area.get_parent() else ""
	if "water" in an or "water" in pn or area.is_in_group("water"):
		in_water = true
		return

	var parent = area.get_parent()
	if parent != null:
		if parent is RigidBody2D or parent.has_method("get_line_attach_point"):
			_on_hook_detected(parent)

func _on_area_exited(area: Area2D):
	# Pesce che scappa: non considerarlo "uscito" dall'acqua, altrimenti cade nel vuoto
	if is_escaping:
		return
	var an = area.name.to_lower()
	var pn = area.get_parent().name.to_lower() if area.get_parent() else ""
	if "water" in an or "water" in pn or area.is_in_group("water"):
		# Se sei ancora sotto superficie nel bacino, resti in acqua.
		if _try_reenter_water():
			return
		in_water = false

func _on_hook_detected(hook: Node):
	# Non reagire se in cooldown o già agganciato
	if hook_cooldown > 0 or is_hooked_to_player or is_escaping:
		return
	
	target_hook = hook

	if hook.has_method("get_player_reference"):
		player_ref = hook.call("get_player_reference")
	elif "player_ref" in hook:
		player_ref = hook.player_ref

	attract_to(hook.global_position)

# ===========================================
# RELEASE - Chiamato quando il pesce scappa
# ===========================================
func release_from_hook():
	print("🐟 Pesce liberato! Resta in acqua e nuota via...")
	
	# SEMPRE: pesce in acqua, mai cadere o fluttuare nel vuoto
	gravity_scale = 0.0
	freeze = false
	collision_mask = 0
	in_water = true
	
	# Azzera stato aggancio
	is_hooked_to_player = false
	is_attracted = false
	is_struggling = false
	struggle_timer = 0.0
	reel_force = Vector2.ZERO
	_wrong_reel = false
	_allow_surface_exit = false
	_catch_jump_active = false
	_has_tether = false
	_set_hanging(false)
	_reel_force_smoothed = Vector2.ZERO
	player_ref = null
	target_hook = null
	
	# Se fuori dall'acqua (reeled out): teleporta dentro l'acqua
	if _water_body != null and is_instance_valid(_water_body) and _water_body.has_method("get_water_bounds_global_rect"):
		var r: Rect2 = _water_body.call("get_water_bounds_global_rect")
		var p := global_position
		if p.y < r.position.y or p.x < r.position.x or p.x > r.position.x + r.size.x or p.y > r.position.y + r.size.y:
			p.x = clampf(p.x, r.position.x + WATER_BOUNDS_MARGIN, r.position.x + r.size.x - WATER_BOUNDS_MARGIN)
			p.y = clampf(p.y, r.position.y + WATER_BOUNDS_MARGIN, r.position.y + r.size.y - WATER_BOUNDS_MARGIN)
			global_position = p
	_try_reenter_water()
	
	# Resta dove si è liberato: home = posizione attuale, torna subito a nuotare normale
	home_position = global_position + home_offset
	velocity = Vector2.ZERO
	is_escaping = false
	_pick_new_swim_direction()
	
	hook_cooldown = hook_cooldown_time

# ===========================================
# API
# ===========================================
func set_player_reference(player: Node):
	player_ref = player
	is_hooked_to_player = true
	is_attracted = false
	is_escaping = false
	_allow_surface_exit = false
	_catch_jump_active = false
	freeze = false
	_reel_force_smoothed = Vector2.ZERO  # reset smooth quando si aggancia
	_try_reenter_water()
func attract_to(target_pos: Vector2):
	if hook_cooldown > 0 or is_escaping:
		return
	attraction_target = target_pos
	is_attracted = true

func apply_reel_force(force: Vector2):
	# Non sovrascrivere bruscamente: il smoothing è in _process_swimming
	reel_force = force


## Tiro a lenza: velocita' smooth + piccolo passo verso la canna.
func pull_along_line(rod_pos: Vector2, amount: float, allow_exit: bool = false) -> void:
	if amount <= 0.0 or not is_hooked_to_player:
		return
	var to_rod := rod_pos - global_position
	if to_rod.length_squared() < 0.0001:
		return
	var dir := to_rod.normalized()
	var exiting := allow_exit or _allow_surface_exit or _hanging
	if not exiting:
		dir = Vector2(dir.x, clampf(dir.y, -0.35, 0.75)).normalized()
	elif not _hanging:
		dir = Vector2(dir.x * 0.55, minf(dir.y, -0.7)).normalized()
	var target_speed := clampf(amount * 18.0, 22.0, 70.0)
	var step := clampf(amount * 0.7, 1.5, 10.0)
	if exiting and not _hanging:
		target_speed = clampf(amount * 14.0, 22.0, 72.0)
		step = clampf(amount * 0.45, 1.2, 5.5)
	velocity = velocity.lerp(dir * target_speed, 0.12 if not exiting else 0.16)
	if _hanging and _has_tether:
		var to_anchor := global_position - _tether_anchor
		var d := to_anchor.length()
		if d > 0.01:
			var radial_in := -to_anchor / d
			global_position += radial_in * minf(step, maxf(0.0, d - 18.0))
			_tether_length = maxf(18.0, d - step)
			var rv := velocity.dot(radial_in)
			if rv < 0.0:
				velocity -= radial_in * rv
			_constrain_hanging_to_line(true)
	else:
		global_position += dir * minf(step, to_rod.length())
	linear_velocity = velocity
	if exiting and (_is_above_water_surface() or _hanging):
		in_water = false
	elif not exiting:
		_clamp_below_surface(6.0)
		_clamp_to_water_bounds()


func apply_struggle_force(force: Vector2):
	if is_hooked_to_player:
		velocity += force
		if velocity.length() > hooked_max_speed:
			velocity = velocity.normalized() * hooked_max_speed


func start_struggle():
	is_struggling = true
	struggle_timer = struggle_duration
	if player_ref != null and is_instance_valid(player_ref):
		struggle_direction = (global_position - player_ref.global_position).normalized()
	else:
		var angle = randf() * TAU
		struggle_direction = Vector2(cos(angle), sin(angle)).normalized()


func stop_struggle():
	is_struggling = false
	struggle_timer = 0.0


## Saltino fuori acqua → poi hang / possibile rientro.
func do_catch_jump():
	_allow_surface_exit = true
	_catch_jump_active = true
	freeze = false
	gravity_scale = 0.0
	in_water = true
	if _hanging:
		_set_hanging(false)
	# Hop verso l'alto: deve uscire nettamente sopra la superficie.
	var hop := Vector2(clampf(velocity.x * 0.4, -55.0, 55.0), -240.0)
	if _has_tether:
		var to_rod := _tether_anchor - global_position
		if to_rod.length_squared() > 0.01:
			var n := to_rod.normalized()
			hop = Vector2(n.x * 48.0, minf(n.y * 160.0, -210.0))
	velocity = hop
	var surf := _get_water_surface_y()
	if surf < INF:
		var depth := global_position.y - surf
		if depth > 0.0:
			# Avvicina alla superficie senza uscire ancora (l'hang parte dopo il breach).
			global_position.y -= minf(depth * 0.45, 36.0)
		elif global_position.y > surf - 28.0:
			# Gia' a pelo d'acqua / sopra: porta la bocca piu' in alto.
			global_position.y = surf - 28.0
	if _is_above_water_surface():
		_start_hanging_out_of_water()


## Passaggio acqua → hang (lenza = distanza attuale, niente allungo).
func _start_hanging_out_of_water() -> void:
	if _hanging:
		return
	_allow_surface_exit = true
	_catch_jump_active = true
	in_water = false
	var surf := _get_water_surface_y()
	_spawn_water_exit_effect(surf)
	# Bocca ben sopra la superficie cosi' il corpo appeso non resta mezzo in acqua.
	const EXIT_CLEARANCE := 48.0
	if surf < INF and global_position.y > surf - EXIT_CLEARANCE:
		global_position.y = surf - EXIT_CLEARANCE
	# Velocita' da saltino, non da catapulta.
	velocity.x = clampf(velocity.x, -120.0, 120.0)
	velocity.y = clampf(velocity.y, -200.0, 20.0)
	_set_hanging(true)
	if _has_tether:
		# Lenza al massimo = distanza corrente (non stirare oltre).
		_tether_length = maxf(28.0, global_position.distance_to(_tether_anchor))
		_constrain_hanging_to_line(false)


## Splash + gocce quando il pesce esce dall'acqua.
func _spawn_water_exit_effect(surf_y: float) -> void:
	var splash_y := surf_y if surf_y < INF else global_position.y
	var splash_pos := Vector2(global_position.x, splash_y)
	var water: Node = _find_water_area()
	if water != null and water.has_method("splash_at"):
		water.call("splash_at", splash_pos.x, 320.0, 96.0)
	var parent_n := get_parent()
	if parent_n == null:
		return
	var burst := CPUParticles2D.new()
	burst.name = "FishExitSplash"
	burst.z_index = 13
	burst.emitting = false
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.amount = 8 if OS.get_name() == "Android" or OS.has_feature("mobile") else 22
	burst.lifetime = 0.45
	burst.preprocess = 0.0
	burst.direction = Vector2(0, -1)
	burst.spread = 55.0
	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 180.0
	burst.gravity = Vector2(0, 520)
	burst.scale_amount_min = 1.2
	burst.scale_amount_max = 2.6
	burst.color = Color(0.72, 0.88, 0.95, 0.85)
	parent_n.add_child(burst)
	burst.global_position = splash_pos
	burst.emitting = true
	# Cleanup sicuro (signal finished non sempre affidabile su CPUParticles).
	burst.get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)


## Durante l'uscita: spinta verso (e oltre) la superficie.
func _process_surface_breach(delta: float) -> void:
	var surf := _get_water_surface_y()
	if surf < INF:
		var depth := global_position.y - surf
		if depth > -36.0:
			# Continua a salire finche' non e' abbastanza sopra acqua.
			velocity.y -= (280.0 + maxf(depth, 0.0) * 5.0) * delta
			velocity.y = maxf(velocity.y, -280.0)
	if _has_tether:
		var to_rod := _tether_anchor - global_position
		if to_rod.length_squared() > 0.01:
			velocity = velocity.lerp(to_rod.normalized() * 140.0, delta * 2.4)


func set_allow_surface_exit(allowed: bool) -> void:
	# Mai interrompere un'uscita / hang gia' avviati.
	if _hanging or _catch_jump_active:
		_allow_surface_exit = true
		return
	_allow_surface_exit = allowed
	if not allowed:
		_try_reenter_water()

func set_wrong_reel(active: bool):
	_wrong_reel = active

func is_hooked() -> bool:
	return is_hooked_to_player

func is_in_water() -> bool:
	return in_water

func set_in_water(water: bool):
	in_water = water

## True se il pesce è vicino al player (reel zone): ignora limiti acqua e viene reelato / può uscire
func _in_reel_zone() -> bool:
	if player_ref == null or not is_instance_valid(player_ref):
		return false
	var player_2d := player_ref as Node2D
	if player_2d == null:
		return false
	var offset: Vector2 = global_position - player_2d.global_position
	return absf(offset.x) <= reel_zone_radius and absf(offset.y) <= reel_zone_radius * 2.2

## True se la posizione del pesce è sopra la superficie dell'acqua (Y minore = più in alto)
func _is_above_water_surface() -> bool:
	var water_area = _find_water_area()
	if water_area == null:
		return false
	var surface_y: float = water_area.global_position.y
	if "target_height" in water_area:
		surface_y += water_area.target_height
	return global_position.y < surface_y + 8.0

## True se il pesce è vicino alla superficie (può uscire / saltare anche con collider)
func is_near_surface() -> bool:
	if not in_water:
		return true
	var water_area = _find_water_area()
	if water_area == null:
		return false
	var surface_y: float = water_area.global_position.y
	if "target_height" in water_area:
		surface_y += water_area.target_height
	var depth: float = global_position.y - surface_y
	return depth <= near_surface_depth

func is_available_for_hook() -> bool:
	return not is_hooked_to_player and not is_escaping and hook_cooldown <= 0

# ===========================================
# ZONA NUOTO - Mantieni i pesci vicini alla parte alta dell'acqua
# ===========================================
func _keep_near_top():
	if not in_water:
		return
	
	var water_area = _find_water_area()
	if water_area == null:
		return
	
	var water_surface_y = water_area.global_position.y + water_area.target_height
	var current_depth_from_surface: float = global_position.y - water_surface_y
	
	# Fase sbarco attiva: spingi verso la superficie.
	if is_hooked_to_player and (_allow_surface_exit or _catch_jump_active):
		if current_depth_from_surface > 2.0:
			velocity.y -= current_depth_from_surface * 5.5
		return
	
	# Troppo in basso: spingi verso l'alto (resta entro la fascia)
	if current_depth_from_surface > max_depth_from_top:
		var push_up: float = (current_depth_from_surface - max_depth_from_top) * 2.0
		velocity.y -= push_up
	elif current_depth_from_surface < -15.0:
		# Sopra la superficie: spingi verso il basso
		velocity.y += 1.5
	elif current_depth_from_surface < min_depth_from_top:
		# Troppo sul bordo: spingi più in giù (non restare troppo in superficie)
		var push_down: float = (min_depth_from_top - current_depth_from_surface) * 1.2
		velocity.y += push_down

func _find_water_area():
	var water_nodes = get_tree().get_nodes_in_group("water")
	if water_nodes.size() == 0:
		return null
	
	# Trova l'acqua più vicina
	var closest = water_nodes[0]
	var min_dist = global_position.distance_to(closest.global_position)
	
	for water in water_nodes:
		var dist = global_position.distance_to(water.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = water
	
	return closest

# ===========================================
# DEBUG
# ===========================================
func get_status() -> String:
	if is_hooked_to_player:
		if is_struggling:
			return "LOTTA"
		return "AGGANCIATO"
	if is_escaping:
		return "SCAPPA"
	if is_attracted:
		return "ATTRATTO"
	if hook_cooldown > 0:
		return "COOLDOWN"
	return "NUOTA"
