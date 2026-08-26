# find-spark.ps1 - READ ONLY. spark's Bukkit build is not on Modrinth
# (that project lists neoforge/fabric/forge/quilt only). Find the real source.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero' }

foreach ($u in @(
    'https://sparkapi.lucko.me/download/bukkit',
    'https://sparkapi.lucko.me/download',
    'https://api.github.com/repos/lucko/spark/releases/latest')) {
  Write-Output ("=== " + $u)
  try {
    $r = Invoke-WebRequest -Uri $u -Headers $hdr -TimeoutSec 25 -MaximumRedirection 0 -ErrorAction Stop
    Write-Output ("  status {0}  type {1}  len {2}" -f $r.StatusCode, $r.Headers['Content-Type'], $r.RawContentLength)
    if ($r.Headers['Location']) { Write-Output ("  redirect -> " + $r.Headers['Location']) }
    if ($r.Headers['Content-Type'] -like '*json*') {
      $j = $r.Content | ConvertFrom-Json
      Write-Output ("  json keys: " + (($j.PSObject.Properties.Name) -join ', '))
      if ($j.tag_name) { Write-Output ("  tag: " + $j.tag_name) }
      if ($j.assets)   { $j.assets | ForEach-Object { Write-Output ("  asset " + $_.name + "  " + $_.browser_download_url) } }
      if ($j.url)      { Write-Output ("  url: " + $j.url) }
    }
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      Write-Output ("  status {0}" -f [int]$resp.StatusCode)
      $loc = $resp.Headers['Location']
      if ($loc) { Write-Output ("  redirect -> " + $loc) }
    } else { Write-Output ("  error: " + $_.Exception.Message) }
  }
  Write-Output ''
}
