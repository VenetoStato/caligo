extends StaticBody2D

signal prop_broken

const PARTICLE_BURST := preload("res://Fx/particle_burst.gd")

enum VisualVariant { FISHING_CACHE, CRACKED_URN, NET_BUNDLE }

@export_range(1, 4, 1) var hits_required := 1
@export var visual_variant := VisualVariant.FISHING_CACHE
@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

@onready var _solid: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _visual: Sprite2D = $Visual

var _hits_left := 1
var _broken := false


func _ready() -> void:
	add_to_group("dogana_breakable")
	_hits_left = hits_required
	_apply_visual_variant()
	_hurtbox.area_entered.connect(_on_hurtbox_entered)


func _apply_visual_variant() -> void:
	if art_profile == null:
		return
	match visual_variant:
		VisualVariant.CRACKED_URN:
			_visual.texture = art_profile.cracked_urn
			_visual.scale = art_profile.cracked_urn_scale
			_visual.position = art_profile.cracked_urn_offset
		VisualVariant.NET_BUNDLE:
			_visual.texture = art_profile.net_bundle
			_visual.scale = art_profile.net_bundle_scale
			_visual.position = art_profile.net_bundle_offset
		_:
			_visual.texture = art_profile.fishing_cache
			_visual.scale = art_profile.fishing_cache_scale
			_visual.position = art_profile.fishing_cache_offset


func _on_hurtbox_entered(area: Area2D) -> void:
	if _broken or not area.is_in_group("player_attack"):
		return
	_hits_left -= 1
	var camera := get_tree().get_first_node_in_group("camera")
	if camera and camera.has_method("add_shake"):
		camera.call("add_shake", 0.25 if _hits_left > 0 else 0.46)
	if _hits_left <= 0:
		_break()
	else:
		var tween := create_tween()
		tween.tween_property(_visual, "rotation", 0.08, 0.055)
		tween.tween_property(_visual, "rotation", -0.065, 0.055)
		tween.tween_property(_visual, "rotation", 0.0, 0.055)


func _break() -> void:
	_broken = true
	_solid.set_deferred("disabled", true)
	_hurtbox.set_deferred("monitoring", false)
	_spawn_debris()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_visual, "modulate:a", 0.0, 0.22)
	tween.tween_property(_visual, "scale", _visual.scale * Vector2(1.18, 0.68), 0.22)
	tween.chain().tween_callback(_visual.hide)
	prop_broken.emit()


func _spawn_debris() -> void:
	PARTICLE_BURST.spawn(
		get_tree().current_scene,
		global_position + Vector2(0, -36),
		Color(0.2, 0.67, 0.58, 0.88),
		16,
		Vector2.UP,
		45.0,
		145.0,
		0.72
	)
	for index in 5:
		var shard := Polygon2D.new()
		var size := randf_range(3.0, 8.0)
		shard.polygon = PackedVector2Array([
			Vector2(-size, -size * 0.45),
			Vector2(size * 0.8, -size),
			Vector2(size, size * 0.7),
			Vector2(-size * 0.7, size),
		])
		shard.color = Color(0.32, 0.29, 0.22, 0.95).lerp(
			Color(0.16, 0.48, 0.43, 0.9),
			0.35 if index % 3 == 0 else 0.0
		)
		shard.position = Vector2(randf_range(-38.0, 38.0), randf_range(-56.0, -8.0))
		add_child(shard)
		var target := shard.position + Vector2(randf_range(-70.0, 70.0), randf_range(-75.0, 22.0))
		var tween := create_tween().set_parallel(true)
		tween.tween_property(shard, "position", target, randf_range(0.35, 0.58)).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shard, "rotation", randf_range(-3.5, 3.5), 0.5)
		tween.tween_property(shard, "modulate:a", 0.0, 0.55).set_delay(0.12)
		tween.chain().tween_callback(shard.queue_free)
