# check-geyser-for.ps1 - READ ONLY. Finds the newest Geyser build that states
# support for a given Java server version. Geyser publishes on Modrinth as beta,
# so version_type is not filtered here - the game_versions list is what matters.
param([string]$Target = '1.21.11')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero (build planning)' }

foreach ($slug in @('geyser','floodgate')) {
  Write-Output ("=== {0} : builds mentioning {1} ===" -f $slug, $Target)
  try {
    $vs = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$slug/version" -Headers $hdr -TimeoutSec 25
  } catch { Write-Output ("  error: " + $_.Exception.Message); continue }

  $match = @($vs | Where-Object { $_.game_versions -contains $Target })
  Write-Output ("  total builds: {0}   supporting {1}: {2}" -f @($vs).Count, $Target, $match.Count)

  foreach ($m in $match[0..([Math]::Min(2, $match.Count - 1))]) {
    $paperFile = @($m.files | Where-Object { $_.filename -match 'Spigot|Paper|Bukkit' })
    $f = if ($paperFile.Count) { $paperFile[0] } else { $m.files[0] }
    Write-Output ("  {0,-22} type {1,-7} loaders {2}" -f $m.version_number, $m.version_type, ($m.loaders -join '/'))
    Write-Output ("     file {0}" -f $f.filename)
    Write-Output ("     sha512-prefix {0}" -f $f.hashes.sha512.Substring(0,32))
    Write-Output ("     sha1 {0}" -f $f.hashes.sha1)
    Write-Output ("     url  {0}" -f $f.url)
  }
  if ($match.Count -eq 0) {
    $all = @($vs | ForEach-Object { $_.game_versions } | Select-Object -Unique)
    Write-Output ("  NONE. versions seen include: " + (($all | Select-Object -First 12) -join ', '))
  }
  Write-Output ''
}
