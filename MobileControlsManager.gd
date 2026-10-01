extends Node
## Autoload: controlli touch + direzione joystick lancio canna.

## Direzione del joystick lancio (tieni premuto e trascina). ZERO = non attivo.
var cast_joystick_direction: Vector2 = Vector2.ZERO
## True mentre l'utente tiene premuto e trascina sul joystick cast.
var cast_joystick_active: bool = false
var _controls_layer: CanvasLayer
var _refresh_timer := 0.0

const GAMEPLAY_SCENES: PackedStringArray = [
	"res://Levels/Scenes/test_area.tscn",
	"res://Levels/Scenes/punta_della_dogana.tscn",
]

func _ready() -> void:
	if not _should_show_mobile_controls():
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_refresh_controls")


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_refresh_controls()


func _refresh_controls() -> void:
	var current := get_tree().current_scene
	var current_path := current.scene_file_path if current else ""
	var should_exist := current_path in GAMEPLAY_SCENES
	if should_exist and not is_instance_valid(_controls_layer):
		var scene := load("res://UI/MobileControls.tscn") as PackedScene
		if scene:
			_controls_layer = scene.instantiate() as CanvasLayer
			get_tree().root.add_child(_controls_layer)
	elif not should_exist and is_instance_valid(_controls_layer):
		_controls_layer.queue_free()
		_controls_layer = null
		cast_joystick_active = false
		cast_joystick_direction = Vector2.ZERO

func _should_show_mobile_controls() -> bool:
	return OS.get_name() == "Android"
