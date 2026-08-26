# resolve-26-2.ps1 - READ ONLY against the network. Prints manifest-ready values.
#
# Resolves ONLY the components whose pin changes when the server moves from 1.21.11
# to 26.2. Deliberately does not rewrite server/manifest.yml: the manifest now carries
# hand-written context - the GrimAC exclusion, the infrastructure_images block, the
# aarch64 load proofs - that a full regeneration would silently discard.
#
# plugin-support.ps1 already established which components need no change:
#   viaversion 5.11.0, viabackwards 5.11.0, luckperms 5.5.71, simple-voice-chat
#   2.6.21 all state support for 26.2 as well as 1.21.11.
#
# And which cannot come along:
#   grimac - latest 2.3.73 states 1.21.11 and NOT 26.2. There is no build to pin.

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/version-move (manifest resolution)' }
$MC  = '26.2'

function Show {
  param($Name, $Version, $File, $Algo, $Hash, $Url, $Source, $Note = '')
  Write-Output ''
  Write-Output ("  - name: `"{0}`"" -f $Name)
  Write-Output ("    version: `"{0}`"" -f $Version)
  Write-Output ("    file: `"{0}`"" -f $File)
  Write-Output ("    checksum_algo: `"{0}`"" -f $Algo)
  Write-Output ("    checksum: `"{0}`"" -f $Hash)
  Write-Output ("    url: `"{0}`"" -f $Url)
  Write-Output ("    checksum_source: `"{0}`"" -f $Source)
  if ($Note) { Write-Output ("    notes: `"{0}`"" -f $Note) }
}

Write-Output "=== Paper $MC ==="
try {
  $builds = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri "https://fill.papermc.io/v3/projects/paper/versions/$MC/builds"
  $pb = @($builds | Where-Object { $_.channel -eq 'STABLE' })[0]
  $dl = $pb.downloads.'server:default'
  Show -Name 'paper' -Version ("{0}-{1}" -f $MC, $pb.id) -File $dl.name `
       -Algo 'sha256' -Hash $dl.checksums.sha256 -Url $dl.url -Source 'fill.papermc.io/v3' `
       -Note ("build {0}, channel {1}, java_minimum from API" -f $pb.id, $pb.channel)
  Write-Output ("    (java minimum: {0})" -f $pb.java.version.minimum)
} catch {
  Write-Output ("  FAILED: " + $_.Exception.Message)
}

# ---- Modrinth components -----------------------------------------------------
function Resolve-Modrinth {
  param([string]$Slug, [string]$Loader = 'paper')
  try {
    $vs = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 `
      -Uri "https://api.modrinth.com/v2/project/$Slug/version"
    # Newest version that lists 26.2 and a server-side loader.
    $match = $vs | Where-Object {
      $_.game_versions -contains $MC -and
      ($_.loaders -contains 'paper' -or $_.loaders -contains 'spigot' -or $_.loaders -contains 'bukkit')
    } | Select-Object -First 1
    if (-not $match) { Write-Output ("  {0}: no version lists {1}" -f $Slug, $MC); return }
    $f = @($match.files | Where-Object { $_.primary })[0]
    if (-not $f) { $f = $match.files[0] }
    $algo = if ($f.hashes.sha512) { 'sha512' } else { 'sha256' }
    $hash = if ($f.hashes.sha512) { $f.hashes.sha512 } else { $f.hashes.sha256 }
    Show -Name $Slug -Version $match.version_number -File $f.filename `
         -Algo $algo -Hash $hash -Url $f.url -Source 'api.modrinth.com/v2' `
         -Note ("loaders: {0}; game_versions include {1}" -f ($match.loaders -join ','), $MC)
  } catch {
    Write-Output ("  {0}: ERROR {1}" -f $Slug, $_.Exception.Message)
  }
}

Write-Output ''
Write-Output "=== Modrinth components that need a NEW pin for $MC ==="
Resolve-Modrinth -Slug 'chunky'
Resolve-Modrinth -Slug 'floodgate'

Write-Output ''
Write-Output "=== components already valid for $MC - no change needed ==="
foreach ($s in 'viaversion', 'viabackwards', 'luckperms', 'simple-voice-chat') {
  Resolve-Modrinth -Slug $s
}

# ---- Geyser: its own API, not Modrinth ---------------------------------------
Write-Output ''
Write-Output '=== Geyser (own API) ==='
try {
  $g = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 `
    -Uri 'https://download.geysermc.org/v2/projects/geyser'
  $latest = $g.versions[-1]
  Write-Output ("  project versions (last 3): {0}" -f (($g.versions | Select-Object -Last 3) -join ', '))
  $b = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 `
    -Uri "https://download.geysermc.org/v2/projects/geyser/versions/$latest/builds/latest"
  $sp = $b.downloads.spigot
  Write-Output ("  latest version {0} build {1}" -f $latest, $b.build)
  Show -Name 'geyser' -Version ("{0}-b{1}" -f $latest, $b.build) -File $sp.name `
       -Algo 'sha256' -Hash $sp.sha256 `
       -Url ("https://download.geysermc.org/v2/projects/geyser/versions/{0}/builds/{1}/downloads/spigot" -f $latest, $b.build) `
       -Source 'download.geysermc.org/v2' `
       -Note 'Geyser tracks the newest Minecraft release; it is not pinned per MC version'
} catch {
  Write-Output ("  FAILED: " + $_.Exception.Message)
}

Write-Output ''
Write-Output '=== GrimAC ==='
Write-Output '  NO BUILD FOR 26.2. plugin-support.ps1: latest 2.3.73 states 1.21.11 only.'
Write-Output '  It cannot come to 26.2 and stays quarantined. Row 50 remains unclaimable.'
