extends Node2D

@onready var _player: CharacterBody2D = $Player
@onready var _water: Node = $Water

var _frame := 0
var _peak_wave := 0.0
var _entries := 0
var _was_in_water := false
var _strongest_bounce := 0.0
var _rain_ripple_seen := false
var _rain_ripple_peak := 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 82 and _frame <= 87 and _water.has_method("rain_impact_at"):
		_water.call("rain_impact_at", 470.0 + float(_frame - 82) * 18.0, 1.0)
	if _water.get_node_or_null("RainWaterRipple") != null:
		_rain_ripple_seen = true
	_rain_ripple_peak = maxi(_rain_ripple_peak, get_tree().get_nodes_in_group("water_rain_ripple").size())
	if "springs" in _water:
		for spring in _water.springs:
			_peak_wave = maxf(
				_peak_wave,
				absf(spring.position.y - float(spring.get("target_height")))
			)
	if _player.is_in_water and not _was_in_water:
		_entries += 1
		_strongest_bounce = minf(_strongest_bounce, _player.velocity.y)
	_was_in_water = _player.is_in_water

	if _frame < 110:
		return
	print("CALIGO_PLAYER_WATER_TEST: health %d, entries %d, bounce %.2f, peak wave %.2f px" % [
		_player.current_health,
		_entries,
		_strongest_bounce,
		_peak_wave,
	])
	if _entries < 1 or _player.current_health != maxi(0, _player.max_health - _entries):
		push_error("Every distinct water entry must remove one health point.")
		get_tree().quit(1)
		return
	if _strongest_bounce > -120.0:
		push_error("Water entry must bounce the player upward.")
		get_tree().quit(1)
		return
	if _peak_wave < 2.0:
		push_error("Player entry did not create a visible physical wave.")
		get_tree().quit(1)
		return
	if not _rain_ripple_seen:
		push_error("Rain impact did not create a visible surface ripple.")
		get_tree().quit(1)
		return
	if _rain_ripple_peak < 4:
		push_error("Consecutive rain drops were over-throttled instead of producing near 1:1 ripples.")
		get_tree().quit(1)
		return
	get_tree().quit(0)
