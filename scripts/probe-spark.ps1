# probe-spark.ps1 - READ ONLY. Follow spark's download endpoint to a versioned file.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'Mozilla/5.0 LaughTail-SMP/day-zero' }

foreach ($u in @(
    'https://spark.lucko.me/download/stable/bukkit',
    'https://sparkapi.lucko.me/download/bukkit/stable',
    'https://ci.lucko.me/job/spark/lastStableBuild/api/json?tree=number,url,artifacts[fileName,relativePath]'
)) {
  Write-Output ("=== " + $u)
  try {
    $r = Invoke-WebRequest -Uri $u -Headers $hdr -TimeoutSec 30 -ErrorAction Stop
    Write-Output ("  status {0}  type {1}  len {2}" -f $r.StatusCode, $r.Headers['Content-Type'], $r.RawContentLength)
    Write-Output ("  final uri: " + $r.BaseResponse.ResponseUri)
    $cd = $r.Headers['Content-Disposition']
    if ($cd) { Write-Output ("  content-disposition: " + $cd) }
    if ($r.Headers['Content-Type'] -like '*json*') {
      $j = $r.Content | ConvertFrom-Json
      if ($j.number) { Write-Output ("  build number: " + $j.number) }
      if ($j.artifacts) { $j.artifacts | ForEach-Object { Write-Output ("  artifact " + $_.fileName + "  rel " + $_.relativePath) } }
    }
  } catch {
    if ($_.Exception.Response) { Write-Output ("  status " + [int]$_.Exception.Response.StatusCode) }
    else { Write-Output ("  error: " + $_.Exception.Message) }
  }
  Write-Output ''
}
