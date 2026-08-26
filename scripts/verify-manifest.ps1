# verify-manifest.ps1 - downloads every component in server/manifest.yml and
# checks it against the checksum the publisher stated.
#
# Never-break rule 9 is only real if something enforces it. This is that thing.
# Downloads land in .cache/artefacts/, which is git-ignored - jars are never
# committed (.gitignore excludes *.jar).
#
# Exits non-zero on any mismatch, missing file, or download failure. Fail closed.

param([switch]$Force)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = Split-Path -Parent $PSScriptRoot
$man  = Join-Path $repo 'server\manifest.yml'
$cache = Join-Path $repo '.cache\artefacts'
New-Item -ItemType Directory -Force -Path $cache | Out-Null

if (-not (Test-Path -LiteralPath $man)) { throw "server/manifest.yml not found. Run scripts/manifest-resolve.ps1 first." }

# --- minimal YAML read: this manifest is a flat list, so a full parser is overkill
$components = @()
$cur = $null
foreach ($line in Get-Content -LiteralPath $man) {
  if ($line -match '^\s*#') { continue }
  if ($line -match '^\s{2}-\s+name:\s*"(.+)"\s*$') {
    if ($cur) { $components += $cur }
    $cur = [ordered]@{ name = $Matches[1] }
    continue
  }
  if ($null -ne $cur -and $line -match '^\s{4}(\w+):\s*"(.*)"\s*$') { $cur[$Matches[1]] = $Matches[2] }
}
if ($cur) { $components += $cur }

# The bundled section has no url; drop anything without one.
$components = @($components | Where-Object { $_.url })

Write-Output ("manifest components with a download url: " + $components.Count)
Write-Output ''

$fail = 0
$totalBytes = 0

foreach ($c in $components) {
  $dest = Join-Path $cache $c.file
  $need = $true

  if ((Test-Path -LiteralPath $dest) -and -not $Force) {
    $need = $false
    Write-Output ("{0,-20} cached" -f $c.name)
  }

  if ($need) {
    Write-Output ("{0,-20} downloading {1}" -f $c.name, $c.file)
    try {
      Invoke-WebRequest -Uri $c.url -OutFile $dest -TimeoutSec 300 `
        -Headers @{ 'User-Agent' = 'LaughTail-SMP/day-zero (manifest verification)' }
    } catch {
      Write-Output ("  FAIL download: " + $_.Exception.Message)
      $fail++
      continue
    }
  }

  if (-not (Test-Path -LiteralPath $dest)) { Write-Output '  FAIL file absent after download'; $fail++; continue }

  $algo = if ($c.checksum_algo) { $c.checksum_algo.ToUpperInvariant() } else { 'SHA256' }
  $actual = (Get-FileHash -LiteralPath $dest -Algorithm $algo).Hash.ToLowerInvariant()
  $expected = $c.checksum.ToLowerInvariant()
  $size = (Get-Item -LiteralPath $dest).Length
  $totalBytes += $size

  if ($actual -eq $expected) {
    Write-Output ("  OK   {0} {1}  {2:N0} bytes  v{3}" -f $algo, $actual.Substring(0,16), $size, $c.version)
  } else {
    Write-Output ("  FAIL {0} MISMATCH" -f $algo)
    Write-Output ("       expected {0}" -f $expected)
    Write-Output ("       actual   {0}" -f $actual)
    Write-Output  '       The artefact at that URL is not the one the publisher checksummed.'
    Write-Output  '       Do NOT install it. Re-resolve the manifest and investigate.'
    $fail++
  }
}

Write-Output ''
Write-Output ("components: {0}   failures: {1}   total {2:N1} MB" -f $components.Count, $fail, ($totalBytes / 1MB))
if ($fail -eq 0) { Write-Output 'MANIFEST VERIFIED - every artefact matches its publisher checksum'; exit 0 }
else { Write-Output 'MANIFEST VERIFICATION FAILED'; exit 1 }
