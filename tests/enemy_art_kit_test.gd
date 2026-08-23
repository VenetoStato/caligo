extends SceneTree

const KitScript := preload("res://Enemies/enemy_art_kit.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var probe = KitScript.new()
	var clip_names: Array = probe.CLIP_NAMES
	if clip_names.size() != 8:
		_fail("Enemy art kit is missing the Hollow Knight clip contract.")
		return
	var layout_eight: Dictionary = probe.default_layout(8)
	for clip_name in clip_names:
		if not layout_eight.has(clip_name):
			_fail("Default 8-frame layout is missing clip %s." % clip_name)
			return

	var kit = KitScript.new()
	kit.still = load("res://Landscape/Dogana/Generated/tide_bloater.png")
	if kit.still == null:
		_fail("Tide bloater still art is missing.")
		return
	kit.sheet = kit.still
	kit.sheet_columns = 1
	kit.sheet_rows = 1
	var frames = kit.resolved_frames()
	if frames == null or not frames.has_animation("idle"):
		_fail("A one-cell sheet did not produce an idle clip.")
		return

	var packed := load("res://Enemies/enemy.tscn") as PackedScene
	var enemy := packed.instantiate() as CharacterBody2D
	root.add_child(enemy)
	await process_frame
	var body := enemy.get_node("CollisionShape2D") as CollisionShape2D
	var hurt := enemy.get_node("Hurtbox") as Area2D
	var body_before := body.position
	var hurt_before := hurt.position
	enemy.call("apply_art_kit", kit)
	if not bool(enemy.get("_using_frames")):
		_fail("Enemy did not switch to named clips after receiving a sheet.")
		return
	enemy.call("_play_clip", "idle", true)
	enemy.call("_play_clip", "windup", true)
	enemy.call("_play_clip", "attack", true)
	if body.position != body_before or hurt.position != hurt_before:
		_fail("Swapping enemy art moved collision or hurtbox.")
		return

	var profile = load("res://Levels/Scenes/Dogana/dogana_art_profile.tres")
	if (
		profile == null
		or profile.get("tide_bloater_kit") == null
		or profile.get("lagoon_oracle_kit") == null
		or profile.get("drowned_warden_kit") == null
	):
		_fail("Dogana art profile is missing enemy kits.")
		return
	print("CALIGO_ENEMY_ART_KIT_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
