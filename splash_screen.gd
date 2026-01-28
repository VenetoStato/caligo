extends CanvasLayer

# ===========================================
# SPLASH SCREEN - Schermata iniziale CALIGO
# ===========================================
# Mostra il titolo con fade in/out

@export_category("Timing")
@export var fade_in_duration: float = 1.5
@export var display_duration: float = 2.5
@export var fade_out_duration: float = 1.0

@export_category("Visual")
@export var title_text: String = "CALIGO"
@export var title_font_size: int = 80
@export var title_color: Color = Color(1, 1, 1, 1)
@export var title_outline_color: Color = Color(0, 0, 0, 0.9)
@export var title_outline_size: int = 6

var title_label: Label
var background: ColorRect
var can_skip: bool = true  # Permetti di skippare subito
var is_skipping: bool = false  # Evita skip multipli

func _ready():
	layer = 200  # Sopra tutto
	_create_background()
	_create_title()
	
	# Inizia la sequenza
	await get_tree().process_frame
	_play_sequence()

func _input(event):
	# Permetti di skippare con qualsiasi tasto o click
	if can_skip and not is_skipping and (event is InputEventKey or event is InputEventMouseButton):
		if event.pressed:
			_skip_to_controls()

func _create_background():
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _create_title():
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Font grande e pulito
	title_label.add_theme_font_size_override("font_size", title_font_size)
	
	# Colore principale
	title_label.add_theme_color_override("font_color", title_color)
	
	# Outline elegante
	title_label.add_theme_color_override("font_outline_color", title_outline_color)
	title_label.add_theme_constant_override("outline_size", title_outline_size)
	
	# Centra PERFETTAMENTE al centro dello schermo
	var viewport_size = get_viewport().get_visible_rect().size
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.offset_left = -250
	title_label.offset_top = -60
	title_label.offset_right = 250
	title_label.offset_bottom = 60
	
	add_child(title_label)
	
	# Inizia invisibile
	title_label.modulate.a = 0.0

func _play_sequence():
	# Fade in del titolo semplice ed elegante (senza movimento, solo fade)
	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, fade_in_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	# Mantieni visibile
	await get_tree().create_timer(display_duration).timeout
	
	# Fade out semplice
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 0.0, fade_out_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(background, "color:a", 0.0, fade_out_duration)
	
	await tween.finished
	
	# Passa alla schermata dei comandi
	_go_to_controls()

func _skip_to_controls():
	# Evita skip multipli
	if is_skipping:
		return
	
	is_skipping = true
	can_skip = false
	
	# Fade out rapido
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(background, "color:a", 0.0, 0.2)
	
	await tween.finished
	
	# Passa alla schermata dei comandi
	_go_to_controls()

func _go_to_controls():
	var controls_scene = load("res://controls_info.tscn")
	if controls_scene:
		get_tree().change_scene_to_packed(controls_scene)
	else:
		# Se non esiste, vai direttamente al gioco
		var game_scene = load("res://Levels/Scenes/test_area.tscn")
		if game_scene:
			get_tree().change_scene_to_packed(game_scene)
