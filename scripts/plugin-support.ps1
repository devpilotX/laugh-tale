# plugin-support.ps1 - READ ONLY. Asks each plugin's own repository which
# Minecraft versions it supports, so the version pin in the manifest is evidence
# based (spec 4.2: "Check every plugin's stated support for your exact version
# before install, not after").
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero (build planning; contact via repo)' }

# Candidate server versions, newest first, from scripts/paper-versions.ps1.
$targets = @('26.2', '26.1.2', '1.21.11')

# Modrinth slugs for the components Appendix A makes mandatory or near-mandatory.
$slugs = @(
  @{ s = 'viaversion';   role = 'Older Java clients (4.3)' }
  @{ s = 'viabackwards'; role = 'Older Java clients (4.3)' }
  @{ s = 'geyser';       role = 'Bedrock crossplay (4.4)' }
  @{ s = 'floodgate';    role = 'Bedrock auth (4.4)' }
  @{ s = 'luckperms';    role = 'Permissions (Section 17)' }
  @{ s = 'chunky';       role = 'Pregeneration (Phase 2)' }
  @{ s = 'spark';        role = 'Profiling, Law 5' }
  @{ s = 'grimac';       role = 'Simulation anti-cheat (14.1)' }
  @{ s = 'vault';        role = 'Economy bridge (Section 8)' }
  @{ s = 'simple-voice-chat'; role = 'Proximity voice (Section 13)' }
)

Write-Output ("targets: " + ($targets -join ', '))
Write-Output ''

foreach ($p in $slugs) {
  $url = "https://api.modrinth.com/v2/project/$($p.s)/version"
  try {
    $vs = Invoke-RestMethod -Uri $url -Headers $hdr -TimeoutSec 25
  } catch {
    Write-Output ("{0,-20} NOT ON MODRINTH or error: {1}" -f $p.s, $_.Exception.Message)
    continue
  }

  # Only Paper/Bukkit-loadable releases matter here.
  $rel = @($vs | Where-Object { $_.version_type -eq 'release' -and ($_.loaders -contains 'paper' -or $_.loaders -contains 'bukkit' -or $_.loaders -contains 'spigot' -or $_.loaders -contains 'purpur') })
  if ($rel.Count -eq 0) { $rel = @($vs | Where-Object { $_.version_type -eq 'release' }) }
  if ($rel.Count -eq 0) { Write-Output ("{0,-20} no release versions" -f $p.s); continue }

  $latest = $rel[0]
  $supported = @($rel | ForEach-Object { $_.game_versions } | Select-Object -Unique)

  $hits = @()
  foreach ($t in $targets) { if ($supported -contains $t) { $hits += $t } }

  $newest3 = (@($supported | Sort-Object -Descending)[0..([Math]::Min(3, $supported.Count - 1))]) -join ', '
  Write-Output ("{0,-20} latest {1,-22} supports target: {2,-18} newest MC seen: {3}" -f `
    $p.s, $latest.version_number, $(if ($hits.Count) { $hits -join '/' } else { 'NONE' }), $newest3)
}
