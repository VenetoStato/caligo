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
var _section_tween: Tween
var _section_veil: ColorRect
var _last_section := ""
var _armed := false


func _ready() -> void:
	# Sopra PostFX/vignetta (20), sotto HUD (60) e mappa (90)
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	for step in STEP_ORDER:
		_completed[step] = false
		_observed[step] = false
	_build_panel()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_fishing_panel = _panel
	if _panel:
		_panel.visible = false
	var level := get_tree().current_scene
	if level and level.has_signal("grace_activated"):
		level.connect("grace_activated", _on_grace_activated)
	var training_cache := level.get_node_or_null("Gameplay/Breakables/ArrivalCache") if level else null
	if training_cache and training_cache.has_signal("prop_broken"):
		training_cache.connect("prop_broken", _on_training_cache_broken)
	# Hook subito: le azioni fatte prima dell'arm possono valere come step.
	call_deferred("_ensure_player_hooks")
	# Dopo tutti i _ready: se non c'è cutscene di arrivo, arma subito.
	call_deferred("_maybe_auto_arm")


func _maybe_auto_arm() -> void:
	if _armed:
		return
	if get_tree().get_first_node_in_group("dogana_arrival_cutscene") != null:
		return
	arm_tutorial()


func set_armed(armed: bool) -> void:
	_armed = armed
	if _panel and not armed:
		_panel.visible = false


func arm_tutorial() -> void:
	if _armed:
		return
	_armed = true
	_ensure_player_hooks()
	# Dopo la cutscene riparti da QUI: lo spostamento in barca non deve chiudere MOVE.
	if _player:
		_start_position = _player.global_position
		_observed[Step.MOVE] = false
		_completed[Step.MOVE] = false
	_refresh_step()


func _ensure_player_hooks() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		return
	if _start_position == Vector2.INF:
		_start_position = _player.global_position
	if not _player_signal_connected and _player.has_signal("tutorial_action_performed"):
		_player.connect("tutorial_action_performed", _on_player_tutorial_action)
		_player_signal_connected = true
	if not _fish_signal_connected and _player.has_signal("fish_caught"):
		_player.connect("fish_caught", _on_fish_caught)
		_fish_signal_connected = true


func _process(_delta: float) -> void:
	# Sempre: cattura azioni anticipate anche con tutorial non ancora armato.
	_ensure_player_hooks()
	if _player == null:
		return
	if _start_position != Vector2.INF:
		var moved := absf(_player.global_position.x - _start_position.x) >= 72.0
		if moved:
			_observe_step(Step.MOVE)
	var map_overlay := get_tree().current_scene.get_node_or_null("DoganaMap/Overlay") as Control if get_tree().current_scene else null
	if map_overlay and map_overlay.visible:
		_observe_step(Step.MAP)
	if not _armed:
		return


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
		&"attack":
			_observe_step(Step.ATTACK)
		&"cast":
			_observe_step(Step.CAST)
		# REEL si completa solo con una cattura reale (vedi _on_fish_caught).


func _on_fish_caught(_health_restored: int) -> void:
	_observe_step(Step.REEL)


func _on_grace_activated(_site_id: String) -> void:
	_observe_step(Step.INTERACT)


func _on_training_cache_broken() -> void:
	# Anche se il tutorial non è armato / non è ancora ATTACK: memorizza.
	_observed[Step.ATTACK] = true
	_observe_step(Step.ATTACK)


func notify_altar_used() -> void:
	_observe_step(Step.INTERACT)


func _observe_step(step: Step) -> void:
	# Latch sempre: azioni fatte in anticipo non si perdono.
	_observed[step] = true
	if not _armed:
		return
	# Solo lo step corrente si completa subito; i futuri verranno skippati in advance.
	if step != _current_step:
		return
	_mark_completed(step)


func _mark_completed(step: Step) -> void:
	if not _armed:
		return
	if step != _current_step:
		return
	if bool(_completed.get(step, false)):
		return
	_completed[step] = true
	_advance_to_next_step()


func _advance_to_next_step() -> void:
	for step in STEP_ORDER:
		if not bool(_completed.get(step, false)):
			_current_step = step
			# Se lo step era già stato fatto in anticipo, completa subito senza mostrarlo.
			if bool(_observed.get(step, false)):
				_completed[step] = true
				continue
			if step == Step.ATTACK and _is_training_cache_already_broken():
				_observed[step] = true
				_completed[step] = true
				continue
			if step == Step.INTERACT and _is_altar_already_used():
				_observed[step] = true
				_completed[step] = true
				continue
			_apply_step_copy(step)
			return
	_current_step = Step.COMPLETE
	_unlock_tutorial_gate()
	_show_completion()


func _is_altar_already_used() -> bool:
	# Solo se il player ha davvero usato un altare (notify / grace_activated).
	# L'attivazione silenziosa del pontile all'avvio NON conta.
	return bool(_observed.get(Step.INTERACT, false))


func _is_training_cache_already_broken() -> bool:
	var level := get_tree().current_scene
	if level == null:
		return bool(_observed.get(Step.ATTACK, false))
	var cache := level.get_node_or_null("Gameplay/Breakables/ArrivalCache")
	if cache == null:
		return true
	return bool(cache.get("_broken"))


func _refresh_step() -> void:
	_advance_to_next_step()


