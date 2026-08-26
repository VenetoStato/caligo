@tool
extends Node2D

@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")
## Mantiene il fronte dei pontili visibile nella viewport dell'editor, così gli
## oggetti di scena possono essere posizionati rispetto alla grafica reale.
@export var preview_in_editor := true:
	set(value):
		preview_in_editor = value
		if is_inside_tree():
			_rebuild_platform_art()

@export var show_platform_guides := true:
	set(value):
		show_platform_guides = value
		queue_redraw()

const SEA_LEVEL_Y := 565.0

var _top_padding := -1.0


## Prima riga di texture davvero piena. get_used_rect() non basta: bastano due
## pixel sporchi in cima a farla tornare zero.
func _texture_top_padding() -> float:
	if _top_padding >= 0.0:
		return _top_padding
	_top_padding = 0.0
	var texture: Texture2D = art_profile.walkable_platform
	if texture == null:
		return _top_padding
	var image := texture.get_image()
	if image == null:
		return _top_padding
	if image.is_compressed() and image.decompress() != OK:
		return _top_padding
	var width := image.get_width()
	var step := maxi(width / 96, 1)
	var samples := 0
	for x in range(0, width, step):
		samples += 1
	for y in mini(image.get_height(), 48):
		var solid := 0
		for x in range(0, width, step):
			if image.get_pixel(x, y).a > 0.35:
				solid += 1
		if solid > samples / 4:
			_top_padding = float(y)
			return _top_padding
	return _top_padding



func _ready() -> void:
	add_to_group("dogana_generated_platform_art")
	z_index = -1
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_rebuild_platform_art()
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_platform_guides:
		return
	# Guide volutamente editor-only: mostra piano calpestabile e bordo di
	# collisione anche quando la texture dipinta si confonde con il fondale.
	var platforms := [
		Rect2(-435, 460, 700, 96),
		Rect2(395, 460, 630, 96),
		Rect2(1190, 485, 915, 110),
		Rect2(2060, 485, 1200, 110),
		Rect2(3260, 485, 850, 110),
		Rect2(4110, 485, 510, 110),
		Rect2(4620, 485, 1120, 110),
	]
	for rect in platforms:
		draw_rect(rect, Color(0.22, 0.86, 0.78, 0.08), true)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.32, 1.0, 0.88, 0.9), 2.0)
		draw_line(Vector2(rect.position.x, rect.end.y), rect.end, Color(0.22, 0.68, 0.72, 0.45), 1.0)


func _rebuild_platform_art() -> void:
	_clear_generated_platform_art()
	if art_profile == null or art_profile.walkable_platform == null:
		push_warning("Dogana platform preview: missing walkable_platform texture.")
		return

	# Atto I: pontile lungo con varco di pesca (acqua visibile sotto, amo può passare).
	_add_ledge(Rect2(-435, 460, 700, 96), 0.78, 0.0)
	_add_ledge(Rect2(395, 460, 630, 96), 0.78, 0.04)

	# Quay continuo fino alla Salute. La Punta reale si legge lateralmente come
	# un fronte d'acqua unitario: niente scale di blocchi o ripiani sospesi.
	_add_ledge(Rect2(1190, 485, 915, 110), 0.82, 0.02)
	_add_ledge(Rect2(2060, 485, 1200, 110), 0.72, 0.03)
	_add_ledge(Rect2(3260, 485, 850, 110), 0.72, 0.02)
	_add_ledge(Rect2(4110, 485, 510, 110), 0.72, 0.025)
	_add_ledge(Rect2(4620, 485, 1120, 110), 0.8, 0.01)


func _clear_generated_platform_art() -> void:
	for child in get_children():
		if child.get_meta("generated_platform_preview", false):
			remove_child(child)
			child.queue_free()


