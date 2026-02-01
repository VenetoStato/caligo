@tool
extends Window
## Finestra comoda per importare PSD/PSB: percorso file, cartella output,
## controllo dipendenze (ImageMagick / Python+psd-tools) e log.

const TEST_FILE_PATH := "C:/Users/Utente/Cloud Repositories/LovecraftFishing/Assets/Fish Catcher Pro/Art/World/Lake_1.psd"

var _editor_interface: EditorInterface
var _file_dialog: EditorFileDialog
var _dir_dialog: FileDialog
var _log_text: TextEdit
var _path_edit: LineEdit
var _output_edit: LineEdit
var _check_btn: Button
var _import_btn: Button
var _imagemagick_ok: bool = false
var _python_ok: bool = false

func _init():
	size = Vector2i(560, 420)
	title = "Importa PSD / PSB layers"
	unresizable = false

func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func _ready():
	if _editor_interface == null:
		return
	_build_ui()

func _build_ui():
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	v.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	# --- File PSD/PSB ---
	var lbl_file := Label.new()
	lbl_file.text = "File PSD o PSB:"
	inner.add_child(lbl_file)
	var h_file := HBoxContainer.new()
	h_file.add_theme_constant_override("separation", 6)
	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "Percorso completo del file .psd o .psb"
	_path_edit.custom_minimum_size.x = 320
	_path_edit.text = TEST_FILE_PATH
	h_file.add_child(_path_edit)
	var btn_browse_file := Button.new()
	btn_browse_file.text = "Sfoglia..."
	btn_browse_file.pressed.connect(_on_browse_file)
	h_file.add_child(btn_browse_file)
	inner.add_child(h_file)

	# --- Cartella output ---
	var lbl_out := Label.new()
	lbl_out.text = "Cartella di destinazione PNG:"
	inner.add_child(lbl_out)
	var h_out := HBoxContainer.new()
	h_out.add_theme_constant_override("separation", 6)
	_output_edit = LineEdit.new()
	_output_edit.placeholder_text = "Cartella dove salvare i PNG (uno per layer)"
	_output_edit.custom_minimum_size.x = 320
	h_out.add_child(_output_edit)
	var btn_browse_dir := Button.new()
	btn_browse_dir.text = "Sfoglia..."
	btn_browse_dir.pressed.connect(_on_browse_dir)
	h_out.add_child(btn_browse_dir)
	inner.add_child(h_out)

	# --- Dipendenze e azioni ---
	var h_actions := HBoxContainer.new()
	h_actions.add_theme_constant_override("separation", 12)
	_check_btn = Button.new()
	_check_btn.text = "Controlla dipendenze"
	_check_btn.pressed.connect(_check_dependencies)
	h_actions.add_child(_check_btn)
	_import_btn = Button.new()
	_import_btn.text = "Importa layer"
	_import_btn.pressed.connect(_run_import)
	h_actions.add_child(_import_btn)
	inner.add_child(h_actions)

	# --- Log ---
	var lbl_log := Label.new()
	lbl_log.text = "Stato e log:"
	inner.add_child(lbl_log)
	_log_text = TextEdit.new()
	_log_text.custom_minimum_size.y = 160
	_log_text.editable = false
	_log_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	inner.add_child(_log_text)

	close_requested.connect(hide)
	# Controllo dipendenze all'apertura
	_check_dependencies()

func _log(msg: String):
	_log_text.text += msg + "\n"
	var scroll := _log_text.get_v_scroll_bar()
	if scroll:
		scroll.value = scroll.max_value

func _clear_log():
	_log_text.clear()

func _on_browse_file():
	if _file_dialog == null:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.set_file_mode(EditorFileDialog.FILE_MODE_OPEN_FILE)
		_file_dialog.add_filter("*.psd ; Photoshop Document")
		_file_dialog.add_filter("*.psb ; Photoshop Big")
		_file_dialog.title = "Seleziona PSD o PSB"
		_file_dialog.file_selected.connect(_on_file_selected)
		_editor_interface.get_base_control().add_child(_file_dialog)
	_file_dialog.current_dir = _path_edit.text.get_base_dir() if _path_edit.text.get_base_dir().length() > 0 else "/"
	_file_dialog.popup_file_dialog()

func _on_file_selected(path: String):
	_path_edit.text = path
	if _output_edit.text.is_empty():
		_output_edit.text = path.get_base_dir()

func _on_browse_dir():
	if _dir_dialog == null:
		_dir_dialog = FileDialog.new()
		_dir_dialog.set_file_mode(FileDialog.FILE_MODE_OPEN_DIR)
		_dir_dialog.title = "Cartella destinazione PNG"
		_dir_dialog.dir_selected.connect(_on_dir_selected)
		_editor_interface.get_base_control().add_child(_dir_dialog)
	_dir_dialog.current_dir = _output_edit.text if _output_edit.text.length() > 0 else _path_edit.text.get_base_dir()
	_dir_dialog.popup_centered()

