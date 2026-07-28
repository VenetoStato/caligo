extends Node2D
## Arte pontili/passerelle: asse, tavole, pile, bordi. Più leggibile del solo stretch texture.

@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")

var _time := 0.0
var _ledges: Array[Dictionary] = []
var _mobile := false


func _ready() -> void:
	add_to_group("dogana_generated_platform_art")
	z_index = -1
	_mobile = OS.get_name() == "Android" or OS.has_feature("mobile")

	# Atto I: pontile lungo con varco di pesca.
	_add_ledge(Rect2(-435, 460, 700, 96), 0.78, true)
	_add_ledge(Rect2(395, 460, 630, 96), 0.78, true)

	_add_ledge(Rect2(1190, 485, 790, 110), 0.82, true)
	_add_central_wedge()
	for rect in [
		Rect2(2165, 396, 190, 28),
		Rect2(2535, 166, 190, 28),
		Rect2(2905, 396, 190, 28),
	]:
		_add_ledge(rect, 1.0, false)

	for rect in [
		Rect2(3265, 491, 190, 28),
		Rect2(3505, 411, 190, 28),
		Rect2(3735, 331, 190, 28),
		Rect2(4056, 521, 168, 28),
		Rect2(4206, 441, 168, 28),
		Rect2(4036, 361, 168, 28),
		Rect2(4206, 281, 168, 28),
		Rect2(4046, 201, 168, 28),
		Rect2(4206, 121, 168, 28),
		Rect2(4146, 41, 168, 28),
	]:
		_add_ledge(rect, 0.95, false)
	_add_ledge(Rect2(4620, 485, 1120, 110), 0.8, true)

	_add_ledge(Rect2(1200, 632, 760, 36), 0.5, false)
	_add_ledge(Rect2(1200, 832, 760, 36), 0.5, false)
	_add_ledge(Rect2(1975, 686, 190, 28), 0.72, false)
	_add_ledge(Rect2(1990, 746, 190, 28), 0.72, false)
	_add_ledge(Rect2(2000, 806, 190, 28), 0.72, false)
	_add_ledge(Rect2(3615, 20, 430, 30), 0.48, false)
	_add_ledge(Rect2(3615, 235, 430, 30), 0.48, false)

	_spawn_pier_props()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _add_ledge(rect: Rect2, depth_scale: float, is_pier: bool) -> void:
	# Sprite base (allineamento collisioni testato via walkable_rect).
	if art_profile and art_profile.walkable_platform:
		var sprite := Sprite2D.new()
		sprite.texture = art_profile.walkable_platform
		sprite.centered = false
		sprite.position = rect.position
		var scale_x := rect.size.x / float(art_profile.walkable_platform.get_width())
		sprite.scale = Vector2(scale_x, scale_x * depth_scale)
		sprite.modulate = Color(0.62, 0.7, 0.68, 0.55)
		sprite.z_index = -1
		sprite.set_meta("walkable_rect", rect)
		add_child(sprite)
	_ledges.append({"rect": rect, "pier": is_pier, "depth": depth_scale})


func _add_central_wedge() -> void:
	if art_profile == null or art_profile.central_wedge == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "CentralDoganaWedgeArt"
	sprite.texture = art_profile.central_wedge
	sprite.centered = false
	sprite.position = Vector2(1980, 148)
	sprite.modulate = Color(0.72, 0.78, 0.76, 1.0)
	add_child(sprite)


func _spawn_pier_props() -> void:
	# Lanterne / bandiere procedurali animate lungo i pontili.
	for spot in [
		Vector2(-200, 460), Vector2(120, 460), Vector2(520, 460), Vector2(860, 460),
		Vector2(1400, 485), Vector2(1750, 485), Vector2(4800, 485), Vector2(5200, 485),
	]:
		_add_lantern(spot)


func _add_lantern(at: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = at + Vector2(0, -8)
	holder.z_index = 2
	holder.set_meta("lantern", true)
	add_child(holder)


func _draw() -> void:
	for ledge in _ledges:
		_draw_ledge_detail(ledge.rect, ledge.pier, float(ledge.depth))
	for child in get_children():
		if child is Node2D and child.has_meta("lantern"):
			_draw_lantern(child as Node2D)


func _draw_ledge_detail(rect: Rect2, is_pier: bool, _depth: float) -> void:
	var top := rect.position.y
	var left := rect.position.x
	var right := rect.end.x
	var bottom := rect.end.y
	var deck := Color(0.28, 0.32, 0.3, 0.92)
	var seam := Color(0.12, 0.14, 0.13, 0.55)
	var rim := Color(0.55, 0.62, 0.58, 0.7)
	var wet := Color(0.35, 0.55, 0.55, 0.18 + sin(_time * 1.4 + left * 0.01) * 0.06)

	# Piano superiore.
	draw_rect(Rect2(left, top, rect.size.x, maxf(10.0, rect.size.y * 0.38)), deck, true)
	draw_line(Vector2(left, top), Vector2(right, top), rim, 2.0, true)
	# Tavole.
	var plank_step := 22.0 if is_pier else 28.0
	var x := left + 8.0
	while x < right - 4.0:
		draw_line(Vector2(x, top + 2.0), Vector2(x, top + rect.size.y * 0.36), seam, 1.0, true)
		x += plank_step
	# Bordo umido animato (luce sulla linea d'acqua).
	draw_rect(Rect2(left, top + rect.size.y * 0.32, rect.size.x, 5.0), wet, true)
	# Spessore / ombra sotto.
	draw_rect(Rect2(left, top + rect.size.y * 0.38, rect.size.x, rect.size.y * 0.45), Color(0.12, 0.14, 0.14, 0.85), true)
	draw_line(Vector2(left, bottom - 2.0), Vector2(right, bottom - 2.0), Color(0.05, 0.06, 0.06, 0.7), 2.0, true)

	if not is_pier:
		return
	# Pali del pontile.
	var post_step := 96.0
	var px := left + 24.0
	while px < right - 16.0:
		var sway := sin(_time * 1.1 + px * 0.02) * 1.2
		draw_line(Vector2(px + sway, bottom), Vector2(px + sway, bottom + 48.0), Color(0.18, 0.2, 0.19, 0.9), 5.0, true)
		draw_line(Vector2(px + 7.0 + sway, bottom), Vector2(px + 7.0 + sway, bottom + 48.0), Color(0.1, 0.11, 0.11, 0.7), 2.0, true)
		# Anello / corda.
		draw_circle(Vector2(px + 3.0 + sway, bottom + 10.0), 3.0, Color(0.45, 0.4, 0.28, 0.7))
		px += post_step


func _draw_lantern(node: Node2D) -> void:
	var sway := sin(_time * 1.8 + node.position.x * 0.03) * 0.12
	var tip := node.position + Vector2(sin(sway) * 6.0, -46.0)
	var base := node.position
	draw_line(base, tip, Color(0.25, 0.22, 0.16, 0.85), 2.0, true)
	var glow := 0.45 + sin(_time * 3.2 + node.position.x) * 0.12
	draw_circle(tip, 7.0, Color(0.95, 0.72, 0.28, 0.2 + glow * 0.25))
	draw_circle(tip, 3.5, Color(1.0, 0.88, 0.45, 0.55 + glow * 0.35))
	# Bandierina.
	var flag := PackedVector2Array([
		tip + Vector2(2, 4),
		tip + Vector2(16 + sin(_time * 2.5 + node.position.x) * 3.0, 8),
		tip + Vector2(2, 14),
	])
	draw_colored_polygon(flag, Color(0.55, 0.18, 0.16, 0.75))
