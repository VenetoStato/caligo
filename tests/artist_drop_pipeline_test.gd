extends SceneTree

## Verifica che la pipeline ArtistDrop sia completa e coerente.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var slots_path := "res://Landscape/Dogana/ArtistDrop/SLOTS.json"
	if not FileAccess.file_exists(slots_path):
		_fail("Missing ArtistDrop/SLOTS.json")
		return
	if not FileAccess.file_exists("res://Landscape/Dogana/ArtistDrop/LEGGIMI.md"):
		_fail("Missing ArtistDrop/LEGGIMI.md")
		return
	if not FileAccess.file_exists("res://tools/sync_artist_drop.py"):
		_fail("Missing tools/sync_artist_drop.py")
		return
	var raw := FileAccess.get_file_as_string(slots_path)
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY or not data.has("slots"):
		_fail("SLOTS.json is invalid")
		return
	var slots: Array = data["slots"]
	if slots.size() < 12:
		_fail("ArtistDrop slots are incomplete")
		return
	var profile := load("res://Levels/Scenes/Dogana/dogana_art_profile.tres")
	if profile == null:
		_fail("dogana_art_profile.tres missing")
		return
	for slot in slots:
		var dest: String = str(slot.get("dest", ""))
		var profile_key: String = str(slot.get("profile", ""))
		if dest.is_empty() or not ResourceLoader.exists("res://" + dest):
			_fail("Live art missing for slot dest: %s" % dest)
			return
		if profile_key.is_empty() or profile.get(profile_key) == null:
			_fail("Art profile slot empty: %s" % profile_key)
			return
	print("CALIGO_ARTIST_DROP_OK: %d slots wired" % slots.size())
	quit(0)


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)
