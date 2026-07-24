extends CanvasLayer

const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")
const ARRIVAL_ART := preload("res://Landscape/Dogana/Illustrated/arrival.png")

@export_category("Timing")
@export var fade_in_duration: float = 2.8
@export var display_duration: float = 4.5
@export var fade_out_duration: float = 2.2
@export var skip_fade_duration: float = 1.15

@export_category("Visual")
@export var title_text: String = "CALIGO"
@export var title_font_size: int = 80
@export var title_color: Color = Color(1, 1, 1, 1)
@export var title_outline_color: Color = Color(0, 0, 0, 0.9)
@export var title_outline_size: int = 6

var title_label: Label
var background: ColorRect
var title_group: VBoxContainer
var can_skip: bool = true  # Permetti di skippare subito
var is_skipping: bool = false  # Evita skip multipli
var _transition_started := false
var _active_tween: Tween

func _ready():
	layer = 200  # Sopra tutto
	_create_background()
	_create_title()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	
	# Inizia la sequenza
	await get_tree().process_frame
	_play_sequence()

func _input(event):
	# Permetti di skippare con qualsiasi tasto o click
	if can_skip and not is_skipping and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch):
		if event.pressed:
			_skip_to_controls()

func _create_background():
	var backdrop := TextureRect.new()
	backdrop.name = "IllustratedBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = ARRIVAL_ART
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.24, 0.34, 0.35, 0.54)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.003, 0.014, 0.02, 0.72)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _create_title():
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	title_group = VBoxContainer.new()
	title_group.custom_minimum_size = Vector2(720, 240)
	title_group.alignment = BoxContainer.ALIGNMENT_CENTER
	title_group.add_theme_constant_override("separation", 3)
	center.add_child(title_group)

	var eyebrow := Label.new()
	eyebrow.text = "UNA STORIA DI PESCA NELLA NEBBIA"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", BODY_FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.42, 0.78, 0.72, 0.88))
	title_group.add_child(eyebrow)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Font grande e pulito
	title_label.add_theme_font_override("font", DISPLAY_FONT)
	title_label.add_theme_font_size_override("font_size", 104)
	
	# Colore principale
	title_label.add_theme_color_override("font_color", title_color)
	
	# Outline elegante
	title_label.add_theme_color_override("font_outline_color", title_outline_color)
	title_label.add_theme_constant_override("outline_size", title_outline_size)
	
	title_label.custom_minimum_size = Vector2(720, 118)
	title_group.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "PUNTA DELLA DOGANA  ·  VENEZIA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", BODY_FONT)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.76, 0.53, 0.88))
	title_group.add_child(subtitle)

	title_group.modulate.a = 0.0


func _apply_responsive_layout() -> void:
	if title_group == null or title_label == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	var width := clampf(viewport_size.x - 32.0, 280.0, 720.0)
	title_group.custom_minimum_size = Vector2(width, minf(240.0, viewport_size.y - 24.0))
	title_label.custom_minimum_size = Vector2(width, 88.0 if compact else 118.0)
	title_label.add_theme_font_size_override("font_size", 70 if compact else 104)

func _play_sequence():
	_active_tween = create_tween()
	_active_tween.tween_property(title_group, "modulate:a", 1.0, fade_in_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_active_tween.finished.connect(_on_title_faded_in, CONNECT_ONE_SHOT)


func _on_title_faded_in() -> void:
	if is_skipping or _transition_started:
		return
	get_tree().create_timer(display_duration).timeout.connect(_fade_sequence_out, CONNECT_ONE_SHOT)


func _fade_sequence_out() -> void:
	if is_skipping or _transition_started:
		return
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(title_group, "modulate:a", 0.0, fade_out_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_property(background, "color:a", 0.0, fade_out_duration)
	_active_tween.finished.connect(_go_to_controls, CONNECT_ONE_SHOT)

func _skip_to_controls():
	# Evita skip multipli
	if is_skipping:
		return
	
	is_skipping = true
	can_skip = false
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(title_group, "modulate:a", 0.0, skip_fade_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(background, "color:a", 0.0, skip_fade_duration)
	_active_tween.finished.connect(_go_to_controls, CONNECT_ONE_SHOT)

func _go_to_controls():
	if _transition_started:
		return
	_transition_started = true
	can_skip = false
	var controls_scene = load("res://controls_info.tscn")
	if controls_scene:
		get_tree().change_scene_to_packed(controls_scene)
	else:
		AsyncSceneLoader.load_scene("res://Levels/Scenes/punta_della_dogana.tscn")
