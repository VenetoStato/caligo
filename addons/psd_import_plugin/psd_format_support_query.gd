@tool
extends EditorFileSystemImportFormatSupportQuery
## Dice a Godot di accettare file .psd e .psb quando vengono trascinati
## dall'esterno nel pannello FileSystem (così compaiono nella lista).

func _get_file_extensions() -> PackedStringArray:
	return PackedStringArray(["psd", "psb"])

func _is_active() -> bool:
	return true

func _query() -> bool:
	return true
