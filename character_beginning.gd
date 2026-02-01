extends CharacterBody2D

# Character Beginning: all'avvio della scena mostra l'animazione intro,
# poi sostituisce se stesso con il Player vero.
# Ha gravità come il Player (entrambi soggetti alla fisica).

@export var player_scene: PackedScene
## Offset in pixel verso il basso quando compare il player (rispetto al character beginning)
@export var player_spawn_offset_y: float = 18.0

var _anim: AnimationPlayer

func _ready():
	velocity = Vector2.ZERO
	
	_anim = get_node_or_null("AnimationPlayer")
	if _anim != null:
		if not _anim.animation_finished.is_connected(_on_intro_finished):
			_anim.animation_finished.connect(_on_intro_finished)
		if _anim.has_animation("intro"):
			_anim.play("intro")
		else:
			_anim.play("idle")
			# Se non c'è intro, passa subito al player dopo un attimo
			await get_tree().create_timer(1.0).timeout
			_switch_to_player()
	else:
		_switch_to_player()

func _physics_process(delta: float):
	# Gravità come il Player: entrambi devono cadere/stare a terra
	var g = get_gravity()
	velocity.y += g.y * delta
	move_and_slide()

func _on_intro_finished(anim_name: StringName):
	if anim_name == "intro":
		_switch_to_player()

func _switch_to_player():
	if player_scene == null:
		player_scene = load("res://Player/Scene/Player.tscn") as PackedScene
	if player_scene == null:
		return
	
	var player = player_scene.instantiate()
	var parent = get_parent()
	if parent == null:
		return
	
	# Evita il fade in/out quando passiamo da Character Beginning al Player (stessa scena)
	player.set_meta("skip_initial_fade", true)
	
	var pos = global_position
	var my_index = get_index()
	
	# I figli aggiunti dalla scena (es. Camera2D, PostFx, PointLight2D) vanno riassegnati al Player
	var to_reparent: Array[Node] = []
	for c in get_children():
		# Tutti i nodi che non fanno parte della scena character_beginning (Sprite2D, CollisionShape2D, AnimationPlayer)
		var name_lower = c.name.to_lower()
		if name_lower == "camera2d" or name_lower == "postfx" or "pointlight" in name_lower or name_lower == "overlay":
			to_reparent.append(c)
	
	parent.add_child(player)
	# Qualche pixel più in basso rispetto al character beginning
	player.global_position = pos + Vector2(0, player_spawn_offset_y)
	
	for node in to_reparent:
		remove_child(node)
		player.add_child(node)
	
	# Fix telecamera: aggiorna il target e attiva smooth per i primi frame (transizione morbida al passaggio)
	var cam = player.get_node_or_null("Camera2D")
	if cam != null and cam.has_method("set_camera_target"):
		cam.call("set_camera_target", player, 50)  # 50 frame di follow più lento = ~0.8 s smooth
	
	parent.remove_child(self)
	parent.add_child(player)
	parent.move_child(player, my_index)
	
	queue_free()
