# diagnose-manifest.ps1 - READ ONLY. Why spark, chunky and floodgate resolved wrong.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/day-zero' }
$MC = '1.21.11'

Write-Output '=== spark : what loaders and versions does it actually list? ==='
$vs = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri 'https://api.modrinth.com/v2/project/spark/version'
Write-Output ("  total versions: " + @($vs).Count)
$loaders = @($vs | ForEach-Object { $_.loaders } | Select-Object -Unique)
Write-Output ("  loaders seen: " + ($loaders -join ', '))
$withMc = @($vs | Where-Object { $_.game_versions -contains $MC })
Write-Output ("  versions listing {0}: {1}" -f $MC, $withMc.Count)
foreach ($v in $withMc[0..([Math]::Min(3, $withMc.Count - 1))]) {
  Write-Output ("    {0,-26} type {1,-8} loaders {2}" -f $v.version_number, $v.version_type, ($v.loaders -join '/'))
  foreach ($f in $v.files) { Write-Output ("       file " + $f.filename) }
}

Write-Output ''
Write-Output '=== chunky : is there a newer bukkit build than 1.4.40? ==='
$cv = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri 'https://api.modrinth.com/v2/project/chunky/version'
$cb = @($cv | Where-Object { $_.loaders -contains 'bukkit' -or $_.loaders -contains 'paper' -or $_.loaders -contains 'spigot' })
Write-Output ("  bukkit-family builds: " + $cb.Count)
foreach ($v in $cb[0..([Math]::Min(5, $cb.Count - 1))]) {
  $hasMc = if ($v.game_versions -contains $MC) { 'YES' } else { 'no ' }
  Write-Output ("    {0,-12} type {1,-8} supports {2} {3}  files: {4}" -f $v.version_number, $v.version_type, $MC, $hasMc, (($v.files | ForEach-Object { $_.filename }) -join ' '))
}

Write-Output ''
Write-Output '=== floodgate : version list order from the GeyserMC API ==='
$fp = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri 'https://download.geysermc.org/v2/projects/floodgate'
Write-Output ("  versions array: " + ($fp.versions -join ', '))
Write-Output ("  versions[0]  = " + $fp.versions[0])
Write-Output ("  versions[-1] = " + $fp.versions[-1])
if ($fp.PSObject.Properties.Name -contains 'latest') { Write-Output ("  latest field = " + $fp.latest) }
