extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene := load("res://Player/Scene/Player.tscn") as PackedScene
	var player := player_scene.instantiate()
	root.add_child(player)
	var rig := player.get_node_or_null("VisualLayers")
	if rig == null or player.get_node_or_null("VisualLayers/ArtAnimationPlayer") == null:
		_fail("Player visual layers or artist AnimationPlayer are missing.")
		return
	if player.get_node_or_null("VisualLayers/ArtAnimationTree") == null:
		_fail("Player artist AnimationTree is missing.")
		return
	if not rig.has_method("play_art_animation"):
		_fail("Player visual rig API is missing.")
		return

	var image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var kit := EnemyArtKit.new()
	kit.sheet = texture
	kit.sheet_columns = 2
	kit.sheet_rows = 1
	kit.clip_layout = {
		"idle": {"from": 0, "len": 1, "loop": true},
		"artist_custom_dance": {"from": 0, "len": 2, "fps": 12.0, "loop": true},
	}
	var custom_frames := kit.resolved_frames()
	if custom_frames == null or not custom_frames.has_animation("artist_custom_dance"):
		_fail("EnemyArtKit rejected a custom animation name.")
		return

	var overlay_a := EnemyArtLayer.new()
	overlay_a.layer_name = "costume"
	overlay_a.still = texture
	var overlay_b := EnemyArtLayer.new()
	overlay_b.layer_name = "weapon"
	overlay_b.frames = custom_frames
	kit.layers = [overlay_a, overlay_b]

	var enemy_scene := load("res://Enemies/ArtistEnemyTemplate.tscn") as PackedScene
	var enemy := enemy_scene.instantiate()
	root.add_child(enemy)
	enemy.call("apply_art_kit", kit)
	await process_frame
	if int(enemy.get("_art_layers").size()) != 2:
		_fail("Enemy did not create all additional visual layers.")
		return
	enemy.call("play_art_clip", "artist_custom_dance")
	print("CALIGO_ARTIST_FREEDOM_OK: free palette, player AnimationTree, custom clips and multilayer enemies")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
