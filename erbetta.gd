extends Sprite2D

var anim_player: AnimationPlayer = null

func _ready():
	# Cerca l'AnimationPlayer (può chiamarsi "erba_anim" o "AnimationPlayer")
	anim_player = get_node_or_null("erba_anim")
	if anim_player == null:
		anim_player = get_node_or_null("AnimationPlayer")
	
	# Se c'è un AnimationPlayer, avvia l'animazione in loop
	if anim_player != null and is_instance_valid(anim_player):
		if anim_player.has_animation("moving_erbette"):
			var anim = anim_player.get_animation("moving_erbette")
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play("moving_erbette")

func play_anim():
	# Riproduci l'animazione se l'AnimationPlayer esiste
	if anim_player != null and is_instance_valid(anim_player):
		if anim_player.has_animation("moving_erbette"):
			anim_player.play("moving_erbette")
