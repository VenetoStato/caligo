extends CanvasLayer

# ===========================================
# POETIC TEXT - Testo di presentazione
# ===========================================
# Mostra il testo poetico in tre versioni

@export_category("Timing")
@export var auto_advance_time: float = 8.0
@export var fade_duration: float = 0.8

@export_category("Visual")
@export var background_color: Color = Color(0, 0, 0, 1)
@export var text_color: Color = Color(1, 1, 1, 1)

var text_container: VBoxContainer
var background: ColorRect
var skip_timer: float = 0.0

func _ready():
	layer = 200  # Sopra tutto
	_create_background()
	_create_text_display()
	
	# Fade in
	await get_tree().process_frame
	_fade_in()
	
	# Timer per skip automatico
	skip_timer = auto_advance_time

func _process(delta):
	skip_timer -= delta
	
	# Skip con qualsiasi tasto o click
	if Input.is_anything_pressed():
		_go_to_game()
	
	# Skip automatico
	if skip_timer <= 0:
		_go_to_game()

func _create_background():
	background = ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _create_text_display():
	# Container principale centrato
	var main_container = CenterContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Container verticale per i testi
	text_container = VBoxContainer.new()
	text_container.name = "TextContainer"
	text_container.add_theme_constant_override("separation", 24)
	text_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(text_container)
	
	# Testo in inglese arcaico (principale, più grande)
	var poetic_text_english = Label.new()
	poetic_text_english.name = "PoeticTextEnglish"
	poetic_text_english.text = "From the mist of the marsh, a bundle took life"
	poetic_text_english.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poetic_text_english.add_theme_font_size_override("font_size", 32)
	poetic_text_english.add_theme_color_override("font_color", text_color)
	poetic_text_english.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	poetic_text_english.add_theme_constant_override("outline_size", 4)
	text_container.add_child(poetic_text_english)
	
	# Spaziatura
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	text_container.add_child(spacer1)
	
	# Testo in dialetto veneto
	var poetic_text_veneto = Label.new()
	poetic_text_veneto.name = "PoeticTextVeneto"
	poetic_text_veneto.text = "Un manuin in te la paude, in mexo al caligo, taco a movarse"
	poetic_text_veneto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poetic_text_veneto.add_theme_font_size_override("font_size", 26)
	poetic_text_veneto.add_theme_color_override("font_color", Color(text_color.r * 0.95, text_color.g * 0.95, text_color.b * 0.95, 0.9))
	poetic_text_veneto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	poetic_text_veneto.add_theme_constant_override("outline_size", 3)
	text_container.add_child(poetic_text_veneto)
	
	# Spaziatura
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	text_container.add_child(spacer2)
	
	# Testo in inglese normale
	var poetic_text_english_normal = Label.new()
	poetic_text_english_normal.name = "PoeticTextEnglishNormal"
	poetic_text_english_normal.text = "From the fog of the swamp, a bundle began to move"
	poetic_text_english_normal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poetic_text_english_normal.add_theme_font_size_override("font_size", 24)
	poetic_text_english_normal.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.8))
	poetic_text_english_normal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	poetic_text_english_normal.add_theme_constant_override("outline_size", 2)
	text_container.add_child(poetic_text_english_normal)
	
	# Spaziatura finale
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 50)
	text_container.add_child(spacer3)
	
	# Istruzione per continuare
	var instruction = Label.new()
	instruction.name = "Instruction"
	instruction.text = "Premi un tasto qualsiasi per continuare..."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 20)
	instruction.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.6))
	text_container.add_child(instruction)
	
	# Inizia invisibile per fade in
	text_container.modulate.a = 0.0

func _fade_in():
	var tween = create_tween()
	tween.tween_property(text_container, "modulate:a", 1.0, fade_duration)
	await tween.finished

func _fade_out():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(text_container, "modulate:a", 0.0, fade_duration)
	tween.tween_property(background, "color:a", 0.0, fade_duration)
	await tween.finished

func _go_to_game():
	await _fade_out()
	
	var game_scene = load("res://Levels/Scenes/test_area.tscn")
	if game_scene:
		get_tree().change_scene_to_packed(game_scene)
	else:
		print("ERRORE: Impossibile caricare la scena del gioco!")
