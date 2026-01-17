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

var _target: Node2D
var _look_vec: Vector2 = Vector2.ZERO

var _post_rect: ColorRect
var _post_mat: ShaderMaterial

func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D
	else:
		# fallback: parent (common if Camera2D is child of Player)
		_target = get_parent() as Node2D

	if _target == null:
		push_error("Camera: target not found. Set target_path or parent the camera under the player.")
		return

	# We control smoothing manually
	position_smoothing_enabled = false

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

func _apply_postfx_params() -> void:
	if _post_mat == null:
		return
	_post_mat.set_shader_parameter("u_vignette_strength", vignette_strength)
	_post_mat.set_shader_parameter("u_vignette_softness", vignette_softness)
	_post_mat.set_shader_parameter("u_vignette_radius", vignette_radius)

	_post_mat.set_shader_parameter("u_grain_amount", grain_amount)
	_post_mat.set_shader_parameter("u_grain_size", grain_size)
	_post_mat.set_shader_parameter("u_grain_speed", grain_speed)

	_post_mat.set_shader_parameter("u_desaturate", desaturate)

func _process(delta: float) -> void:
	if _target == null:
		return

	# se modifichi gli export a runtime dall'Inspector, aggiorna
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

	# --- Smooth follow ---
	var t := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_cam, t)

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
	# This clamps camera center inside room rect.
	# If you use zoom or want perfect edge behavior, adapt with viewport size.
	var r := room_limits
	p.x = clamp(p.x, r.position.x, r.position.x + r.size.x)
	p.y = clamp(p.y, r.position.y, r.position.y + r.size.y)
	return p
