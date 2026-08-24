# Esegue i test headless principali di Caligo e riporta OK/FAIL.
param(
    [switch]$LaunchGame,
    [switch]$Full
)

$ErrorActionPreference = "Stop"
$root = "C:\Users\user\caligo"
$godot = "C:\Users\user\tools\godot-4.5\Godot_v4.5-stable_win64_console.exe"
Set-Location $root

# Isola i log/cache del runner dall'editor Godot aperto: su Windows due processi
# che condividono user://logs possono causare un crash nativo prima del parse.
$testProfile = Join-Path $root "tmp\godot-test-profile"
$env:APPDATA = Join-Path $testProfile "appdata"
$env:LOCALAPPDATA = Join-Path $testProfile "localappdata"
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400

# Senza questo passaggio i test girano sulle texture gia' in cache: un asset
# ridisegnato risulta "verde" pur non essendo mai entrato nel gioco.
Write-Host "=== IMPORT ==="
& $godot --headless --path $root --import 2>&1 | Out-Null

Write-Host "=== PARSE ==="
$parse = & $godot --headless --path $root --quit-after 1 2>&1 | Out-String
if ($parse -match "Parse Error|Failed to load script") {
    Write-Host "PARSE_FAIL"
    $parse
    exit 1
}
Write-Host "PARSE_OK"

$tests = @(
    @{ kind = "script"; path = "res://tests/smoke_test.gd"; token = "CALIGO_SMOKE_OK"; timeout = 45000 },
    @{ kind = "script"; path = "res://tests/artist_drop_pipeline_test.gd"; token = "CALIGO_ARTIST_DROP_OK"; timeout = 20000 },
    @{ kind = "script"; path = "res://tests/enemy_art_kit_test.gd"; token = "CALIGO_ENEMY_ART_KIT_OK"; timeout = 30000 },
    @{ kind = "script"; path = "res://tests/fishing_reentry_reel_test.gd"; token = "FISHING_REENTRY_REEL_TEST_OK"; timeout = 30000 },
    @{ kind = "script"; path = "res://tests/fishing_attract_swim_test.gd"; token = "FISHING_ATTRACT_SWIM_TEST_OK"; timeout = 30000 },
    @{ kind = "scene"; path = "res://tests/player_jump_test.tscn"; token = "CALIGO_JUMP_TEST"; timeout = 30000 },
    @{ kind = "scene"; path = "res://tests/pogo_bounce_test.tscn"; token = "CALIGO_POGO_BOUNCE_OK"; timeout = 30000 },
    @{ kind = "scene"; path = "res://tests/boss_lamp_aim_test.tscn"; token = "CALIGO_BOSS_LAMP_AIM_OK"; timeout = 30000 },
    @{ kind = "scene"; path = "res://tests/guided_tutorial_geometry_test.tscn"; token = "CALIGO_GUIDED_TUTORIAL"; timeout = 90000 },
    @{ kind = "scene"; path = "res://tests/dogana_section_tour_test.tscn"; token = "CALIGO_SECTION_TOUR_OK"; timeout = 120000 },
    @{ kind = "scene"; path = "res://tests/dogana_zone_coherence_test.tscn"; token = "CALIGO_ZONE_COHERENCE_OK"; timeout = 120000 },
    @{ kind = "scene"; path = "res://tests/dogana_artist_pipeline_test.tscn"; token = "CALIGO_ARTIST_PIPELINE"; timeout = 180000 },
    @{ kind = "scene"; path = "res://tests/dogana_ai_systems_tour_test.tscn"; token = "CALIGO_AI_SYSTEMS_TOUR_OK"; timeout = 180000 },
    @{ kind = "scene"; path = "res://tests/boss_fight_test.tscn"; token = "CALIGO_BOSS_FIGHT_OK"; timeout = 180000 }
)

if ($Full) {
    $tests += @(
        @{ kind = "scene"; path = "res://tests/dogana_gameplay_test.tscn"; token = "CALIGO_DOGANA_TEST"; timeout = 180000 },
        @{ kind = "scene"; path = "res://tests/enemy_archetype_test.tscn"; token = "CALIGO_ENEMY_ARCHETYPES"; timeout = 90000 },
        @{ kind = "scene"; path = "res://tests/enemy_collision_test.tscn"; token = "CALIGO_ENEMY_COLLISION_TEST"; timeout = 60000 },
        @{ kind = "scene"; path = "res://tests/dogana_interaction_matrix_test.tscn"; token = "CALIGO_INTERACTION_MATRIX_OK"; timeout = 120000 },
        @{ kind = "scene"; path = "res://tests/fishing_cast_test.tscn"; token = "CALIGO_FISHING_CAST"; timeout = 90000 },
        @{ kind = "scene"; path = "res://tests/fishing_health_test.tscn"; token = "CALIGO_FISHING_TEST"; timeout = 60000 },
        @{ kind = "scene"; path = "res://tests/fish_natural_movement_test.tscn"; token = "CALIGO_FISH_NATURAL_TEST"; timeout = 60000 },
        @{ kind = "scene"; path = "res://tests/player_water_test.tscn"; token = "CALIGO_PLAYER_WATER_TEST"; timeout = 60000 },
        @{ kind = "scene"; path = "res://tests/palace_performance_test.tscn"; token = "CALIGO_PALACE_PERF"; timeout = 120000 },
        @{ kind = "scene"; path = "res://tests/responsive_overlay_test.tscn"; token = "CALIGO_RESPONSIVE_OVERLAYS"; timeout = 60000 },
        @{ kind = "scene"; path = "res://tests/mobile_controls_layout_test.tscn"; token = "CALIGO_MOBILE_CONTROLS_OK"; timeout = 60000 },
        @{ kind = "script"; path = "res://tests/scene_transition_stress_test.gd"; token = "CALIGO_TRANSITION_TEST"; timeout = 120000 },
        @{ kind = "script"; path = "res://tests/startup_click_test.gd"; token = "CALIGO_STARTUP_TEST"; timeout = 120000 }
    )
}

$failed = 0
$passed = 0
foreach ($t in $tests) {
    $o = Join-Path $root "_t_out.txt"
    $e = Join-Path $root "_t_err.txt"
    Remove-Item $o, $e -ErrorAction SilentlyContinue
    $args = @("--headless", "--path", $root)
    if ($t.kind -eq "script") {
        $args += @("--script", $t.path)
    } else {
        $args += $t.path
    }
    $p = Start-Process -FilePath $godot -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
    if (-not $p.WaitForExit([int]$t.timeout)) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Host "TIMEOUT $($t.path)"
        $failed++
        continue
    }
    $txt = ((Get-Content $o, $e -Raw -ErrorAction SilentlyContinue) -join "`n")
    Remove-Item $o, $e -ErrorAction SilentlyContinue
    if ($txt -match [regex]::Escape([string]$t.token)) {
        Write-Host "OK $($t.token)"
        $passed++
    } else {
        Write-Host "FAIL $($t.path)"
        ($txt | Select-String -Pattern "ERROR|FAIL|Parse|AI_FAIL" | Select-Object -First 8 | ForEach-Object { $_.Line }) | ForEach-Object { Write-Host "  $_" }
        $failed++
    }
}

Write-Host "=== RESULT passed=$passed failed=$failed ==="
if ($LaunchGame -and $failed -eq 0) {
    Start-Process -FilePath $godot -ArgumentList @("--path", $root) -WorkingDirectory $root
}
exit $failed
