extends Area2D

# ===========================================
# PROP / OBIETTIVO (tesoro, leone di San Marco, ecc.)
# ===========================================
# Il player ci va sopra → segna come preso, effetti, notifica achievement
# Assegna lo sprite dall'Inspector. prop_id: per achievement "leoni" usare leone_san_marco_1, leone_san_marco_2, leone_san_marco_3

@export var prop_id: String = ""
@export var collect_effect_scene: PackedScene = null
@export var collect_sound: AudioStream = null

var _collected: bool = false
var _sprite: Node2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	_sprite = get_node_or_null("Sprite2D")
	if _sprite == null:
		_sprite = get_node_or_null("Sprite")
	# Rileva il player (layer 2)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	call_deferred("_snap_visual_to_ground")


func _snap_visual_to_ground() -> void:
	# I collezionabili sono props da pavimento: allinea l'origine alla prima
	# collisione statica sottostante e conserva lo sprite sopra la quota.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -120), global_position + Vector2(0, 180), 1)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var floor_y := (hit.position as Vector2).y
		global_position.y = floor_y + 9.0
		if _sprite is Sprite2D:
			var sprite := _sprite as Sprite2D
			var image := sprite.texture.get_image() if sprite.texture else null
			if image:
				var used := image.get_used_rect()
				if used.size.y > 0:
					var opaque_bottom := float(used.end.y) - float(image.get_height()) * 0.5
					var current_bottom := sprite.position.y + opaque_bottom * absf(sprite.scale.y)
					sprite.position.y -= current_bottom

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body == null or not body.is_in_group("player"):
		return
	_collected = true
	# Effetto raccolta
	_spawn_collect_effect()
	if collect_sound and body.has_node("AudioStreamPlayer2D") == false:
		var asp = AudioStreamPlayer2D.new()
		body.get_parent().add_child(asp)
		asp.stream = collect_sound
		asp.global_position = global_position
		asp.play()
		asp.finished.connect(asp.queue_free)
	# Achievement: se è un leone di San Marco
	var am = get_node_or_null("/root/AchievementManager")
	if am != null and am.has_method("add_leone_found"):
		am.add_leone_found(prop_id)
	# Nascondi il prop (preso)
	visible = false
	set_deferred("monitoring", false)
	get_tree().create_timer(0.6).timeout.connect(queue_free)

func _spawn_collect_effect() -> void:
	var scene: PackedScene = collect_effect_scene
	if scene == null:
		scene = load("res://Fx/black_particle.tscn") as PackedScene
	if scene == null:
		return
	var container: Node = get_parent() if get_parent() else get_tree().current_scene
	var p: Node2D = scene.instantiate() as Node2D
	container.add_child(p)
	p.global_position = global_position
	if p.has_method("set_direction"):
		p.call("set_direction", Vector2.UP)
	if p.has_method("set_color"):
		p.call("set_color", Color(1.0, 0.85, 0.3, 0.95))
	if p.has_method("set_amount"):
		p.call("set_amount", 14)
	if p.has_method("play"):
		p.call("play")