func _add_ledge(rect: Rect2, depth_scale: float, wear: float) -> void:
	# AO sotto: dà peso e contatto a terra.
	var ao := Polygon2D.new()
	ao.set_meta("generated_platform_preview", true)
	ao.z_index = -1
	ao.polygon = PackedVector2Array([
		Vector2(rect.position.x + 6, rect.end.y - 2),
		Vector2(rect.end.x - 6, rect.end.y - 2),
		Vector2(rect.end.x - 18, rect.end.y + 16 + wear * 10.0),
		Vector2(rect.position.x + 18, rect.end.y + 16 + wear * 10.0),
	])
	ao.color = Color(0.015, 0.03, 0.035, 0.55)
	add_child(ao)

	var sprite := Sprite2D.new()
	sprite.set_meta("generated_platform_preview", true)
	sprite.texture = art_profile.walkable_platform
	sprite.centered = false
	# Usa solo il bordo superiore dell'asset. La vecchia sprite intera creava
	# enormi muri ripetuti che coprivano facciata, porte e silhouette laterale.
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		0.0,
		0.0,
		float(art_profile.walkable_platform.get_width()),
		minf(72.0, float(art_profile.walkable_platform.get_height()))
	)
	sprite.region_filter_clip_enabled = true
	var scale_x := rect.size.x / float(art_profile.walkable_platform.get_width())
	sprite.scale = Vector2(scale_x, clampf(depth_scale, 0.48, 0.82))
	# L'asset ha righe trasparenti in testa: senza compensarle la pietra
	# disegnata cade sotto la collisione e tutto cio' che vi poggia sembra
	# sospeso di qualche pixel.
	sprite.position = Vector2(
		rect.position.x, rect.position.y - _texture_top_padding() * sprite.scale.y
	)
	# Quasi naturale: lascia emergere muschio, metallo, barnacles del PNG.
	var shade := 0.9 - wear * 0.08
	sprite.modulate = Color(shade, shade + 0.02, shade + 0.01, 1.0)
	sprite.set_meta("walkable_rect", rect)
	# La collisione unica del fronte Dogana-Salute copre lo stesso bordo ma non
	# e' spezzata come i moduli artistici sostituibili.
	sprite.set_meta("continuous_waterfront_art", rect.position.x >= 2060.0)
	add_child(sprite)

	# Bordo umido / sale sulla camminata.
	var wet := Line2D.new()
	wet.set_meta("generated_platform_preview", true)
	wet.z_index = 1
	wet.width = 2.0
	wet.default_color = Color(0.62, 0.78, 0.74, 0.22 + wear * 0.1)
	wet.points = PackedVector2Array([
		Vector2(rect.position.x + 4, rect.position.y + 1),
		Vector2(rect.end.x - 4, rect.position.y + 1),
	])
	add_child(wet)

	# Specular corto intermittente (pietra bagnata).
	if rect.size.x > 160.0:
		var sheen := Polygon2D.new()
		sheen.set_meta("generated_platform_preview", true)
		sheen.z_index = 1
		var sx := rect.position.x + rect.size.x * (0.28 + wear)
		sheen.polygon = PackedVector2Array([
			Vector2(sx, rect.position.y + 1),
			Vector2(sx + 36, rect.position.y + 1),
			Vector2(sx + 30, rect.position.y + 4),
			Vector2(sx + 4, rect.position.y + 4),
		])
		sheen.color = Color(0.7, 0.88, 0.84, 0.12)
		add_child(sheen)

	# Nessun ripiano deve sembrare sospeso. Le banchine basse ricevono una
	# fondazione illustrata fino alla linea del mare; i balconi alti una mensola.
	if rect.position.y >= 450.0:
		_add_waterline_foundation(rect, wear)
	else:
		_add_facade_bracket(rect, wear)


func _add_waterline_foundation(rect: Rect2, wear: float) -> void:
	var source_h := float(art_profile.walkable_platform.get_height())
	var source_w := float(art_profile.walkable_platform.get_width())
	var top := rect.position.y + minf(38.0, rect.size.y * 0.42)
	var bottom := maxf(SEA_LEVEL_Y + 8.0, minf(rect.end.y, SEA_LEVEL_Y + 34.0))
	var height := bottom - top
	if height <= 4.0:
		return
	var foundation := Sprite2D.new()
	foundation.set_meta("generated_platform_preview", true)
	foundation.name = "WaterlineFoundation"
	foundation.z_index = -2
	foundation.texture = art_profile.walkable_platform
	foundation.centered = false
	foundation.region_enabled = true
	foundation.region_rect = Rect2(0.0, 72.0, source_w, maxf(source_h - 72.0, 1.0))
	foundation.region_filter_clip_enabled = true
	foundation.position = Vector2(rect.position.x, top)
	foundation.scale = Vector2(rect.size.x / source_w, height / maxf(source_h - 72.0, 1.0))
	var shade := 0.66 - wear * 0.08
	foundation.modulate = Color(shade, shade + 0.035, shade + 0.03, 0.98)
	foundation.add_to_group("dogana_waterline_foundation")
	foundation.set_meta("foundation_bottom_y", bottom)
	add_child(foundation)
	var contact := Line2D.new()
	contact.set_meta("generated_platform_preview", true)
	contact.z_index = -1
	contact.width = 3.0
	contact.default_color = Color(0.32, 0.62, 0.59, 0.24)
	contact.points = PackedVector2Array([Vector2(rect.position.x + 8.0, SEA_LEVEL_Y), Vector2(rect.end.x - 8.0, SEA_LEVEL_Y)])
	add_child(contact)


func _add_facade_bracket(rect: Rect2, wear: float) -> void:
	var source_w := float(art_profile.walkable_platform.get_width())
	var source_h := float(art_profile.walkable_platform.get_height())
	var bracket_width := clampf(rect.size.x * 0.34, 42.0, 76.0)
	var bracket_height := clampf(rect.size.x * 0.24, 34.0, 58.0)
	var bracket := Sprite2D.new()
	bracket.set_meta("generated_platform_preview", true)
	bracket.name = "FacadeBracket"
	bracket.z_index = -2
	bracket.texture = art_profile.walkable_platform
	bracket.centered = false
	bracket.region_enabled = true
	bracket.region_rect = Rect2(source_w * 0.36, 72.0, source_w * 0.28, maxf(source_h - 72.0, 1.0))
	bracket.region_filter_clip_enabled = true
	bracket.position = Vector2(rect.get_center().x - bracket_width * 0.5, rect.position.y + 13.0)
	bracket.scale = Vector2(bracket_width / (source_w * 0.28), bracket_height / maxf(source_h - 72.0, 1.0))
	var shade := 0.7 - wear * 0.06
	bracket.modulate = Color(shade, shade + 0.025, shade + 0.02, 0.96)
	bracket.add_to_group("dogana_facade_bracket")
	add_child(bracket)
