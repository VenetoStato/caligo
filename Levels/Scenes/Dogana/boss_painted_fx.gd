extends Sprite2D

## Un singolo asset dipinto, animato soltanto con scala/movimento/fade.  Gli
## attacchi del Custode usano questi sprite per il rilascio, invece di burst
## geometrici generici che non raccontavano cosa stesse per succedere.

var lifetime := 0.55
var velocity := Vector2.ZERO
var target_scale := Vector2.ONE
var _age := 0.0
var _initial_scale := Vector2.ONE


func setup(
	painted_texture: Texture2D,
	facing := Vector2.RIGHT,
	duration := 0.55,
	start_scale := Vector2(0.12, 0.12),
	end_scale := Vector2(0.19, 0.19),
	drift := Vector2.ZERO
) -> void:
	texture = painted_texture
	lifetime = maxf(duration, 0.05)
	velocity = drift
	_initial_scale = start_scale
	target_scale = end_scale
	scale = start_scale
	flip_h = facing.x < 0.0
	rotation = facing.angle() * 0.12


func _ready() -> void:
	z_index = 11
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Alone morbido additivo dietro la pennellata: leggibile sul fondale scuro
	# senza trasformare l'effetto in una sagoma geometrica.
	if texture:
		var aura := Sprite2D.new()
		aura.name = "PaintedBloom"
		aura.texture = texture
		aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		aura.scale = Vector2.ONE * 1.14
		aura.modulate = Color(0.42, 0.9, 0.86, 0.2)
		aura.z_index = -1
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		aura.material = additive
		add_child(aura)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var progress := clampf(_age / lifetime, 0.0, 1.0)
	global_position += velocity * delta
	scale = _initial_scale.lerp(target_scale, progress)
	modulate.a = 1.0 - progress * progress
