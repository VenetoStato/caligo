extends Node2D

@export var body_count := 18
@export var sample_frames := 240

var _started_usec: int
var _frames := 0
var _peak_displacement := 0.0
var _propagated_displacement := 0.0

@onready var _water: Node = $Water


func _ready() -> void:
	_spawn_bodies()
	_started_usec = Time.get_ticks_usec()
	_water.call_deferred("splash_at", 640.0, 320.0, 120.0)


func _physics_process(_delta: float) -> void:
	_frames += 1
	_measure_wave()
	if _frames < sample_frames:
		return
	var elapsed_ms := float(Time.get_ticks_usec() - _started_usec) / 1000.0
	var average_ms := elapsed_ms / float(sample_frames)
	print("CALIGO_WATER_BENCHMARK: %.3f ms/frame, peak %.2f px, propagated %.2f px, %d bodies, %d samples" % [
		average_ms,
		_peak_displacement,
		_propagated_displacement,
		body_count,
		sample_frames,
	])
	if _peak_displacement < 2.0 or _propagated_displacement < 0.1:
		push_error("Dynamic water did not produce and propagate a visible physical wave.")
		get_tree().quit(1)
		return
	get_tree().quit(0)


func _measure_wave() -> void:
	if not ("springs" in _water) or _water.springs.is_empty():
		return
	var center := floori(float(_water.springs.size()) * 0.5)
	for spring in _water.springs:
		_peak_displacement = maxf(
			_peak_displacement,
			absf(spring.position.y - float(spring.get("target_height")))
		)
	var propagated_index: int = mini(center + 7, _water.springs.size() - 1)
	var propagated: Node2D = _water.springs[propagated_index] as Node2D
	_propagated_displacement = maxf(
		_propagated_displacement,
		absf(propagated.position.y - float(propagated.get("target_height")))
	)


func _spawn_bodies() -> void:
	for index in body_count:
		var body := RigidBody2D.new()
		body.name = "BenchmarkBody%d" % index
		body.position = Vector2(150.0 + float(index % 9) * 115.0, 220.0 - float(index / 9) * 90.0)
		body.mass = 0.7 + float(index % 4) * 0.35
		body.collision_layer = 2
		body.collision_mask = 0
		body.linear_velocity = Vector2(randf_range(-90.0, 90.0), randf_range(40.0, 260.0))

		var shape := CircleShape2D.new()
		shape.radius = 10.0 + float(index % 3) * 3.0
		var collision := CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
