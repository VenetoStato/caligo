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

## Ritardo prima che il glifo compaia: se l'azione la scopri da solo non vedi
## mai nulla. Il suggerimento arriva solo quando resti davvero fermo.
const HINT_DELAY := 4.2

var _player: CharacterBody2D
var _panel: PanelContainer
var _fishing_panel: PanelContainer
var _mark: HintMark
var _hint_wait := 0.0
var _hint_shown := false
var _start_position := Vector2.INF
var _completed: Dictionary = {}
var _observed: Dictionary = {}
var _current_step: Step = Step.MOVE
var _completion_started := false
var _player_signal_connected := false
var _fish_signal_connected := false
var _step_transition: Tween
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
	_update_hint_fade(_delta)


## Il glifo emerge dal nero solo dopo l'attesa e pulsa appena, come un riflesso.
func _update_hint_fade(delta: float) -> void:
	if _panel == null or _completion_started:
		return
	if _current_step == Step.COMPLETE:
		return
	_hint_wait += delta
	if _hint_wait < HINT_DELAY:
		_panel.modulate.a = move_toward(_panel.modulate.a, 0.0, delta * 3.0)
		return
	_hint_shown = true
	var breathe: float = 0.42 + 0.12 * sin(Time.get_ticks_msec() * 0.0021)
	_panel.modulate.a = move_toward(_panel.modulate.a, breathe, delta * 0.9)


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
	if _step_transition and _step_transition.is_valid():
		_step_transition.kill()
	_panel.visible = true
	_panel.modulate.a = 0.0
	_hint_wait = 0.0
	_hint_shown = false
	_mark.show_mark(_step_mark(step), _step_key(step, touch))


## Il disegno dice cosa fare, il tasto dice con cosa farlo.
func _step_mark(step: Step) -> HintMark.Mark:
	match step:
		Step.MOVE:
			return HintMark.Mark.MOVE
		Step.INTERACT:
			return HintMark.Mark.INTERACT
		Step.JUMP:
			return HintMark.Mark.JUMP
		Step.DOUBLE_JUMP:
			return HintMark.Mark.DOUBLE_JUMP
		Step.DASH:
			return HintMark.Mark.DASH
		Step.ATTACK:
			return HintMark.Mark.ATTACK
		Step.CAST:
			return HintMark.Mark.CAST
		Step.REEL:
			return HintMark.Mark.REEL
		Step.MAP:
			return HintMark.Mark.MAP
	return HintMark.Mark.NONE


## Su touch il comando e' un pulsante a schermo: il tasto non si scrive.
func _step_key(step: Step, touch: bool) -> String:
	if touch:
		return ""
	match step:
		Step.MOVE:
			return "A D"
		Step.INTERACT:
			return "E"
		Step.JUMP, Step.DOUBLE_JUMP:
			return "SPAZIO"
		Step.DASH:
			return "SHIFT"
		Step.ATTACK:
			return "CLICK"
		Step.CAST:
			return "F"
		Step.REEL:
			return "R"
		Step.MAP:
			return "M"
	return ""


func _completed_count() -> int:
	var count := 0
	for step in STEP_ORDER:
		if bool(_completed.get(step, false)):
			count += 1
	return count


func _unlock_tutorial_gate() -> void:
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_shake"):
		cam.call("add_shake", 0.16)


func _show_completion() -> void:
	if _completion_started:
		return
	_completion_started = true
	_mark.clear_mark()
	tutorial_completed.emit()
	_fade_completed_tutorial()


func _fade_completed_tutorial() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: _panel.visible = false)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GuidedTutorial"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Nessuna cornice, nessuno sfondo: il glifo galleggia sulla scena.
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_panel.modulate.a = 0.0
	add_child(_panel)

	_mark = HintMark.new()
	_mark.name = "HintMark"
	_panel.add_child(_mark)


func _apply_responsive_layout() -> void:
	if _panel == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	var margin := clampf(viewport_size.y * 0.09, 40.0, 76.0)
	var mark_height := 40.0 if compact else 46.0
	_panel.offset_bottom = -margin
	_panel.offset_top = -margin - mark_height
	_panel.offset_left = -70.0
	_panel.offset_right = 70.0
	if _mark:
		_mark.set_scale_compact(compact)
