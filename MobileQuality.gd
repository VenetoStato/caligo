extends Node
## Budget per telefoni scarsi: meno fill-rate, niente extra da vetrina.

const STANDARD_MOBILE_RENDER_SIZE := Vector2i(960, 540)
const LOW_POWER_MOBILE_RENDER_SIZE := Vector2i(720, 405)
const LOW_POWER_MODEL_MARKERS: PackedStringArray = ["CPH2699"]

func _ready() -> void:
	Engine.max_fps = 60
	if not is_mobile():
		return
	var win := get_window()
	if win:
		win.content_scale_size = (
			LOW_POWER_MOBILE_RENDER_SIZE if is_low_power_mobile() else STANDARD_MOBILE_RENDER_SIZE
		)
	# In Godot 4.5 il VSync appartiene a DisplayServer, non a Window.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)


static func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.has_feature("mobile")


static func is_low_power_mobile() -> bool:
	if not is_mobile():
		return false
	var model := OS.get_model_name().to_upper()
	for marker in LOW_POWER_MODEL_MARKERS:
		if model.contains(marker):
			return true
	return false