func _apply_step_copy(step: Step) -> void:
	var touch := OS.get_name() == "Android"
	var copy := _get_step_copy(step, touch)
	if _step_transition and _step_transition.is_valid():
		_step_transition.kill()
	_panel.visible = true
	_step_transition = create_tween()
	if _title.text.is_empty():
		_panel.modulate.a = 0.0
	else:
		_step_transition.tween_property(_panel, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	_step_transition.tween_callback(_set_step_copy.bind(step, copy))
	_step_transition.tween_property(_panel, "modulate:a", 0.82, 0.28).set_trans(Tween.TRANS_SINE)


func _set_step_copy(step: Step, copy: Dictionary) -> void:
	_last_section = _get_section_label(step)
	_eyebrow.text = "%s   ·   %02d / %02d" % [_last_section, _completed_count() + 1, STEP_ORDER.size()]
	_title.text = str(copy.title)
	_instruction.text = str(copy.instruction)
	_key_label.text = str(copy.key)
	_progress.text = _build_progress_text()
	_panel.visible = true


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
				"title": "Muoviti",
				"instruction": "Vai verso l'altare sul pontile.",
				"key": "◀ ▶" if touch else "A / D",
			}
		Step.INTERACT:
			return {
				"title": "Altare",
				"instruction": "Tieni premuto sull'altare per riposare e fissare il respawn.",
				"key": "TIENI ✦" if touch else "TIENI E",
			}
		Step.JUMP:
			return {
				"title": "Salto",
				"instruction": "Salta una volta sul pontile.",
				"key": "↑" if touch else "SPAZIO",
			}
		Step.DOUBLE_JUMP:
			return {
				"title": "Doppio salto",
				"instruction": "In aria, salta di nuovo.",
				"key": "↑↑" if touch else "SPAZIO ×2",
			}
		Step.DASH:
			return {
				"title": "Scatto",
				"instruction": "Esegui uno scatto a terra o in aria.",
				"key": "⚡" if touch else "SHIFT",
			}
		Step.ATTACK:
			return {
				"title": "Attacco",
				"instruction": "Rompi la cassa sul pontile.",
				"key": "⚔" if touch else "CLICK",
			}
		Step.CAST:
			return {
				"title": "Pesca",
				"instruction": "Con F lanci la lenza (e un po' di pastura). Mira al varco d'acqua.",
				"key": "LENZA" if touch else "F",
			}
		Step.REEL:
			return {
				"title": "Tira",
				"instruction": "Quando abborda: tieni R per recuperare, rilascia se la lenza diventa rossa. Serve una cattura.",
				"key": "R" if touch else "R (tieni / rilascia)",
			}
		Step.MAP:
			return {
				"title": "Mappa",
				"instruction": "Apri la mappa della laguna.",
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
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_shake"):
		cam.call("add_shake", 0.38)
	var level := get_tree().current_scene
	if level and level.has_method("_show_message"):
		level.call("_show_message", "IL VARCO È APERTO — prosegui sul pontile")


func _show_completion() -> void:
	if _completion_started:
		return
	_completion_started = true
	_eyebrow.text = "OK"
	_title.text = "Varco aperto"
	_instruction.text = "Puoi lasciare il pontile."
	_key_label.text = ""
	_progress.text = ""
	tutorial_completed.emit()
	var completion_timer := Timer.new()
	completion_timer.one_shot = true
	completion_timer.wait_time = 3.5
	completion_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	completion_timer.timeout.connect(_fade_completed_tutorial)
	add_child(completion_timer)
	completion_timer.start()


func _fade_completed_tutorial() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: _panel.visible = false)


func _build_panel() -> void:
	# Niente velo a tutto schermo: troppo invasivo.
	_section_veil = null

	_panel = PanelContainer.new()
	_panel.name = "GuidedTutorial"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 16.0
	_panel.offset_bottom = -16.0
	_panel.offset_top = -96.0
	_panel.custom_minimum_size = Vector2(240.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.03, 0.04, 0.72)
	style.border_color = Color(0.55, 0.5, 0.32, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", style)
	_panel.modulate.a = 0.82
	add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	_panel.add_child(content)
	_eyebrow = Label.new()
	_eyebrow.add_theme_font_override("font", BODY_FONT)
	_eyebrow.add_theme_font_size_override("font_size", 11)
	_eyebrow.add_theme_color_override("font_color", Color(0.55, 0.85, 0.78, 0.85))
	content.add_child(_eyebrow)
	_title = Label.new()
	_title.add_theme_font_override("font", DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72, 0.95))
	content.add_child(_title)
	_instruction = Label.new()
	_instruction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.add_theme_font_override("font", BODY_FONT)
	_instruction.add_theme_font_size_override("font_size", 12)
	_instruction.add_theme_color_override("font_color", Color(0.86, 0.9, 0.88, 0.9))
	content.add_child(_instruction)
	_key_label = Label.new()
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_key_label.add_theme_font_override("font", BODY_FONT)
	_key_label.add_theme_font_size_override("font_size", 13)
	_key_label.add_theme_color_override("font_color", Color(0.5, 0.92, 0.8, 0.95))
	content.add_child(_key_label)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_progress.add_theme_font_override("font", BODY_FONT)
	_progress.add_theme_font_size_override("font_size", 10)
	_progress.add_theme_color_override("font_color", Color(0.75, 0.7, 0.5, 0.7))
	content.add_child(_progress)


func _apply_responsive_layout() -> void:
	if _panel == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	var margin := clampf(viewport_size.x * 0.02, 10.0, 18.0)
	_panel.offset_left = margin
	_panel.offset_bottom = -margin
	_panel.offset_top = - (88.0 if compact else 100.0)
	_panel.custom_minimum_size.x = clampf(viewport_size.x * 0.28, 200.0, 280.0)
	_title.add_theme_font_size_override("font_size", 16 if compact else 18)
	_instruction.add_theme_font_size_override("font_size", 11 if compact else 12)
