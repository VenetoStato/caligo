extends CanvasLayer

const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")
const ARRIVAL_ART := preload("res://Landscape/Dogana/Illustrated/arrival.png")

@export_category("Timing")
@export var auto_advance_time: float = 8.0
@export var fade_duration: float = 0.8

@export_category("Visual")
@export var background_color: Color = Color(0.003, 0.014, 0.02, 0.84)
@export var text_color: Color = Color(0.88, 0.89, 0.82, 1.0)

var text_container: VBoxContainer
var background: ColorRect
var skip_timer: float = 0.0
var _advancing := false
var _frame: PanelContainer
var _frame_style: StyleBoxFlat
var _primary_line: Label
var _veneto_line: Label

func _ready():
	layer = 200  # Sopra tutto
	_create_background()
	_create_text_display()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	
	# Fade in
	await get_tree().process_frame
	_fade_in()
	
	# Timer per skip automatico
	skip_timer = auto_advance_time

func _process(delta):
	if _advancing:
		return
	skip_timer -= delta
	# Skip automatico
	if skip_timer <= 0:
		_go_to_game()


func _input(event: InputEvent) -> void:
	if _advancing:
		return
	var pressed: bool = (
		event is InputEventKey and event.pressed and not event.echo
		or event is InputEventMouseButton and event.pressed
		or event is InputEventScreenTouch and event.pressed
	)
	if pressed:
		_go_to_game()

func _create_background():
	var backdrop := TextureRect.new()
	backdrop.name = "IllustratedBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = ARRIVAL_ART
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.22, 0.34, 0.35, 0.48)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	background = ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _create_text_display():
	var main_container = CenterContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	_frame = PanelContainer.new()
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color(0.006, 0.025, 0.032, 0.9)
	_frame_style.border_color = Color(0.56, 0.49, 0.31, 0.62)
	_frame_style.set_border_width_all(1)
	_frame_style.set_corner_radius_all(10)
	_frame_style.shadow_color = Color(0, 0, 0, 0.75)
	_frame_style.shadow_size = 20
	_frame.add_theme_stylebox_override("panel", _frame_style)
	main_container.add_child(_frame)

	text_container = VBoxContainer.new()
	text_container.name = "TextContainer"
	text_container.add_theme_constant_override("separation", 24)
	text_container.alignment = BoxContainer.ALIGNMENT_CENTER
	text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.add_child(text_container)

	var eyebrow := Label.new()
	eyebrow.text = "PROLOGO  ·  LA LAGUNA RICORDA"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", BODY_FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.42, 0.78, 0.72, 0.9))
	text_container.add_child(eyebrow)

	var poetic_text_english = Label.new()
	poetic_text_english.name = "PoeticTextEnglish"
	poetic_text_english.text = "From the mist of the marsh, a bundle took life"
	poetic_text_english.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poetic_text_english.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	poetic_text_english.add_theme_font_override("font", DISPLAY_FONT)
	poetic_text_english.add_theme_font_size_override("font_size", 39)
	poetic_text_english.add_theme_color_override("font_color", Color(0.92, 0.85, 0.67, 1.0))
	poetic_text_english.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	poetic_text_english.add_theme_constant_override("outline_size", 4)
	text_container.add_child(poetic_text_english)
	_primary_line = poetic_text_english
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	text_container.add_child(spacer1)
	
	var poetic_text_veneto = Label.new()
	poetic_text_veneto.name = "PoeticTextVeneto"
	poetic_text_veneto.text = "Un manuin in te la paude, in mexo al caligo, taco a movarse"
	poetic_text_veneto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poetic_text_veneto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	poetic_text_veneto.add_theme_font_override("font", DISPLAY_FONT)
	poetic_text_veneto.add_theme_font_size_override("font_size", 25)
	poetic_text_veneto.add_theme_color_override("font_color", Color(0.63, 0.83, 0.77, 0.92))
	poetic_text_veneto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	poetic_text_veneto.add_theme_constant_override("outline_size", 3)
	text_container.add_child(poetic_text_veneto)
	_veneto_line = poetic_text_veneto
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	text_container.add_child(spacer2)
	
	var poetic_text_english_normal = Label.new()
	poetic_text_english_normal.name = "PoeticTextEnglishNormal"
	poetic_text_english_normal.text = "From the fog of the swamp, a bundle began to move"
	poetic_text_english_normal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poetic_text_english_normal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	poetic_text_english_normal.add_theme_font_override("font", BODY_FONT)
	poetic_text_english_normal.add_theme_font_size_override("font_size", 16)
	poetic_text_english_normal.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.8))
	poetic_text_english_normal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	poetic_text_english_normal.add_theme_constant_override("outline_size", 2)
	text_container.add_child(poetic_text_english_normal)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 22)
	text_container.add_child(spacer3)
	
	var instruction = Label.new()
	instruction.name = "Instruction"
	instruction.text = "PREMI UN TASTO PER ENTRARE NEL CALIGO"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_override("font", BODY_FONT)
	instruction.add_theme_font_size_override("font_size", 13)
	instruction.add_theme_color_override("font_color", Color(0.74, 0.72, 0.61, 0.72))
	text_container.add_child(instruction)
	
	# Inizia invisibile per fade in
	text_container.modulate.a = 0.0


func _apply_responsive_layout() -> void:
	if _frame == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	_frame.custom_minimum_size = CaligoResponsiveLayout.fitted_panel(viewport_size, Vector2(840, 430), 20.0)
	var horizontal_margin := 20.0 if compact else 56.0
	_frame_style.content_margin_left = horizontal_margin
	_frame_style.content_margin_right = horizontal_margin
	_frame_style.content_margin_top = 22.0 if compact else 38.0
	_frame_style.content_margin_bottom = 20.0 if compact else 32.0
	text_container.add_theme_constant_override("separation", 14 if compact else 24)
	_primary_line.add_theme_font_size_override("font_size", 29 if compact else 39)
	_veneto_line.add_theme_font_size_override("font_size", 20 if compact else 25)

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
	if _advancing:
		return
	_advancing = true
	set_process(false)
	set_process_input(false)
	await _fade_out()
	AsyncSceneLoader.load_scene("res://Levels/Scenes/punta_della_dogana.tscn")
