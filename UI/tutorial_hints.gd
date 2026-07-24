extends CanvasLayer

signal tutorial_completed

enum Step {
	MOVE,
	INTERACT,
	JUMP,
	DOUBLE_JUMP,
	DASH,
	ATTACK,
	CAST,
	REEL,
	MAP,
	COMPLETE,
}

const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")
const STEP_ORDER: Array[Step] = [
	Step.MOVE,
	Step.INTERACT,
	Step.JUMP,
	Step.DOUBLE_JUMP,
	Step.DASH,
	Step.ATTACK,
	Step.CAST,
	Step.REEL,
	Step.MAP,
]

var _player: CharacterBody2D
var _panel: PanelContainer
var _fishing_panel: PanelContainer
var _eyebrow: Label
var _title: Label
var _instruction: Label
var _key_label: Label
var _progress: Label
var _start_position := Vector2.INF
var _completed: Dictionary = {}
var _observed: Dictionary = {}
var _current_step: Step = Step.MOVE
var _completion_started := false
var _player_signal_connected := false
var _fish_signal_connected := false
var _step_transition: Tween


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	for step in STEP_ORDER:
		_completed[step] = false
		_observed[step] = false
	_build_panel()
	_fishing_panel = _panel
	var level := get_tree().current_scene
	if level and level.has_signal("grace_activated"):
		level.connect("grace_activated", _on_grace_activated)
	var training_cache := level.get_node_or_null("Gameplay/Breakables/ArrivalCache") if level else null
	if training_cache and training_cache.has_signal("prop_broken"):
		training_cache.connect("prop_broken", _on_training_cache_broken)
	_refresh_step()


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player == null:
			return
		_start_position = _player.global_position
	if not _player_signal_connected and _player.has_signal("tutorial_action_performed"):
		_player.connect("tutorial_action_performed", _on_player_tutorial_action)
		_player_signal_connected = true
	if not _fish_signal_connected and _player.has_signal("fish_caught"):
		_player.connect("fish_caught", _on_fish_caught)
		_fish_signal_connected = true
	if _current_step == Step.MOVE:
		var moved := absf(_player.global_position.x - _start_position.x) >= 72.0
		if moved:
			_mark_completed(Step.MOVE)
	if _current_step == Step.MAP:
		var map_overlay := get_tree().current_scene.get_node_or_null("DoganaMap/Overlay") as Control
		if map_overlay and map_overlay.visible:
			_observe_step(Step.MAP)


func _unhandled_input(event: InputEvent) -> void:
	# Le azioni vengono confermate dai sistemi che le hanno realmente eseguite,
	# non dal solo tasto premuto. Manteniamo l'hook per compatibilità con la scena.
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
		var map_overlay := get_tree().current_scene.get_node_or_null("DoganaMap/Overlay") as Control
		if map_overlay and map_overlay.visible:
			_observe_step(Step.MAP)


func _on_player_tutorial_action(action: StringName) -> void:
	match action:
		&"jump":
			_observe_step(Step.JUMP)
		&"double_jump":
			_observe_step(Step.DOUBLE_JUMP)
		&"dash":
			_observe_step(Step.DASH)
		&"cast":
			_observe_step(Step.CAST)


func _on_fish_caught(_health_restored: int) -> void:
	_observe_step(Step.REEL)


func _on_grace_activated(_site_id: String) -> void:
	_observe_step(Step.INTERACT)


func _on_training_cache_broken() -> void:
	_observe_step(Step.ATTACK)


func _observe_step(step: Step) -> void:
	_observed[step] = true
	if step == _current_step:
		_mark_completed(step)


func _mark_completed(step: Step) -> void:
	if bool(_completed.get(step, false)):
		return
	_completed[step] = true
	_refresh_step()


func _refresh_step() -> void:
	for step in STEP_ORDER:
		if not bool(_completed.get(step, false)):
			if bool(_observed.get(step, false)):
				_completed[step] = true
				continue
			_current_step = step
			_apply_step_copy(step)
			return
	_current_step = Step.COMPLETE
	_unlock_tutorial_gate()
	_show_completion()


