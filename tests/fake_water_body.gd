extends Node2D
## Fake water for isolated fishing tests.

var target_height: float = 0.0
var bounds: Rect2 = Rect2(0, 500, 800, 300)


func get_water_bounds_global_rect() -> Rect2:
	return bounds
