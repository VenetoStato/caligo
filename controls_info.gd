extends CanvasLayer

const DOGANA_SCENE := "res://Levels/Scenes/punta_della_dogana.tscn"
const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")
const ARRIVAL_ART := preload("res://Landscape/Dogana/Illustrated/arrival.png")

@export_category("Timing")
@export var auto_advance_time: float = 10.0  # Secondi prima di avanzare automaticamente
@export var fade_duration: float = 0.5

@export_category("Visual")
@export var background_color: Color = Color(0.004, 0.016, 0.022, 0.88)
@export var text_color: Color = Color(0.86, 0.9, 0.84, 1.0)
@export var key_color: Color = Color(0.1, 0.28, 0.27, 1.0)

var controls_container: VBoxContainer
var background: ColorRect
var skip_timer: float = 0.0
var _advancing := false

# Comandi PC (tastiera)
var _commands_pc: Array = [
	["MUOVITI", "A  /  D", "Esplora pontili e palazzi"],
	["SALTA", "SPAZIO", "Premi ancora per il doppio salto"],
	["SCATTA", "SHIFT", "Attraversa rapidamente il pericolo"],
	["ATTACCA", "CLICK SX", "Colpo rapido con l'amo"],
	["PESCA", "F", "Lancia la lenza verso i pesci"],
	["RECUPERA", "R", "Tira la preda: il pesce cura la vita"],
	["INTERAGISCI", "E", "Altari, porte, mappe e passaggi"],
	["CAMBIA AMO", "C", "Alterna pesca e attraversamento"],
]
# Comandi touch/Android (pulsanti a schermo)
var _commands_touch: Array = [
	["MUOVITI", "◀  ▶", "Comandi trasparenti a sinistra"],
	["SALTA", "↑", "Premi ancora per il doppio salto"],
	["ATTACCA", "Z", "Colpo rapido con l'amo"],
	["SCATTA", "D", "Attraversa rapidamente il pericolo"],
	["PESCA", "LENZA", "Lancia verso un pesce"],
	["RECUPERA", "TIRA", "La preda pescata recupera vita"],
	["INTERAGISCI", "✦", "Altari, porte e passaggi"],
	["CAMBIA AMO", "AMO", "Alterna pesca e attraversamento"],
]

func _is_touch_platform() -> bool:
	return OS.get_name() == "Android"

func _ready():
	layer = 200  # Sopra tutto
	AsyncSceneLoader.preload_scene(DOGANA_SCENE)
	_create_background()
	_create_controls_display()
	
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
	backdrop.modulate = Color(0.26, 0.38, 0.38, 0.52)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	background = ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _create_controls_display():
	var main_container := CenterContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1040, 630)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.008, 0.028, 0.034, 0.93)
	frame_style.border_color = Color(0.57, 0.5, 0.31, 0.72)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(10)
	frame_style.content_margin_left = 44.0
	frame_style.content_margin_right = 44.0
	frame_style.content_margin_top = 28.0
	frame_style.content_margin_bottom = 24.0
	frame_style.shadow_color = Color(0, 0, 0, 0.72)
	frame_style.shadow_size = 18
	frame.add_theme_stylebox_override("panel", frame_style)
	main_container.add_child(frame)

	controls_container = VBoxContainer.new()
	controls_container.name = "ControlsContainer"
	controls_container.add_theme_constant_override("separation", 10)
	controls_container.alignment = BoxContainer.ALIGNMENT_CENTER
	frame.add_child(controls_container)

	var eyebrow := Label.new()
	eyebrow.text = "MANUALE DEL PESCATORE  ·  I"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", BODY_FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.38, 0.74, 0.68, 0.9))
	controls_container.add_child(eyebrow)

	var title := Label.new()
	title.name = "Title"
	title.text = "Sopravvivere al Caligo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 45)
	title.add_theme_color_override("font_color", Color(0.91, 0.83, 0.62, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0.01, 0.014, 0.95))
	title.add_theme_constant_override("outline_size", 3)
	controls_container.add_child(title)

	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(760, 8)
	controls_container.add_child(rule)

	var commands: Array = _commands_touch if _is_touch_platform() else _commands_pc
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	controls_container.add_child(grid)
	for cmd in commands:
		_create_command_row(grid, cmd[0], cmd[1], cmd[2])

	var fishing_note := Label.new()
	fishing_note.text = "PESCA PER VIVERE  ·  Ogni pesce recuperato restituisce salute."
	fishing_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fishing_note.add_theme_font_override("font", BODY_FONT)
	fishing_note.add_theme_font_size_override("font_size", 17)
	fishing_note.add_theme_color_override("font_color", Color(0.43, 0.9, 0.78, 1.0))
	controls_container.add_child(fishing_note)

	var instruction := Label.new()
	instruction.name = "Instruction"
	instruction.text = "TOCCA PER CONTINUARE" if _is_touch_platform() else "PREMI UN TASTO PER CONTINUARE"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_override("font", BODY_FONT)
	instruction.add_theme_font_size_override("font_size", 13)
	instruction.add_theme_color_override("font_color", Color(0.74, 0.74, 0.65, 0.72))
	controls_container.add_child(instruction)

	controls_container.modulate.a = 0.0


