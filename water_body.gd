extends Area2D

# Sistema acqua dinamica - versione originale tutorial convertita per Godot 4
# Basato su: C:\Users\Utente\Downloads\Water_Tutorial\Water_Tutorial
# Adattato per Area2D invece di Node2D

@export var k: float = 0.015  # spring factor
@export var d: float = 0.03  # dampening factor
@export var spread: float = 0.2  # spread factor
@export var distance_between_springs: float = 32.0  # distanza tra spring
@export var spring_number: int = 6  # numero di spring
@export var depth: float = 1000.0  # profondità acqua
@export var border_thickness: float = 1.1  # spessore bordo

var springs: Array[Node2D] = []
var passes: int = 12
var target_height: float = 0.0
var bottom: float = 0.0

var water_polygon: Polygon2D = null
var water_border: Path2D = null
var collision_polygon: CollisionPolygon2D = null

# Buoyancy system
var bodies_in_water: Array[Node2D] = []
@export var player_buoyancy_force: float = 800.0  # Forza verso l'alto per il player
@export var player_gravity_reduction: float = 0.3  # Riduzione gravità player (0.3 = 70% di gravità normale)
@export var rigidbody_gravity_reduction: float = 0.1  # Riduzione gravità per RigidBody (0.1 = 90% di gravità normale)

# Fish spawning
@export var fish_scene: PackedScene = null
@export var fish_count: int = 5  # Numero di pesci da spawnare

func _ready():
	# Trova CollisionPolygon2D
	collision_polygon = get_node_or_null("CollisionPolygon2D")
	if collision_polygon == null:
		push_error("Water_Body: CollisionPolygon2D non trovato!")
		return
	
	var polygon_local = collision_polygon.polygon
	if polygon_local.size() < 4:
		push_error("Water_Body: CollisionPolygon2D deve avere almeno 4 punti!")
		return
	
	# Converti i punti in coordinate locali all'Area2D (considerando posizione e scale del CollisionPolygon2D)
	var polygon_points: Array[Vector2] = []
	for point in polygon_local:
		# Applica scale e posizione del CollisionPolygon2D
		var transformed_point = point * collision_polygon.scale + collision_polygon.position
		polygon_points.append(transformed_point)
	
	# Trova i due punti più in alto (superficie dell'acqua)
	# Ordiniamo per Y (i più in alto hanno Y minore)
	var sorted_by_y = polygon_points.duplicate()
	sorted_by_y.sort_custom(func(a, b): return a.y < b.y)
	
	# Prendi i due punti più in alto
	var top_points: Array[Vector2] = []
	for i in range(min(2, sorted_by_y.size())):
		top_points.append(sorted_by_y[i])
	
	# Se abbiamo solo un punto in alto, cerca i due con Y più simile
	if top_points.size() < 2:
		# Cerca i due punti con Y più bassa (più in alto)
		var min_y = sorted_by_y[0].y
		var tolerance = 5.0  # tolleranza per considerare punti alla stessa altezza
		for point in polygon_points:
			if abs(point.y - min_y) <= tolerance and not top_points.has(point):
				top_points.append(point)
				if top_points.size() >= 2:
					break
	
	# Se ancora non abbiamo 2 punti, usa i primi due del polygon
	if top_points.size() < 2:
		top_points = [polygon_points[0], polygon_points[1]]
	
	# Determina left e right
	var top_left: Vector2
	var top_right: Vector2
	if top_points[0].x <= top_points[1].x:
		top_left = top_points[0]
		top_right = top_points[1]
	else:
		top_left = top_points[1]
		top_right = top_points[0]
	
	# Calcola lunghezza superficie
	var surface_width = top_right.distance_to(top_left)
	var actual_spring_number = max(2, min(int(surface_width / distance_between_springs) + 1, spring_number))
	
	# Calcola target_height (media Y dei punti superiori)
	target_height = (top_left.y + top_right.y) / 2.0
	bottom = target_height + depth
	
	print("Water_Body: top_left=", top_left, " top_right=", top_right, " target_height=", target_height)
	
	# Normalizza spread
	spread = spread / 1000.0
	
	# Crea Water_Polygon (come nel tutorial)
	water_polygon = Polygon2D.new()
	water_polygon.color = Color(0.2, 0.5, 0.8, 0.7)  # Più visibile
	water_polygon.z_index = 0  # Cambiato da -1 a 0 per essere visibile
	add_child(water_polygon)
	
	# Crea Water_Border (come nel tutorial)
	water_border = Path2D.new()
	var curve = Curve2D.new()
	water_border.curve = curve
	add_child(water_border)
	
	# Crea i spring (come nel tutorial originale)
	for i in range(actual_spring_number):
		var t = float(i) / float(actual_spring_number - 1) if actual_spring_number > 1 else 0.0
		var spring_pos = top_left.lerp(top_right, t)
		var x_position = spring_pos.x
		
		# Crea spring dinamicamente (come nel tutorial)
		var spring = _create_water_spring(x_position, spring_pos.y, i, distance_between_springs)
		add_child(spring)
		springs.append(spring)
		print("Water_Body: Spring ", i, " creato a posizione ", spring.position)
	
	# Collega segnali
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Assicurati che monitoring sia attivo
	monitoring = true
	
	# Spawn pesci nell'acqua (usa call_deferred con un piccolo delay per assicurarsi che il player sia pronto)
	await get_tree().process_frame
	await get_tree().process_frame  # Doppio frame per essere sicuri
	call_deferred("spawn_fish_in_water")
	
	print("Water_Body: Creati ", springs.size(), " springs")
	print("Water_Body: Area2D position = ", position)
	print("Water_Body: CollisionPolygon2D position = ", collision_polygon.position, " scale = ", collision_polygon.scale)

