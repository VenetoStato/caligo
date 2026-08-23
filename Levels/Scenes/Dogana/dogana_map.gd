extends CanvasLayer

signal fast_travel_requested(site_id: String, debug_unlock: bool)

@onready var _map_button: Button = $MapButton
@onready var _overlay: Control = $Overlay
@onready var _status: Label = $Overlay/Frame/Status
@onready var _canvas: Control = $Overlay/Frame/MapCanvas
@onready var _debug_travel: CheckButton = $Overlay/Frame/DebugTravel
@onready var _buttons := {
	"pontile": $Overlay/Frame/MapCanvas/Pontile,
	"dogana": $Overlay/Frame/MapCanvas/Dogana,
	"fortuna": $Overlay/Frame/MapCanvas/Fortuna,
}

var _sites: Dictionary = {}
var _current_site := ""
var _was_paused := false
var _regions: Dictionary = {"arrival": true}
var _player_world_position := Vector2(330, 425)


## La carta si apre con M: a schermo resta solo un glifo appena visibile al
## posto dell'etichetta "CARTA [M]", che spiegava un comando gia' noto.
func _style_map_glyph() -> void:
	_map_button.text = "\u25C8"
	_map_button.flat = true
	_map_button.focus_mode = Control.FOCUS_NONE
	_map_button.custom_minimum_size = Vector2(30, 30)
	_map_button.offset_left = -78.0
	_map_button.offset_right = -48.0
	_map_button.offset_top = 8.0
	_map_button.offset_bottom = 38.0
	_map_button.modulate = Color(1, 1, 1, 0.34)
	_map_button.add_theme_font_size_override("font_size", 16)
	_map_button.add_theme_color_override("font_color", Color(0.7, 0.79, 0.75, 1.0))
	_map_button.add_theme_color_override("font_hover_color", Color(0.96, 0.86, 0.55, 1.0))
	_map_button.mouse_entered.connect(func() -> void: _map_button.modulate.a = 0.9)
	_map_button.mouse_exited.connect(func() -> void: _map_button.modulate.a = 0.34)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.visible = false
	_map_button.pressed.connect(toggle_map)
	_style_map_glyph()
	$Overlay/Frame/Close.pressed.connect(close_map)
	_debug_travel.toggled.connect(_on_debug_travel_toggled)
	for site_id in _buttons:
		(_buttons[site_id] as Button).pressed.connect(_on_site_pressed.bind(site_id))


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel") and _overlay.visible
		or event is InputEventKey
		and event.pressed
		and not event.echo
		and event.physical_keycode == KEY_M
	):
		toggle_map()
		get_viewport().set_input_as_handled()


func configure_sites(sites: Array[Dictionary], current_site: String) -> void:
	_sites.clear()
	_current_site = current_site
	for site in sites:
		_sites[str(site["id"])] = site
	_refresh()


func set_current_site(site_id: String) -> void:
	_current_site = site_id
	_refresh()


func configure_regions(regions: Dictionary) -> void:
	_regions = regions.duplicate()
	if _canvas and _canvas.has_method("set_map_state"):
		_canvas.call("set_map_state", _regions, _player_world_position)


func set_player_world_position(world_position: Vector2) -> void:
	_player_world_position = world_position
	if _overlay.visible and _canvas and _canvas.has_method("set_map_state"):
		_canvas.call("set_map_state", _regions, _player_world_position)


func toggle_map() -> void:
	if _overlay.visible:
		close_map()
	else:
		open_map()


func open_map() -> void:
	# Un solo modal alla volta: una lettura aperta non deve lasciare la pausa
	# incastrata quando si passa direttamente alla carta.
	var reader := get_tree().current_scene.get_node_or_null("LoreReader") if get_tree().current_scene else null
	if reader and reader.has_method("close_entry"):
		reader.call("close_entry")
	_was_paused = get_tree().paused
	get_tree().paused = true
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	$Overlay/Frame.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property($Overlay/Frame, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_refresh()
	if _canvas.has_method("set_map_state"):
		_canvas.call("set_map_state", _regions, _player_world_position)


func close_map() -> void:
	if not _overlay.visible:
		return
	_overlay.visible = false
	get_tree().paused = _was_paused


func _refresh() -> void:
	if not is_node_ready():
		return
	for site_id in _buttons:
		var button := _buttons[site_id] as Button
		var data: Dictionary = _sites.get(site_id, {})
		var discovered := bool(data.get("activated", false))
		var available := discovered or _debug_travel.button_pressed
		button.disabled = not available
		button.text = "GRAZIA\n%s" % str(data.get("name", "Sconosciuto")) if available else "?\nNON SCOPERTO"
		button.modulate = Color(1.0, 0.84, 0.45, 1.0) if site_id == _current_site else Color.WHITE
	_status.text = (
		"DEBUG ATTIVO - clicca una Grazia per sbloccarla e raggiungerla"
		if _debug_travel.button_pressed
		else "Seleziona un Altare della Marea scoperto per viaggiare"
	)


func _on_site_pressed(site_id: String) -> void:
	var data: Dictionary = _sites.get(site_id, {})
	if not bool(data.get("activated", false)) and not _debug_travel.button_pressed:
		return
	var debug_unlock := _debug_travel.button_pressed and not bool(data.get("activated", false))
	close_map()
	fast_travel_requested.emit(site_id, debug_unlock)


func _on_debug_travel_toggled(_enabled: bool) -> void:
	_refresh()
