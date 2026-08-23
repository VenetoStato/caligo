class_name HintMark
extends Control

## Segno del comando, disegnato a mano: un pittogramma dell'azione e, sotto, il
## tasto in un riquadro minuscolo.
##
## Prima qui c'erano glifi emoji (spade, fulmini, stelle). Le emoji vengono
## risolte dal font di sistema, cambiano forma da piattaforma a piattaforma e a
## schermo leggono come interfaccia di debug incollata sopra la scena dipinta.
## Un tratto vettoriale invece appartiene al disegno del gioco.

enum Mark {
	NONE,
	MOVE,
	INTERACT,
	JUMP,
	DOUBLE_JUMP,
	DASH,
	ATTACK,
	CAST,
	REEL,
	MAP,
}

const KEY_FONT := preload("res://UI/Fonts/CormorantGaramond.ttf")
const STROKE := Color(0.84, 0.94, 0.9, 1.0)
const STROKE_SOFT := Color(0.84, 0.94, 0.9, 0.45)
const SHADOW := Color(0.02, 0.04, 0.06, 0.55)

var mark: Mark = Mark.NONE
var key_text := ""
var stroke_width := 2.0

var _key_font_size := 13


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96, 46)


func show_mark(new_mark: Mark, new_key_text: String) -> void:
	mark = new_mark
	key_text = new_key_text
	queue_redraw()


func clear_mark() -> void:
	mark = Mark.NONE
	key_text = ""
	queue_redraw()


func set_scale_compact(compact: bool) -> void:
	stroke_width = 1.7 if compact else 2.0
	_key_font_size = 11 if compact else 13
	custom_minimum_size = Vector2(84, 40) if compact else Vector2(96, 46)
	queue_redraw()


func _draw() -> void:
	if mark == Mark.NONE:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.36)
	match mark:
		Mark.MOVE:
			_draw_chevron(center + Vector2(-16, 0), Vector2.LEFT)
			_draw_chevron(center + Vector2(16, 0), Vector2.RIGHT)
		Mark.INTERACT:
			_draw_diamond(center, 11.0)
			_draw_dot(center, 2.2)
		Mark.JUMP:
			_draw_chevron(center + Vector2(0, -3), Vector2.UP)
			_draw_ground_tick(center + Vector2(0, 11))
		Mark.DOUBLE_JUMP:
			_draw_chevron(center + Vector2(0, -8), Vector2.UP)
			_draw_chevron(center + Vector2(0, 4), Vector2.UP)
		Mark.DASH:
			_draw_streaks(center)
		Mark.ATTACK:
			_draw_slash(center)
		Mark.CAST:
			_draw_cast_arc(center)
		Mark.REEL:
			_draw_reel_loop(center)
		Mark.MAP:
			_draw_folded_sheet(center)
		Mark.NONE:
			return
	if not key_text.is_empty():
		_draw_key_cap()


func _stroke(points: PackedVector2Array, color: Color = STROKE) -> void:
	# Contorno scuro sotto il tratto: il segno resta leggibile anche su pietra chiara.
	var shadow_points := PackedVector2Array()
	for point in points:
		shadow_points.append(point + Vector2(0, 1.4))
	draw_polyline(shadow_points, SHADOW, stroke_width + 1.4, true)
	draw_polyline(points, color, stroke_width, true)


func _draw_chevron(at: Vector2, direction: Vector2) -> void:
	var span := 7.0
	var depth := 6.0
	var perpendicular := Vector2(-direction.y, direction.x)
	_stroke(PackedVector2Array([
		at - perpendicular * span - direction * depth,
		at + direction * depth,
		at + perpendicular * span - direction * depth,
	]))


func _draw_diamond(at: Vector2, radius: float) -> void:
	_stroke(PackedVector2Array([
		at + Vector2(0, -radius), at + Vector2(radius * 0.72, 0),
		at + Vector2(0, radius), at + Vector2(-radius * 0.72, 0),
		at + Vector2(0, -radius),
	]))