func _create_water_spring(x_pos: float, y_pos: float, id: int, width: float) -> Node2D:
	# Crea spring come nel tutorial originale
	var spring = Node2D.new()
	spring.name = "WaterSpring_" + str(id)
	spring.position = Vector2(x_pos, y_pos)
	
	# Aggiungi script
	var script = load("res://water_spring.gd")
	if script != null:
		spring.set_script(script)
	
	# Crea Area2D (come nel tutorial)
	var area = Area2D.new()
	area.name = "Area2D"
	spring.add_child(area)
	
	# Crea CollisionShape2D
	var collision = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	# Godot 4: usa size invece di extents
	rect_shape.size = Vector2(width, 20.0)
	collision.shape = rect_shape
	area.add_child(collision)
	
	# Collega segnale
	area.body_entered.connect(_on_spring_area_body_entered.bind(spring))
	
	# Inizializza (come nel tutorial)
	if spring.has_method("initialize"):
		spring.call("initialize", x_pos, id)
	
	# set_collision_width (come nel tutorial)
	if spring.has_method("set_collision_width"):
		spring.call("set_collision_width", width)
	
	# Collega splash signal (come nel tutorial)
	if spring.has_signal("splash"):
		spring.connect("splash", _on_spring_splash)
	
	return spring

func _physics_process(delta: float):
	if springs.size() == 0:
		return
	
	# Muove tutti i springs (come nel tutorial)
	for spring in springs:
		if spring != null and is_instance_valid(spring) and spring.has_method("water_update"):
			spring.call("water_update", k, d)
	
	# Propaga onde (come nel tutorial originale)
	var left_deltas = []
	var right_deltas = []
	
	for i in range(springs.size()):
		left_deltas.append(0.0)
		right_deltas.append(0.0)
	
	for j in range(passes):
		for i in range(springs.size()):
			if springs[i] == null or not is_instance_valid(springs[i]):
				continue
			
			# Spring a sinistra
			if i > 0 and springs[i-1] != null and is_instance_valid(springs[i-1]):
				left_deltas[i] = spread * (springs[i].height - springs[i-1].height)
				springs[i-1].velocity += left_deltas[i]
			
			# Spring a destra
			if i < springs.size() - 1 and springs[i+1] != null and is_instance_valid(springs[i+1]):
				right_deltas[i] = spread * (springs[i].height - springs[i+1].height)
				springs[i+1].velocity += right_deltas[i]
	
	# Aggiorna visualizzazione (come nel tutorial)
	_update_border()
	draw_water_body()
	
	# Applica buoyancy ai corpi in acqua
	apply_buoyancy(delta)

func draw_water_body():
	# Come nel tutorial originale
	if water_polygon == null or water_border == null:
		return
	
	var curve = water_border.curve
	if curve == null:
		return
	
	# Godot 4: get_baked_points() restituisce PackedVector2Array
	var points = curve.get_baked_points()
	if points.size() == 0:
		return
	
	var water_polygon_points = Array(points)
	
	# Aggiungi punti fondo (come nel tutorial)
	if water_polygon_points.size() > 0:
		var first_index = 0
		var last_index = water_polygon_points.size() - 1
		water_polygon_points.append(Vector2(water_polygon_points[last_index].x, bottom))
		water_polygon_points.append(Vector2(water_polygon_points[first_index].x, bottom))
	
	# Godot 4: PackedVector2Array invece di PoolVector2Array
	var polygon_array = PackedVector2Array(water_polygon_points)
	water_polygon.polygon = polygon_array
	water_polygon.uv = polygon_array

func _update_border():
	# Come nel tutorial originale
	if water_border == null or springs.size() == 0:
		return
	
	var curve = Curve2D.new()
	
	for spring in springs:
		if spring != null and is_instance_valid(spring):
			curve.add_point(spring.position)
	
	water_border.curve = curve
	# Nota: smooth() non esiste più in Godot 4, ma va bene così

