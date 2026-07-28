extends StaticBody2D

signal wall_broken

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

@export_range(1, 5, 1) var hits_required := 2
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

@onready var _solid: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _visual: Sprite2D = $Visual

var _hits_left := 2
var _broken := false


func _ready() -> void:
	_hits_left = hits_required
	add_to_group("dogana_breakable")
	if art_profile and art_profile.fishbone_wall:
		_visual.texture = art_profile.fishbone_wall
	_visual.z_index = 1
	_visual.modulate = Color(1.1, 1.18, 1.14, 1.0)
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask = 4
	_hurtbox.monitoring = true
	_hurtbox.monitorable = true
	_hurtbox.area_entered.connect(_on_hurtbox_entered)
	# Alone hint: thin cyan outline so the sealed door reads in the dark.
	queue_redraw()
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _broken:
		return
	# Alone soft, non un rettangolo pieno.
	var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.004) * 0.2
	draw_arc(Vector2.ZERO, 42.0 + pulse * 4.0, 0.0, TAU, 36, Color(0.2, 0.85, 0.75, 0.1 + pulse * 0.08), 2.0, true)
	draw_line(Vector2(-20, -70), Vector2(20, -70), Color(0.25, 0.8, 0.7, 0.25 + pulse * 0.2), 2.0, true)
	draw_line(Vector2(-24, 70), Vector2(24, 70), Color(0.2, 0.7, 0.65, 0.2), 2.0, true)


func _on_hurtbox_entered(area: Area2D) -> void:
	if _broken or not area.is_in_group("player_attack"):
		return
	_hits_left -= 1
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.2 if _hits_left > 0 else 0.5)
	if _hits_left <= 0:
		_break()
	else:
		var tween := create_tween()
		tween.tween_property(_visual, "position:x", 5.0, 0.05)
		tween.tween_property(_visual, "position:x", -4.0, 0.05)
		tween.tween_property(_visual, "position:x", 0.0, 0.05)


func _break() -> void:
	_broken = true
	_solid.set_deferred("disabled", true)
	_hurtbox.set_deferred("monitoring", false)
	_spawn_debris()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "modulate:a", 0.0, 0.28)
	tween.tween_property(_visual, "scale", _visual.scale * Vector2(1.35, 0.7), 0.28)
	tween.chain().tween_callback(_visual.hide)
	wall_broken.emit()


func _spawn_debris() -> void:
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position,
		Color(0.22, 0.72, 0.63, 0.9),
		22,
		Vector2.UP,
		55.0,
		170.0,
		0.86
	)
	for index in 6:
		var shard := Polygon2D.new()
		var size := randf_range(3.0, 7.0)
		shard.polygon = PackedVector2Array([
			Vector2(-size, -size),
			Vector2(size, -size * 0.45),
			Vector2(size * 0.7, size),
			Vector2(-size * 0.8, size * 0.55),
		])
		shard.color = Color(0.31, 0.32, 0.28, 0.95)
		if index % 4 == 0:
			shard.color = Color(0.18, 0.7, 0.62, 0.88)
		shard.position = Vector2(randf_range(-24.0, 24.0), randf_range(-82.0, 82.0))
		add_child(shard)
		var target := shard.position + Vector2(randf_range(-65.0, 65.0), randf_range(-90.0, 35.0))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(shard, "position", target, randf_range(0.38, 0.64)).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shard, "rotation", randf_range(-4.0, 4.0), 0.58)
		tween.tween_property(shard, "modulate:a", 0.0, 0.62).set_delay(0.16)
		tween.chain().tween_callback(shard.queue_free)
