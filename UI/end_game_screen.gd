extends CanvasLayer

# ===========================================
# END GAME SCREEN - TE SI STA BRAO
# ===========================================
# Mostrata quando 3/3 pesci + 3/3 leoni. Mostra tempo, tier, pulsanti Esci e Ricomincia.

var _panel: PanelContainer = null
var _title_label: Label = null
var _time_label: Label = null
var _tier_label: Label = null
var _buttons_container: HBoxContainer = null

func _ready() -> void:
	layer = 100
	_build_ui()
	hide()

func show_with_result(elapsed_sec: float) -> void:
	var am = get_node_or_null("/root/AchievementManager") as Node
	var tier: String = "B"
	if am and am.has_method("get_tier_for_time"):
		tier = am.get_tier_for_time(elapsed_sec)
	var minuti := int(elapsed_sec) / 60
	var secondi := int(elapsed_sec) % 60
	var time_str := "%d:%02d" % [minuti, secondi]
	if _time_label:
		_time_label.text = "Tempo:  " + time_str
	if _tier_label:
		_tier_label.text = "Rank:  " + tier
		# Colore in base al tier
		var c := Color(0.85, 0.85, 0.9, 1)
		if tier == "S":
			c = Color(1.0, 0.92, 0.25, 1)
		elif tier == "S-":
			c = Color(0.95, 0.88, 0.5, 1)
		elif tier == "A":
			c = Color(0.6, 0.85, 1.0, 1)
		_tier_label.add_theme_color_override("font_color", c)
	show()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.02, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.set_anchor(SIDE_TOP, 0.35)
	_panel.set_offset(SIDE_LEFT, -220)
	_panel.set_offset(SIDE_TOP, 0)
	_panel.set_offset(SIDE_RIGHT, 220)
	_panel.set_offset(SIDE_BOTTOM, 380)
	_panel.custom_minimum_size = Vector2(440, 340)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.18, 0.98)
	style.border_color = Color(0.45, 0.5, 0.7, 1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(32)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "TE SI STA BRAO"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 42)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5, 1))
	_title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 1))
	_title_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_title_label)

	_time_label = Label.new()
	_time_label.name = "Time"
	_time_label.text = "Tempo:  0:00"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 28)
	_time_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95, 1))
	vbox.add_child(_time_label)

	_tier_label = Label.new()
	_tier_label.name = "Tier"
	_tier_label.text = "Rank:  —"
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_tier_label)

	vbox.add_child(Control.new())  # spacer

	_buttons_container = HBoxContainer.new()
	_buttons_container.add_theme_constant_override("separation", 24)
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_buttons_container)

	var btn_esci = _make_button("Esci", _on_esci_pressed)
	_buttons_container.add_child(btn_esci)
	var btn_ricomincia = _make_button("Ricomincia", _on_ricomincia_pressed)
	_buttons_container.add_child(btn_ricomincia)

func _make_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 52)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(callback)
	return btn

func _on_esci_pressed() -> void:
	get_tree().quit()

func _on_ricomincia_pressed() -> void:
	var am = get_node_or_null("/root/AchievementManager")
	if am and am.has_method("reset_run"):
		am.reset_run()
	get_tree().reload_current_scene()
