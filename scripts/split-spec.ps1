# split-spec.ps1 - implements spec 33.4 steps 2 and 4.
# Splits docs/spec/MASTER.md into one file per top-level (##) section/appendix,
# then verifies the split is lossless.
# Read-only against MASTER.md. Writes only into docs/spec/.

$ErrorActionPreference = 'Stop'
$repo   = 'C:\Laugh-Tale'
$master = Join-Path $repo 'docs\spec\MASTER.md'
$outDir = Join-Path $repo 'docs\spec'

if (-not (Test-Path $master)) { throw "MASTER.md not found at $master" }

$lines = Get-Content -LiteralPath $master
$total = $lines.Count

# --- locate every top-level heading -------------------------------------------
$heads = @()
for ($i = 0; $i -lt $total; $i++) {
  if ($lines[$i] -match '^##\s+\S') { $heads += $i }
}
Write-Output ("MASTER lines: {0}   top-level headings: {1}" -f $total, $heads.Count)

function New-Slug([string]$text) {
  $s = $text
  $s = $s -replace '\(.*?\)', ' '        # drop parenthetical asides
  $s = $s -replace '[^A-Za-z0-9]+', '-'
  $s = $s.Trim('-').ToLowerInvariant()
  if ($s.Length -gt 52) {
    $cut = $s.Substring(0, 52)
    $lastDash = $cut.LastIndexOf('-')
    if ($lastDash -gt 20) { $cut = $cut.Substring(0, $lastDash) }
    $s = $cut
  }
  return $s
}

$parts = @()

# --- preamble (everything before the first ## heading) ------------------------
if ($heads[0] -gt 0) {
  $parts += [pscustomobject]@{
    Key      = '_preamble'
    Heading  = '(document front matter)'
    File     = '_preamble.md'
    Start    = 1
    End      = $heads[0]           # 1-based inclusive
  }
}

# --- one part per heading -----------------------------------------------------
for ($h = 0; $h -lt $heads.Count; $h++) {
  $startIdx = $heads[$h]
  $endIdx   = if ($h -lt $heads.Count - 1) { $heads[$h + 1] - 1 } else { $total - 1 }
  $headText = ($lines[$startIdx] -replace '^##\s+', '').Trim()

  $key = $null; $title = $headText
  if ($headText -match '^SECTION\s+(\d+)\s*[-–—:]\s*(.+)$') {
    $key   = ([int]$Matches[1]).ToString('00')
    $title = $Matches[2].Trim()
  }
  elseif ($headText -match '^APPENDIX\s+([A-Z])\s*[-–—:]\s*(.+)$') {
    $key   = $Matches[1]
    $title = $Matches[2].Trim()
  }
  elseif ($headText -match '^END OF DOCUMENT') {
    $key   = '_end'
    $title = 'end-of-document'
  }
  else {
    throw "Unrecognised top-level heading form on line $($startIdx+1): $headText"
  }

  $file = if ($key -eq '_end') { '_end-of-document.md' } else { "$key-$(New-Slug $title).md" }
  $parts += [pscustomobject]@{
    Key     = $key
    Heading = $headText
    File    = $file
    Start   = $startIdx + 1
    End     = $endIdx + 1
  }
}

# --- write the parts ---------------------------------------------------------
foreach ($p in $parts) {
  $slice = $lines[($p.Start - 1)..($p.End - 1)]
  $path  = Join-Path $outDir $p.File
  Set-Content -LiteralPath $path -Value $slice -Encoding UTF8
  Write-Output ("{0,-4} {1,-58} lines {2,5}-{3,-5} = {4}" -f $p.Key, $p.File, $p.Start, $p.End, $slice.Count)
}

# --- emit a machine-readable manifest for INDEX.md generation ----------------
$parts | Select-Object Key, File, Heading, Start, End |
  Export-Csv -LiteralPath (Join-Path $outDir '.split-manifest.csv') -NoTypeInformation -Encoding UTF8

Write-Output ("`nWrote {0} part files." -f $parts.Count)
