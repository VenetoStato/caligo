extends CanvasLayer

const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")

@onready var _panel: Control = $Overlay
@onready var _title: Label = $Overlay/Panel/Title
@onready var _body: Label = $Overlay/Panel/Body
@onready var _hint: Label = $Overlay/Panel/Hint

var _was_paused := false
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_label(_title, DISPLAY_FONT, 28, Color(0.98, 0.88, 0.58, 1.0), 8)
	_style_label(_body, BODY_FONT, 20, Color(0.96, 0.94, 0.86, 1.0), 6)
	_style_label(_hint, BODY_FONT, 15, Color(0.88, 0.84, 0.68, 0.95), 4)
	_panel.hide()
	visibility_changed.connect(_on_visibility_changed)
	$Overlay/Panel/Close.pressed.connect(close_entry)


func _style_label(label: Label, font: Font, size: int, color: Color, outline: int) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", outline)


func show_entry(title: String, body: String) -> void:
	_was_paused = get_tree().paused
	_title.text = title.to_upper()
	_body.text = body
	_panel.show()
	_panel.modulate.a = 0.0
	_opened_frame = Engine.get_process_frames()
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.16)


func close_entry() -> void:
	if not _panel.visible:
		return
	_panel.hide()


func _on_visibility_changed() -> void:
	# La scena può essere nascosta direttamente da test/editor: in quel caso
	# rilascia comunque la pausa posseduta dal lettore.
	if not visible:
		_was_paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or Engine.get_process_frames() <= _opened_frame:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_entry()
		get_viewport().set_input_as_handled()
