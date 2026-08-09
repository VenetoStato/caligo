# HollowKnightCamera2D.gd (Godot 4.x)
extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 10.0            # higher = snappier
@export var look_ahead_x: float = 120.0           # pixels
@export var look_ahead_y: float = 40.0            # pixels (small)
@export var look_ahead_lerp: float = 8.0          # how fast look-ahead changes

@export var deadzone_y: float = 28.0              # vertical dead-zone around target
@export var deadzone_x: float = 0.0               # keep 0 for HK-like (mostly horizontal follow)

@export var use_room_limits: bool = false
@export var room_limits: Rect2 = Rect2(Vector2.ZERO, Vector2(4000, 2000)) # world/room rect in px

@export var use_pixel_snap: bool = false          # helps with pixel art

# --- PostFX hookup (CanvasLayer/ColorRect con ShaderMaterial) ---
@export var postfx_colorrect_path: NodePath       # es: "../PostFX/Overlay"
@export var postfx_enabled: bool = true

# Vignette tuning (match shader uniforms)
@export var vignette_strength: float = 0.85
@export var vignette_softness: float = 0.35
@export var vignette_radius: float = 0.95

# Grain tuning
@export var grain_amount: float = 0.12
@export var grain_size: float = 1.25
@export var grain_speed: float = 1.5
@export var desaturate: float = 0.06

# Post-produzione estesa
@export var contrast: float = 1.06
@export var saturation: float = 0.92
@export var grade_strength: float = 0.28
@export var chroma: float = 0.55
@export var bloom: float = 0.22
@export var bloom_threshold: float = 0.62
@export var haze: float = 0.08
@export var shadow_tint: Color = Color(0.12, 0.28, 0.32, 1.0)
@export var highlight_tint: Color = Color(0.95, 0.92, 0.82, 1.0)
@export var haze_color: Color = Color(0.55, 0.78, 0.82, 1.0)

var _target: Node2D
var _look_vec: Vector2 = Vector2.ZERO

# Screen shake (trauma-based: 0..1, decay per frame)
var _shake_trauma: float = 0.0
@export var shake_decay: float = 1.8
@export var shake_max_offset: float = 28.0

# Smooth al passaggio target (es. character_beginning -> Player): per N frame usa follow più lento
var _smooth_attach_frames: int = 0
const _smooth_attach_follow_speed: float = 1.8  # più basso = transizione più morbida (evita scatto)

var _post_rect: ColorRect
var _post_mat: ShaderMaterial
var _postfx_dirty := true
var _last_postfx_key := ""

func _ready() -> void:
	_apply_mobile_postfx_budget()
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D
	else:
		# fallback: parent (common if Camera2D is child of Player)
		_target = get_parent() as Node2D

	if _target == null:
		push_error("Camera: target not found. Set target_path or parent the camera under the player.")
		return

	add_to_group("camera")
	# We control smoothing manually

## Chiama per far tremare lo schermo. intensity 0..1 (es. 0.15 = leggero, 0.4 = forte)
func add_shake(intensity: float = 0.2) -> void:
	_shake_trauma = min(1.0, _shake_trauma + intensity)

func set_camera_target(node: Node2D, smooth_attach_frames: int = 0):
	"""Imposta il target da seguire (es. quando passi dalla barca o character_beginning -> Player).
	smooth_attach_frames: se > 0, per i primi N frame usa follow più lento per transizione morbida."""
	_target = node
	position_smoothing_enabled = false
	_smooth_attach_frames = smooth_attach_frames

	# Hook PostFX
	_setup_postfx()

func _setup_postfx() -> void:
	_post_rect = null
	_post_mat = null

	if postfx_colorrect_path == NodePath():
		return

	_post_rect = get_node_or_null(postfx_colorrect_path) as ColorRect
	if _post_rect == null:
		push_error("PostFX: ColorRect not found at postfx_colorrect_path.")
		return

	_post_rect.visible = postfx_enabled

	if _post_rect.material is ShaderMaterial:
		_post_mat = _post_rect.material as ShaderMaterial
	else:
		push_error("PostFX: ColorRect material is not a ShaderMaterial.")
		return

	# Push initial params
	_apply_postfx_params()

func _apply_mobile_postfx_budget() -> void:
	var mobile := OS.has_feature("mobile") or OS.get_name() == "Android"
	if not mobile:
		return
	bloom = minf(bloom, 0.12)
	chroma = minf(chroma, 0.25)
	grain_amount = minf(grain_amount, 0.06)
	haze = minf(haze, 0.04)
	grade_strength = minf(grade_strength, 0.18)
	_postfx_dirty = true


