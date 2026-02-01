@tool
extends Window
## Copia un file PSD/PSB da fuori del progetto nella cartella del progetto,
## così appare nel FileSystem e viene importato come scena (layer separati).

var _editor_interface: EditorInterface
var _file_dialog: EditorFileDialog
var _dir_dialog: FileDialog
var _log_text: TextEdit
var _path_edit: LineEdit
var _dest_edit: LineEdit

func _init():
	size = Vector2i(520, 280)
	title = "Importa PSD/PSB nel progetto (da file esterno)"
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

	var lbl1 := Label.new()
	lbl1.text = "File PSD o PSB (da qualsiasi cartella):"
	inner.add_child(lbl1)
	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 6)
	_path_edit = LineEdit.new()
	_path_edit.placeholder_text = "Percorso del file..."
	_path_edit.custom_minimum_size.x = 320
	h1.add_child(_path_edit)
	var btn1 := Button.new()
	btn1.text = "Sfoglia..."
	btn1.pressed.connect(_on_browse_file)
	h1.add_child(btn1)
	inner.add_child(h1)

	var lbl2 := Label.new()
	lbl2.text = "Destinazione nel progetto (cartella res://):"
	inner.add_child(lbl2)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 6)
	_dest_edit = LineEdit.new()
	_dest_edit.placeholder_text = "es. imported/ o Landscape/Sprites/"
	_dest_edit.text = "imported"
	_dest_edit.custom_minimum_size.x = 320
	h2.add_child(_dest_edit)
	var btn2 := Button.new()
	btn2.text = "Sfoglia..."
	btn2.pressed.connect(_on_browse_dest)
	h2.add_child(btn2)
	inner.add_child(h2)

	var btn_import := Button.new()
	btn_import.text = "Copia nel progetto e importa"
	btn_import.pressed.connect(_do_import)
	inner.add_child(btn_import)

	_log_text = TextEdit.new()
	_log_text.custom_minimum_size.y = 80
	_log_text.editable = false
	inner.add_child(_log_text)

	close_requested.connect(hide)
	if _file_dialog == null:
		_file_dialog = EditorFileDialog.new()
		_file_dialog.set_file_mode(EditorFileDialog.FILE_MODE_OPEN_FILE)
		_file_dialog.add_filter("*.psd ; Photoshop Document")
		_file_dialog.add_filter("*.psb ; Photoshop Big")
		_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_selected.connect(_on_file_selected)
		_editor_interface.get_base_control().add_child(_file_dialog)
	if _dir_dialog == null:
		_dir_dialog = FileDialog.new()
		_dir_dialog.set_file_mode(FileDialog.FILE_MODE_OPEN_DIR)
		_dir_dialog.title = "Cartella nel progetto (res://)"
		_dir_dialog.dir_selected.connect(_on_dest_selected)
		_editor_interface.get_base_control().add_child(_dir_dialog)

func _on_browse_file():
	_file_dialog.current_dir = _path_edit.text.get_base_dir() if _path_edit.text.get_base_dir().length() > 0 else "/"
	_file_dialog.popup_file_dialog()

func _on_file_selected(path: String):
	_path_edit.text = path

func _on_browse_dest():
	_dir_dialog.current_dir = ProjectSettings.globalize_path("res://")
	_dir_dialog.popup_centered()

func _on_dest_selected(path: String):
	var proj_root := ProjectSettings.globalize_path("res://")
	var rel := path
	if rel.begins_with(proj_root):
		rel = rel.substr(proj_root.length())
	rel = rel.replace("\\", "/").trim_suffix("/").lstrip("/")
	_dest_edit.text = rel if rel.length() > 0 else "imported"

func _log(msg: String):
	_log_text.text += msg + "\n"
	var scroll := _log_text.get_v_scroll_bar()
	if scroll:
		scroll.value = scroll.max_value

func _do_import():
	var src := _path_edit.text.strip_edges()
	var dest_folder := _dest_edit.text.strip_edges().trim_suffix("/")
	if dest_folder.is_empty():
		dest_folder = "imported"
	if not dest_folder.begins_with("res://"):
		dest_folder = "res://" + dest_folder
	_log_text.clear()
	if src.is_empty():
		_log("Seleziona un file PSD o PSB.")
		return
	if not FileAccess.file_exists(src):
		_log("File non trovato: " + src)
		return
	var fname := src.get_file()
	if not (fname.to_lower().ends_with(".psd") or fname.to_lower().ends_with(".psb")):
		_log("Il file deve essere .psd o .psb")
		return
	var dest_dir_global := ProjectSettings.globalize_path(dest_folder)
	var da := DirAccess.open("res://")
	if da == null:
		_log("Impossibile aprire res://")
		return
	var to_create := dest_folder.trim_prefix("res://").trim_suffix("/")
	if to_create.contains("/"):
		for part in to_create.split("/"):
			if part.is_empty():
				continue
			if not da.dir_exists(part):
				var err = da.make_dir(part)
				if err != OK:
					_log("Impossibile creare cartella: " + part)
					return
			da.change_dir(part)
		da = DirAccess.open(dest_folder)
	if da == null:
		_log("Impossibile aprire " + dest_folder)
		return
	var dest_path_res := dest_folder.path_join(fname)
	var dest_path_global := ProjectSettings.globalize_path(dest_path_res)
	# Copia con FileAccess (DirAccess.copy_absolute può non esistere su tutti i build)
	var fr := FileAccess.open(src, FileAccess.READ)
	if fr == null:
		_log("Impossibile aprire il file sorgente.")
		return
	var buf := fr.get_buffer(fr.get_length())
	fr.close()
	var fw := FileAccess.open(dest_path_global, FileAccess.WRITE)
	if fw == null:
		_log("Impossibile scrivere in " + dest_path_res)
		return
	fw.store_buffer(buf)
	fw.close()
	_log("File copiato in: " + dest_path_res)
	_editor_interface.get_resource_filesystem().scan()
	_log("FileSystem aggiornato. Il file verrà importato come scena (layer separati).")
	_log("Trascina " + fname + " dalla FileSystem nella viewport 2D per usarlo.")
	close_requested.emit()
