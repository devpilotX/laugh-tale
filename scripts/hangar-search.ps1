# hangar-search.ps1 - READ ONLY. Find a project's real Hangar slug.
param([string]$Query = 'spark')
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero'; 'Accept' = 'application/json' }
try {
  $r = Invoke-RestMethod -Headers $hdr -TimeoutSec 25 -Uri ("https://hangar.papermc.io/api/v1/projects?q={0}&limit=10" -f [uri]::EscapeDataString($Query))
  Write-Output ("results: " + @($r.result).Count)
  foreach ($p in $r.result) {
    Write-Output ("  slug '{0}'  name '{1}'  author '{2}'  category {3}" -f $p.namespace.slug, $p.name, $p.namespace.owner, $p.category)
  }
} catch { Write-Output ("search failed: " + $_.Exception.Message) }
