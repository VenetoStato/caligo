extends CanvasLayer

const DOGANA_SCENE := "res://Levels/Scenes/punta_della_dogana.tscn"
const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")
const ARRIVAL_ART := preload("res://Landscape/Dogana/Illustrated/arrival.png")

@export_category("Timing")
@export var auto_advance_time: float = 18.0
@export var fade_duration: float = 1.65

@export_category("Visual")
@export var background_color: Color = Color(0.004, 0.016, 0.022, 0.88)
@export var text_color: Color = Color(0.86, 0.9, 0.84, 1.0)
@export var key_color: Color = Color(0.1, 0.28, 0.27, 1.0)

var controls_container: VBoxContainer
var background: ColorRect
var skip_timer: float = 0.0
var _advancing := false
var _frame: PanelContainer
var _frame_style: StyleBoxFlat
var _grid: GridContainer
var _title: Label
var _rule: HSeparator
var _rows: Array[PanelContainer] = []
var _key_labels: Array[Label] = []
var _fade_tween: Tween

# Comandi PC (tastiera)
var _commands_pc: Array = [
	["MUOVITI", "A  /  D", "Esplora pontili e palazzi"],
	["SALTA", "SPAZIO", "Premi ancora per il doppio salto"],
	["SCATTA", "SHIFT", "Attraversa rapidamente il pericolo"],
	["ATTACCA", "CLICK SX", "Colpo rapido con l'amo"],
	["PESCA", "F", "Lancia la lenza verso i pesci"],
	["RECUPERA", "R", "Tira la preda: il pesce cura la vita"],
	["INTERAGISCI", "E", "Altari, porte, mappe e passaggi"],
	["ABILITÀ SIGILLATA", "C", "L'amo da attraversamento si ottiene dal Custode"],
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
	["ABILITÀ SIGILLATA", "AMO", "Si sblocca sconfiggendo il Custode"],
]

func _is_touch_platform() -> bool:
	return OS.get_name() == "Android"

func _ready():
	layer = 200  # Sopra tutto
	AsyncSceneLoader.preload_scene(DOGANA_SCENE)
	_create_background()
	_create_controls_display()
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

	_frame = PanelContainer.new()
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color(0.008, 0.028, 0.034, 0.93)
	_frame_style.border_color = Color(0.57, 0.5, 0.31, 0.72)
	_frame_style.set_border_width_all(1)
	_frame_style.set_corner_radius_all(10)
	_frame_style.shadow_color = Color(0, 0, 0, 0.72)
	_frame_style.shadow_size = 18
	_frame.add_theme_stylebox_override("panel", _frame_style)
	main_container.add_child(_frame)

	var scroll := ScrollContainer.new()
	scroll.name = "ResponsiveScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(scroll)

	controls_container = VBoxContainer.new()
	controls_container.name = "ControlsContainer"
	controls_container.add_theme_constant_override("separation", 10)
	controls_container.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(controls_container)

	var eyebrow := Label.new()
	eyebrow.text = "MANUALE DEL PESCATORE  ·  I"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", BODY_FONT)
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.38, 0.74, 0.68, 0.9))
	controls_container.add_child(eyebrow)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "Sopravvivere al Caligo"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 45)
	_title.add_theme_color_override("font_color", Color(0.91, 0.83, 0.62, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0, 0.01, 0.014, 0.95))
	_title.add_theme_constant_override("outline_size", 3)
	controls_container.add_child(_title)

	_rule = HSeparator.new()
	_rule.custom_minimum_size.y = 8
	_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_container.add_child(_rule)

	var commands: Array = _commands_touch if _is_touch_platform() else _commands_pc
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_container.add_child(_grid)
	for cmd in commands:
		_create_command_row(_grid, cmd[0], cmd[1], cmd[2])

	var fishing_note := Label.new()
	fishing_note.text = "PESCA PER VIVERE  ·  Ogni pesce recuperato restituisce salute."
	fishing_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fishing_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	row.custom_minimum_size = Vector2(0, 76)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_rows.append(row)

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
	_key_labels.append(key_label)

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
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(desc_label)


func _apply_responsive_layout() -> void:
	if _frame == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	_frame.custom_minimum_size = CaligoResponsiveLayout.fitted_panel(viewport_size, Vector2(1040, 630), 16.0)
	var side_margin := 16.0 if compact else 44.0
	_frame_style.content_margin_left = side_margin
	_frame_style.content_margin_right = side_margin
	_frame_style.content_margin_top = 14.0 if compact else 28.0
	_frame_style.content_margin_bottom = 14.0 if compact else 24.0
	_grid.columns = 1 if compact else 2
	_grid.add_theme_constant_override("h_separation", 8 if compact else 14)
	_grid.add_theme_constant_override("v_separation", 6 if compact else 10)
	controls_container.add_theme_constant_override("separation", 6 if compact else 10)
	_title.add_theme_font_size_override("font_size", 33 if compact else 45)
	for row in _rows:
		row.custom_minimum_size.y = 62.0 if compact else 76.0
	for key_label in _key_labels:
		key_label.custom_minimum_size.x = 82.0 if compact else 110.0

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
	_fade_tween = create_tween()
	_fade_tween.tween_property(controls_container, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE)
	await _fade_tween.finished

func _fade_out():
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(controls_container, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(background, "color:a", 0.0, fade_duration)
	await _fade_tween.finished

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
