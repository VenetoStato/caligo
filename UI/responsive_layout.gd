class_name CaligoResponsiveLayout
extends RefCounted


static func viewport_size(node: Node) -> Vector2:
	if node == null or node.get_viewport() == null:
		return Vector2(1280, 720)
	return node.get_viewport().get_visible_rect().size


static func is_compact(size: Vector2) -> bool:
	return size.x < 900.0 or size.y < 620.0


static func ui_scale(size: Vector2) -> float:
	return clampf(minf(size.x / 1280.0, size.y / 720.0), 0.68, 1.15)


static func fitted_panel(size: Vector2, maximum: Vector2, margin := 24.0) -> Vector2:
	return Vector2(
		clampf(size.x - margin * 2.0, 280.0, maximum.x),
		clampf(size.y - margin * 2.0, 240.0, maximum.y)
	)
