extends Node
## Autoload: controlli touch + direzione joystick lancio canna.

## Direzione del joystick lancio (tieni premuto e trascina). ZERO = non attivo.
var cast_joystick_direction: Vector2 = Vector2.ZERO
## True mentre l'utente tiene premuto e trascina sul joystick cast.
var cast_joystick_active: bool = false

func _ready() -> void:
	if not _should_show_mobile_controls():
		return
	var scene := load("res://UI/MobileControls.tscn") as PackedScene
	if scene:
		var layer := scene.instantiate()
		get_tree().root.add_child(layer)
		# Aggiunto per ultimo = disegnato sopra (così i pulsanti si vedono)

func _should_show_mobile_controls() -> bool:
	# Mostra controlli touch su Android o quando è disponibile il touch (DisplayServer in Godot 4)
	if OS.get_name() == "Android":
		return true
	return DisplayServer.is_touchscreen_available()
