# build-acceptance.ps1 - creates docs/acceptance.md from the Section 21 table.
# Every row starts as "Not started" with no evidence. Never-break rule 11:
# a task is not complete without evidence, so the Evidence column is the point
# of this file, not the Status column.

$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot
$specDir = Join-Path $repo 'docs\spec'
$src     = Join-Path $specDir '21-the-master-acceptance-test-table.md'

# Phase ownership, from docs/spec/.findings/G6.md PHASE-TO-ACCEPTANCE MAP.
$phase = @{}
'1,2,3,4,5,6,25,77'                                                  -split ',' | ForEach-Object { $phase[$_.Trim()] = '0' }
'7,8,9,10,11,12,13,14,14c,16,17,18,49,50,51,52,53,54,55,56,57'       -split ',' | ForEach-Object { $phase[$_.Trim()] = '1' }
'45,46,47'                                                           -split ',' | ForEach-Object { $phase[$_.Trim()] = '2' }
'26,27,28,29,41'                                                     -split ',' | ForEach-Object { $phase[$_.Trim()] = '3' }
'14a,14b,15,30,31,32,33,34,35,36,37,38,39'                           -split ',' | ForEach-Object { $phase[$_.Trim()] = '4' }
'40,42,43,44'                                                        -split ',' | ForEach-Object { $phase[$_.Trim()] = '5' }
'19,20,21,22,23,24,48'                                               -split ',' | ForEach-Object { $phase[$_.Trim()] = '6' }
'58,59,60,61,62,63,64,65,66,67,68,69,70'                             -split ',' | ForEach-Object { $phase[$_.Trim()] = '7' }
'71,72,73,74,75,76,78'                                               -split ',' | ForEach-Object { $phase[$_.Trim()] = '8' }

# Rows owned by more than one phase; first is the owner of the pass.
$multi = @{
  '13'='1, re-audit 8'; '14'='1, re-audit 8'; '16'='1 payment path, 8 pages'
  '18'='1 in-game, 8 web and Discord'; '20'='6 budget, 7 real event'
  '25'='0 rule, 6 proof'; '37'='4 Java, 7 Bedrock'; '39'='4 monument, 8 web page'
  '41'='3 rule, 5 enforcement'; '51'='1 tuning, 9 qualifying week'
  '55'='1 permissions, 4 RP proof'; '77'='0 to 9 continuous'
  '34'='4 test, 9 live'; '36'='4 test, 9 live'
}

$rows = @()
foreach ($line in Get-Content -LiteralPath $src) {
  if ($line -notmatch '^\|') { continue }
  $c = $line.Trim().Trim('|').Split('|')
  if ($c.Count -lt 4) { continue }
  $id = $c[0].Trim() -replace '\*',''
  if ($id -eq '#' -or $id -match '^-+$') { continue }
  $p = if ($multi.ContainsKey($id)) { $multi[$id] } elseif ($phase.ContainsKey($id)) { $phase[$id] } else { '?' }
  $rows += [pscustomobject]@{
    Id    = $id
    Test  = ($c[1].Trim() -replace '\*','')
    Pass  = ($c[2].Trim() -replace '\*','')
    Evid  = ($c[3].Trim() -replace '\*','')
    Phase = $p
  }
}

$out = New-Object System.Collections.Generic.List[string]
$out.Add('| Row | Test | Pass condition | Evidence required | Phase | Status | Evidence captured |')
$out.Add('|---|---|---|---|---|---|---|')
foreach ($r in $rows) {
  $out.Add(("| **{0}** | {1} | {2} | {3} | {4} | Not started | - |" -f $r.Id, $r.Test, $r.Pass, $r.Evid, $r.Phase))
}
Set-Content -LiteralPath (Join-Path $specDir '.acceptance-body.md') -Value $out -Encoding UTF8
Write-Output ("Section 21 rows extracted: " + $rows.Count)
Write-Output ("rows with no phase assigned: " + (($rows | Where-Object { $_.Phase -eq '?' }).Count))
($rows | Where-Object { $_.Phase -eq '?' }) | ForEach-Object { Write-Output ("  UNASSIGNED row " + $_.Id) }
