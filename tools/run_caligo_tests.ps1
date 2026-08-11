# Esegue i test headless principali di Caligo e riporta OK/FAIL.
param(
    [switch]$LaunchGame
)

$ErrorActionPreference = "Stop"
$root = "C:\Users\user\caligo"
$godot = "C:\Users\user\tools\godot-4.5\Godot_v4.5-stable_win64_console.exe"
Set-Location $root

Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400

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
    @{ kind = "script"; path = "res://tests/fishing_reentry_reel_test.gd"; token = "FISHING_REENTRY_REEL_TEST_OK"; timeout = 30000 },
    @{ kind = "script"; path = "res://tests/fishing_attract_swim_test.gd"; token = "FISHING_ATTRACT_SWIM_TEST_OK"; timeout = 30000 },
    @{ kind = "scene"; path = "res://tests/player_jump_test.tscn"; token = "CALIGO_JUMP_TEST"; timeout = 30000 },
    @{ kind = "scene"; path = "res://tests/guided_tutorial_geometry_test.tscn"; token = "CALIGO_GUIDED_TUTORIAL"; timeout = 90000 },
    @{ kind = "scene"; path = "res://tests/dogana_section_tour_test.tscn"; token = "CALIGO_SECTION_TOUR_OK"; timeout = 120000 },
    @{ kind = "scene"; path = "res://tests/dogana_artist_pipeline_test.tscn"; token = "CALIGO_ARTIST_PIPELINE"; timeout = 180000 }
)

$failed = 0
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
    if ($txt -match [regex]::Escape([string]$t.token) -or $p.ExitCode -eq 0 -and $txt -notmatch "ERROR:|SCRIPT ERROR|FAIL") {
        if ($txt -match [regex]::Escape([string]$t.token)) {
            Write-Host "OK $($t.token)"
        } elseif ($p.ExitCode -eq 0) {
            Write-Host "OK(exit0) $($t.path)"
        } else {
            Write-Host "FAIL $($t.path)"
            $failed++
        }
    } else {
        Write-Host "FAIL $($t.path)"
        ($txt | Select-String -Pattern "ERROR|FAIL|Parse" | Select-Object -First 6 | ForEach-Object { $_.Line }) | ForEach-Object { Write-Host "  $_" }
        $failed++
    }
}

Write-Host "=== RESULT failed=$failed ==="
if ($LaunchGame -and $failed -eq 0) {
    Start-Process -FilePath $godot -ArgumentList @("--path", $root) -WorkingDirectory $root
}
exit $failed
