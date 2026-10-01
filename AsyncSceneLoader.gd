extends CanvasLayer

const MIN_VISIBLE_TIME := 4.2
const READY_FRAMES := 3
const OVERLAY_FADE_IN := 1.4
const OVERLAY_FADE_OUT := 2.1
const DISPLAY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const BODY_FONT := preload("res://UI/Fonts/SourceSans3.ttf")
const ARRIVAL_ART := preload("res://Landscape/Dogana/Illustrated/arrival.png")

var _target_path := ""
var _loading := false
var _elapsed := 0.0
var _displayed_progress := 0.0
var _prepared_path := ""
var _preparing := false
var _prepared_scene: PackedScene
var _overlay: ColorRect
var _progress: ProgressBar
var _status: Label
var _box: VBoxContainer
var _loading_title: Label


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_loading_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	set_process(false)


func load_scene(scene_path: String, instant_cover: bool = false) -> void:
	if _loading:
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("AsyncSceneLoader: scena non trovata: " + scene_path)
		return
	var current := get_tree().current_scene
	if current and current.scene_file_path == scene_path:
		return

	_target_path = scene_path
	_loading = true
	_elapsed = 0.0
	_displayed_progress = 0.0
	_overlay.visible = true
	_progress.value = 0.0
	_status.text = "CARICAMENTO…"
	if instant_cover:
		# La schermata precedente è già un velo opaco: niente fade-in da zero.
		_overlay.modulate.a = 1.0
	else:
		_overlay.modulate.a = 0.0
		create_tween().tween_property(_overlay, "modulate:a", 1.0, OVERLAY_FADE_IN).set_trans(Tween.TRANS_SINE)

	if scene_path == _prepared_path:
		if _prepared_scene:
			set_process(false)
			call_deferred("_finish_loading")
			return
		if _preparing:
			set_process(true)
			return

	var error := ResourceLoader.load_threaded_request(_target_path, "", true)
	if error != OK:
		_fail("Impossibile avviare il caricamento (%s)." % error_string(error))
		return
	set_process(true)


func preload_scene(scene_path: String) -> void:
	if _loading or _preparing or _prepared_scene:
		return
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return
	var error := ResourceLoader.load_threaded_request(scene_path, "", true)
	if error != OK:
		return
	_prepared_path = scene_path
	_preparing = true
	set_process(true)


func is_loading() -> bool:
	return _loading


func _process(delta: float) -> void:
	if not _loading and _preparing:
		var preparation_progress: Array = []
		var preparation_status := ResourceLoader.load_threaded_get_status(_prepared_path, preparation_progress)
		if preparation_status == ResourceLoader.THREAD_LOAD_LOADED:
			_prepared_scene = ResourceLoader.load_threaded_get(_prepared_path) as PackedScene
			_preparing = false
			set_process(false)
		elif preparation_status == ResourceLoader.THREAD_LOAD_FAILED or preparation_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_preparing = false
			_prepared_path = ""
			set_process(false)
		return
	if not _loading:
		return
	_elapsed += delta
	var progress_data: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_path, progress_data)
	var raw_progress := float(progress_data[0]) if not progress_data.is_empty() else 0.0
	var target_progress := maxf(_displayed_progress, minf(raw_progress * 94.0, 94.0))
	# Il loader thread può aggiornare a scatti: la barra conserva il valore reale
	# ma lo raggiunge con un moto continuo, senza false pause al 94%.
	_displayed_progress = move_toward(_displayed_progress, target_progress, delta * 68.0)
	_progress.value = _displayed_progress
	_update_status(_displayed_progress)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		call_deferred("_finish_loading")
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail("Il caricamento della scena è fallito.")


func _finish_loading() -> void:
	if not _loading:
		return
	var packed := _prepared_scene if _target_path == _prepared_path else ResourceLoader.load_threaded_get(_target_path) as PackedScene
	if packed == null and _target_path == _prepared_path:
		packed = ResourceLoader.load_threaded_get(_target_path) as PackedScene
	if packed == null:
		_fail("La scena caricata non è valida.")
		return
	var remaining := maxf(0.0, MIN_VISIBLE_TIME - _elapsed)
	if remaining > 0.0:
		await get_tree().create_timer(remaining, true, false, true).timeout
	_status.text = "CARICAMENTO…"
	var progress_tween := create_tween()
	progress_tween.tween_property(_progress, "value", 100.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await progress_tween.finished
	# Copertura piena prima del swap scena: niente frame di clear-color.
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		_fail("Impossibile aprire la scena (%s)." % error_string(error))
		return
	for _frame in READY_FRAMES:
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_status.text = "PRONTO"
	await get_tree().create_timer(0.12, true, false, true).timeout
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 0.0, OVERLAY_FADE_OUT).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_overlay.visible = false
	_loading = false
	_target_path = ""
	_preparing = false
	_prepared_path = ""
	_prepared_scene = null


func _fail(message: String) -> void:
	push_error("AsyncSceneLoader: " + message)
	set_process(false)
	_status.text = "ERRORE DI CARICAMENTO"
	_progress.value = 0.0
	await get_tree().create_timer(1.2, true, false, true).timeout
	_overlay.visible = false
	_loading = false
	_target_path = ""
	_preparing = false
	_prepared_path = ""
	_prepared_scene = null


func _update_status(percent: float) -> void:
	_status.text = "CARICAMENTO…"


func _build_loading_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "LoadingOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.006, 0.018, 0.024, 1.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var backdrop := TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = ARRIVAL_ART
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.24, 0.34, 0.34, 0.38)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(backdrop)
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.004, 0.016, 0.022, 0.8)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 20)
	center.add_child(_box)

	_loading_title = Label.new()
	_loading_title.text = "CALIGO"
	_loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_title.add_theme_font_override("font", DISPLAY_FONT)
	_loading_title.add_theme_font_size_override("font_size", 58)
	_loading_title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.6, 1.0))
	_loading_title.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.014, 0.95))
	_loading_title.add_theme_constant_override("outline_size", 5)
	_box.add_child(_loading_title)

	var subtitle := Label.new()
	subtitle.text = "PUNTA DELLA DOGANA  ·  VENEZIA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", BODY_FONT)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.46, 0.76, 0.7, 0.82))
	_box.add_child(subtitle)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", BODY_FONT)
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.55, 0.82, 0.78, 0.9))
	_box.add_child(_status)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 18.0
	_progress.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.05, 0.06, 1.0)
	background.border_color = Color(0.32, 0.4, 0.35, 0.8)
	background.set_border_width_all(1)
	background.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.76, 0.68, 1.0)
	fill.border_color = Color(0.87, 0.72, 0.38, 0.9)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(8)
	_progress.add_theme_stylebox_override("background", background)
	_progress.add_theme_stylebox_override("fill", fill)
	_box.add_child(_progress)


func _apply_responsive_layout() -> void:
	if _box == null:
		return
	var viewport_size := CaligoResponsiveLayout.viewport_size(self)
	var compact := CaligoResponsiveLayout.is_compact(viewport_size)
	_box.custom_minimum_size = Vector2(clampf(viewport_size.x - 40.0, 260.0, 580.0), 150.0)
	_loading_title.add_theme_font_size_override("font_size", 42 if compact else 58)
	_progress.custom_minimum_size.x = clampf(viewport_size.x - 40.0, 260.0, 580.0)
