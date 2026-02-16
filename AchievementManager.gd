extends Node

# ===========================================
# ACHIEVEMENT MANAGER (autoload)
# ===========================================
# Traccia: Pesca 3 pesci | Trova i 3 leoni di San Marco
# Gli achievement si aggiornano a schermo tramite segnali
# Ogni avvio del gioco parte da 0 (nessun salvataggio obiettivi)

signal fish_caught_count_changed(count: int)
signal leoni_collected_changed(ids: Array)
signal game_completed(elapsed_sec: float)

const FISH_GOAL: int = 3
const LEONI_GOAL: int = 3
const LEONE_ID_PREFIX: String = "leone_san_marco"
const TIER_S_MAX_SEC: float = 120.0   # < 2:00 = S
const TIER_S_MINUS_MAX_SEC: float = 150.0  # < 2:30 = S-
const TIER_A_MAX_SEC: float = 180.0   # < 3:00 = A

var fish_caught_count: int = 0
var leoni_collected_ids: Array[String] = []
var game_start_time_sec: float = -1.0

func _ready() -> void:
	# Ogni riavvio: obiettivi da zero (non carichiamo da disco)
	fish_caught_count = 0
	leoni_collected_ids.clear()
	fish_caught_count_changed.emit(fish_caught_count)
	leoni_collected_changed.emit(leoni_collected_ids.duplicate())

func start_game_timer() -> void:
	game_start_time_sec = Time.get_ticks_msec() / 1000.0

func get_elapsed_time_sec() -> float:
	if game_start_time_sec < 0:
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - game_start_time_sec

func get_tier_for_time(sec: float) -> String:
	if sec <= TIER_S_MAX_SEC:
		return "S"
	if sec <= TIER_S_MINUS_MAX_SEC:
		return "S-"
	if sec <= TIER_A_MAX_SEC:
		return "A"
	return "B"

func _check_and_emit_game_completed() -> void:
	if is_fish_achievement_done() and is_leoni_achievement_done():
		game_completed.emit(get_elapsed_time_sec())

func add_fish_caught() -> void:
	fish_caught_count += 1
	fish_caught_count_changed.emit(fish_caught_count)
	_check_and_emit_game_completed()

func add_leone_found(prop_id: String) -> void:
	if prop_id.is_empty():
		return
	if not (prop_id.to_lower().contains("leone") or LEONE_ID_PREFIX in prop_id.to_lower()):
		return
	if leoni_collected_ids.size() >= LEONI_GOAL:
		return
	if prop_id not in leoni_collected_ids:
		leoni_collected_ids.append(prop_id)
	else:
		# Stesso prop_id su più leoni (es. tutti "leone_san_marco_1"): conta comunque fino a 3
		for i in range(1, LEONI_GOAL + 1):
			var candidate = LEONE_ID_PREFIX + "_" + str(i)
			if candidate not in leoni_collected_ids:
				leoni_collected_ids.append(candidate)
				break
	leoni_collected_changed.emit(leoni_collected_ids.duplicate())
	_check_and_emit_game_completed()

func is_fish_achievement_done() -> bool:
	return fish_caught_count >= FISH_GOAL

func is_leoni_achievement_done() -> bool:
	return leoni_collected_ids.size() >= LEONI_GOAL

func get_fish_progress() -> String:
	return "%d / %d" % [fish_caught_count, FISH_GOAL]

func get_leoni_progress() -> String:
	return "%d / %d" % [leoni_collected_ids.size(), LEONI_GOAL]

## Chiamato da "Ricomincia" nella schermata fine gioco: reset e reload
func reset_run() -> void:
	fish_caught_count = 0
	leoni_collected_ids.clear()
	game_start_time_sec = -1.0
	fish_caught_count_changed.emit(fish_caught_count)
	leoni_collected_changed.emit(leoni_collected_ids.duplicate())
