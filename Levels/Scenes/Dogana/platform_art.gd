extends Node2D

@export var art_profile: DoganaArtProfile = preload("res://Levels/Scenes/Dogana/dogana_art_profile.tres")


func _ready() -> void:
	add_to_group("dogana_generated_platform_art")
	z_index = -1

	# Atto I: approdo tranquillo, primo combattimento e salita sulla Dogana.
	_add_ledge(Rect2(15, 460, 1010, 96), 0.78)
	_add_ledge(Rect2(1190, 485, 790, 110), 0.82)
	_add_central_wedge()
	for rect in [
		Rect2(2165, 396, 190, 28),
		Rect2(2535, 166, 190, 28),
		Rect2(2905, 396, 190, 28),
	]:
		_add_ledge(rect, 1.0)

	# Atto II: percorso sul canale, torre e arena conclusiva.
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
		_add_ledge(rect, 0.95)
	_add_ledge(Rect2(4620, 485, 1120, 110), 0.8)

	# Le stanze segrete condividono lo stesso linguaggio visivo.
	_add_ledge(Rect2(1200, 632, 760, 36), 0.5)
	_add_ledge(Rect2(1200, 832, 760, 36), 0.5)
	# Discesa visibile sul lato destro del muro segreto: il giocatore può
	# scendere dal cuneo, atterrare e colpire la parete dall'esterno.
	_add_ledge(Rect2(1975, 686, 190, 28), 0.72)
	_add_ledge(Rect2(1905, 806, 190, 28), 0.72)
	_add_ledge(Rect2(3615, 20, 430, 30), 0.48)
	_add_ledge(Rect2(3615, 235, 430, 30), 0.48)


func _add_ledge(rect: Rect2, depth_scale: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = art_profile.walkable_platform
	sprite.centered = false
	sprite.position = rect.position
	var scale_x := rect.size.x / float(art_profile.walkable_platform.get_width())
	sprite.scale = Vector2(scale_x, scale_x * depth_scale)
	sprite.modulate = Color(0.78, 0.84, 0.82, 1.0)
	sprite.set_meta("walkable_rect", rect)
	add_child(sprite)


func _add_central_wedge() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "CentralDoganaWedgeArt"
	sprite.texture = art_profile.central_wedge
	sprite.centered = false
	sprite.position = Vector2(1980, 148)
	sprite.modulate = Color(0.72, 0.78, 0.76, 1.0)
	add_child(sprite)
