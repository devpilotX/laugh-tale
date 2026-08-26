# build-index.ps1 - implements spec 33.4 step 3.
# Joins the per-group summary rows onto the authoritative heading inventory
# (.split-manifest.csv + .subsections.csv) and emits docs/spec/INDEX.md in
# document order. Reports any heading that has no summary row.

$ErrorActionPreference = 'Stop'
$specDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs\spec'
$parts   = Import-Csv -LiteralPath (Join-Path $specDir '.split-manifest.csv')
$subs    = Import-Csv -LiteralPath (Join-Path $specDir '.subsections.csv')

# --- load every summary row from the group partials --------------------------
$byKey = @{}
$rowCount = 0
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $specDir '.index-parts') -Filter '*.md' | Sort-Object Name) {
  foreach ($line in Get-Content -LiteralPath $f.FullName) {
    if ($line -notmatch '^\s*\|') { continue }
    $cells = $line.Trim().Trim('|').Split('|')
    if ($cells.Count -lt 4) { continue }
    $num   = $cells[0].Trim()
    $title = $cells[1].Trim()
    $file  = $cells[2].Trim()
    $summ  = $cells[3].Trim()
    $k = ($file + '#' + ($num -replace '\*',''))
    if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{ Title = $title; Summary = $summ } }
    $rowCount++
  }
}
Write-Output ("loaded summary rows: {0}   unique keys: {1}" -f $rowCount, $byKey.Count)

# --- emit ---------------------------------------------------------------------
$out = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

function Get-Summary($file, $num, $fallbackTitle) {
  $k = ($file + '#' + $num)
  if ($byKey.ContainsKey($k)) { return $byKey[$k] }
  $script:missingHit = $true
  $missing.Add(("{0} :: {1} :: {2}" -f $file, $num, $fallbackTitle))
  return @{ Title = $fallbackTitle; Summary = 'SUMMARY MISSING' }
}

$out.Add('| # | Section or subsection | File | What you come here to find out |')
$out.Add('|---|---|---|---|')

foreach ($p in $parts) {
  # section-level row
  if ($p.Key -eq '_preamble') { $key = 'Preamble' }
  elseif ($p.Key -eq '_end')  { $key = 'END' }
  else { $key = ($p.Key -replace '^0(\d)$', '$1') }   # 00 -> 0, 03 -> 3, 33 -> 33

  $hdr = $p.Heading -replace '^(SECTION\s+\d+|APPENDIX\s+[A-Z])\s*[-–—:]\s*', ''
  $s = Get-Summary $p.File $key $hdr
  $out.Add(("| **{0}** | {1} | [{2}]({2}) | {3} |" -f $key, $s.Title, $p.File, $s.Summary))

  # subsection rows, in file order
  foreach ($sub in ($subs | Where-Object { $_.File -eq $p.File })) {
    $num = if ($sub.Num) { $sub.Num } else { '' }
    if (-not $num) {
      # un-numbered: section 20 phases and appendix G invitation
      if ($p.Key -eq '20' -and $sub.Title -match '^Phase\s+(\d)') { $num = '20.P' + $Matches[1] }
      elseif ($p.Key -eq 'G') { $num = 'G.x' }
      else { $num = $p.Key + '.?' }
    }
    $ss = Get-Summary $p.File $num $sub.Title
    $t = if ($ss.Title) { $ss.Title } else { $sub.Title }
    $out.Add(("| {0} | {1} | [{2}]({2}) | {3} |" -f $num, $t, $p.File, $ss.Summary))
  }
}

Set-Content -LiteralPath (Join-Path $specDir '.index-body.md') -Value $out -Encoding UTF8
Write-Output ("index body rows: {0}" -f ($out.Count - 2))
Write-Output ("headings with no summary: {0}" -f $missing.Count)
$missing | ForEach-Object { Write-Output ("  MISSING  " + $_) }
