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
# Patterns for files that must never be tracked. The credentials/secrets words are
# anchored to data-file extensions so this script's own name does not match itself.
$patterns = '\.pem$','\.key$','\.env$','\.sql$','\.jar$','\.log$','^docs/private/',
            'host\.env\.ps1$','\.dump$',
            '(^|/)(credentials|secrets|token|password)[^/]*\.(txt|json|ya?ml|cfg|ini|conf)$'
$bad = @()

# The D-0001 carve-out, applied here as well as in .gitignore.
#
# The specification's own .gitignore list excludes '*.sql' while the SAME
# subsection mandates that db/migrations/ be version controlled from the first
# commit (Appendix D: "Use schema migrations from the first commit"). Both cannot
# hold literally. Decision D-0001 resolved it in .gitignore; this script encoded
# the pattern list without the exception, so it started failing the moment the
# schema was actually written - and it failed the deploy, correctly, rather than
# quietly passing.
#
# The exemption is deliberately narrow: ONLY .sql directly under db/migrations/.
# A .sql file anywhere else is still a failure, because a stray dump or an export
# containing player data is exactly what this check exists to catch.
$exempt = @(
  @{ rx = '^db/migrations/[^/]+\.sql$'; why = 'schema migration, mandated by Appendix D - decision D-0001' }
)

foreach ($t in $tracked) {
  $isExempt = $false
  foreach ($e in $exempt) {
    if ($t -match $e.rx) {
      $isExempt = $true
      Write-Output ("  exempt: {0}  ({1})" -f $t, $e.why)
      break
    }
  }
  if ($isExempt) { continue }
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
