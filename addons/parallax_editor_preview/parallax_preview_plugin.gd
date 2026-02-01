@tool
extends EditorPlugin
## Pannello in basso "Parallax Preview": seleziona un ParallaxBackground con lo script parallax_preview.gd
## e muovi gli slider X/Y per vedere l'effetto parallasse nell'editor.

var _panel: Control
var _spin_x: SpinBox
var _spin_y: SpinBox
var _current_parallax: Node

func _enter_tree() -> void:
	_panel = _make_panel()
	add_control_to_bottom_panel(_panel, "Parallax Preview")
	_panel.hide()
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)

func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	remove_control_from_bottom_panel(_panel)
	if _panel:
		_panel.queue_free()

func _make_panel() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	v.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	margin.add_child(inner)
	var lbl := Label.new()
	lbl.text = "Preview Offset (muovi per vedere il parallasse in editor):"
	inner.add_child(lbl)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var lbl_x := Label.new()
	lbl_x.text = "X:"
	lbl_x.custom_minimum_size.x = 20
	h.add_child(lbl_x)
	_spin_x = SpinBox.new()
	_spin_x.min_value = -10000
	_spin_x.max_value = 10000
	_spin_x.step = 10
	_spin_x.value_changed.connect(_on_spin_changed)
	h.add_child(_spin_x)
	var lbl_y := Label.new()
	lbl_y.text = "Y:"
	lbl_y.custom_minimum_size.x = 20
	h.add_child(lbl_y)
	_spin_y = SpinBox.new()
	_spin_y.min_value = -10000
	_spin_y.max_value = 10000
	_spin_y.step = 10
	_spin_y.value_changed.connect(_on_spin_changed)
	h.add_child(_spin_y)
	inner.add_child(h)
	var hint := Label.new()
	hint.text = "Seleziona un ParallaxBackground con script Parallax Preview per usare gli slider."
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	inner.add_child(hint)
	return v

func _find_parallax_with_preview(node: Node) -> Node:
	var n: Node = node
	while n:
		if n is ParallaxBackground and n.get_script():
			var path := n.get_script().resource_path
			if path.get_file() == "parallax_preview.gd":
				return n
		n = n.get_parent()
	return null

func _on_selection_changed() -> void:
	var sel = EditorInterface.get_selection().get_selected_nodes()
	if sel.is_empty():
		_panel.hide()
		_current_parallax = null
		return
	var parallax = _find_parallax_with_preview(sel[0])
	if parallax == null:
		_panel.hide()
		_current_parallax = null
		return
	_current_parallax = parallax
	var off = parallax.get("preview_offset")
	if off == null:
		off = parallax.scroll_offset
	_spin_x.set_block_signals(true)
	_spin_y.set_block_signals(true)
	_spin_x.value = off.x
	_spin_y.value = off.y
	_spin_x.set_block_signals(false)
	_spin_y.set_block_signals(false)
	_panel.show()

func _on_spin_changed(_value: float) -> void:
	if _current_parallax == null or not is_instance_valid(_current_parallax):
		return
	var v = Vector2(_spin_x.value, _spin_y.value)
	_current_parallax.set("preview_offset", v)
	_current_parallax.scroll_offset = v