func _apply_step_copy(step: Step) -> void:
	var touch := OS.get_name() == "Android"
	var copy := _get_step_copy(step, touch)
	if _step_transition and _step_transition.is_valid():
		_step_transition.kill()
	_step_transition = create_tween()
	if _title.text.is_empty():
		_panel.modulate.a = 0.0
	else:
		_step_transition.tween_property(_panel, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	_step_transition.tween_callback(_set_step_copy.bind(step, copy))
	_step_transition.tween_property(_panel, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE)


func _set_step_copy(step: Step, copy: Dictionary) -> void:
	_eyebrow.text = "%s  ·  %02d / %02d" % [
		_get_section_label(step),
		_completed_count() + 1,
		STEP_ORDER.size(),
	]
	_title.text = str(copy.title)
	_instruction.text = str(copy.instruction)
	_key_label.text = str(copy.key)
	_progress.text = _build_progress_text()
	_panel.visible = true
	var pulse := create_tween()
	pulse.tween_property(_key_label, "modulate", Color(1.35, 1.2, 0.72, 1.0), 0.12)
	pulse.tween_property(_key_label, "modulate", Color.WHITE, 0.22)


func _get_section_label(step: Step) -> String:
	if step in [Step.MOVE, Step.INTERACT]:
		return "SEZIONE I  ·  IL PONTILE"
	if step in [Step.JUMP, Step.DOUBLE_JUMP, Step.DASH]:
		return "SEZIONE II  ·  MOVIMENTO"
	if step == Step.ATTACK:
		return "SEZIONE III  ·  OGGETTI FRAGILI"
	if step in [Step.CAST, Step.REEL]:
		return "SEZIONE IV  ·  PESCA"
	return "SEZIONE V  ·  ORIENTAMENTO"


func _get_step_copy(step: Step, touch: bool) -> Dictionary:
	match step:
		Step.MOVE:
			return {
				"title": "Prendi confidenza col pontile",
				"instruction": "Muoviti fino all'altare. Il pannello resta visibile finché l'azione non è completata.",
				"key": "◀  ▶" if touch else "A   /   D",
			}
		Step.INTERACT:
			return {
				"title": "Risveglia e usa gli altari",
				"instruction": "Avvicinati all'altare luminoso e interagisci. Qui riposi, curi e imposti il respawn.",
				"key": "✦" if touch else "E",
			}
		Step.JUMP:
			return {
				"title": "Supera gli ostacoli bassi",
				"instruction": "Prova un salto sul pontile. Il comando risponde appena viene premuto.",
				"key": "↑" if touch else "SPAZIO",
			}
		Step.DOUBLE_JUMP:
			return {
				"title": "Resta sospeso un istante",
				"instruction": "Premi salto una seconda volta mentre sei in aria per effettuare il doppio salto.",
				"key": "↑   ↑" if touch else "SPAZIO  × 2",
			}
		Step.DASH:
			return {
				"title": "Attraversa rapidamente il pericolo",
				"instruction": "Esegui uno scatto. Puoi usarlo a terra o durante un salto.",
				"key": "D" if touch else "SHIFT",
			}
		Step.ATTACK:
			return {
				"title": "Rompi la cassa da pesca",
				"instruction": "Colpisci la cassa illustrata sul pontile. Gli oggetti crepati nascondono spesso passaggi.",
				"key": "Z" if touch else "CLICK SINISTRO",
			}
		Step.CAST:
			return {
				"title": "La pesca è il tuo nutrimento",
				"instruction": "Tieni premuto per mirare e lancia la lenza verso i pesci sotto il pontile.",
				"key": "LENZA" if touch else "F",
			}
		Step.REEL:
			return {
				"title": "Recupera la preda",
				"instruction": "Quando un pesce abbocca, tira a impulsi. Ogni cattura restituisce un punto vita.",
				"key": "TIRA" if touch else "R",
			}
		Step.MAP:
			return {
				"title": "Consulta la mappa della laguna",
				"instruction": "Apri la mappa: mostra stanze scoperte, altari attivi e passaggi nascosti trovati.",
				"key": "MAPPA" if touch else "M",
			}
	return {"title": "", "instruction": "", "key": ""}


func _completed_count() -> int:
	var count := 0
	for step in STEP_ORDER:
		if bool(_completed.get(step, false)):
			count += 1
	return count


func _build_progress_text() -> String:
	var markers: PackedStringArray = []
	for step in STEP_ORDER:
		markers.append("◆" if bool(_completed.get(step, false)) else "◇")
	return "  ".join(markers)


func _unlock_tutorial_gate() -> void:
	var gate := get_tree().get_first_node_in_group("dogana_tutorial_gate")
	if gate and gate.has_method("unlock"):
		gate.call("unlock")


func _show_completion() -> void:
	if _completion_started:
		return
	_completion_started = true
	_eyebrow.text = "ADDESTRAMENTO COMPLETATO"
	_title.text = "La Dogana è davanti a te"
	_instruction.text = "Pesca per curarti, osserva i telegraph nemici e cerca crepe nelle pareti."
	_key_label.text = "IL VARCO È APERTO"
	_progress.text = "◆  ◆  ◆  ◆  ◆  ◆  ◆  ◆  ◆"
	tutorial_completed.emit()
	var completion_timer := Timer.new()
	completion_timer.one_shot = true
	completion_timer.wait_time = 5.5
	completion_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	completion_timer.timeout.connect(_fade_completed_tutorial)
	add_child(completion_timer)
	completion_timer.start()


func _fade_completed_tutorial() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: _panel.visible = false)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GuidedTutorial"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 24.0
	_panel.offset_top = 108.0
	_panel.custom_minimum_size = Vector2(390.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.025, 0.032, 0.985)
	style.border_color = Color(0.78, 0.66, 0.36, 0.94)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_panel.add_child(content)
	_eyebrow = Label.new()
	_eyebrow.add_theme_font_override("font", BODY_FONT)
	_eyebrow.add_theme_font_size_override("font_size", 12)
	_eyebrow.add_theme_color_override("font_color", Color(0.56, 1.0, 0.88, 1.0))
	_eyebrow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_eyebrow.add_theme_constant_override("outline_size", 1)
	content.add_child(_eyebrow)
	_title = Label.new()
	_title.add_theme_font_override("font", DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_title.add_theme_constant_override("outline_size", 2)
	content.add_child(_title)
	_instruction = Label.new()
	_instruction.custom_minimum_size = Vector2(360, 0)
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.add_theme_font_override("font", BODY_FONT)
	_instruction.add_theme_font_size_override("font_size", 14)
	_instruction.add_theme_color_override("font_color", Color(0.92, 0.96, 0.92, 1.0))
	_instruction.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_instruction.add_theme_constant_override("outline_size", 1)
	content.add_child(_instruction)
	_key_label = Label.new()
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_override("font", BODY_FONT)
	_key_label.add_theme_font_size_override("font_size", 16)
	_key_label.add_theme_color_override("font_color", Color(0.56, 1.0, 0.86, 1.0))
	_key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_key_label.add_theme_constant_override("outline_size", 2)
	content.add_child(_key_label)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_override("font", BODY_FONT)
	_progress.add_theme_font_size_override("font_size", 12)
	_progress.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55, 0.9))
	content.add_child(_progress)
