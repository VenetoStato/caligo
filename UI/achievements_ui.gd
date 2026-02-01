extends CanvasLayer

# ===========================================
# ACHIEVEMENTS UI - Mostra a schermo gli obiettivi
# ===========================================
# Pesca 3 pesci | Trova i 3 leoni di San Marco

@export var anchor: Vector2 = Vector2(0.02, 0.02)
@export var font_size: int = 18
@export var color_pending: Color = Color(0.7, 0.7, 0.7, 0.9)
@export var color_done: Color = Color(0.3, 0.9, 0.4, 1.0)

var _fish_label: Label = null
var _leoni_label: Label = null
var _container: Control = null

func _ready():
	layer = 5
	_build_ui()
	if AchievementManager:
		AchievementManager.fish_caught_count_changed.connect(_on_fish_changed)
		AchievementManager.leoni_collected_changed.connect(_on_leoni_changed)
	_update_labels()

func _build_ui():
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_container.set_anchor(SIDE_LEFT, anchor.x)
	_container.set_anchor(SIDE_TOP, anchor.y)
	_container.set_offset(SIDE_LEFT, 12)
	_container.set_offset(SIDE_TOP, 12)
	_container.set_custom_minimum_size(Vector2(280, 56))
	add_child(_container)

	_fish_label = Label.new()
	_fish_label.name = "FishAchievement"
	_fish_label.position = Vector2(0, 0)
	_fish_label.size = Vector2(260, 26)
	_fish_label.add_theme_font_size_override("font_size", font_size)
	_container.add_child(_fish_label)

	_leoni_label = Label.new()
	_leoni_label.name = "LeoniAchievement"
	_leoni_label.position = Vector2(0, 28)
	_leoni_label.size = Vector2(260, 26)
	_leoni_label.add_theme_font_size_override("font_size", font_size)
	_container.add_child(_leoni_label)

func _on_fish_changed(_count: int):
	_update_labels()

func _on_leoni_changed(_ids: Array):
	_update_labels()

func _update_labels():
	if _fish_label == null or _leoni_label == null:
		return
	var fish_done: bool = AchievementManager.is_fish_achievement_done() if AchievementManager else false
	var leoni_done: bool = AchievementManager.is_leoni_achievement_done() if AchievementManager else false
	var fish_progress: String = AchievementManager.get_fish_progress() if AchievementManager else "0 / 3"
	var leoni_progress: String = AchievementManager.get_leoni_progress() if AchievementManager else "0 / 3"
	_fish_label.text = ("[OK] " if fish_done else "[  ] ") + "Pesca 3 pesci  " + fish_progress
	_fish_label.add_theme_color_override("font_color", color_done if fish_done else color_pending)
	_leoni_label.text = ("[OK] " if leoni_done else "[  ] ") + "Trova i 3 leoni di San Marco  " + leoni_progress
	_leoni_label.add_theme_color_override("font_color", color_done if leoni_done else color_pending)
