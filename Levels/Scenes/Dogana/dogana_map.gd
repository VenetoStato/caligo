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


## La carta si apre con M. Il pulsante e' la stessa icona della carta, non un
## rombo unicode che sembrava un misuratore.
func _style_map_glyph() -> void:
	_map_button.text = ""
	_map_button.flat = true
	_map_button.focus_mode = Control.FOCUS_NONE
	_map_button.tooltip_text = "Carta della Dogana  [M]"
	_map_button.custom_minimum_size = Vector2(46, 46)
	_map_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_map_button.offset_left = -66.0
	_map_button.offset_right = -20.0
	_map_button.offset_top = -66.0
	_map_button.offset_bottom = -20.0
	_map_button.modulate = Color(0.7, 0.88, 0.82, 0.34)
	_map_button.add_theme_color_override("font_color", Color(0.78, 0.94, 0.88, 1.0))
	_map_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_map_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_map_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_map_button.mouse_entered.connect(func() -> void: _map_button.modulate.a = 0.72)
	_map_button.mouse_exited.connect(func() -> void: _map_button.modulate.a = 0.34)
	if _map_button.get_node_or_null("MapGlyph") == null:
		var glyph := HintMark.new()
		glyph.name = "MapGlyph"
		glyph.position = Vector2(0.0, 0.0)
		glyph.size = Vector2(46.0, 46.0)
		glyph.show_mark(HintMark.Mark.MAP, "")
		_map_button.add_child(glyph)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# La scena principale salva questo CanvasLayer nascosto per non coprire la
	# viewport dell'editor. In gioco deve riattivarsi autonomamente: altrimenti M
	# metteva in pausa con l'overlay figlio visibile dentro un parent invisibile.
	visible = true
	_overlay.visible = false
	_map_button.pressed.connect(toggle_map)
	_style_map_glyph()
	$Overlay/Frame/Close.pressed.connect(close_map)
	_debug_travel.toggled.connect(_on_debug_travel_toggled)
	call_deferred("_bind_global_debug")
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
	visible = true
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	$Overlay/Frame.scale = Vector2(0.96, 0.96)
	# Pausa soltanto dopo che l'intera gerarchia CanvasLayer -> Overlay e' stata
	# resa visibile. Anche senza tween non puo' piu' esistere un freeze "cieco".
	get_tree().paused = true
	var tween := create_tween().set_parallel(true)
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
		var available := discovered or _is_debug_travel_enabled()
		button.disabled = not available
		button.text = "GRAZIA\n%s" % str(data.get("name", "Sconosciuto")) if available else "?\nNON SCOPERTO"
		button.modulate = Color(1.0, 0.84, 0.45, 1.0) if site_id == _current_site else Color.WHITE
	_status.text = (
		"DEBUG ATTIVO - tutte le Grazie sono selezionabili"
		if _is_debug_travel_enabled()
		else "Seleziona un Altare della Marea scoperto per viaggiare"
	)


func _on_site_pressed(site_id: String) -> void:
	var data: Dictionary = _sites.get(site_id, {})
	if not bool(data.get("activated", false)) and not _is_debug_travel_enabled():
		return
	var debug_unlock := _is_debug_travel_enabled() and not bool(data.get("activated", false))
	close_map()
	fast_travel_requested.emit(site_id, debug_unlock)


func _on_debug_travel_toggled(_enabled: bool) -> void:
	_refresh()


func _bind_global_debug() -> void:
	var debug_tools := get_tree().get_first_node_in_group("dogana_debug_tools")
	if debug_tools and debug_tools.has_signal("debug_mode_changed"):
		debug_tools.connect("debug_mode_changed", _on_global_debug_changed)
	_refresh()


func _on_global_debug_changed(_enabled: bool) -> void:
	_refresh()


func _is_debug_travel_enabled() -> bool:
	# Il controllo nascosto resta compatibile con le scene di test; nel gioco
	# il flag piccolo in alto a sinistra e' l'unico ingresso visibile.
	if _debug_travel and _debug_travel.button_pressed:
		return true
	var debug_tools := get_tree().get_first_node_in_group("dogana_debug_tools")
	return debug_tools != null and debug_tools.has_method("is_debug_enabled") and bool(debug_tools.call("is_debug_enabled"))
