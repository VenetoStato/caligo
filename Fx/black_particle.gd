extends Node2D

# ===========================================
# BLACK PARTICLE EFFECT - Stile Hollow Knight
# ===========================================
# Particelle nere per effetti visivi (dash, salto, attacco, ecc.)
# Usa il layer del player (non layer 3)

@export var auto_play: bool = false
@export var duration: float = 0.3
@export var use_player_layer: bool = true  # Se true, usa il layer del player, altrimenti layer 3

var cpu_particles: CPUParticles2D = null

func _ready():
	# Trova il nodo particelle
	cpu_particles = get_node_or_null("CPUParticles2D")
	
	if cpu_particles == null:
		print("BlackParticle: CPUParticles2D non trovato!")
		return
	
	# Se use_player_layer è false, usa layer 3 per parallasse (particelle ambientali)
	if not use_player_layer:
		z_index = 3
		z_as_relative = false
		cpu_particles.z_index = 3
		cpu_particles.z_as_relative = false
		print("BlackParticle: Usando layer 3 (parallasse)")
	else:
		# Usa il layer del player (default) - z_index relativo
		z_index = 0
		z_as_relative = true
		cpu_particles.z_index = 0
		cpu_particles.z_as_relative = true
		print("BlackParticle: Usando layer player (z_index relativo)")
	
	# Assicura che le particelle siano visibili
	cpu_particles.visible = true
	cpu_particles.show_behind_parent = false
	
	if auto_play:
		play()

func play():
	"""Attiva le particelle"""
	if cpu_particles == null:
		print("BlackParticle: play() chiamato ma cpu_particles è null!")
		return
	
	cpu_particles.restart()
	cpu_particles.emitting = true
	cpu_particles.visible = true
	
	print("BlackParticle: Particelle avviate, emitting: ", cpu_particles.emitting)
	
	# Auto-rimuovi dopo la durata
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		queue_free()

func stop():
	"""Ferma le particelle"""
	if cpu_particles != null:
		cpu_particles.emitting = false

func set_direction(dir: Vector2):
	"""Imposta la direzione delle particelle (scia)"""
	if cpu_particles == null:
		return
	
	# Per la scia, le particelle vanno nella direzione opposta al movimento
	var dir_normalized = dir.normalized() if dir.length() > 0.1 else Vector2.LEFT
	
	# Imposta la direzione di emissione con più randomicità
	cpu_particles.direction = dir_normalized
	
	# Velocità iniziale nella direzione della scia (più variabile)
	var speed = dir.length() * 0.4 if dir.length() > 0.1 else 15.0
	cpu_particles.initial_velocity_min = speed * 0.3
	cpu_particles.initial_velocity_max = speed * 1.5
	
	# Spread moderato per scia
	cpu_particles.spread = 60.0
	
	# Randomicità moderata
	cpu_particles.randomness = 0.5
	
	# Esplosività zero per scia continua
	cpu_particles.explosiveness = 0.0
	
	# Gravità leggera
	cpu_particles.gravity = Vector2(randf_range(-2.0, 2.0), randf_range(8.0, 12.0))

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
