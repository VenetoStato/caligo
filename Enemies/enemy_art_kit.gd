class_name EnemyArtKit
extends Resource

## Kit artistico aperto: il gameplay non legge i pixel. Le clip standard sono
## convenzioni usate dalla logica, ma SpriteFrames e clip_layout possono
## contenere qualsiasi altra animazione decisa dall'artista.

const CLIP_NAMES := ["idle", "walk", "wake", "windup", "attack", "hurt", "death", "jump"]

@export var still: Texture2D
@export var frames: SpriteFrames
@export var sheet: Texture2D
@export_range(1, 16, 1) var sheet_columns := 8
@export_range(1, 8, 1) var sheet_rows := 1
@export var sheet_fps := 8.0
## Optional override: { "idle": { "from": 0, "len": 2, "fps": 4.0, "loop": true } }
@export var clip_layout: Dictionary = {}
## Layer aggiuntivi sincronizzati: corpo, costume, arma, maschera, VFX, ecc.
@export var layers: Array[EnemyArtLayer] = []


func resolved_still() -> Texture2D:
	if still:
		return still
	var built := resolved_frames()
	if built and built.has_animation("idle") and built.get_frame_count("idle") > 0:
		return built.get_frame_texture("idle", 0)
	return null


func resolved_frames() -> SpriteFrames:
	if frames:
		return frames
	var source := sheet
	if source == null and still:
		var guess := String(still.resource_path).get_basename() + "_sheet.png"
		if ResourceLoader.exists(guess):
			source = load(guess) as Texture2D
	if source == null:
		return null
	return _frames_from_sheet(source)


func has_clip(clip_name: String) -> bool:
	var sprite_frames := resolved_frames()
	return sprite_frames != null and sprite_frames.has_animation(clip_name)


func available_clips() -> PackedStringArray:
	var sprite_frames := resolved_frames()
	var found := PackedStringArray()
	if sprite_frames == null:
		return found
	for clip_name in sprite_frames.get_animation_names():
		found.append(clip_name)
	return found


func _frames_from_sheet(source: Texture2D) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var cols := maxi(sheet_columns, 1)
	var rows := maxi(sheet_rows, 1)
	var cell := Vector2i(
		maxi(source.get_width() / cols, 1),
		maxi(source.get_height() / rows, 1)
	)
	var total := cols * rows
	var layout: Dictionary = clip_layout if not clip_layout.is_empty() else default_layout(total)
	for clip_key in layout.keys():
		var clip_name := str(clip_key)
		if not layout.has(clip_name):
			continue
		var spec: Dictionary = layout[clip_name]
		var from := int(spec.get("from", 0))
		var length := int(spec.get("len", 1))
		if from >= total:
			continue
		length = mini(length, total - from)
		if length <= 0:
			continue
		if not sprite_frames.has_animation(clip_name):
			sprite_frames.add_animation(clip_name)
		sprite_frames.set_animation_speed(clip_name, float(spec.get("fps", sheet_fps)))
		sprite_frames.set_animation_loop(clip_name, bool(spec.get("loop", clip_name in ["idle", "walk"])))
		for index_offset in length:
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			var frame_index := from + index_offset
			var cell_x := frame_index % cols
			var cell_y := int(frame_index / cols)
			atlas.region = Rect2(cell_x * cell.x, cell_y * cell.y, cell.x, cell.y)
			sprite_frames.add_frame(clip_name, atlas)
	return sprite_frames


static func default_layout(total: int) -> Dictionary:
	if total <= 1:
		return {
			"idle": {"from": 0, "len": 1, "fps": 3.0, "loop": true},
		}
	if total == 2:
		return {
			"idle": {"from": 0, "len": 2, "fps": 3.0, "loop": true},
			"walk": {"from": 0, "len": 2, "fps": 7.0, "loop": true},
			"wake": {"from": 1, "len": 1, "fps": 6.0, "loop": false},
			"windup": {"from": 1, "len": 1, "fps": 6.0, "loop": false},
			"attack": {"from": 1, "len": 1, "fps": 8.0, "loop": false},
			"hurt": {"from": 0, "len": 1, "fps": 8.0, "loop": false},
			"death": {"from": 0, "len": 1, "fps": 4.0, "loop": false},
			"jump": {"from": 1, "len": 1, "fps": 8.0, "loop": false},
		}
	if total <= 4:
		return {
			"idle": {"from": 0, "len": 2, "fps": 4.0, "loop": true},
			"walk": {"from": 2, "len": mini(2, total - 2), "fps": 8.0, "loop": true},
			"wake": {"from": 0, "len": 1, "fps": 6.0, "loop": false},
			"windup": {"from": mini(3, total - 1), "len": 1, "fps": 6.0, "loop": false},
			"attack": {"from": mini(3, total - 1), "len": 1, "fps": 8.0, "loop": false},
			"hurt": {"from": 1, "len": 1, "fps": 8.0, "loop": false},
			"death": {"from": 1, "len": 1, "fps": 4.0, "loop": false},
			"jump": {"from": 2, "len": 1, "fps": 8.0, "loop": false},
		}
	return {
		"idle": {"from": 0, "len": 2, "fps": 4.0, "loop": true},
		"walk": {"from": 2, "len": 2, "fps": 8.0, "loop": true},
		"wake": {"from": 4, "len": 1, "fps": 6.0, "loop": false},
		"windup": {"from": 5, "len": 1, "fps": 6.0, "loop": false},
		"attack": {"from": 6, "len": 1, "fps": 8.0, "loop": false},
		"hurt": {"from": 7, "len": 1, "fps": 10.0, "loop": false},
		"death": {"from": 7, "len": 1, "fps": 4.0, "loop": false},
		"jump": {"from": 2, "len": 1, "fps": 8.0, "loop": false},
	}
