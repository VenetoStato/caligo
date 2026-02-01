@tool
extends EditorImportPlugin
## Importa PSD/PSB: genera un PNG per ogni layer e una scena con un Node2D
## che contiene uno Sprite2D per layer, ognuno al suo posto (posizione PSD).
## Trascinando il .psd/.psb nella scena vedi i layer separati ma già posizionati.

func _get_importer_name() -> String:
	return "psd.import.layers"

func _get_visible_name() -> String:
	return "Import as Scene (one Sprite2D per layer)"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["psd", "psb"])

func _get_save_extension() -> String:
	return "tscn"

func _get_resource_type() -> String:
	return "PackedScene"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(_path: String, _preset_index: int) -> Array:
	return []

func _import(source_file: String, save_path: String, _options: Dictionary, _platform_variants: Array, gen_files: Array) -> Error:
	var base_dir := source_file.get_base_dir()
	var base_name := source_file.get_file().get_basename()
	var layers_dir_res := base_dir.path_join(base_name) + "_layers"
	var source_global := ProjectSettings.globalize_path(source_file)
	var layers_dir_global := ProjectSettings.globalize_path(layers_dir_res)

	# 1) Esegui Python: --for-godot source cartella_layers (oppure usa cartella _layers già esistente)
	var script_res := "res://addons/psd_import_plugin/export_psd_layers.py"
	var json_path := layers_dir_res.path_join("layers.json")
	var layers_dir_exists := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(layers_dir_res))
	var json_exists := FileAccess.file_exists(json_path)

	if not json_exists or not layers_dir_exists:
		if not FileAccess.file_exists(script_res):
			push_error("PSD Import: script export_psd_layers.py non trovato.")
			return ERR_FILE_NOT_FOUND
		var script_global := ProjectSettings.globalize_path(script_res)
		# Prova python3, py (Windows), python
		var py_commands := ["python3", "py", "python"]
		if OS.get_name() == "Windows":
			py_commands = ["py", "python", "python3"]
		var code := -1
		var py_out := []
		for py_cmd in py_commands:
			py_out.clear()
			# Comando corretto: python script.py --for-godot file.psd cartella_output
			code = OS.execute(py_cmd, [script_global, "--for-godot", source_global, layers_dir_global], py_out, true, true)
			if code == 0:
				break
			if py_out.size() > 0:
				push_error("PSD Import (con %s): %s" % [py_cmd, str(py_out)])
		if code != 0:
			push_error("PSD Import: export layer fallito. Installa Python e poi: pip install psd-tools Pillow")
			push_error("Oppure esegui a mano: python export_psd_layers.py --for-godot <file.psd> <cartella_output>")
			return ERR_SCRIPT_FAILED
		json_exists = FileAccess.file_exists(json_path)
		if not json_exists:
			push_error("PSD Import: layers.json non creato in " + layers_dir_res)
			return ERR_FILE_NOT_FOUND

	# 2) Leggi layers.json
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_error("PSD Import: layers.json non trovato in " + layers_dir_res)
		return ERR_FILE_NOT_FOUND
	var json_text := f.get_as_text()
	f.close()
	var json_data := JSON.parse_string(json_text)
	if json_data == null:
		push_error("PSD Import: layers.json non valido.")
		return ERR_PARSE_ERROR
	var layers_arr = json_data.get("layers", [])
	if layers_arr.is_empty():
		push_error("PSD Import: nessun layer in layers.json.")
		return ERR_INVALID_DATA

	# Calcola il centro della composizione (per mettere l'origine al centro e vederla subito in viewport)
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for layer in layers_arr:
		var l: float = float(layer.get("left", 0))
		var t: float = float(layer.get("top", 0))
		var r: float = l + float(layer.get("width", 0))
		var b: float = t + float(layer.get("height", 0))
		min_x = minf(min_x, l)
		min_y = minf(min_y, t)
		max_x = maxf(max_x, r)
		max_y = maxf(max_y, b)
	var center_x := (min_x + max_x) * 0.5
	var center_y := (min_y + max_y) * 0.5

	# 3) Crea root e uno Sprite2D per layer (carica texture da file: al momento dell'import i PNG non sono ancora in cache)
	var root := Node2D.new()
	root.name = base_name
	for i in range(layers_arr.size()):
		var layer: Dictionary = layers_arr[i]
		var tex_path := layers_dir_res.path_join(layer.get("path", ""))
		gen_files.append(tex_path)
		var tex_global := ProjectSettings.globalize_path(tex_path)
		var img := Image.new()
		if img.load(tex_global) != OK:
			push_warning("PSD Import: impossibile caricare " + layer.get("path", ""))
			continue
		var tex := ImageTexture.create_from_image(img)
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.name = (layer.get("name", "layer_%d" % i) as String).replace(" ", "_")
		sprite.texture = tex
		sprite.centered = true
		var left: float = float(layer.get("left", 0))
		var top: float = float(layer.get("top", 0))
		var w: float = float(layer.get("width", tex.get_width()))
		var h: float = float(layer.get("height", tex.get_height()))
		# Posizione centrata nel layer, poi offset per avere l'origine al centro della composizione
		sprite.position = Vector2(left + w * 0.5 - center_x, top + h * 0.5 - center_y)
		root.add_child(sprite)
		sprite.owner = root

	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		return ERR_CANT_CREATE
	var out_path := save_path + "." + _get_save_extension()
	return ResourceSaver.save(scene, out_path)
