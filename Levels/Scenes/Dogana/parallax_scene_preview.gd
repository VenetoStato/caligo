@tool
extends Node2D

const DISTANT_DOGANA := preload("res://Landscape/Dogana/Generated/Parallax/dogana_distant_fog_v2.png")
const SHIP_SHEET := preload("res://Landscape/Dogana/Generated/Parallax/distant_velieri_sheet_v1.png")
const LAGOON_FOG := preload("res://Landscape/Dogana/Generated/Parallax/distant_lagoon_fog_v1.png")

@export var show_distant_dogana := true:
	set(value):
		show_distant_dogana = value
		queue_redraw()
@export var show_ships := true:
	set(value):
		show_ships = value
		queue_redraw()
@export var show_fog := true:
	set(value):
		show_fog = value
		queue_redraw()
@export var preview_offset := Vector2.ZERO:
	set(value):
		preview_offset = value
		queue_redraw()


func _ready() -> void:
	# Tra fondale (-20) e Dogana principale (-17): il preview rispetta la
	# profondita' reale e non passa mai davanti all'architettura giocabile.
	z_index = -18 if Engine.is_editor_hint() else -100
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if show_distant_dogana:
		for index in 6:
			_draw_scaled_texture(
				DISTANT_DOGANA,
				Vector2(620.0 + index * 1220.0, 286.0) + preview_offset,
				Vector2(0.936, 0.936),
				Color(0.72, 0.86, 1.0, 0.72)
			)
	if show_ships:
		var fleet := [
			[Vector2(-230, 390), 0.64, 0],
			[Vector2(150, 438), 0.44, 1],
			[Vector2(720, 418), 0.52, 3],
			[Vector2(4350, 353), 0.72, 2],
			[Vector2(5880, 418), 0.52, 3],
		]
		var frame_width := float(SHIP_SHEET.get_width()) / 4.0
		for entry in fleet:
			var target_size := Vector2(frame_width, float(SHIP_SHEET.get_height())) * float(entry[1])
			var target := Rect2(entry[0] + preview_offset - target_size * 0.5, target_size)
			var source := Rect2(frame_width * int(entry[2]), 0.0, frame_width, float(SHIP_SHEET.get_height()))
			draw_texture_rect_region(SHIP_SHEET, target, source, Color(0.66, 0.82, 0.95, 0.72))
	if show_fog:
		for index in 5:
			_draw_scaled_texture(
				LAGOON_FOG,
				Vector2(360.0 + index * 1420.0, 430.0) + preview_offset,
				Vector2(0.78, 0.78),
				Color(0.72, 0.85, 1.0, 0.46)
			)


func _draw_scaled_texture(texture: Texture2D, center: Vector2, scale_value: Vector2, tint: Color) -> void:
	var size := texture.get_size() * scale_value
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, tint)
