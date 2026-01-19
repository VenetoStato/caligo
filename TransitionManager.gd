extends CanvasLayer

# ===========================================
# TRANSITION MANAGER - Fade In/Out stile Hollow Knight
# ===========================================
# Gestisce le transizioni di schermo (fade in/out)
# e gli effetti di morte/respawn

class_name TransitionManager

# Singleton
static var instance: TransitionManager

@export_category("Fade Settings")
@export var fade_color: Color = Color(0, 0, 0, 1)
@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 0.8
@export var death_freeze_time: float = 0.5
@export var death_fade_delay: float = 0.3

@export_category("Death Particles")
@export var death_particle_scene: PackedScene
@export var death_particle_count: int = 12
@export var death_particle_spread: float = 50.0

# Nodi
var fade_rect: ColorRect
var is_transitioning: bool = false

# Segnali
signal fade_in_started
signal fade_in_completed
signal fade_out_started
signal fade_out_completed
signal death_sequence_started
signal death_sequence_completed

func _ready():
	instance = self
	layer = 100  # Sopra tutto
	_create_fade_rect()
	
	# Fade in all'avvio del gioco
	await get_tree().process_frame
	fade_in()

func _create_fade_rect():
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = fade_color
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Copre tutto lo schermo
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.size = get_viewport().get_visible_rect().size * 2
	fade_rect.position = -fade_rect.size / 4
	
	add_child(fade_rect)
	
	# Inizia nero (coperto)
	fade_rect.color.a = 1.0

# ===========================================
# FADE IN (da nero a trasparente)
# ===========================================
func fade_in(duration: float = -1.0) -> void:
	if duration < 0:
		duration = fade_in_duration
	
	if is_transitioning:
		return
	
	is_transitioning = true
	fade_in_started.emit()
	
	fade_rect.color.a = 1.0
	fade_rect.visible = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	
	await tween.finished
	
	fade_rect.visible = false
	is_transitioning = false
	fade_in_completed.emit()

# ===========================================
# FADE OUT (da trasparente a nero)
# ===========================================
func fade_out(duration: float = -1.0) -> void:
	if duration < 0:
		duration = fade_out_duration
	
	if is_transitioning:
		return
	
	is_transitioning = true
	fade_out_started.emit()
	
	fade_rect.color.a = 0.0
	fade_rect.visible = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	
	await tween.finished
	
	is_transitioning = false
	fade_out_completed.emit()

# ===========================================
# DEATH SEQUENCE
# ===========================================
func play_death_sequence(player: Node2D, respawn_pos: Vector2) -> void:
	if is_transitioning:
		return
	
	death_sequence_started.emit()
	is_transitioning = true
	
	# 1. Freeze del gioco (effetto slow-mo)
	Engine.time_scale = 0.1
	
	# 2. Spawn particelle di morte
	_spawn_death_particles(player.global_position)
	
	# 3. Flash bianco breve
	await _flash_white(0.1)
	
	# 4. Attendi un po' in slow-mo
	await get_tree().create_timer(death_freeze_time * 0.1).timeout  # * 0.1 perché time_scale
	
	# 5. Torna a velocità normale
	Engine.time_scale = 1.0
	
	# 6. Breve pausa
	await get_tree().create_timer(death_fade_delay).timeout
	
	# 7. Fade out
	is_transitioning = false  # Reset per permettere fade_out
	await fade_out()
	
	# 8. Respawn del player
	player.global_position = respawn_pos
	if player.has_method("_on_respawn"):
		player.call("_on_respawn")
	
	# 9. Breve pausa al nero
	await get_tree().create_timer(0.3).timeout
	
	# 10. Fade in
	await fade_in()
	
	death_sequence_completed.emit()

func _flash_white(duration: float) -> void:
	var original_color = fade_rect.color
	fade_rect.color = Color(1, 1, 1, 0)
	fade_rect.visible = true
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.8, duration * 0.3)
	tween.tween_property(fade_rect, "color:a", 0.0, duration * 0.7)
	
	await tween.finished
	
	fade_rect.color = original_color

func _spawn_death_particles(pos: Vector2) -> void:
	# Se hai una scena di particelle personalizzata
	if death_particle_scene:
		for i in range(death_particle_count):
			var p = death_particle_scene.instantiate()
			get_tree().current_scene.add_child(p)
			p.global_position = pos
			
			# Direzione casuale
			var angle = (float(i) / death_particle_count) * TAU + randf_range(-0.3, 0.3)
			var dir = Vector2(cos(angle), sin(angle))
			
			if p.has_method("set_direction"):
				p.call("set_direction", dir)
			if p.has_method("play"):
				p.call("play")
	else:
		# Crea particelle semplici se non c'è una scena
		_spawn_simple_death_particles(pos)

func _spawn_simple_death_particles(pos: Vector2) -> void:
	for i in range(death_particle_count):
		var particle = _create_simple_particle()
		get_tree().current_scene.add_child(particle)
		particle.global_position = pos
		
		# Direzione e velocità casuale
		var angle = (float(i) / death_particle_count) * TAU + randf_range(-0.2, 0.2)
		var speed = randf_range(100, 250)
		var dir = Vector2(cos(angle), sin(angle))
		
		# Anima la particella
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Movimento
		var end_pos = pos + dir * speed * randf_range(0.5, 1.5)
		tween.tween_property(particle, "global_position", end_pos, 0.8).set_ease(Tween.EASE_OUT)
		
		# Fade out
		tween.tween_property(particle, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.2)
		
		# Scala
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.8)
		
		# Rimuovi dopo l'animazione
		tween.chain().tween_callback(particle.queue_free)

func _create_simple_particle() -> Node2D:
	var particle = Node2D.new()
	particle.z_index = 50
	
	# Crea uno script inline per disegnare un cerchio
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var radius: float = 4.0
var color: Color = Color(0.1, 0.1, 0.1, 1.0)

func _draw():
	draw_circle(Vector2.ZERO, radius, color)
"""
	script.reload()
	particle.set_script(script)
	
	# Varia leggermente la dimensione
	particle.set("radius", randf_range(3, 7))
	particle.scale = Vector2(1, 1)
	
	return particle

# ===========================================
# UTILITY
# ===========================================
func is_fading() -> bool:
	return is_transitioning

# Transizione per cambio scena
func transition_to_scene(scene_path: String) -> void:
	await fade_out()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_in()

# Transizione con callback
func transition_with_callback(callback: Callable) -> void:
	await fade_out()
	callback.call()
	await get_tree().create_timer(0.2).timeout
	await fade_in()
