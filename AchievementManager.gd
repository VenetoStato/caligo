extends Node

# ===========================================
# ACHIEVEMENT MANAGER (autoload)
# ===========================================
# Traccia: Pesca 3 pesci | Trova i 3 leoni di San Marco
# Gli achievement si aggiornano a schermo tramite segnali

signal fish_caught_count_changed(count: int)
signal leoni_collected_changed(ids: Array)

const FISH_GOAL: int = 3
const LEONI_GOAL: int = 3
const LEONE_ID_PREFIX: String = "leone_san_marco"

var fish_caught_count: int = 0
var leoni_collected_ids: Array[String] = []

func add_fish_caught() -> void:
	fish_caught_count += 1
	fish_caught_count_changed.emit(fish_caught_count)

func add_leone_found(prop_id: String) -> void:
	if prop_id.is_empty():
		return
	if prop_id.to_lower().contains("leone") or LEONE_ID_PREFIX in prop_id.to_lower():
		if prop_id not in leoni_collected_ids:
			leoni_collected_ids.append(prop_id)
			leoni_collected_changed.emit(leoni_collected_ids.duplicate())

func is_fish_achievement_done() -> bool:
	return fish_caught_count >= FISH_GOAL

func is_leoni_achievement_done() -> bool:
	return leoni_collected_ids.size() >= LEONI_GOAL

func get_fish_progress() -> String:
	return "%d / %d" % [fish_caught_count, FISH_GOAL]

func get_leoni_progress() -> String:
	return "%d / %d" % [leoni_collected_ids.size(), LEONI_GOAL]
