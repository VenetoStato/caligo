extends Node2D

# ===========================================
# ATTACKABLE / INTERACTABLE ON ATTACK
# ===========================================
# Oggetto che reagisce quando il player lo colpisce (Attack_fast / Attack_strong).
# - ANIMATE: riproduci un'animazione (es. shake sui casoni)
# - BREAK: riproduci animazione di rottura e resta lì "rotta" (es. croce/tomba)

enum Behavior { ANIMATE_ONLY, BREAK_ON_HIT }

@export var behavior: Behavior = Behavior.ANIMATE_ONLY
@export var hit_animation_name: String = "hit"
@export var break_animation_name: String = "break"

var _hurtbox: Area2D = null
var _anim: AnimationPlayer = null
var _sprite: Node2D = null
var _broken: bool = false

func _ready():
	_hurtbox = get_node_or_null("Hurtbox")
	_anim = get_node_or_null("AnimationPlayer")
	_sprite = get_node_or_null("Sprite2D")
	if _sprite == null:
		_sprite = get_node_or_null("Sprite")
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		# Rileva l'area di attacco del player (layer 4)
		_hurtbox.collision_layer = 2
		_hurtbox.collision_mask = 4
		_hurtbox.monitoring = true

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if _broken:
		return
	if area == null or not area.is_in_group("player_attack"):
		return
	_on_hit()

func _on_hit() -> void:
	if _broken:
		return
	# Colpetto camera quando colpisci o rompi qualcosa
	var cam = get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("add_shake"):
		cam.add_shake(0.36)
	if behavior == Behavior.ANIMATE_ONLY:
		_play_hit()
	elif behavior == Behavior.BREAK_ON_HIT:
		_play_break()

func _play_hit() -> void:
	if _anim and hit_animation_name and _anim.has_animation(hit_animation_name):
		_anim.play(hit_animation_name)

func _play_break() -> void:
	_broken = true
	if _hurtbox:
		_hurtbox.monitoring = false
	if _anim and break_animation_name and _anim.has_animation(break_animation_name):
		if not _anim.animation_finished.is_connected(_on_break_anim_finished):
			_anim.animation_finished.connect(_on_break_anim_finished)
		_anim.play(break_animation_name)
	# Resta lì rotta: non rimuoviamo il nodo

func _on_break_anim_finished(_anim_name: String) -> void:
	if _anim_name == break_animation_name:
		_anim.animation_finished.disconnect(_on_break_anim_finished)
