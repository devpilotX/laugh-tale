# git-commit.ps1 - resolves git without relying on PATH, then commits staged paths.
# Usage: git-commit.ps1 -Paths 'a','b' -Subject '...' -Body '...'
param(
  [string[]]$Paths,
  [string]$Subject,
  [string]$Body = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$git  = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) {
  foreach ($c in @(
      (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'))) {
    if ($c -and (Test-Path -LiteralPath $c)) { $git = $c; break }
  }
}
if (-not $git) { throw 'git not found' }
Set-Location $repo

& $git add -- @Paths
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
Write-Output '--- staged ---'
& $git diff --cached --name-status

if ($Body) { & $git commit -m $Subject -m $Body } else { & $git commit -m $Subject }
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }

Write-Output ''
Write-Output '--- history ---'
& $git log --oneline
Write-Output ''
Write-Output '--- status (empty means clean) ---'
& $git status --short
