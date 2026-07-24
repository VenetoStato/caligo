extends Node


func _ready() -> void:
	for path in [
		"res://game_menu.tscn",
		"res://UI/AchievementsUI.tscn",
		"res://UI/end_game_screen.tscn",
	]:
		var packed := load(path) as PackedScene
		var overlay := packed.instantiate()
		add_child(overlay)
		await get_tree().process_frame
		if overlay.has_method("_apply_responsive_layout"):
			overlay.call("_apply_responsive_layout")
		await get_tree().process_frame
		if not _overlay_fits(overlay, path):
			push_error("Responsive overlay exceeds viewport: " + path)
			get_tree().quit(1)
			return
		remove_child(overlay)
		overlay.queue_free()
		await get_tree().process_frame
	print("CALIGO_RESPONSIVE_OVERLAYS: menu, achievements and end screen fit viewport")
	get_tree().quit(0)


func _overlay_fits(overlay: Node, path: String) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	if path.ends_with("game_menu.tscn"):
		var panel := overlay.get("panel") as Control
		return panel != null and panel.size.x <= viewport_size.x + 1.0 and panel.size.y <= viewport_size.y + 1.0
	if path.ends_with("AchievementsUI.tscn"):
		var achievements := overlay.get("_container") as Control
		return achievements != null and achievements.custom_minimum_size.x <= viewport_size.x + 1.0
	var end_panel := overlay.get("_panel") as Control
	return (
		end_panel != null
		and end_panel.custom_minimum_size.x <= viewport_size.x + 1.0
		and end_panel.custom_minimum_size.y <= viewport_size.y + 1.0
	)
