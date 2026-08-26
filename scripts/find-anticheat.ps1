# find-anticheat.ps1 - READ ONLY. Which anti-cheats state support for our version?
#
# GrimAC has no 26.2 build, so acceptance row 50 cannot be satisfied and the server
# cannot open to paying players (14.1). This asks Modrinth which server-side
# anti-cheats actually state 26.2, rather than relying on what was true last year.
#
# Spec 14.1's guidance is explicit and worth restating before reading the results:
#   "Start with the free movement anti-cheat, monitor false positives and cheat
#    reports for one full season, and add a paid combat layer only if real evidence
#    shows you need it. Do not buy anti-cheat you have not proven you need."
# So a free, movement-focused, actively maintained option is what to look for. A paid
# combat layer is explicitly a later decision, not this one.

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$hdr = @{ 'User-Agent' = 'LaughTail-SMP/anticheat-survey' }
$MC = '26.2'

function Search-Modrinth {
  param([string]$Query)
  $facets = '[["project_type:plugin"],["versions:' + $MC + '"]]'
  $url = 'https://api.modrinth.com/v2/search?query=' + [uri]::EscapeDataString($Query) +
         '&facets=' + [uri]::EscapeDataString($facets) + '&limit=15&index=relevance'
  try { return Invoke-RestMethod -Uri $url -Headers $hdr -TimeoutSec 30 }
  catch { Write-Output ("  search failed: " + $_.Exception.Message); return $null }
}

Write-Output "=== Modrinth plugins matching 'anticheat' that state $MC ==="
$r = Search-Modrinth 'anticheat'
if ($r) {
  foreach ($h in $r.hits) {
    Write-Output ("  {0,-26} downloads {1,-10} {2}" -f $h.slug, $h.downloads, $h.title)
    Write-Output ("      {0}" -f ($h.description -replace '\s+', ' ').Substring(0, [Math]::Min(110, $h.description.Length)))
  }
}

Write-Output ''
Write-Output "=== also searching 'cheat detection' and 'movement check' ==="
foreach ($q in 'cheat detection', 'movement checks', 'combat cheat') {
  Write-Output ("--- $q ---")
  $r2 = Search-Modrinth $q
  if ($r2) {
    foreach ($h in ($r2.hits | Select-Object -First 6)) {
      Write-Output ("  {0,-26} downloads {1}" -f $h.slug, $h.downloads)
    }
  }
}

Write-Output ''
Write-Output '=== named candidates checked directly ==='
# Names known in this space. Checked individually because search ranking is not proof
# of version support, and several of these are paid and not on Modrinth at all.
$named = @('grimac', 'vulcan-anticheat', 'themis', 'negativity', 'anticheatreloaded',
           'spartan-anticheat', 'matrix-anticheat', 'polar-anticheat', 'nocheatplus',
           'exploitfixer', 'anti-xray', 'packetevents')
foreach ($slug in $named) {
  try {
    $p = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$slug" -Headers $hdr -TimeoutSec 20
    $has = $p.game_versions -contains $MC
    $newest = ($p.game_versions | Select-Object -Last 1)
    Write-Output ("  {0,-22} on Modrinth. states {1}: {2,-5} newest listed: {3}  downloads {4}" -f `
      $slug, $MC, $has, $newest, $p.downloads)
  } catch {
    Write-Output ("  {0,-22} not on Modrinth" -f $slug)
  }
}
