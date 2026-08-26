# verify-split.ps1 - implements spec 33.4 step 4.
# Three checks, all must pass:
#   1. sum(part line counts) == MASTER.md line count
#   2. every '##' top-level heading appears exactly once across the parts
#   3. parts concatenated in document order are byte-for-byte identical to MASTER.md
# Read-only. Exits non-zero on any failure.

$ErrorActionPreference = 'Stop'
$repo     = Split-Path -Parent $PSScriptRoot
$specDir  = Join-Path $repo 'docs\spec'
$master   = Join-Path $specDir 'MASTER.md'
$manifest = Join-Path $specDir '.split-manifest.csv'

$masterLines = Get-Content -LiteralPath $master
$parts = Import-Csv -LiteralPath $manifest
$fail = 0

# --- check 1: line counts ----------------------------------------------------
$sum = 0
$rebuilt = New-Object System.Collections.Generic.List[string]
foreach ($p in $parts) {
  $pl = Get-Content -LiteralPath (Join-Path $specDir $p.File)
  if ($null -eq $pl) { $pl = @() }
  $sum += $pl.Count
  foreach ($l in $pl) { $rebuilt.Add($l) }
}
Write-Output ("CHECK 1  master lines = {0}   sum of part lines = {1}" -f $masterLines.Count, $sum)
if ($sum -eq $masterLines.Count) { Write-Output "CHECK 1  PASS" } else { Write-Output "CHECK 1  FAIL"; $fail++ }

# --- check 2: every ## heading exactly once -----------------------------------
$masterHeads = $masterLines | Where-Object { $_ -match '^##\s+\S' }
$partHeads   = $rebuilt      | Where-Object { $_ -match '^##\s+\S' }
$dupes = $partHeads | Group-Object | Where-Object { $_.Count -ne 1 }
$missing = Compare-Object -ReferenceObject $masterHeads -DifferenceObject $partHeads
Write-Output ("CHECK 2  headings in master = {0}   headings across parts = {1}   duplicated = {2}   differing = {3}" -f `
  $masterHeads.Count, $partHeads.Count, $dupes.Count, @($missing).Count)
if ($dupes.Count -eq 0 -and @($missing).Count -eq 0 -and $masterHeads.Count -eq $partHeads.Count) {
  Write-Output "CHECK 2  PASS"
} else {
  Write-Output "CHECK 2  FAIL"; $fail++
  $dupes | ForEach-Object { Write-Output ("  duplicated: " + $_.Name) }
}

# --- check 3: exact content reconstruction ------------------------------------
$diff = 0
for ($i = 0; $i -lt [Math]::Max($masterLines.Count, $rebuilt.Count); $i++) {
  $a = if ($i -lt $masterLines.Count) { $masterLines[$i] } else { '<<missing>>' }
  $b = if ($i -lt $rebuilt.Count)     { $rebuilt[$i] }     else { '<<missing>>' }
  if ($a -cne $b) {
    $diff++
    if ($diff -le 5) { Write-Output ("  line {0} differs:`n    master: {1}`n    parts : {2}" -f ($i+1), $a, $b) }
  }
}
Write-Output ("CHECK 3  differing lines = {0}" -f $diff)
if ($diff -eq 0) { Write-Output "CHECK 3  PASS" } else { Write-Output "CHECK 3  FAIL"; $fail++ }

# --- subsection inventory (feeds INDEX.md) ------------------------------------
$sub = ($rebuilt | Where-Object { $_ -match '^###\s+\S' }).Count
Write-Output ("`nSubsection (###) headings: {0}   Part files: {1}" -f $sub, $parts.Count)

if ($fail -eq 0) { Write-Output "`nSPLIT VERIFIED LOSSLESS (spec 33.4 step 4)"; exit 0 }
else { Write-Output "`nSPLIT VERIFICATION FAILED"; exit 1 }
