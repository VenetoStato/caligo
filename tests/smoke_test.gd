extends SceneTree

var _failures := PackedStringArray()

const REQUIRED_RESOURCES: PackedStringArray = [
	"res://Player/Scene/Player.tscn",
	"res://Levels/Scenes/test_area.tscn",
	"res://Levels/Scenes/punta_della_dogana.tscn",
	"res://Levels/Scenes/Dogana/dogana_environment.tscn",
	"res://Levels/Scenes/Dogana/vertical_palace.tscn",
	"res://Water/water_mobile.gdshader",
]


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	await process_frame
	for path in REQUIRED_RESOURCES:
		_check_resource(path)
	if not FileAccess.file_exists("res://export_presets.cfg"):
		_failures.append("Missing export_presets.cfg")
	_check_water_api()

	if _failures.is_empty():
		print("CALIGO_SMOKE_OK: all critical resources and water APIs loaded.")
		await create_timer(1.1).timeout
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		await create_timer(1.1).timeout
		quit(1)


func _check_resource(path: String) -> void:
	if not ResourceLoader.exists(path):
		_failures.append("Missing resource: %s" % path)
		return
	var resource := ResourceLoader.load(path)
	if resource == null:
		_failures.append("Could not load resource: %s" % path)
		return
	if resource is PackedScene:
		var instance := (resource as PackedScene).instantiate()
		if instance == null:
			_failures.append("Could not instantiate scene: %s" % path)
		else:
			instance.free()


func _check_water_api() -> void:
	var water_script := load("res://water_body.gd") as Script
	if water_script == null:
		_failures.append("Could not load water_body.gd")
		return
	var water := Area2D.new()
	water.set_script(water_script)
	for method in ["splash_at", "get_surface_height", "get_surface_slope", "get_water_bounds_global_rect"]:
		if not water.has_method(method):
			_failures.append("Water API missing method: %s" % method)
	water.free()
