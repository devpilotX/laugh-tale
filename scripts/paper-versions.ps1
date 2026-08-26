# paper-versions.ps1 - READ ONLY. Queries the PaperMC API to establish what
# versions and builds actually exist, so the pin in the manifest is a fact and
# not an assumption (spec 4.2: pin the exact version, never a floating latest).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero (build planning)' }

function Try-Api {
  param([string]$Url)
  try { return Invoke-RestMethod -Uri $Url -Headers $hdr -TimeoutSec 25 }
  catch { Write-Output ("  ! {0} -> {1}" -f $Url, $_.Exception.Message); return $null }
}

Write-Output '=== PaperMC v3 (fill) : project paper ==='
$proj = Try-Api 'https://fill.papermc.io/v3/projects/paper'
if ($proj) {
  $vers = @()
  foreach ($p in $proj.versions.PSObject.Properties) { $vers += $p.Value }
  $flat = $vers | ForEach-Object { $_ } | Select-Object -Unique
  Write-Output ("  total versions: " + @($flat).Count)
  Write-Output ("  newest 12: " + (@($flat)[0..([Math]::Min(11, @($flat).Count - 1))] -join ', '))
}

Write-Output ''
Write-Output '=== latest stable builds for the newest few versions ==='
$candidates = @()
if ($proj) {
  $all = @()
  foreach ($p in $proj.versions.PSObject.Properties) { foreach ($v in $p.Value) { $all += $v } }
  $candidates = @($all | Select-Object -Unique)[0..([Math]::Min(5, @($all).Count - 1))]
}

foreach ($v in $candidates) {
  $builds = Try-Api ("https://fill.papermc.io/v3/projects/paper/versions/{0}/builds" -f $v)
  if (-not $builds) { continue }
  $stable = @($builds | Where-Object { $_.channel -eq 'STABLE' })
  $use = if ($stable.Count -gt 0) { $stable[0] } else { $builds[0] }
  $jar = $use.downloads.'server:default'
  Write-Output ("  {0,-10} build {1,-6} channel {2,-12} java {3,-4} sha256 {4}" -f `
    $v, $use.id, $use.channel, $use.java.version.minimum, $(if ($jar) { $jar.checksums.sha256 } else { 'n/a' }))
  if ($jar) { Write-Output ("             url  " + $jar.url) }
}
