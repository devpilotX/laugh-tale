# install-hooks.ps1 - points git at the committed .githooks directory.
#
# Why core.hooksPath and not .git/hooks: .git/ is not version controlled, so a hook
# placed there exists on exactly one machine and vanishes on a fresh clone. Spec
# 33.6 item 13 wants a guarantee, and a guarantee that only one PC has is not one.
#
# This is the ONE git config value this project sets, it is repository-local, and
# it is set by a committed script rather than by hand so it is reproducible.
#
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-hooks.ps1

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$git = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) {
  foreach ($c in @(
      (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'))) {
    if ($c -and (Test-Path -LiteralPath $c)) { $git = $c; break }
  }
}
if (-not $git) { throw 'git not found' }

& $git config core.hooksPath .githooks
Write-Output ("core.hooksPath = " + (& $git config core.hooksPath))

# Git needs the shim executable on platforms that care. Harmless on Windows, and
# skipped if the shim is not tracked yet - update-index errors on an untracked path.
$tracked = @(& $git ls-files -- '.githooks/pre-commit')
if ($tracked.Count -gt 0) {
  try { & $git update-index --chmod=+x .githooks/pre-commit 2>$null | Out-Null } catch { }
} else {
  Write-Output 'note: .githooks/pre-commit is not tracked yet; run this again after committing it to set the executable bit.'
}

Write-Output ''
Write-Output '--- self-test: the hook must REFUSE a staged secret ---'

$probe = Join-Path $repo 'hook-selftest.env'
Set-Content -LiteralPath $probe -Value 'APP_KEY=base64:thisIsNotARealKeyItIsATest0000000000000=' -Encoding UTF8
& $git add -f -- 'hook-selftest.env'

$out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'hooks\pre-commit.ps1') 2>&1
$code = $LASTEXITCODE

& $git restore --staged -- 'hook-selftest.env' 2>$null
Remove-Item -LiteralPath $probe -Force

if ($code -ne 0) {
  Write-Output 'PASS: the hook refused a staged secret, exit code 1 as required.'
  Write-Output ($out | Where-Object { $_ -match 'FORBIDDEN|SECRET|REFUSED' } | ForEach-Object { '  ' + $_ })
} else {
  Write-Output 'FAIL: the hook ALLOWED a staged secret. Do not rely on it.'
  Write-Output ($out | ForEach-Object { '  ' + $_ })
  exit 1
}

Write-Output ''
Write-Output '--- self-test: a clean staged file must be ALLOWED ---'
$clean = Join-Path $repo 'hook-selftest-clean.txt'
Set-Content -LiteralPath $clean -Value 'rcon.password=__PRESERVE__' -Encoding UTF8
& $git add -- 'hook-selftest-clean.txt'
$out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'hooks\pre-commit.ps1') 2>&1
$code2 = $LASTEXITCODE
& $git restore --staged -- 'hook-selftest-clean.txt' 2>$null
Remove-Item -LiteralPath $clean -Force

if ($code2 -eq 0) {
  Write-Output 'PASS: __PRESERVE__ placeholder allowed, so the deploy path still works.'
} else {
  Write-Output 'FAIL: the hook refused a clean file. It would block all work.'
  Write-Output ($out2 | ForEach-Object { '  ' + $_ })
  exit 1
}

Write-Output ''
Write-Output 'HOOKS INSTALLED AND PROVEN (spec 33.6 item 13, never-break rule 5)'
