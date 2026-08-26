extends Node2D

const ATTACK_IMPACT_BLUR := preload("res://Fx/attack_impact_blur.gdshader")

# ===========================================
# BLACK PARTICLE EFFECT - Stile Hollow Knight
# ===========================================
# Particelle nere per effetti visivi (dash, salto, attacco, ecc.)
# Usa il layer del player (non layer 3)

@export var auto_play: bool = false
@export var duration: float = 1.6
@export var use_player_layer: bool = true
@export var cone_angle: float = 95.0
@export var cone_amount: int = 6

var cpu_particles: CPUParticles2D = null
var amount_override: int = -1  # se > 0 usato al posto di cone_amount (es. dash con meno particelle)

func _ready():
	# Trova il nodo particelle
	cpu_particles = get_node_or_null("CPUParticles2D")
	
	if cpu_particles == null:
		return
	
	# Se use_player_layer è false, usa layer 3 per parallasse (particelle ambientali)
	if not use_player_layer:
		z_index = 3
		z_as_relative = false
		cpu_particles.z_index = 3
		cpu_particles.z_as_relative = false
	else:
		# Usa il layer del player (default) - z_index relativo
		z_index = 0
		z_as_relative = true
		cpu_particles.z_index = 0
		cpu_particles.z_as_relative = true
	
	# Assicura che le particelle siano visibili
	cpu_particles.visible = true
	cpu_particles.show_behind_parent = false
	
	if auto_play:
		play()

func play():
	"""Attiva le particelle: una sola emissione, poi il nodo si rimuove"""
	if cpu_particles == null:
		return
	
	cpu_particles.one_shot = true
	cpu_particles.restart()
	cpu_particles.emitting = true
	cpu_particles.visible = true
	
	# Rimuovi il nodo dopo che le particelle sono finite (no ricomparsa)
	if duration > 0:
		await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		# Nascondi e ferma prima di liberare, così non "ricompare" un frame
		cpu_particles.emitting = false
		cpu_particles.visible = false
		visible = false
		queue_free()

func stop():
	"""Ferma le particelle"""
	if cpu_particles != null:
		cpu_particles.emitting = false

func set_direction(_dir: Vector2):
	"""Esplosione: una sola volta (one_shot), ogni particella con movimento random (seed diverso)"""
	if cpu_particles == null:
		return
	
	# One shot: emette UNA volta e non ricomincia (niente ricomparsa)
	cpu_particles.one_shot = true
	
	# Seed random per questa istanza: ogni esplosione ha valori diversi (doc Godot)
	cpu_particles.use_fixed_seed = true
	cpu_particles.seed = randi()
	
	cpu_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	cpu_particles.emission_sphere_radius = 0.0
	cpu_particles.amount = amount_override if amount_override > 0 else cone_amount
	
	# Direzione: spread 180° = ogni particella prende direzione random nel cerchio (doc Godot)
	cpu_particles.direction = Vector2.RIGHT
	cpu_particles.spread = 180.0
	
	# Velocità random dall'inizio: range ampio così subito lente/veloci in tutte le direzioni
	cpu_particles.initial_velocity_min = 4.0
	cpu_particles.initial_velocity_max = 56.0
	cpu_particles.randomness = 1.0
	cpu_particles.lifetime_randomness = 0.75
	
	cpu_particles.explosiveness = 1.0
	cpu_particles.angular_velocity_min = -520.0
	cpu_particles.angular_velocity_max = 520.0
	cpu_particles.gravity = Vector2(randf_range(-14.0, 14.0), randf_range(2.0, 20.0))
	cpu_particles.damping_min = 0.0
	cpu_particles.damping_max = 18.0
	cpu_particles.scale_amount_min = 0.04
	cpu_particles.scale_amount_max = 0.18
	# Movimento random (doc Godot): tangential = swirl, radial = via/verso centro, orbit = gira intorno
	cpu_particles.tangential_accel_min = -80.0
	cpu_particles.tangential_accel_max = 80.0
	cpu_particles.radial_accel_min = -40.0
	cpu_particles.radial_accel_max = 60.0
	cpu_particles.orbit_velocity_min = -0.4
	cpu_particles.orbit_velocity_max = 0.4


func set_attack_impact_blur(impact_direction: Vector2) -> void:
	if cpu_particles == null:
		return
	var direction := impact_direction.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	# Un ventaglio nella direzione del colpo: l'impatto legge come materia
	# trascinata dalla canna, non come coriandoli casuali.
	cpu_particles.direction = direction
	cpu_particles.spread = 38.0
	# La texture sorgente e' grande: una scala oltre 0.2 trasforma il pogo in
	# sprite giganti. Otto frammenti piccoli mantengono il colpo leggibile.
	cpu_particles.amount = 8
	cpu_particles.initial_velocity_min = 26.0
	cpu_particles.initial_velocity_max = 82.0
	cpu_particles.lifetime = 0.36
	cpu_particles.lifetime_randomness = 0.22
	cpu_particles.gravity = direction * 14.0 + Vector2(0.0, 28.0)
	cpu_particles.damping_min = 22.0
	cpu_particles.damping_max = 48.0
	cpu_particles.scale_amount_min = 0.065
	cpu_particles.scale_amount_max = 0.15
	cpu_particles.color = Color(0.66, 0.88, 0.94, 0.9)
	var material := ShaderMaterial.new()
	material.shader = ATTACK_IMPACT_BLUR
	material.set_shader_parameter("motion_direction", direction)
	material.set_shader_parameter("smear_texels", 48.0)
	cpu_particles.material = material

func set_amount(amount: int):
	"""Override numero particelle (es. dash con meno particelle). Chiamare prima di play()."""
	amount_override = amount

func set_color(color: Color):
	"""Imposta il colore delle particelle"""
	if cpu_particles != null:
		cpu_particles.color = color

func set_use_player_layer(value: bool):
	"""Imposta se usare il layer del player o layer 3"""
	use_player_layer = value
	if not use_player_layer:
		z_index = 3
		z_as_relative = false
		if cpu_particles != null:
			cpu_particles.z_index = 3
			cpu_particles.z_as_relative = false
