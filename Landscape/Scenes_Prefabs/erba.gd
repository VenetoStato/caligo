extends Sprite2D

func play_anim():
	$erba_anim.play("erba_moving")


func _on_area_2d_body_entered(body: Node2D) -> void:
	play_anim()
