@tool
extends EditorPlugin
## Addon: Importa PSD/PSB.
##
## DOVE TROVARE LE AZIONI:
##   - Barra principale: due pulsanti "PSD: Importa da file..." e "PSD: Esporta layer..." (accanto a Play).
##   - Menu: Project → Tools (stesse voci, se presenti nella tua versione).
##   - FileSystem: tasto destro su una cartella → "Importa PSD/PSB qui".
##
## Dopo aver importato da file, trascina il .psd dalla FileSystem nella viewport 2D per i layer separati.

var _psd_dialog = null
var _external_dialog = null
var _import_plugin = null
var _format_query = null
var _context_menu_plugin = null
var _toolbar = null

func _enter_tree():
	# Se fallisce con solo questo, il problema è fuori dallo script (cfg o Godot)
	add_tool_menu_item("Importa PSD/PSB da file...", Callable(self, "_on_menu_import_from_external"))
	add_tool_menu_item("Import PSD layers...", Callable(self, "_on_menu_import_psd"))
	add_tool_menu_item("ArtistDrop: sincronizza disegni...", Callable(self, "_on_menu_sync_artist_drop"))
	add_tool_menu_item("ArtistDrop: apri cartella...", Callable(self, "_on_menu_open_artist_drop"))
	call_deferred("_add_toolbar_buttons")
	call_deferred("_deferred_init")

func _exit_tree():
	if _toolbar != null:
		remove_control_from_container(0, _toolbar)  # CONTAINER_TOOLBAR
		_toolbar.queue_free()
		_toolbar = null
	if _import_plugin:
		remove_import_plugin(_import_plugin)
	_remove_format_support_query()
	_remove_context_menu()
	remove_tool_menu_item("Importa PSD/PSB da file...")
	remove_tool_menu_item("Import PSD layers...")
	remove_tool_menu_item("ArtistDrop: sincronizza disegni...")
	remove_tool_menu_item("ArtistDrop: apri cartella...")
	if _psd_dialog and is_instance_valid(_psd_dialog):
		_psd_dialog.queue_free()
	if _external_dialog and is_instance_valid(_external_dialog):
		_external_dialog.queue_free()

func _deferred_init():
	# Import plugin
	var imp = _get_import_plugin()
	if imp:
		add_import_plugin(imp)
	_add_format_support_query()
	_add_context_menu()

func _add_toolbar_buttons():
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 4)
	var btn_ext := Button.new()
	btn_ext.text = "PSD: Importa da file..."
	btn_ext.tooltip_text = "Copia un .psd/.psb da fuori nel progetto"
	btn_ext.pressed.connect(_on_menu_import_from_external)
	_toolbar.add_child(btn_ext)
	var btn_layers := Button.new()
	btn_layers.text = "PSD: Esporta layer..."
	btn_layers.tooltip_text = "Esporta i layer del PSD come PNG"
	btn_layers.pressed.connect(_on_menu_import_psd)
	_toolbar.add_child(btn_layers)
	var btn_art := Button.new()
	btn_art.text = "ArtistDrop sync"
	btn_art.tooltip_text = "Copia i PNG da Landscape/Dogana/ArtistDrop nello slot live"
	btn_art.pressed.connect(_on_menu_sync_artist_drop)
	_toolbar.add_child(btn_art)
	add_control_to_container(0, _toolbar)  # CONTAINER_TOOLBAR

func _add_format_support_query():
	# EditorFileSystemImportFormatSupportQuery esiste solo da Godot 4.4
	var ver := Engine.get_version_info()
	if ver.major < 4 or (ver.major == 4 and ver.minor < 4):
		return
	var QueryClass = load("res://addons/psd_import_plugin/psd_format_support_query.gd") as GDScript
	if QueryClass == null:
		return
	_format_query = QueryClass.new()
	if _format_query != null and EditorInterface.get_resource_filesystem().has_method("add_import_format_support_query"):
		EditorInterface.get_resource_filesystem().call("add_import_format_support_query", _format_query)

