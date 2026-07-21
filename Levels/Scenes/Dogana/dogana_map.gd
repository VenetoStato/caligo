extends CanvasLayer

signal fast_travel_requested(site_id: String)

@onready var _map_button: Button = $MapButton
@onready var _overlay: Control = $Overlay
@onready var _status: Label = $Overlay/Frame/Status
@onready var _canvas: Control = $Overlay/Frame/MapCanvas
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.visible = false
	_map_button.pressed.connect(toggle_map)
	$Overlay/Frame/Close.pressed.connect(close_map)
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
		button.disabled = not discovered
		button.text = "✦\n%s" % str(data.get("name", "Sconosciuto")) if discovered else "?\nNON SCOPERTO"
		button.modulate = Color(1.0, 0.84, 0.45, 1.0) if site_id == _current_site else Color.WHITE
	_status.text = "Seleziona un Altare della Marea scoperto per viaggiare"


func _on_site_pressed(site_id: String) -> void:
	var data: Dictionary = _sites.get(site_id, {})
	if not bool(data.get("activated", false)):
		return
	close_map()
	fast_travel_requested.emit(site_id)
