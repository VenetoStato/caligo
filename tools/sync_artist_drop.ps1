# Wrapper Windows per la disegnatrice.
# Uso:  .\tools\sync_artist_drop.ps1
#       .\tools\sync_artist_drop.ps1 -Status
#       .\tools\sync_artist_drop.ps1 -Seed
param(
    [switch]$Status,
    [switch]$Seed,
    [switch]$NoStrip,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$argsList = @()
if ($Status) { $argsList += "--status" }
if ($Seed) { $argsList += "--seed" }
if ($NoStrip) { $argsList += "--no-strip" }
if ($Files) { $argsList += $Files }

python "$root\tools\sync_artist_drop.py" @argsList
exit $LASTEXITCODE