func _create_command_row(parent: GridContainer, action: String, key: String, description: String):
	var row := PanelContainer.new()
	row.name = "CommandRow_" + action
	row.custom_minimum_size = Vector2(468, 76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.07, 0.075, 0.82)
	style.border_color = Color(0.25, 0.45, 0.4, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", style)
	parent.add_child(row)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	row.add_child(layout)
	var key_label := Label.new()
	key_label.text = key
	key_label.custom_minimum_size = Vector2(110, 0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", BODY_FONT)
	key_label.add_theme_font_size_override("font_size", 16)
	key_label.add_theme_color_override("font_color", Color(0.92, 0.81, 0.52, 1.0))
	layout.add_child(key_label)

	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 0)
	layout.add_child(copy)
	var action_label := Label.new()
	action_label.name = "ActionLabel"
	action_label.text = action
	action_label.add_theme_font_override("font", BODY_FONT)
	action_label.add_theme_font_size_override("font_size", 16)
	action_label.add_theme_color_override("font_color", text_color)
	copy.add_child(action_label)
	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = description
	desc_label.add_theme_font_override("font", BODY_FONT)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.67, 0.9))
	copy.add_child(desc_label)

func _load_image_from_path(path: String) -> Texture2D:
	# Prova a caricare come scena e estrarre lo sprite
	if path.ends_with(".tscn"):
		var scene = load(path)
		if scene:
			var instance = scene.instantiate()
			if instance:
				# Cerca uno Sprite2D nella scena
				var sprite = instance.get_node_or_null("Sprite2D")
				if sprite == null:
					sprite = instance.get_node_or_null("Sprite")
				if sprite and sprite.texture:
					var texture = sprite.texture
					instance.queue_free()
					return texture
				instance.queue_free()
	
	# Prova a caricare come texture diretta
	var texture = load(path)
	if texture is Texture2D:
		return texture
	
	return null

func _fade_in():
	var tween = create_tween()
	tween.tween_property(controls_container, "modulate:a", 1.0, fade_duration)
	await tween.finished

func _fade_out():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(controls_container, "modulate:a", 0.0, fade_duration)
	tween.tween_property(background, "color:a", 0.0, fade_duration)
	await tween.finished

func _go_to_game():
	if _advancing:
		return
	_advancing = true
	set_process(false)
	set_process_input(false)
	await _fade_out()
	
	# Passa alla schermata del testo poetico
	var poetic_scene = load("res://poetic_text.tscn")
	if poetic_scene:
		get_tree().change_scene_to_packed(poetic_scene)
	else:
		AsyncSceneLoader.load_scene("res://Levels/Scenes/punta_della_dogana.tscn")
