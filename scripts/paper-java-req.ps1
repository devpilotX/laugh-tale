# paper-java-req.ps1 - READ ONLY. Spec 4.2: "Use the JDK the current Paper build
# asks for, not an older one you happen to have." Find where the API states it.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero' }
$MC = '1.21.11'

$builds = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri ("https://fill.papermc.io/v3/projects/paper/versions/{0}/builds" -f $MC)
$b = @($builds | Where-Object { $_.channel -eq 'STABLE' })[0]

Write-Output ("build id: " + $b.id)
Write-Output ("top-level keys: " + (($b.PSObject.Properties.Name) -join ', '))
if ($b.PSObject.Properties.Name -contains 'java') {
  Write-Output ("java keys: " + (($b.java.PSObject.Properties.Name) -join ', '))
  Write-Output ($b.java | ConvertTo-Json -Depth 6)
}
Write-Output '--- full build object (depth 4) ---'
Write-Output ($b | ConvertTo-Json -Depth 4)
