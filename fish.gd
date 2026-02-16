extends RigidBody2D

# ===========================================
# FISH - Pesce che nuota e può essere pescato
# ===========================================
# Quando scappa dall'amo, torna a nuotare liberamente
# invece di sparire

@export_category("Movement")
@export var natural_swim_speed: float = 85.0
@export var attraction_speed: float = 72.0
@export var swim_change_interval: float = 0.9
@export var escape_speed: float = 65.0
@export var escape_duration: float = 2.2

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
@export var reel_zone_radius: float = 100.0
## Sotto questa profondità dalla superficie il pesce è "vicino al bordo" e può uscire (salto)
@export var near_surface_depth: float = 70.0

@export_category("Physics")
@export var swim_response: float = 3.0
@export var water_damping: float = 0.98
@export var boundary_push: float = 80.0

@export_category("Struggle")
@export var struggle_strength: float = 320.0
@export var struggle_duration: float = 1.5
@export var reel_resistance: float = 0.95
## Resistenza costante verso l'amo quando agganciato (nuota via)
@export var hooked_resist_strength: float = 24.0
## Velocità max quando agganciato: più alta = reel avvicina bene il pesce
@export var hooked_max_speed: float = 130.0
## Damping più forte quando agganciato (movimento più fluido)
@export var hooked_damping: float = 0.92

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
const REEL_FORCE_SMOOTH: float = 4.0

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
# Riferimento al water body per restare nei limiti dell'acqua
var _water_body: Node = null
## Margine dai bordi: i pesci restano distanti dai bordi dell'acqua
const WATER_BOUNDS_MARGIN: float = 38.0
var _breath_timer: float = 0.0
var _fish_base_scale: float = 0.1  # Salvata per evitare che il respiro faccia sparire il pesce

func _ready():
	add_to_group("fish")
	# z_index > water (10): pesci visibili sopra l'acqua
	z_index = 15
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
	_pick_new_swim_direction()

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
	# Aggiorna cooldown
	if hook_cooldown > 0:
		hook_cooldown -= delta
	if _flip_cooldown > 0:
		_flip_cooldown -= delta
	
	# FORZA: blocca sempre la rotazione
	lock_rotation = true
	rotation = 0.0
	
	# Assicura che lo sprite non ruoti mai
	if sprite != null:
		sprite.rotation = 0.0
	
	# Se agganciato e sopra la superficie (ma non in reel zone): gravità lo riporta in acqua
	var above_surface: bool = _is_above_water_surface()
	var use_gravity_out_of_water: bool = is_hooked_to_player and above_surface and not _in_reel_zone()
	var effectively_in_water: bool = in_water and not use_gravity_out_of_water

	if effectively_in_water:
		if is_escaping:
			_process_escaping(delta)
		else:
			_process_swimming(delta)
	else:
		if is_hooked_to_player:
			_process_hooked_out_of_water(delta)
		else:
			_process_falling(delta)

	# Usa linear_velocity invece di modificare global_position direttamente
	linear_velocity = velocity
	_update_sprite_direction()
	_update_sprite_color()
	_update_breathing(delta)
	
	# Mantieni i pesci vicini alla parte alta dell'acqua (in reel zone non spingiamo giù)
	_keep_near_top()
	# Resta dentro i limiti del water body; in reel zone vicino al player non clampare così può uscire / essere reelato
	if effectively_in_water and not (is_hooked_to_player and _in_reel_zone()):
		_clamp_to_water_bounds()
	# Se era sopra superficie e ora è ridisceso in acqua, torna a nuotare (gravity_scale resta 0)
	if use_gravity_out_of_water and not _is_above_water_surface() and _water_body != null:
		in_water = true
		gravity_scale = 0.0

func _process_swimming(delta: float):
	var desired = Vector2.ZERO

	if is_hooked_to_player:
		# Reel force: smooth per evitare tremolio (direzione non salta frame a frame)
		if reel_force.length_squared() > 0.01:
			_reel_force_smoothed = _reel_force_smoothed.lerp(reel_force, delta * REEL_FORCE_SMOOTH)
			desired += _reel_force_smoothed * reel_resistance
		else:
			_reel_force_smoothed = _reel_force_smoothed.lerp(Vector2.ZERO, delta * 5.0)
		reel_force = reel_force.lerp(Vector2.ZERO, delta * 3.0)

		# Resistenza costante: nuota via dall'amo (più sfida)
		if target_hook != null and is_instance_valid(target_hook):
			var away = (global_position - target_hook.global_position).normalized()
			desired += away * hooked_resist_strength

		# Struggle: lotta via dal player
		if is_struggling:
			struggle_timer -= delta
			if struggle_timer > 0.0:
				desired += struggle_direction * struggle_strength
			else:
				is_struggling = false

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
		if swim_timer >= swim_change_interval:
			swim_timer = 0.0
			_pick_new_swim_direction()

		desired = swim_direction * natural_swim_speed

	# Boundary steering: in reel zone vicino al player non spingere verso i bordi, così il pesce va diritto verso il player
	if not (is_hooked_to_player and _in_reel_zone()):
		var offset = global_position - home_position
		if offset.x > swim_bounds_x:
			desired.x -= boundary_push
		elif offset.x < -swim_bounds_x:
			desired.x += boundary_push
		if offset.y > swim_bounds_y:
			desired.y -= boundary_push
		elif offset.y < -swim_bounds_y:
			desired.y += boundary_push

	velocity = velocity.lerp(desired, delta * swim_response)
	# Quando agganciato: damping più forte e cap velocità per evitare tremolio
	if is_hooked_to_player:
		velocity *= hooked_damping
		if velocity.length() > hooked_max_speed:
			velocity = velocity.normalized() * hooked_max_speed
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
	var r := _get_water_bounds_rect()
	var p := global_position
	p.x = clampf(p.x, r.position.x, r.position.x + r.size.x)
	p.y = clampf(p.y, r.position.y, r.position.y + r.size.y)
	global_position = p

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

