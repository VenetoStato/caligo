@tool
class_name PlayerVisualRig
extends Node2D

## Contenitore libero per l'arte del player. I figli Sprite2D seguono il frame
## del foglio base quando hanno la stessa griglia; AnimatedSprite2D e
## AnimationTree possono invece avere animazioni completamente indipendenti.

@export var base_sprite_path := NodePath("../Sprite2D")
@export var gameplay_animation_player_path := NodePath("../anim")
@export var sync_matching_sprite_sheets := true
@export var sync_facing := true

var _last_gameplay_animation := ""


func _process(_delta: float) -> void:
	var base := get_node_or_null(base_sprite_path) as Sprite2D
	if base == null:
		return
	for child in get_children():
		if child is Sprite2D:
			var layer := child as Sprite2D
			if sync_facing:
				layer.flip_h = base.flip_h
			if (
				sync_matching_sprite_sheets
				and layer.texture != null
				and layer.hframes == base.hframes
				and layer.vframes == base.vframes
			):
				layer.frame = base.frame
		elif child is AnimatedSprite2D and sync_facing:
			(child as AnimatedSprite2D).flip_h = base.flip_h
	_sync_named_animation()


func _sync_named_animation() -> void:
	var tree := get_node_or_null("ArtAnimationTree") as AnimationTree
	if tree and tree.active:
		return
	var gameplay := get_node_or_null(gameplay_animation_player_path) as AnimationPlayer
	var artist := get_node_or_null("ArtAnimationPlayer") as AnimationPlayer
	if gameplay == null or artist == null:
		return
	var current := String(gameplay.current_animation)
	if current.is_empty() or current == _last_gameplay_animation:
		return
	_last_gameplay_animation = current
	if artist.has_animation(current):
		artist.play(current)


func play_art_animation(animation_name: StringName) -> void:
	var artist := get_node_or_null("ArtAnimationPlayer") as AnimationPlayer
	if artist and artist.has_animation(animation_name):
		artist.play(animation_name)


func get_art_animation_tree() -> AnimationTree:
	return get_node_or_null("ArtAnimationTree") as AnimationTree
