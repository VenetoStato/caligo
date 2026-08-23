extends Node


func _ready() -> void:
	var packed := load("res://UI/MobileControls.tscn") as PackedScene
	var controls := packed.instantiate()
	controls.set("force_preview", true)
	add_child(controls)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport_rect := get_viewport().get_visible_rect()
	var controls_to_check: Array[Control] = []
	for child in controls.get_children():
		if child is Control and child.visible:
			controls_to_check.append(child as Control)
	for control in controls_to_check:
		var rect := control.get_global_rect()
		if not viewport_rect.encloses(rect):
			push_error("Mobile control outside viewport: %s %s" % [control.name, rect])
			get_tree().quit(1)
			return
	for i in controls_to_check.size():
		for j in range(i + 1, controls_to_check.size()):
			if controls_to_check[i].get_global_rect().intersects(controls_to_check[j].get_global_rect()):
				push_error("Mobile controls overlap: %s / %s" % [controls_to_check[i].name, controls_to_check[j].name])
				get_tree().quit(1)
				return
	print("CALIGO_MOBILE_CONTROLS_OK")
	get_tree().quit(0)
