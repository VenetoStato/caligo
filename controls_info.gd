extends CanvasLayer

# ===========================================
# CONTROLS INFO - Infografica dei comandi
# ===========================================
# Mostra i comandi del gioco con icone/immagini

@export_category("Timing")
@export var auto_advance_time: float = 10.0  # Secondi prima di avanzare automaticamente
@export var fade_duration: float = 0.5

@export_category("Visual")
@export var background_color: Color = Color(0.05, 0.05, 0.1, 1.0)
@export var text_color: Color = Color(1, 1, 1, 1)
@export var key_color: Color = Color(0.3, 0.6, 0.9, 1.0)

var controls_container: VBoxContainer
var background: ColorRect
var skip_timer: float = 0.0

# Lista dei comandi: [azione, tasto, descrizione] — senza sprite/icone
var commands: Array = [
	["Movimento", "A / D", "Muovi il personaggio"],
	["Salto", "SPAZIO", "Salta (doppio salto disponibile)"],
	["Dash", "SHIFT", "Scatto veloce"],
	["Attacco", "Z", "Attacco base"],
	["Attacco Forte", "Click Destro", "Attacco potente"],
	["Lancia Lenza", "F", "Lancia la lenza da pesca"],
	["Tira Lenza", "R", "Tira la lenza verso di te"],
	["Afferra", "G", "Afferra oggetti/ancoraggi"],
	["Cambia Amo", "C", "Cambia tipo di amo"],
]

func _ready():
	layer = 200  # Sopra tutto
	_create_background()
	_create_controls_display()
	
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

func _create_controls_display():
	# Container principale centrato
	var main_container = CenterContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Container verticale per i comandi
	controls_container = VBoxContainer.new()
	controls_container.name = "ControlsContainer"
	controls_container.add_theme_constant_override("separation", 18)
	controls_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(controls_container)
	
	# Titolo
	var title = Label.new()
	title.name = "Title"
	title.text = "CONTROLLI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", text_color)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 4)
	controls_container.add_child(title)
	
	# Spaziatura
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	controls_container.add_child(spacer1)
	
	# Aggiungi ogni comando (solo testo, senza sprite)
	for cmd in commands:
		var action = cmd[0]
		var key = cmd[1]
		var desc = cmd[2] if cmd.size() > 2 else ""
		_create_command_row(action, key, desc)
	
	# Spaziatura finale
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	controls_container.add_child(spacer2)
	
	# Istruzione per continuare
	var instruction = Label.new()
	instruction.name = "Instruction"
	instruction.text = "Premi un tasto qualsiasi per continuare..."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 20)
	instruction.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.7))
	controls_container.add_child(instruction)
	
	# Inizia invisibile per fade in
	controls_container.modulate.a = 0.0

func _create_command_row(action: String, key: String, description: String):
	# Riga allineata: Azione (larghezza fissa) | Tasto (box fisso) | Descrizione (larghezza fissa)
	var row = HBoxContainer.new()
	row.name = "CommandRow_" + action
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_container.add_child(row)
	
	# Colonna azione (larghezza fissa, allineata a destra)
	var action_label = Label.new()
	action_label.name = "ActionLabel"
	action_label.text = action + ":"
	action_label.add_theme_font_size_override("font_size", 24)
	action_label.add_theme_color_override("font_color", text_color)
	action_label.custom_minimum_size = Vector2(200, 0)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(action_label)
	
	# Box tasto (larghezza fissa)
	var key_box = Panel.new()
	key_box.name = "KeyBox"
	key_box.custom_minimum_size = Vector2(180, 40)
	
	var style = StyleBoxFlat.new()
	style.bg_color = key_color
	style.border_color = Color(key_color.r * 0.6, key_color.g * 0.6, key_color.b * 0.6, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	key_box.add_theme_stylebox_override("panel", style)
	
	var key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = key
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 18)
	key_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	key_box.add_child(key_label)
	
	row.add_child(key_box)
	
	# Colonna descrizione (larghezza fissa, allineata a sinistra)
	var desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.85))
	desc_label.custom_minimum_size = Vector2(340, 0)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(desc_label)

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
	await _fade_out()
	
	# Passa alla schermata del testo poetico
	var poetic_scene = load("res://poetic_text.tscn")
	if poetic_scene:
		get_tree().change_scene_to_packed(poetic_scene)
	else:
		# Se non esiste, vai direttamente al gioco
		var game_scene = load("res://Levels/Scenes/test_area.tscn")
		if game_scene:
			get_tree().change_scene_to_packed(game_scene)
