extends CanvasLayer

# ===========================================
# TUTORIAL HINTS - Indicazioni all'inizio e vicino all'acqua
# ===========================================
# All'inizio: attacco e doppio salto
# Vicino all'acqua: pesca

@export var start_hint_duration: float = 12.0
@export var near_water_distance: float = 320.0

var _player: Node2D = null
var _start_panel: PanelContainer = null
var _fishing_panel: PanelContainer = null
var _start_timer: float = 0.0
var _start_hint_hidden: bool = false

func _ready():
	layer = 15
	_build_start_hint()
	_build_fishing_hint()
	_start_timer = start_hint_duration
	_start_panel.visible = true
	_fishing_panel.visible = false

func _process(delta: float):
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	# Hint iniziale: attacco e doppio salto (nasconde dopo durata o primo input attacco/salto)
	if _start_panel.visible and not _start_hint_hidden:
		_start_timer -= delta
		if _start_timer <= 0.0 or Input.is_action_just_pressed("ui_attack") or Input.is_action_just_pressed("ui_attack_strong") or Input.is_action_just_pressed("ui_accept"):
			_hide_start_hint()
			_start_hint_hidden = true

	# Hint pesca: solo vicino all'acqua
	var near_water := _is_player_near_water()
	if near_water:
		_fishing_panel.visible = true
	else:
		_fishing_panel.visible = false

func _is_player_near_water() -> bool:
	if _player == null:
		return false
	if _player.get("is_in_water") != null and bool(_player.get("is_in_water")):
		return true
	var waters = get_tree().get_nodes_in_group("water")
	for w in waters:
		if w is Node2D:
			var dist = _player.global_position.distance_to((w as Node2D).global_position)
			if dist < near_water_distance:
				return true
	return false

func _build_style_panel(bg_alpha: float = 0.88) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, bg_alpha)
	style.border_color = Color(0.35, 0.5, 0.7, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	return style

func _build_start_hint():
	_start_panel = PanelContainer.new()
	_start_panel.name = "StartHint"
	_start_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_start_panel.set_anchor(SIDE_LEFT, 0.5)
	_start_panel.set_anchor(SIDE_TOP, 0.0)
	_start_panel.set_offset(SIDE_LEFT, -200)
	_start_panel.set_offset(SIDE_TOP, 24)
	_start_panel.set_custom_minimum_size(Vector2(400, 0))
	_start_panel.add_theme_stylebox_override("panel", _build_style_panel())
	add_child(_start_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_start_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Combat & movimento"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	var l1 = Label.new()
	l1.text = "Attacco: Z o Click sinistro  |  Attacco forte: Click destro"
	l1.add_theme_font_size_override("font_size", 18)
	l1.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l1.add_theme_constant_override("outline_size", 1)
	vbox.add_child(l1)

	var l2 = Label.new()
	l2.text = "Doppio salto: SPAZIO due volte"
	l2.add_theme_font_size_override("font_size", 18)
	l2.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l2.add_theme_constant_override("outline_size", 1)
	vbox.add_child(l2)

func _build_fishing_hint():
	_fishing_panel = PanelContainer.new()
	_fishing_panel.name = "FishingHint"
	_fishing_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fishing_panel.set_anchor(SIDE_LEFT, 0.5)
	_fishing_panel.set_anchor(SIDE_BOTTOM, 1.0)
	_fishing_panel.set_offset(SIDE_LEFT, -200)
	_fishing_panel.set_offset(SIDE_BOTTOM, -28)
	_fishing_panel.set_custom_minimum_size(Vector2(400, 0))
	_fishing_panel.add_theme_stylebox_override("panel", _build_style_panel())
	add_child(_fishing_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_fishing_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Pesca"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	var l1 = Label.new()
	l1.text = "F lancia lenza  |  R recupera  |  C cambia amo (pesca / lancio)"
	l1.add_theme_font_size_override("font_size", 18)
	l1.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l1.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l1.add_theme_constant_override("outline_size", 1)
	vbox.add_child(l1)

func _hide_start_hint():
	if _start_panel == null:
		return
	var tween = create_tween()
	tween.tween_property(_start_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _start_panel.visible = false)