## Fuori acqua ma agganciato: peso morto (gravità) + reel verso il player così resta appeso e puoi tirarlo
func _process_hooked_out_of_water(delta: float):
	var desired := Vector2.ZERO
	# Reel: verso il player/amo così puoi reelarlo e mangiarlo
	if reel_force.length_squared() > 0.01:
		_reel_force_smoothed = _reel_force_smoothed.lerp(reel_force, delta * REEL_FORCE_SMOOTH)
		desired += _reel_force_smoothed * reel_resistance * 1.4
	else:
		_reel_force_smoothed = _reel_force_smoothed.lerp(Vector2.ZERO, delta * 3.0)
	reel_force = reel_force.lerp(Vector2.ZERO, delta * 2.0)
	# Peso morto: gravità
	desired.y += 400.0 * delta
	velocity = velocity.lerp(desired, delta * 5.0)
	velocity.y += 280.0 * delta
	velocity.x *= 0.97

func _process_falling(delta: float):
	velocity.y += 980.0 * delta
	velocity.x *= 0.98

func _pick_new_swim_direction():
	# Movimento libero (non solo orizzontale)
	# I pesci Go' si muovono poco dal fondale, quindi preferiscono movimento orizzontale
	# ma possono anche muoversi leggermente in verticale
	var angle = randf() * TAU
	# Preferisci angoli più orizzontali (pesci sul fondale)
	var horizontal_bias = 0.3  # 0.3 = più orizzontale, 1.0 = completamente random
	var adjusted_angle = angle * horizontal_bias + (PI/2) * (1.0 - horizontal_bias)
	swim_direction = Vector2(cos(adjusted_angle), sin(adjusted_angle) * 0.5).normalized()

func _update_sprite_direction():
	if sprite == null:
		return
	
	# FORZA: lo sprite non deve mai ruotare
	sprite.rotation = 0.0

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
	if sprite == null:
		return
	_breath_timer += delta
	var t = sin(_breath_timer * 2.6)
	var breath_y = 1.0 + 0.02 * t
	var breath_x = 1.0 - 0.025 * t
	var base = _fish_base_scale
	var sign_x = 1.0 if sprite.scale.x >= 0 else -1.0
	sprite.scale.x = sign_x * base * breath_x
	sprite.scale.y = base * breath_y

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
		print("🎣 Pesce agganciato!")

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
	in_water = true
	
	# Azzera stato aggancio
	is_hooked_to_player = false
	is_attracted = false
	is_struggling = false
	struggle_timer = 0.0
	reel_force = Vector2.ZERO
	_wrong_reel = false
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
	_reel_force_smoothed = Vector2.ZERO  # reset smooth quando si aggancia

func attract_to(target_pos: Vector2):
	if hook_cooldown > 0 or is_escaping:
		return
	attraction_target = target_pos
	is_attracted = true

func apply_reel_force(force: Vector2):
	# Non sovrascrivere bruscamente: il smoothing è in _process_swimming
	reel_force = force

func apply_struggle_force(force: Vector2):
	# Forza applicata dal player durante lo struggle (cap per evitare spike)
	if is_hooked_to_player:
		velocity += force
		if velocity.length() > hooked_max_speed:
			velocity = velocity.normalized() * hooked_max_speed

func start_struggle():
	is_struggling = true
	struggle_timer = struggle_duration
	# Lotta via dal player (non direzione random = più sfida)
	if player_ref != null and is_instance_valid(player_ref):
		struggle_direction = (global_position - player_ref.global_position).normalized()
	else:
		var angle = randf() * TAU
		struggle_direction = Vector2(cos(angle), sin(angle)).normalized()

func stop_struggle():
	is_struggling = false
	struggle_timer = 0.0

## Scatto verso l'alto e verso il player fuori dall'acqua (~50 px), così puoi reelarlo (mai verso il basso)
func do_catch_jump():
	var up_strength: float = 320.0
	var toward_strength: float = 220.0
	if player_ref != null and is_instance_valid(player_ref):
		var to_player: Vector2 = (player_ref.global_position - global_position).normalized()
		# Sempre verso l'alto + verso il player
		velocity.x = to_player.x * toward_strength
		velocity.y = -up_strength
	else:
		velocity.y = -up_strength
		velocity.x *= 0.25

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
	return global_position.distance_to(player_ref.global_position) <= reel_zone_radius

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
	
	# In reel zone agganciato: non spingere giù, così il pesce può salire verso la superficie e uscire
	if is_hooked_to_player and _in_reel_zone():
		if current_depth_from_surface > max_depth_from_top:
			var push_up: float = (current_depth_from_surface - max_depth_from_top) * 2.0
			velocity.y -= push_up
		# Non applicare push_down: può andare verso la superficie e saltare
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
