extends Node2D

# ===========================================
# AMBIENT PARTICLE - Scia solo su salto/dash
# ===========================================
# Usato dal player: spawn come scia quando salta o fa dash.
# Non più emissione continua in scena.

@export var auto_start: bool = false
@export var particle_amount: int = 50
@export var trail_cone_amount: int = 10
@export var trail_cone_angle: float = 55.0
@export var lifetime: float = 0.5
@export var emission_radius: float = 25.0
@export var trail_duration: float = 0.4
@export var wind_strength: float = 5.0
@export var wind_direction: Vector2 = Vector2(1, 0)

var cpu_particles: CPUParticles2D = null
var wind_timer: float = 0.0
var _trail_mode: bool = false

func _ready():
	cpu_particles = get_node_or_null("CPUParticles2D")
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
	
	wind_timer = randf_range(2.0, 5.0)

func _process(delta):
	if cpu_particles == null or _trail_mode:
		return
	
	wind_timer -= delta
	if wind_timer <= 0:
		wind_timer = randf_range(3.0, 6.0)
		wind_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
	
	var current_gravity = cpu_particles.gravity
	cpu_particles.gravity = Vector2(
		current_gravity.x + wind_direction.x * wind_strength * delta,
		current_gravity.y + wind_direction.y * wind_strength * delta
	)
	cpu_particles.gravity = cpu_particles.gravity.clamp(Vector2(-20, -10), Vector2(20, 30))

func set_intensity(intensity: float):
	if cpu_particles != null:
		cpu_particles.amount = int(particle_amount * intensity)
		cpu_particles.color = Color(0, 0, 0, 0.3 * intensity)

func set_direction(dir: Vector2):
	"""Modalità scia: emissione a cono, meno particelle"""
	if cpu_particles == null:
		return
	_trail_mode = true
	var d = dir.normalized() if dir.length() > 0.1 else Vector2.LEFT
	cpu_particles.direction = d
	cpu_particles.spread = trail_cone_angle
	cpu_particles.amount = trail_cone_amount
	cpu_particles.emission_sphere_radius = 0.0
	cpu_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	cpu_particles.lifetime = lifetime

func start():
	if cpu_particles != null:
		cpu_particles.emitting = true

func stop():
	if cpu_particles != null:
		cpu_particles.emitting = false

func play():
	"""Avvia la scia e rimuovi dopo trail_duration"""
	if cpu_particles == null:
		return
	cpu_particles.restart()
	cpu_particles.emitting = true
	cpu_particles.visible = true
	if _trail_mode and trail_duration > 0:
		await get_tree().create_timer(trail_duration).timeout
		queue_free()
