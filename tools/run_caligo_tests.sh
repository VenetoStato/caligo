#!/usr/bin/env bash
# Linux/macOS equivalent of run_caligo_tests.ps1: headless tests, prints OK/FAIL.
# GODOT=/path/to/godot tools/run_caligo_tests.sh [--full]
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-godot}"
cd "$root"

echo "=== IMPORT ==="
"$godot" --headless --path "$root" --import >/dev/null 2>&1
echo "=== PARSE ==="
parse="$("$godot" --headless --path "$root" --quit-after 1 2>&1)"
if grep -qE "Parse Error|Failed to load script" <<<"$parse"; then
  echo "PARSE_FAIL"; echo "$parse"; exit 1
fi
echo "PARSE_OK"

# kind path token timeout_s
tests=(
  "script res://tests/smoke_test.gd CALIGO_SMOKE_OK 45"
  "script res://tests/artist_drop_pipeline_test.gd CALIGO_ARTIST_DROP_OK 20"
  "script res://tests/enemy_art_kit_test.gd CALIGO_ENEMY_ART_KIT_OK 30"
  "script res://tests/fishing_reentry_reel_test.gd FISHING_REENTRY_REEL_TEST_OK 30"
  "script res://tests/fishing_attract_swim_test.gd FISHING_ATTRACT_SWIM_TEST_OK 30"
  "scene res://tests/player_jump_test.tscn CALIGO_JUMP_TEST 30"
  "scene res://tests/pogo_bounce_test.tscn CALIGO_POGO_BOUNCE_OK 30"
  "scene res://tests/boss_lamp_aim_test.tscn CALIGO_BOSS_LAMP_AIM_OK 30"
  "scene res://tests/guided_tutorial_geometry_test.tscn CALIGO_GUIDED_TUTORIAL 90"
  "scene res://tests/dogana_section_tour_test.tscn CALIGO_SECTION_TOUR_OK 120"
  "scene res://tests/dogana_zone_coherence_test.tscn CALIGO_ZONE_COHERENCE_OK 120"
  "scene res://tests/dogana_artist_pipeline_test.tscn CALIGO_ARTIST_PIPELINE 180"
  "scene res://tests/dogana_ai_systems_tour_test.tscn CALIGO_AI_SYSTEMS_TOUR_OK 180"
  "scene res://tests/boss_fight_test.tscn CALIGO_BOSS_FIGHT_OK 180"
)
if [[ "${1:-}" == "--full" ]]; then
  tests+=(
    "scene res://tests/dogana_gameplay_test.tscn CALIGO_DOGANA_TEST 180"
    "scene res://tests/enemy_archetype_test.tscn CALIGO_ENEMY_ARCHETYPES 90"
    "scene res://tests/enemy_collision_test.tscn CALIGO_ENEMY_COLLISION_TEST 60"
    "scene res://tests/dogana_interaction_matrix_test.tscn CALIGO_INTERACTION_MATRIX_OK 120"
    "scene res://tests/fishing_cast_test.tscn CALIGO_FISHING_CAST 90"
    "scene res://tests/fishing_health_test.tscn CALIGO_FISHING_TEST 60"
    "scene res://tests/fish_natural_movement_test.tscn CALIGO_FISH_NATURAL_TEST 60"
    "scene res://tests/player_water_test.tscn CALIGO_PLAYER_WATER_TEST 60"
  )
fi

fail=0
mkdir -p "$root/tmp/test-logs"
for t in "${tests[@]}"; do
  read -r kind path token timeout_s <<<"$t"
  log="$root/tmp/test-logs/$(basename "$path").log"
  if [[ $kind == script ]]; then
    timeout "$timeout_s" "$godot" --headless --path "$root" -s "$path" >"$log" 2>&1
  else
    timeout "$timeout_s" "$godot" --headless --path "$root" "$path" >"$log" 2>&1
  fi
  if grep -q "$token" "$log" && ! grep -qE "${token}[_A-Z]*FAIL|SCRIPT ERROR" "$log"; then
    echo "OK   $path"
  else
    echo "FAIL $path  (log: $log)"; fail=1
  fi
done
exit $fail
