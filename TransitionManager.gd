extends CanvasLayer

class_name TransitionManager

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

## Fade nero stile Hollow Knight — nessun flash bianco tra le transizioni.

static var instance: TransitionManager

@export_category("Fade Settings")
@export var fade_color: Color = Color(0.004, 0.016, 0.022, 1)
@export var fade_in_duration: float = 1.15
@export var fade_out_duration: float = 0.85
@export var death_freeze_time: float = 1.4
@export var death_fade_delay: float = 0.35
@export var hold_black_after_cut: float = 0.18

@export_category("Death Particles")
@export var death_particle_scene: PackedScene
@export var death_particle_count: int = 12
@export var death_particle_spread: float = 50.0

var fade_rect: ColorRect
var is_transitioning: bool = false
var _fade_tween: Tween

signal fade_in_started
signal fade_in_completed
signal fade_out_started
signal fade_out_completed
signal death_sequence_started
signal death_sequence_completed


func _ready() -> void:
	instance = self
	add_to_group("transition_manager")
	layer = 100
	_create_fade_rect()
	# Boot: niente nero (splash/prologo hanno il proprio velo).
	_set_cover(0.0, false)


func _create_fade_rect() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = fade_color
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _set_cover(alpha: float, show: bool) -> void:
	fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, alpha)
	fade_rect.visible = show or alpha > 0.001


## Copertura immediata (niente frame scoperto prima del tween).
func cover_now(alpha: float = 1.0) -> void:
	_kill_fade_tween()
	_set_cover(alpha, true)


func fade_in(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = fade_in_duration
	_kill_fade_tween()
	is_transitioning = true
	fade_in_started.emit()
	# Parte sempre da nero pieno: evita flash se lo stato era inconsistente.
	_set_cover(1.0, true)
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_QUAD)
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, duration)
	await _fade_tween.finished
	_set_cover(0.0, false)
	is_transitioning = false
	fade_in_completed.emit()


func fade_out(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = fade_out_duration
	_kill_fade_tween()
	is_transitioning = true
	fade_out_started.emit()
	# Se già coperto, non ripartire da zero (evita flash).
	if fade_rect.color.a < 0.99:
		_set_cover(maxf(fade_rect.color.a, 0.0), true)
		_fade_tween = create_tween()
		_fade_tween.set_ease(Tween.EASE_IN)
		_fade_tween.set_trans(Tween.TRANS_QUAD)
		_fade_tween.tween_property(fade_rect, "color:a", 1.0, duration)
		await _fade_tween.finished
	else:
		_set_cover(1.0, true)
	is_transitioning = false
	fade_out_completed.emit()


func play_death_sequence(player: Node2D, respawn_pos: Vector2) -> void:
	if is_transitioning:
		return
	death_sequence_started.emit()
	is_transitioning = true
	Engine.time_scale = 0.12
	_spawn_death_particles(player.global_position)
	# Flash scuro laguna (niente bianco).
	await _flash_lagoon(0.14)
	await get_tree().create_timer(death_freeze_time * 0.12).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(death_fade_delay).timeout
	is_transitioning = false
	await fade_out()
	player.global_position = respawn_pos
	if player.has_method("_on_respawn"):
		player.call("_on_respawn")
	await get_tree().create_timer(hold_black_after_cut).timeout
	await fade_in()
	death_sequence_completed.emit()


func _flash_lagoon(duration: float) -> void:
	var previous := fade_rect.color
	_kill_fade_tween()
	fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", 0.55, duration * 0.35)
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, duration * 0.65)
	await _fade_tween.finished
	fade_rect.color = previous
	if previous.a <= 0.001:
		fade_rect.visible = false


func _spawn_death_particles(pos: Vector2) -> void:
	if death_particle_scene:
		for i in range(death_particle_count):
			var p = death_particle_scene.instantiate()
			get_tree().current_scene.add_child(p)
			p.global_position = pos
			var angle = (float(i) / death_particle_count) * TAU + randf_range(-0.3, 0.3)
			var dir = Vector2(cos(angle), sin(angle))
			if p.has_method("set_direction"):
				p.call("set_direction", dir)
			if p.has_method("play"):
				p.call("play")
	else:
		PARTICLE_BURST.spawn(
			get_tree().current_scene,
			pos,
			Color(0.08, 0.12, 0.13, 0.95),
			death_particle_count * 2,
			Vector2.UP,
			75.0,
			210.0,
			1.0
		)


func is_fading() -> bool:
	return is_transitioning


func transition_to_scene(scene_path: String) -> void:
	await fade_out()
	cover_now(1.0)
	get_tree().change_scene_to_file(scene_path)
	# Resta coperto finché la nuova scena non ha disegnato qualche frame.
	for _i in 4:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().create_timer(hold_black_after_cut).timeout
	await fade_in()


func transition_with_callback(callback: Callable) -> void:
	await fade_out()
	cover_now(1.0)
	callback.call()
	for _i in 3:
		await get_tree().process_frame
	await get_tree().create_timer(hold_black_after_cut).timeout
	await fade_in()