func _on_dir_selected(dir_path: String):
	_output_edit.text = dir_path

func _check_dependencies():
	_clear_log()
	_log("Controllo dipendenze in corso...")
	_imagemagick_ok = false
	_python_ok = false

	# 1) ImageMagick (preferisci magick, su Windows "convert" è un altro programma)
	var code = OS.execute("magick", ["--version"], [], true, true)
	if code == 0:
		_imagemagick_ok = true
		_log("OK ImageMagick: trovato 'magick'")
	else:
		code = OS.execute("convert", ["-version"], [], true, true)
		if code == 0:
			_imagemagick_ok = true
			_log("OK ImageMagick: trovato 'convert'")
	if not _imagemagick_ok:
		_log("-- ImageMagick non trovato (installa e aggiungi magick/convert al PATH)")

	# 2) Python + psd-tools
	var py_cmd := "python"
	if OS.get_name() == "Windows":
		var c = OS.execute("python", ["--version"], [], true, true)
		if c != 0:
			py_cmd = "py"
	var script_res := "res://addons/psd_import_plugin/export_psd_layers.py"
	var script_path := ProjectSettings.globalize_path(script_res)
	if not FileAccess.file_exists(script_res):
		_log("-- Script Python non trovato: %s" % script_res)
	else:
		var check_args := [ "-c", "import psd_tools; import PIL; print('ok')" ]
		var out: Array = []
		var code = OS.execute(py_cmd, check_args, out, true, true)
		if code == 0:
			_python_ok = true
			_log("OK Python + psd-tools: '%s' con psd-tools e Pillow" % py_cmd)
		else:
			_log("-- Python/psd-tools: esegui  pip install psd-tools Pillow")

	_log("")
	if _imagemagick_ok or _python_ok:
		_log("Pronto: puoi usare 'Importa layer'.")
	else:
		_log("Installa almeno uno: ImageMagick 7 oppure  pip install psd-tools Pillow")

func _run_import():
	var psd_path := _path_edit.text.strip_edges()
	var output_dir := _output_edit.text.strip_edges()
	if psd_path.is_empty():
		_log("Inserisci il percorso del file PSD/PSB.")
		return
	if output_dir.is_empty():
		output_dir = psd_path.get_base_dir()
		_output_edit.text = output_dir

	_clear_log()
	_log("Import in corso...")
	_log("File: %s" % psd_path)
	_log("Output: %s" % output_dir)

	var base_name = psd_path.get_file().get_basename()
	var out_base = output_dir.path_join(base_name + "_layers")
	var out_png = out_base + ".png"

	# 1) ImageMagick
	if _imagemagick_ok:
		var ok = _run_imagemagick(psd_path, out_png)
		if ok:
			_log("Fatto con ImageMagick. File: %s-0.png, %s-1.png, ..." % [out_base, out_base])
			_refresh_fs()
			return
		_log("ImageMagick fallito (file corrotto o formato non supportato?). Provo Python...")

	# 2) Python
	if _python_ok:
		var ok = _run_python_export(psd_path, output_dir)
		if ok:
			_log("Fatto con Python (psd-tools).")
			_refresh_fs()
			return
		_log("Python export fallito. Controlla il file (PSD/PSB valido?).")

	if not _imagemagick_ok and not _python_ok:
		_log("Nessun strumento disponibile. Controlla dipendenze.")
	else:
		_log("Import fallito. Prova con un altro file o controlla i percorsi.")

func _run_imagemagick(psd_path: String, out_png: String) -> bool:
	if not _imagemagick_ok:
		return false
	var code = OS.execute("magick", ["convert", psd_path, out_png], [], true, false)
	if code != 0:
		code = OS.execute("convert", [psd_path, out_png], [], true, false)
	return code == 0

func _run_python_export(psd_path: String, output_dir: String) -> bool:
	var script_res := "res://addons/psd_import_plugin/export_psd_layers.py"
	if not FileAccess.file_exists(script_res):
		return false
	var script_path := ProjectSettings.globalize_path(script_res)
	var py_cmd := "python"
	if OS.get_name() == "Windows":
		if OS.execute("python", ["--version"], [], true, true) != 0:
			py_cmd = "py"
	var exit_code = OS.execute(py_cmd, [script_path, psd_path, output_dir], [], true, false)
	return exit_code == 0

func _refresh_fs():
	var efs = _editor_interface.get_resource_filesystem()
	if efs:
		efs.scan()
		_log("FileSystem aggiornato.")