func _on_spring_splash(index: int, speed: float):
	# Come nel tutorial originale
	if index >= 0 and index < springs.size():
		springs[index].velocity += speed

func _on_spring_area_body_entered(body: Node2D, spring: Node2D):
	if spring != null and is_instance_valid(spring) and spring.has_method("_on_Area2D_body_entered"):
		spring.call("_on_Area2D_body_entered", body)

func _on_body_entered(body: Node2D):
	if body == null:
		return
	
	# Aggiungi alla lista dei corpi in acqua
	if body not in bodies_in_water:
		bodies_in_water.append(body)
		print("Water_Body: Body entrato in acqua: ", body.name, " (tipo: ", body.get_class(), ")")
	
	# Chiama in_water() se il body ha questo metodo
	if body.has_method("in_water"):
		body.call("in_water")
	
	# Se è un Node2D, controlla se ha un RigidBody2D figlio (come la pastura)
	if body is Node2D:
		var rigid_child = body.find_child("RigidBody2D", true, false)
		if rigid_child != null and rigid_child is RigidBody2D:
			if rigid_child not in bodies_in_water:
				bodies_in_water.append(rigid_child)
				print("Water_Body: RigidBody2D figlio trovato: ", rigid_child.name)

func _on_body_exited(body: Node2D):
	if body == null:
		return
	
	# Rimuovi dalla lista
	var index = bodies_in_water.find(body)
	if index >= 0:
		bodies_in_water.remove_at(index)
		print("Water_Body: Body uscito dall'acqua: ", body.name)
	
	# Chiama exit_water() se il body ha questo metodo
	if body.has_method("exit_water"):
		body.call("exit_water")

func apply_buoyancy(delta: float):
	# Rimuovi corpi non validi
	bodies_in_water = bodies_in_water.filter(func(b): return b != null and is_instance_valid(b))
	
	for body in bodies_in_water:
		if body == null or not is_instance_valid(body):
			continue
		
		# Verifica se il body è ancora dentro l'acqua (controllo posizione Y)
		var body_y = body.global_position.y
		var body_x = body.global_position.x
		
		# Trova il spring più vicino per determinare la superficie dell'acqua
		var water_surface_y = global_position.y + target_height
		if springs.size() > 0:
			# Trova il spring più vicino al body
			var closest_spring = springs[0]
			var min_dist = abs(springs[0].global_position.x - body_x)
			for spring in springs:
				if spring != null and is_instance_valid(spring):
					var dist = abs(spring.global_position.x - body_x)
					if dist < min_dist:
						min_dist = dist
						closest_spring = spring
			
			# Usa la posizione Y del spring più vicino come superficie
			if closest_spring != null and is_instance_valid(closest_spring):
				water_surface_y = closest_spring.global_position.y
		
		# Se il body è sopra la superficie, non applicare buoyancy
		if body_y < water_surface_y - 10:  # -10 per tolleranza
			continue
		
		# CharacterBody2D (Player) - applica buoyancy e riduci gravità
		if body is CharacterBody2D:
			var char_body = body as CharacterBody2D
			
			# Calcola quanto del body è immerso
			var submerged_depth = max(0.0, body_y - water_surface_y)
			var buoyancy_multiplier = 1.0 + (submerged_depth / 50.0)  # Più è immerso, più galleggia
			
			# Applica forza di galleggiamento (verso l'alto)
			char_body.velocity.y -= player_buoyancy_force * buoyancy_multiplier * delta
			
			# Riduci la gravità applicata
			# Nota: la gravità viene applicata nel player_controller.gd, quindi dobbiamo comunicare che siamo in acqua
			if char_body.has_method("set_in_water"):
				char_body.call("set_in_water", true, player_gravity_reduction)
		
		# RigidBody2D (Pastura, etc.) - riduci gravità
		elif body is RigidBody2D:
			var rigid_body = body as RigidBody2D
			
			# Riduci la gravità applicata
			# In Godot 4, la gravità viene applicata automaticamente, quindi dobbiamo applicare una forza contraria
			var gravity_scale = rigid_body.gravity_scale
			var gravity_force = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0) * gravity_scale
			var reduced_gravity = gravity_force * rigidbody_gravity_reduction
			
			# Applica una forza verso l'alto per compensare la gravità (90% di riduzione)
			rigid_body.apply_central_force(Vector2(0, -gravity_force * 0.9))
			
			# Aggiungi resistenza all'acqua
			rigid_body.linear_velocity *= 0.98
			
			# Comunica al parent Node2D che è in acqua (se esiste)
			var parent = rigid_body.get_parent()
			if parent != null and parent.has_method("set_in_water"):
				parent.call("set_in_water", true)

