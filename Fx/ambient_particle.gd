extends Node2D

# ===========================================
# AMBIENT PARTICLE EFFECT - Stile Hollow Knight
# ===========================================
# Particelle ambientali nere per atmosfera
# Configurate per layer 3 (parallasse)

@export var auto_start: bool = true
@export var particle_amount: int = 50
@export var lifetime: float = 8.0
@export var emission_radius: float = 200.0
@export var wind_strength: float = 5.0
@export var wind_direction: Vector2 = Vector2(1, 0)

var cpu_particles: CPUParticles2D = null
var wind_timer: float = 0.0

func _ready():
	# Trova il nodo particelle
	cpu_particles = get_node_or_null("CPUParticles2D")
	
	# Assicura che sia nel layer 3 per parallasse
	z_index = 3
	z_as_relative = false
	
	if cpu_particles != null:
		cpu_particles.z_index = 3
		cpu_particles.z_as_relative = false
		cpu_particles.amount = particle_amount
		cpu_particles.lifetime = lifetime
		cpu_particles.emission_sphere_radius = emission_radius
		
		if auto_start:
			cpu_particles.emitting = true
	
	# Varia la direzione del vento periodicamente
	wind_timer = randf_range(2.0, 5.0)

func _process(delta):
	if cpu_particles == null:
		return
	
	# Varia la direzione del vento per effetto più naturale
	wind_timer -= delta
	if wind_timer <= 0:
		wind_timer = randf_range(3.0, 6.0)
		wind_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
	
	# Applica vento alle particelle
	var current_gravity = cpu_particles.gravity
	cpu_particles.gravity = Vector2(
		current_gravity.x + wind_direction.x * wind_strength * delta,
		current_gravity.y + wind_direction.y * wind_strength * delta
	)
	
	# Limita la gravità
	cpu_particles.gravity = cpu_particles.gravity.clamp(Vector2(-20, -10), Vector2(20, 30))

func set_intensity(intensity: float):
	"""Imposta l'intensità delle particelle (0.0 - 1.0)"""
	if cpu_particles != null:
		cpu_particles.amount = int(particle_amount * intensity)
		cpu_particles.color = Color(0, 0, 0, 0.3 * intensity)

func start():
	"""Avvia le particelle"""
	if cpu_particles != null:
		cpu_particles.emitting = true

func stop():
	"""Ferma le particelle"""
	if cpu_particles != null:
		cpu_particles.emitting = false
