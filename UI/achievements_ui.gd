extends CanvasLayer

# ===========================================
# ACHIEVEMENTS UI - Mostra a schermo gli obiettivi
# ===========================================
# Pesca 3 pesci | Trova i 3 leoni di San Marco

@export var anchor: Vector2 = Vector2(0.02, 0.02)
@export var font_size: int = 24
@export var title_font_size: int = 20
@export var color_pending: Color = Color(0.75, 0.75, 0.8, 0.95)
@export var color_done: Color = Color(0.25, 0.85, 0.45, 1.0)
@export var panel_bg: Color = Color(0.06, 0.06, 0.12, 0.92)
@export var panel_border: Color = Color(0.35, 0.55, 0.75, 0.9)

var _fish_label: Label = null
var _leoni_label: Label = null
var _container: PanelContainer = null
var _title_label: Label = null

func _ready():
	layer = 5
	_build_ui()
	var am = get_node_or_null("/root/AchievementManager")
	if am != null:
		if am.fish_caught_count_changed.is_connected(_on_fish_changed) == false:
			am.fish_caught_count_changed.connect(_on_fish_changed)
		if am.leoni_collected_changed.is_connected(_on_leoni_changed) == false:
			am.leoni_collected_changed.connect(_on_leoni_changed)
	_update_labels()

func _build_ui():
	_container = PanelContainer.new()
	_container.name = "AchievementsPanel"
	_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_container.set_anchor(SIDE_LEFT, anchor.x)
	_container.set_anchor(SIDE_TOP, anchor.y)
	_container.set_offset(SIDE_LEFT, 16)
	_container.set_offset(SIDE_TOP, 16)
	_container.set_custom_minimum_size(Vector2(380, 100))
	var style = StyleBoxFlat.new()
	style.bg_color = panel_bg
	style.border_color = panel_border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	_container.add_theme_stylebox_override("panel", style)
	add_child(_container)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_container.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Obiettivi"
	_title_label.add_theme_font_size_override("font_size", title_font_size)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 1))
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_title_label)

	_fish_label = Label.new()
	_fish_label.name = "FishAchievement"
	_fish_label.size = Vector2(340, 32)
	_fish_label.add_theme_font_size_override("font_size", font_size)
	_fish_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_fish_label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(_fish_label)

	_leoni_label = Label.new()
	_leoni_label.name = "LeoniAchievement"
	_leoni_label.size = Vector2(340, 32)
	_leoni_label.add_theme_font_size_override("font_size", font_size)
	_leoni_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_leoni_label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(_leoni_label)

func _on_fish_changed(_count: int):
	_update_labels()

func _on_leoni_changed(_ids: Array):
	_update_labels()

func _update_labels():
	if _fish_label == null or _leoni_label == null:
		return
	var am = get_node_or_null("/root/AchievementManager")
	var fish_done: bool = am.is_fish_achievement_done() if am else false
	var leoni_done: bool = am.is_leoni_achievement_done() if am else false
	var fish_progress: String = am.get_fish_progress() if am else "0 / 3"
	var leoni_progress: String = am.get_leoni_progress() if am else "0 / 3"
	_fish_label.text = ("✓ " if fish_done else "○ ") + "Pesca 3 pesci  —  " + fish_progress
	_fish_label.add_theme_color_override("font_color", color_done if fish_done else color_pending)
	_leoni_label.text = ("✓ " if leoni_done else "○ ") + "Trova i 3 leoni di San Marco  —  " + leoni_progress
	_leoni_label.add_theme_color_override("font_color", color_done if leoni_done else color_pending)