func spawn_fish_in_water():
	# Verifica che collision_polygon sia stato inizializzato
	if collision_polygon == null:
		print("Water_Body: collision_polygon è null, non posso spawnare pesci")
		return
	
	if fish_scene == null:
		# Prova a caricare la scena del pesce dal percorso standard
		fish_scene = load("res://fish.tscn") as PackedScene
		if fish_scene == null:
			print("Water_Body: fish_scene non trovato! I pesci non verranno spawnati.")
			return
	
	# Trova il player (CharacterBody2D) nella scena
	var player = null
	var scene = get_tree().current_scene
	if scene != null:
		# Prima prova con il gruppo
		player = get_tree().get_first_node_in_group("player")
		
		# Se non trovato, cerca tutti i CharacterBody2D nella scena (ricorsivamente)
		if player == null:
			player = _find_character_body2d(scene)
		
		# Se ancora non trovato, cerca direttamente nei figli della scena
		if player == null:
			for child in scene.get_children():
				if child is CharacterBody2D:
					player = child
					print("Water_Body: Trovato CharacterBody2D nei figli diretti: ", child.name)
					break
	
	var spawn_center: Vector2
	var spawn_radius: float = 200.0  # Raggio intorno al player
	
	if player != null:
		spawn_center = player.global_position
		print("Water_Body: Player trovato a: ", spawn_center, " (nome: ", player.name, ")")
	else:
		# Fallback: usa il centro dell'area acqua
		var polygon_local = collision_polygon.polygon
		if polygon_local.size() < 4:
			print("Water_Body: Polygon ha meno di 4 punti")
			return
		
		var min_x = INF
		var max_x = -INF
		var min_y = INF
		var max_y = -INF
		
		var cp = collision_polygon
		for point in polygon_local:
			var transformed_point = point * cp.scale + cp.position
			var global_point = to_global(transformed_point)
			min_x = min(min_x, global_point.x)
			max_x = max(max_x, global_point.x)
			min_y = min(min_y, global_point.y)
			max_y = max(max_y, global_point.y)
		
		spawn_center = Vector2((min_x + max_x) / 2, (min_y + max_y) / 2)
		spawn_radius = max((max_x - min_x) / 2, (max_y - min_y) / 2)
		print("Water_Body: Player non trovato, uso centro acqua: ", spawn_center)
	
	# Spawna pesci direttamente a lato del player (usa call_deferred per evitare errori durante il setup)
	if scene == null:
		return
	
	if player == null:
		print("Water_Body: Player non trovato, non posso spawnare pesci")
		return
	
	# Spawna pesci nell'acqua (dentro il polygon)
	for i in range(fish_count):
		var fish = fish_scene.instantiate()
		if fish == null:
			continue
		
		# Calcola posizione casuale dentro l'area dell'acqua
		var fish_pos: Vector2
		
		if collision_polygon != null:
			var polygon_local = collision_polygon.polygon
			var cp = collision_polygon
			
			# Trova i limiti dell'area
			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF
			
			for point in polygon_local:
				var transformed_point = point * cp.scale + cp.position
				var global_point = to_global(transformed_point)
				min_x = min(min_x, global_point.x)
				max_x = max(max_x, global_point.x)
				min_y = min(min_y, global_point.y)
				max_y = max(max_y, global_point.y)
			
			# Spawna casualmente dentro l'area (più in basso, non in superficie)
			var random_x = randf_range(min_x + 20, max_x - 20)
			var random_y = randf_range(min_y + (max_y - min_y) * 0.3, max_y - 20)
			fish_pos = Vector2(random_x, random_y)
		else:
			# Fallback: spawna vicino al player
			fish_pos = spawn_center
			fish_pos.x += randf_range(-100, 100)
			fish_pos.y += randf_range(-50, 50)
		
		# MODIFICA: Riduci la scala del pesce (10 volte più piccolo = 0.01)
		fish.scale = Vector2(0.01, 0.01)
		
		fish.global_position = fish_pos
		# Usa call_deferred per aggiungere il pesce dopo che il setup è completato
		call_deferred("_add_fish_to_scene", fish, scene)
		
		print("Water_Body: Pesce ", i, " spawnato a: ", fish_pos, " (nell'acqua) scala: 0.01")

func _find_character_body2d(node: Node) -> CharacterBody2D:
	# Cerca ricorsivamente il CharacterBody2D
	if node is CharacterBody2D:
		print("Water_Body: Trovato CharacterBody2D ricorsivamente: ", node.name)
		return node as CharacterBody2D
	
	for child in node.get_children():
		var found = _find_character_body2d(child)
		if found != null:
			return found
	
	return null

func _add_fish_to_scene(fish: Node, scene: Node):
	# Helper function per aggiungere il pesce alla scena in modo sicuro
	if fish != null and scene != null and is_instance_valid(fish) and is_instance_valid(scene):
		scene.add_child(fish)
