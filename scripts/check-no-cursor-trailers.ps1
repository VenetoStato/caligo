param([string]$RepoPath = ".")
Set-Location $RepoPath
$matches = git log --format=%B | Select-String -Pattern '(?im)^(Co-authored-by:\s*Cursor|Made-with:\s*Cursor)'
if ($matches) {
  Write-Host "FAIL: found Cursor trailers:" -ForegroundColor Red
  $matches | ForEach-Object { $_.Line }
  exit 1
}
Write-Host "OK: no Cursor Co-authored-by / Made-with trailers found."
exit 0