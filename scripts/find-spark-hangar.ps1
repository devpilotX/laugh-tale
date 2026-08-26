# find-spark-hangar.ps1 - READ ONLY. Hangar is PaperMC's own plugin platform and
# is where Paper-targeted builds of spark live.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero'; 'Accept' = 'application/json' }
$MC = '1.21.11'

foreach ($slug in @('spark')) {
  Write-Output ("=== hangar project " + $slug)
  try {
    $p = Invoke-RestMethod -Headers $hdr -TimeoutSec 25 -Uri "https://hangar.papermc.io/api/v1/projects/$slug"
    Write-Output ("  name {0}   category {1}" -f $p.name, $p.category)
  } catch { Write-Output ("  project lookup failed: " + $_.Exception.Message) }

  try {
    $v = Invoke-RestMethod -Headers $hdr -TimeoutSec 25 -Uri "https://hangar.papermc.io/api/v1/projects/$slug/versions?limit=15"
    Write-Output ("  versions returned: " + @($v.result).Count)
    foreach ($ver in $v.result) {
      $plats = @()
      foreach ($pp in $ver.platformDependencies.PSObject.Properties) { $plats += ("{0}[{1}]" -f $pp.Name, ($pp.Value -join ' ')) }
      $paper = $ver.downloads.PAPER
      $hasMc = if (($plats -join ' ') -match [regex]::Escape($MC)) { 'YES' } else { 'no ' }
      Write-Output ("  {0,-22} channel {1,-10} {2} {3}" -f $ver.name, $ver.channel.name, $MC, $hasMc)
      Write-Output ("     platforms: " + ($plats -join '  '))
      if ($paper) {
        Write-Output ("     file {0}   sha256 {1}" -f $paper.fileInfo.name, $paper.fileInfo.sha256Hash)
        Write-Output ("     url  https://hangar.papermc.io/api/v1/projects/$slug/versions/$($ver.name)/PAPER/download")
      }
    }
  } catch { Write-Output ("  versions lookup failed: " + $_.Exception.Message) }
}
