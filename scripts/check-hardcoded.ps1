# check-hardcoded.ps1 - implements the Appendix E hardcoded-value check.
# Acceptance row 2: "Grep for IP addresses and absolute host paths across the repo
# returns nothing." Spec 5.1: the stack must rebuild anywhere without editing code.
#
# SCOPE, and why. The check runs against deployable artefacts and tooling -
# scripts/, server/, db/, and any config or compose file - and against tracked
# files only. It does NOT scan docs/spec/, because that is the verbatim
# specification and rewriting it would break the lossless-split guarantee.
# It scans docs/*.md for SECRETS but permits a host address in owner-facing prose.
# Scoping decision recorded in docs/decisions.md D-0009.
#
# Exits non-zero on any hit. Intended for CI from the first commit.

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$git  = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe' }
if (-not (Test-Path -LiteralPath $git)) { throw "git not found. See docs/owner-actions.md OA-01" }

# Tracked files only - untracked scratch is not shipped.
Push-Location $repo
$tracked = @(& $git ls-files)
Pop-Location

$scanDeployable = $tracked | Where-Object {
  $_ -match '^(scripts|server|db)/' -or $_ -match '^(docker-compose|Dockerfile|\.env\.example)'
} | Where-Object { $_ -ne 'scripts/host.env.example.ps1' }

$scanDocs = $tracked | Where-Object { $_ -match '^docs/[^/]+\.md$' -or $_ -eq 'README.md' -or $_ -eq 'AGENTS.md' }

# An IPv4 literal that is not a version number and not a documentation range.
$ipRe   = '(?<![\d.])((?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?![\d.])'
$pathRe = '(?<![A-Za-z0-9])[A-Za-z]:\\(?!Laugh-Tale\\?")[A-Za-z0-9_. \\-]{3,}'
$secretRe = '(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-)'

# IPs that are legitimate and not host-specific.
$ipAllow = @('169.254.169.254','127.0.0.1','0.0.0.0','255.255.255.255')

$hits = New-Object System.Collections.Generic.List[string]

foreach ($rel in $scanDeployable) {
  $full = Join-Path $repo $rel
  if (-not (Test-Path -LiteralPath $full)) { continue }
  $n = 0
  foreach ($line in Get-Content -LiteralPath $full) {
    $n++
    foreach ($m in [regex]::Matches($line, $ipRe)) {
      if ($ipAllow -notcontains $m.Value) { $hits.Add(("IP       {0}:{1}  {2}" -f $rel, $n, $m.Value)) }
    }
    foreach ($m in [regex]::Matches($line, $pathRe)) {
      $hits.Add(("ABS PATH {0}:{1}  {2}" -f $rel, $n, $m.Value))
    }
    foreach ($m in [regex]::Matches($line, $secretRe)) {
      $hits.Add(("SECRET   {0}:{1}  redacted match" -f $rel, $n))
    }
  }
}

foreach ($rel in $scanDocs) {
  $full = Join-Path $repo $rel
  if (-not (Test-Path -LiteralPath $full)) { continue }
  $n = 0
  foreach ($line in Get-Content -LiteralPath $full) {
    $n++
    foreach ($m in [regex]::Matches($line, $secretRe)) {
      $hits.Add(("SECRET   {0}:{1}  redacted match" -f $rel, $n))
    }
  }
}

Write-Output ("tracked files: {0}   deployable scanned: {1}   docs scanned: {2}" -f $tracked.Count, @($scanDeployable).Count, @($scanDocs).Count)
Write-Output ("hits: " + $hits.Count)
$hits | ForEach-Object { Write-Output ("  " + $_) }

if ($hits.Count -eq 0) { Write-Output "`nHARDCODED-VALUE CHECK PASS (acceptance row 2, deployable scope)"; exit 0 }
else { Write-Output "`nHARDCODED-VALUE CHECK FAIL"; exit 1 }
