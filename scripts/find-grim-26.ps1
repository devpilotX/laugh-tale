# find-grim-26.ps1 - READ ONLY.
#
# CORRECTS AN EARLIER CONCLUSION. plugin-support.ps1 reported GrimAC as supporting
# only 1.21.11, and I told the owner it had no 26.2 build. That was wrong: it filtered
# to RELEASE-channel versions, and GrimAC's project-level game_versions does include
# 26.2 - so a beta or alpha build supports it. The server itself hinted at this on
# every boot: "New GrimAC version found! Version 2.3.74-961fa54".
#
# This lists every version with its channel, so the choice is made on facts:
#   - a release build that supports 26.2 would be ideal
#   - a beta build is a judgement call: anti-cheat on a paid PvP server is
#     load-bearing, and 14.1 warns about false positives punishing honest players
#   - VoidAC is a GrimAC fork and worth checking for the same reason

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/anticheat-survey' }
$MC = '26.2'

function Show-Versions {
  param([string]$Slug)
  Write-Output ""
  Write-Output "=== $Slug ==="
  try {
    $vs = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$Slug/version" -Headers $hdr -TimeoutSec 30
  } catch {
    Write-Output ("  not available: " + $_.Exception.Message); return
  }
  Write-Output ("  total versions: {0}" -f $vs.Count)
  $supporting = @($vs | Where-Object { $_.game_versions -contains $MC })
  Write-Output ("  versions stating {0}: {1}" -f $MC, $supporting.Count)
  foreach ($v in ($supporting | Select-Object -First 8)) {
    $f = @($v.files | Where-Object { $_.primary })[0]
    if (-not $f) { $f = $v.files[0] }
    Write-Output ("    {0,-24} channel {1,-8} published {2}" -f `
      $v.version_number, $v.version_type, ([string]$v.date_published).Substring(0,10))
    Write-Output ("      file   {0}" -f $f.filename)
    Write-Output ("      sha512 {0}" -f $f.hashes.sha512)
    Write-Output ("      url    {0}" -f $f.url)
    Write-Output ("      mc     {0}" -f (($v.game_versions | Select-Object -Last 6) -join ', '))
    Write-Output ("      loaders {0}" -f ($v.loaders -join ','))
  }
  if ($supporting.Count -eq 0) {
    Write-Output "    newest few versions and what they state:"
    foreach ($v in ($vs | Select-Object -First 4)) {
      Write-Output ("    {0,-24} channel {1,-8} mc: {2}" -f $v.version_number, $v.version_type,
        (($v.game_versions | Select-Object -Last 4) -join ', '))
    }
  }
}

Show-Versions -Slug 'grimac'
Show-Versions -Slug 'voidac'
Show-Versions -Slug 'spartan-anticheat'