func _remove_format_support_query():
	if _format_query != null and EditorInterface.get_resource_filesystem().has_method("remove_import_format_support_query"):
		EditorInterface.get_resource_filesystem().call("remove_import_format_support_query", _format_query)

func _add_context_menu():
	var CtxClass = load("res://addons/psd_import_plugin/psd_context_menu.gd") as GDScript
	if CtxClass == null:
		return
	_context_menu_plugin = CtxClass.new()
	if _context_menu_plugin.has_method("set_import_callback"):
		_context_menu_plugin.set_import_callback(Callable(self, "open_import_from_external_with_dest"))
	add_context_menu_plugin(1, _context_menu_plugin)  # CONTEXT_SLOT_FILESYSTEM

func _remove_context_menu():
	if _context_menu_plugin != null:
		remove_context_menu_plugin(_context_menu_plugin)
		_context_menu_plugin = null

func open_import_from_external_with_dest(dest_folder):
	_on_menu_import_from_external()
	if _external_dialog != null and is_instance_valid(_external_dialog) and _external_dialog.has_method("set_destination"):
		_external_dialog.call("set_destination", dest_folder)

func _get_import_plugin():
	if _import_plugin == null:
		_import_plugin = load("res://addons/psd_import_plugin/psd_import_plugin_importer.gd") as GDScript
		if _import_plugin:
			_import_plugin = (_import_plugin as GDScript).new()
	return _import_plugin

func _on_menu_import_from_external():
	if _external_dialog != null and is_instance_valid(_external_dialog):
		_external_dialog.show()
		_external_dialog.popup_centered()
		return
	var DialogClass = load("res://addons/psd_import_plugin/psd_import_from_external.gd") as GDScript
	if DialogClass == null:
		push_error("PSD Import: script psd_import_from_external.gd non trovato.")
		return
	_external_dialog = DialogClass.new()
	_external_dialog.set_editor_interface(get_editor_interface())
	get_editor_interface().get_base_control().add_child(_external_dialog)
	_external_dialog.show()
	_external_dialog.popup_centered()

func _on_menu_import_psd():
	if _psd_dialog != null and is_instance_valid(_psd_dialog):
		_psd_dialog.show()
		_psd_dialog.popup_centered()
		return
	var DialogClass = load("res://addons/psd_import_plugin/psd_import_dialog.gd") as GDScript
	if DialogClass == null:
		push_error("PSD Import: script psd_import_dialog.gd non trovato.")
		return
	_psd_dialog = DialogClass.new()
	_psd_dialog.set_editor_interface(get_editor_interface())
	get_editor_interface().get_base_control().add_child(_psd_dialog)
	_psd_dialog.show()
	_psd_dialog.popup_centered()


func _on_menu_open_artist_drop() -> void:
	var drop := ProjectSettings.globalize_path("res://Landscape/Dogana/ArtistDrop")
	OS.shell_open(drop)


func _on_menu_sync_artist_drop() -> void:
	var root := ProjectSettings.globalize_path("res://")
	var script := root.path_join("tools/sync_artist_drop.py")
	if not FileAccess.file_exists("res://tools/sync_artist_drop.py"):
		push_error("ArtistDrop: manca tools/sync_artist_drop.py")
		return
	var output: Array = []
	var code := OS.execute("python", PackedStringArray([script]), output, true)
	var lines := PackedStringArray()
	for item in output:
		lines.append(str(item))
	print("\n".join(lines))
	if code != 0 and code != 2:
		push_error("ArtistDrop sync fallito (code %s). Vedi Output." % str(code))
		return
	var board := root.path_join("tools/make_artist_board.py")
	if FileAccess.file_exists("res://tools/make_artist_board.py"):
		OS.execute("python", PackedStringArray([board]), [], true)
	var fs := get_editor_interface().get_resource_filesystem()
	if fs:
		fs.scan()
	print("ArtistDrop: sync completato. Ricarica la scena Dogana per vedere i disegni.")
