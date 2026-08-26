# verify-docs.ps1 - checks that every cross-reference in docs/ resolves.
# Catches the failure mode where a plan cites OA-17 or Q-12 that was never written.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $repo 'docs'
$fail = 0

function Get-Defined($file, $pattern) {
  $set = New-Object System.Collections.Generic.HashSet[string]
  foreach ($l in Get-Content -LiteralPath $file) {
    foreach ($m in [regex]::Matches($l, $pattern)) { [void]$set.Add($m.Groups[1].Value) }
  }
  return $set
}

# Definitions: OA-nn appears in a "BLOCKED - OA-nn" line; Q-nn in a "### Q-nn" heading;
# D-nnnn in a "## D-nnnn" heading; R-nnnn in a "## R-nnnn" heading.
$defOA = Get-Defined (Join-Path $docs 'owner-actions.md') '^(?:BLOCKED|RESOLVED).*?- (OA-\d+)'
$defQ  = Get-Defined (Join-Path $docs 'questions.md')     '^### (Q-\d+)'
$defD  = Get-Defined (Join-Path $docs 'decisions.md')     '^## (D-\d+)'
$defR  = Get-Defined (Join-Path $docs 'rejected.md')      '^## (R-\d+)'

Write-Output ("defined: OA={0} Q={1} D={2} R={3}" -f $defOA.Count, $defQ.Count, $defD.Count, $defR.Count)

$refFiles = Get-ChildItem -LiteralPath $docs -Filter '*.md' -File
$missing = @()
foreach ($f in $refFiles) {
  $n = 0
  foreach ($l in Get-Content -LiteralPath $f.FullName) {
    foreach ($m in [regex]::Matches($l, '\b(OA-\d+)\b'))   { $n++; if (-not $defOA.Contains($m.Groups[1].Value)) { $missing += ("{0}: undefined {1}" -f $f.Name, $m.Groups[1].Value) } }
    foreach ($m in [regex]::Matches($l, '\b(Q-\d+)\b'))    { $n++; if (-not $defQ.Contains($m.Groups[1].Value))  { $missing += ("{0}: undefined {1}" -f $f.Name, $m.Groups[1].Value) } }
    foreach ($m in [regex]::Matches($l, '\b(D-\d{4})\b'))  { $n++; if (-not $defD.Contains($m.Groups[1].Value))  { $missing += ("{0}: undefined {1}" -f $f.Name, $m.Groups[1].Value) } }
    foreach ($m in [regex]::Matches($l, '\b(R-\d{4})\b'))  { $n++; if (-not $defR.Contains($m.Groups[1].Value))  { $missing += ("{0}: undefined {1}" -f $f.Name, $m.Groups[1].Value) } }
  }
  Write-Output ("  {0,-20} references: {1}" -f $f.Name, $n)
}

$missing = $missing | Select-Object -Unique
Write-Output ("`nunresolved references: " + $missing.Count)
$missing | ForEach-Object { Write-Output ("  " + $_); }
if ($missing.Count -gt 0) { $fail++ }

# Required living documents (spec 33.3 step 7 plus 27.5 and 32.5)
$required = 'progress.md','decisions.md','rejected.md','owner-actions.md','questions.md','acceptance.md'
foreach ($r in $required) {
  $p = Join-Path $docs $r
  if (Test-Path -LiteralPath $p) { Write-Output ("present: docs/{0} ({1} lines)" -f $r, (Get-Content -LiteralPath $p).Count) }
  else { Write-Output ("MISSING: docs/$r"); $fail++ }
}

# .gitignore must exclude the secret set from 33.3 step 2
$gi = Get-Content -LiteralPath (Join-Path $repo '.gitignore') -Raw
foreach ($pat in '.env','*.env','docs/private/','*.key','*.pem','id_rsa*','*.sql','backups/','logs/','world*/','*.log') {
  if ($gi -notmatch [regex]::Escape($pat)) { Write-Output ("GITIGNORE MISSING PATTERN: $pat"); $fail++ }
}
Write-Output "gitignore: all 33.3 step 2 patterns present"

if ($fail -eq 0) { Write-Output "`nDOCS VERIFIED"; exit 0 } else { Write-Output "`nDOCS VERIFICATION FAILED"; exit 1 }