func _apply_postfx_params() -> void:
	if _post_mat == null:
		return
	var key := "%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%s|%s|%s" % [
		str(postfx_enabled),
		vignette_strength, vignette_softness, vignette_radius,
		grain_amount, grain_size, grain_speed, desaturate,
		contrast, saturation, grade_strength, chroma, bloom, bloom_threshold, haze,
		str(shadow_tint), str(highlight_tint), str(haze_color)
	]
	if key == _last_postfx_key and not _postfx_dirty:
		return
	_last_postfx_key = key
	_postfx_dirty = false
	_post_mat.set_shader_parameter("u_vignette_strength", vignette_strength)
	_post_mat.set_shader_parameter("u_vignette_softness", vignette_softness)
	_post_mat.set_shader_parameter("u_vignette_radius", vignette_radius)

	_post_mat.set_shader_parameter("u_grain_amount", grain_amount)
	_post_mat.set_shader_parameter("u_grain_size", grain_size)
	_post_mat.set_shader_parameter("u_grain_speed", grain_speed)

	_post_mat.set_shader_parameter("u_desaturate", desaturate)
	_post_mat.set_shader_parameter("u_contrast", contrast)
	_post_mat.set_shader_parameter("u_saturation", saturation)
	_post_mat.set_shader_parameter("u_grade_strength", grade_strength)
	_post_mat.set_shader_parameter("u_chroma", chroma)
	_post_mat.set_shader_parameter("u_bloom", bloom)
	_post_mat.set_shader_parameter("u_bloom_threshold", bloom_threshold)
	_post_mat.set_shader_parameter("u_haze", haze)
	_post_mat.set_shader_parameter("u_shadow_tint", shadow_tint)
	_post_mat.set_shader_parameter("u_highlight_tint", highlight_tint)
	_post_mat.set_shader_parameter("u_haze_color", haze_color)

func _process(delta: float) -> void:
	if _target == null:
		return

	if _post_rect != null:
		_post_rect.visible = postfx_enabled
	_apply_postfx_params()

	var target_pos: Vector2 = _target.global_position

	# --- Look-ahead (uses velocity if available, otherwise uses facing/position delta) ---
	var desired_look := Vector2.ZERO

	# If your player has `velocity` (CharacterBody2D), use it:
	if _target.has_method("get_velocity"):
		var v: Vector2 = _target.call("get_velocity")
		desired_look.x = clamp(v.x * 0.20, -look_ahead_x, look_ahead_x)
		desired_look.y = clamp(v.y * 0.10, -look_ahead_y, look_ahead_y)
	elif "velocity" in _target:
		var v2: Vector2 = _target.get("velocity")
		desired_look.x = clamp(v2.x * 0.20, -look_ahead_x, look_ahead_x)
		desired_look.y = clamp(v2.y * 0.10, -look_ahead_y, look_ahead_y)
	else:
		desired_look = Vector2.ZERO

	_look_vec = _look_vec.lerp(desired_look, 1.0 - exp(-look_ahead_lerp * delta))

	# --- Dead-zone (don’t move camera for small movements) ---
	var desired_cam := global_position

	# Horizontal dead-zone (optional; HK usually tracks X more directly)
	if deadzone_x > 0.0:
		var dx := target_pos.x - desired_cam.x
		if abs(dx) > deadzone_x:
			desired_cam.x += dx - sign(dx) * deadzone_x
	else:
		desired_cam.x = target_pos.x

	# Vertical dead-zone (HK feeling)
	var dy := target_pos.y - desired_cam.y
	if abs(dy) > deadzone_y:
		desired_cam.y += dy - sign(dy) * deadzone_y

	# Apply look-ahead
	desired_cam += _look_vec

	# --- Smooth follow (più lento i primi frame dopo cambio target: transizione fluida) ---
	var effective_speed := follow_speed
	if _smooth_attach_frames > 0:
		effective_speed = _smooth_attach_follow_speed
		_smooth_attach_frames -= 1
		# Primi frame ancora più morbidi: riduci il delta effettivo per evitare scatto
		if _smooth_attach_frames > 70:
			effective_speed *= 0.5
	var t := 1.0 - exp(-effective_speed * delta)
	global_position = global_position.lerp(desired_cam, t)
	
	# --- Screen shake ---
	_shake_trauma = max(0.0, _shake_trauma - shake_decay * delta)
	if _shake_trauma > 0.001:
		var trauma2 = _shake_trauma * _shake_trauma
		var shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_max_offset * trauma2
		offset = shake_offset
	else:
		offset = Vector2.ZERO

	# --- Room clamp (optional) ---
	if use_room_limits:
		global_position = _clamp_to_room(global_position)

	# --- Pixel snap (optional) ---
	if use_pixel_snap:
		global_position = global_position.round()

	# --- Update vignette center to follow player on screen ---
	_update_postfx_center()

func _update_postfx_center() -> void:
	if _post_mat == null or not postfx_enabled:
		return

	# Convert target world position to screen position (in pixels)
	var canvas_xform: Transform2D = get_canvas_transform()

	# world -> canvas/screen px
	var screen_pos: Vector2 = canvas_xform * _target.global_position

	var vp := get_viewport()
	if vp == null:
		return

	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	# Normalize to UV 0..1 for shader
	var center_uv := Vector2(
		clamp(screen_pos.x / vp_size.x, 0.0, 1.0),
		clamp(screen_pos.y / vp_size.y, 0.0, 1.0)
	)

	_post_mat.set_shader_parameter("u_center_uv", center_uv)

func _clamp_to_room(p: Vector2) -> Vector2:
	var r := room_limits
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_zoom := Vector2(maxf(zoom.x, 0.01), maxf(zoom.y, 0.01))
	var half_view := viewport_size * 0.5 / safe_zoom
	var min_center := r.position + half_view
	var max_center := r.end - half_view
	if min_center.x <= max_center.x:
		p.x = clampf(p.x, min_center.x, max_center.x)
	else:
		p.x = r.get_center().x
	if min_center.y <= max_center.y:
		p.y = clampf(p.y, min_center.y, max_center.y)
	else:
		p.y = r.get_center().y
	return p
