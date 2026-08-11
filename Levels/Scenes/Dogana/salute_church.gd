extends Node2D
## Interior stylizzato di Santa Maria della Salute (Longhena):
## pianta ottagonale, cupola, pilastri e nartece.
## La boss fight vive nella navata; Fortuna resta la punta a ovest dell'ingresso.

@export var center := Vector2(5180, 420)
@export var nave_radius := 420.0


func _ready() -> void:
	add_to_group("dogana_salute_church")
	z_index = -3
	_build_dome_silhouette()
	_build_octagon_floor()
	_build_pillars()
	_build_apse_altar()
	_build_entrance_portal()
	_build_side_chapels()
	_label_space()


func _build_dome_silhouette() -> void:
	var dome := Polygon2D.new()
	dome.name = "DomeSilhouette"
	dome.z_index = -5
	dome.color = Color(0.14, 0.16, 0.18, 0.55)
	var pts := PackedVector2Array()
	# Cupola maggiore + lanterna (profilo Longhena semplificato).
	for i in 25:
		var t := float(i) / 24.0
		var ang := PI + t * PI
		pts.append(center + Vector2(cos(ang) * 520.0, sin(ang) * 340.0 - 120.0))
	pts.append(center + Vector2(0, -520))
	dome.polygon = pts
	add_child(dome)

	var ribs := Line2D.new()
	ribs.name = "DomeRibs"
	ribs.z_index = -4
	ribs.width = 2.2
	ribs.default_color = Color(0.72, 0.62, 0.38, 0.35)
	ribs.points = PackedVector2Array([
		center + Vector2(-380, -40),
		center + Vector2(0, -480),
		center + Vector2(380, -40),
		center + Vector2(0, -480),
		center + Vector2(-220, 40),
		center + Vector2(0, -480),
		center + Vector2(220, 40),
	])
	add_child(ribs)

	var lantern := Polygon2D.new()
	lantern.name = "Lantern"
	lantern.z_index = -4
	lantern.color = Color(0.55, 0.48, 0.3, 0.55)
	lantern.polygon = PackedVector2Array([
		center + Vector2(-28, -500),
		center + Vector2(28, -500),
		center + Vector2(18, -560),
		center + Vector2(0, -590),
		center + Vector2(-18, -560),
	])
	add_child(lantern)


func _build_octagon_floor() -> void:
	var floor_poly := Polygon2D.new()
	floor_poly.name = "OctagonNave"
	floor_poly.z_index = -4
	floor_poly.color = Color(0.22, 0.2, 0.18, 0.42)
	var pts := PackedVector2Array()
	for i in 8:
		var ang := -PI * 0.5 + TAU * float(i) / 8.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * nave_radius + Vector2(0, 90))
	floor_poly.polygon = pts
	add_child(floor_poly)

	var trim := Line2D.new()
	trim.name = "MarbleTrim"
	trim.z_index = -3
	trim.width = 3.0
	trim.default_color = Color(0.78, 0.7, 0.48, 0.55)
	var loop := pts.duplicate()
	loop.append(pts[0])
	trim.points = loop
	add_child(trim)


func _build_pillars() -> void:
	var root := Node2D.new()
	root.name = "OctagonPillars"
	root.z_index = -2
	add_child(root)
	for i in 8:
		var ang := -PI * 0.5 + TAU * float(i) / 8.0
		# Saltiamo il lato ingresso ovest (porta dalla Dogana/Fortuna).
		if i == 6 or i == 7:
			continue
		var pos := center + Vector2(cos(ang), sin(ang)) * (nave_radius * 0.78) + Vector2(0, 40)
		var pillar := Polygon2D.new()
		pillar.name = "Pillar%d" % i
		pillar.color = Color(0.42, 0.4, 0.36, 0.78)
		pillar.polygon = PackedVector2Array([
			pos + Vector2(-16, -180),
			pos + Vector2(16, -180),
			pos + Vector2(22, 70),
			pos + Vector2(-22, 70),
		])
		root.add_child(pillar)
		var capital := Polygon2D.new()
		capital.color = Color(0.7, 0.62, 0.4, 0.7)
		capital.polygon = PackedVector2Array([
			pos + Vector2(-26, -190),
			pos + Vector2(26, -190),
			pos + Vector2(20, -168),
			pos + Vector2(-20, -168),
		])
		root.add_child(capital)


func _build_apse_altar() -> void:
	# Abside est: altare maggiore (non grace site — solo scenografia).
	var apse := Polygon2D.new()
	apse.name = "HighAltar"
	apse.z_index = -2
	apse.color = Color(0.55, 0.48, 0.32, 0.55)
	var base := center + Vector2(340, 40)
	apse.polygon = PackedVector2Array([
		base + Vector2(-70, 40),
		base + Vector2(70, 40),
		base + Vector2(55, -20),
		base + Vector2(-55, -20),
	])
	add_child(apse)
	var cross := Line2D.new()
	cross.name = "AltarCross"
	cross.z_index = -1
	cross.width = 3.0
	cross.default_color = Color(0.85, 0.75, 0.45, 0.75)
	cross.points = PackedVector2Array([
		base + Vector2(0, -20),
		base + Vector2(0, -95),
		base + Vector2(-22, -72),
		base + Vector2(22, -72),
	])
	add_child(cross)


func _build_entrance_portal() -> void:
	var portal := Node2D.new()
	portal.name = "NarthexPortal"
	portal.z_index = -1
	add_child(portal)
	var arch := Line2D.new()
	arch.width = 5.0
	arch.default_color = Color(0.62, 0.55, 0.36, 0.7)
	var pts := PackedVector2Array()
	var hinge := Vector2(4580, 310)
	for i in 17:
		var t := float(i) / 16.0
		var ang := PI + t * PI
		pts.append(hinge + Vector2(cos(ang) * 70.0, sin(ang) * 210.0))
	arch.points = pts
	portal.add_child(arch)
	var lintel := Label.new()
	lintel.name = "PortalTitle"
	lintel.position = Vector2(4485, 40)
	lintel.size = Vector2(200, 28)
	lintel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lintel.text = "S. MARIA DELLA SALUTE"
	lintel.add_theme_font_size_override("font_size", 12)
	lintel.add_theme_color_override("font_color", Color(0.82, 0.72, 0.48, 0.78))
	portal.add_child(lintel)


func _build_side_chapels() -> void:
	# Cappelle laterali: piccoli ripiani/visuali coerenti con gli altari laterali.
	for side in [-1, 1]:
		var chapel := Polygon2D.new()
		chapel.name = "SideChapel%s" % ("N" if side < 0 else "S")
		chapel.z_index = -3
		chapel.color = Color(0.18, 0.17, 0.16, 0.5)
		var c := center + Vector2(40, side * 210)
		chapel.polygon = PackedVector2Array([
			c + Vector2(-90, -40),
			c + Vector2(90, -40),
			c + Vector2(110, 50),
			c + Vector2(-110, 50),
		])
		add_child(chapel)


func _label_space() -> void:
	var title := Label.new()
	title.name = "NaveTitle"
	title.z_index = -1
	title.position = center + Vector2(-160, -280)
	title.size = Vector2(320, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "NAVE DELLA SALUTE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.78, 0.68, 0.42, 0.55))
	add_child(title)