func _draw_dot(at: Vector2, radius: float) -> void:
	draw_circle(at + Vector2(0, 1.2), radius + 0.8, SHADOW)
	draw_circle(at, radius, STROKE)


func _draw_ground_tick(at: Vector2) -> void:
	_stroke(PackedVector2Array([at + Vector2(-9, 0), at + Vector2(9, 0)]), STROKE_SOFT)


func _draw_streaks(at: Vector2) -> void:
	for index in 3:
		var y := at.y - 6.0 + float(index) * 6.0
		var length := 10.0 + float(index % 2) * 7.0
		_stroke(PackedVector2Array([
			Vector2(at.x - length, y), Vector2(at.x + length * 0.5, y),
		]), STROKE if index == 1 else STROKE_SOFT)
	_draw_chevron(at + Vector2(16, 0), Vector2.RIGHT)


## Fendente: un arco che si apre, non una spada.
func _draw_slash(at: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 13:
		var t := float(step) / 12.0
		var angle := lerpf(-PI * 0.78, PI * 0.16, t)
		points.append(at + Vector2.from_angle(angle) * lerpf(9.0, 15.0, t))
	_stroke(points)
	_draw_dot(points[points.size() - 1], 1.8)


## Traiettoria della lenza: parabola con l'amo in punta.
func _draw_cast_arc(at: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 15:
		var t := float(step) / 14.0
		points.append(at + Vector2(lerpf(-18.0, 18.0, t), -10.0 * sin(t * PI) + 6.0))
	_stroke(points)
	_draw_dot(points[points.size() - 1], 2.2)


## Recupero: anello quasi chiuso con la punta che rientra.
func _draw_reel_loop(at: Vector2) -> void:
	var points := PackedVector2Array()
	for step in 22:
		var t := float(step) / 21.0
		var angle := lerpf(-PI * 0.35, PI * 1.5, t)
		points.append(at + Vector2.from_angle(angle) * lerpf(11.5, 8.0, t))
	_stroke(points)
	var tip: Vector2 = points[points.size() - 1]
	var heading := (tip - points[points.size() - 3]).normalized()
	var side := Vector2(-heading.y, heading.x)
	_stroke(PackedVector2Array([
		tip - heading * 5.0 + side * 3.5, tip, tip - heading * 5.0 - side * 3.5,
	]))


## Mappa: un foglio piegato, visto di tre quarti.
func _draw_folded_sheet(at: Vector2) -> void:
	_stroke(PackedVector2Array([
		at + Vector2(-14, -8), at + Vector2(-1, -10),
		at + Vector2(13, -7), at + Vector2(13, 8),
		at + Vector2(-1, 10), at + Vector2(-14, 7),
		at + Vector2(-14, -8),
	]))
	_stroke(PackedVector2Array([at + Vector2(-1, -10), at + Vector2(-1, 10)]), STROKE_SOFT)


## Il tasto sta sotto il pittogramma, dentro un riquadro appena accennato: dice
## quale dito muovere senza diventare la scritta principale.
func _draw_key_cap() -> void:
	var font_size := _key_font_size
	var text_size := KEY_FONT.get_string_size(key_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var cap_size := Vector2(maxf(text_size.x + 11.0, 17.0), font_size + 8.0)
	var origin := Vector2((size.x - cap_size.x) * 0.5, size.y - cap_size.y - 2.0)
	draw_rect(Rect2(origin, cap_size), Color(0.03, 0.05, 0.07, 0.4), true)
	draw_rect(Rect2(origin, cap_size), Color(STROKE_SOFT, 0.34), false, 1.0, true)
	draw_string(
		KEY_FONT,
		origin + Vector2(cap_size.x * 0.5 - text_size.x * 0.5, cap_size.y - font_size * 0.32),
		key_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(STROKE, 0.62)
	)
