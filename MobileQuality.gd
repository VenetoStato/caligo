extends Node
## Budget per telefoni scarsi: meno fill-rate, niente extra da vetrina.

func _ready() -> void:
	Engine.max_fps = 60
	if not is_mobile():
		return
	var win := get_window()
	if win:
		win.content_scale_size = Vector2i(960, 540)
		win.vsync_mode = DisplayServer.VSYNC_ENABLED


static func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.has_feature("mobile")
