# check-no-secrets.ps1 - proves never-break rule 5 holds for the tracked tree.
# Fails if any file that must stay secret is tracked by git.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$git  = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe' }
Set-Location $repo

Write-Output '--- is scripts/host.env.ps1 ignored? ---'
& $git check-ignore -v 'scripts/host.env.ps1'
if ($LASTEXITCODE -ne 0) { Write-Output 'NOT IGNORED - this is a defect' } else { Write-Output 'ignored, correct' }

$tracked = @(& $git ls-files)
$patterns = '\.pem$','\.key$','\.env$','\.sql$','\.jar$','\.log$','^docs/private/','host\.env\.ps1$','\.dump$','credentials','secrets'
$bad = @()
foreach ($t in $tracked) {
  foreach ($p in $patterns) { if ($t -match $p) { $bad += ("{0}  (matched {1})" -f $t, $p) } }
}
Write-Output ''
Write-Output '--- tracked files matching a must-stay-secret pattern ---'
if ($bad.Count -gt 0) { $bad | ForEach-Object { Write-Output ('  ' + $_) } } else { Write-Output '  (none)' }

Write-Output ''
Write-Output ("total tracked files: " + $tracked.Count)
Write-Output ("docs/private tracked: " + (@($tracked | Where-Object { $_ -like 'docs/private/*' }).Count))

if ($bad.Count -eq 0) { Write-Output "`nNO-SECRETS CHECK PASS (never-break rule 5)"; exit 0 }
else { Write-Output "`nNO-SECRETS CHECK FAIL"; exit 1 }
