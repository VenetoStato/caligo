@tool
extends EditorContextMenuPlugin
## Menu contestuale FileSystem: tasto destro → "Importa PSD/PSB qui".
## La callback viene impostata dal plugin principale.

var _import_callback: Callable = Callable()

func _popup_menu(paths: PackedStringArray) -> void:
	if _import_callback.is_null():
		return
	add_context_menu_item("Importa PSD/PSB qui", _on_import_here)

func _on_import_here(args: Array) -> void:
	var dest_folder := "res://"
	if args.size() > 0:
		var path: String = args[0]
		if path.get_extension() != "":
			dest_folder = path.get_base_dir()
		else:
			dest_folder = path
	if not _import_callback.is_null():
		_import_callback.call(dest_folder)

func set_import_callback(cb: Callable) -> void:
	_import_callback = cb
