$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

foreach ($d in @('docs\spec','docs\private','server','scripts','db\migrations')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $repo $d) | Out-Null
}

$src = Join-Path $repo 'LaughTail-SMP-MASTER-PROMPT (1).md'
$dst = Join-Path $repo 'docs\spec\MASTER.md'
if (Test-Path -LiteralPath $src) {
  Move-Item -LiteralPath $src -Destination $dst -Force
  Write-Output "Moved master spec -> docs\spec\MASTER.md"
} elseif (Test-Path -LiteralPath $dst) {
  Write-Output "MASTER.md already in place"
} else {
  throw "Master spec not found"
}

Write-Output ("MASTER.md lines: " + (Get-Content -LiteralPath $dst).Count)
Write-Output "--- repo root ---"
Get-ChildItem -LiteralPath $repo -Force | ForEach-Object { Write-Output ("  " + $_.Name) }
