# check-gating-plugins.ps1 - READ ONLY.
# GrimAC looked like the gating component for the version pin. Confirm it, and
# check Geyser, which distributes from its own API rather than Modrinth.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero (build planning)' }

function Sort-McVersions {
  param([string[]]$V)
  # Proper version ordering: "26.2" outranks "1.21.11", and 1.21.11 outranks 1.9.4.
  $V | Sort-Object -Property @{ Expression = {
    $parts = ($_ -replace '[^0-9.].*$','') -split '\.'
    $n = @(0,0,0)
    for ($i=0; $i -lt [Math]::Min(3,$parts.Count); $i++) { [void][int]::TryParse($parts[$i], [ref]$null); $n[$i] = [int]($parts[$i] -as [int]) }
    ($n[0] * 1000000) + ($n[1] * 1000) + $n[2]
  } } -Descending
}

Write-Output '=== GrimAC : every release and the versions it supports ==='
try {
  $vs = Invoke-RestMethod -Uri 'https://api.modrinth.com/v2/project/grimac/version' -Headers $hdr -TimeoutSec 25
  $rel = @($vs | Where-Object { $_.version_type -eq 'release' })
  foreach ($r in $rel[0..([Math]::Min(4, $rel.Count - 1))]) {
    $sorted = Sort-McVersions -V $r.game_versions
    Write-Output ("  {0,-12} type {1,-8} highest MC: {2,-10}  count {3}" -f $r.version_number, $r.version_type, $sorted[0], $r.game_versions.Count)
  }
  $allSupported = Sort-McVersions -V (@($rel | ForEach-Object { $_.game_versions } | Select-Object -Unique))
  Write-Output ("  HIGHEST MC SUPPORTED BY ANY GRIMAC RELEASE: " + $allSupported[0])
  $anyBeta = @($vs | Where-Object { $_.version_type -ne 'release' })
  if ($anyBeta.Count) {
    $bs = Sort-McVersions -V (@($anyBeta | ForEach-Object { $_.game_versions } | Select-Object -Unique))
    Write-Output ("  highest MC in a non-release GrimAC build:    " + $bs[0])
  }
} catch { Write-Output ("  error: " + $_.Exception.Message) }

Write-Output ''
Write-Output '=== Geyser : own distribution API ==='
try {
  $g = Invoke-RestMethod -Uri 'https://download.geysermc.org/v2/projects/geyser' -Headers $hdr -TimeoutSec 25
  Write-Output ("  versions: " + ($g.versions -join ', '))
  $latestVer = $g.versions[-1]
  $b = Invoke-RestMethod -Uri "https://download.geysermc.org/v2/projects/geyser/versions/$latestVer/builds/latest" -Headers $hdr -TimeoutSec 25
  Write-Output ("  latest build {0} for {1}" -f $b.build, $b.version)
  if ($b.downloads.spigot) {
    Write-Output ("  spigot artefact: {0}   sha256 {1}" -f $b.downloads.spigot.name, $b.downloads.spigot.sha256)
    Write-Output ("  url: https://download.geysermc.org/v2/projects/geyser/versions/$latestVer/builds/$($b.build)/downloads/spigot")
  }
} catch { Write-Output ("  error: " + $_.Exception.Message) }
