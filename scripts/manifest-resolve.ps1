# manifest-resolve.ps1 - READ ONLY against the network; writes server/manifest.yml.
#
# Never-break rule 9: never install a plugin that is not in the manifest with a
# pinned version and a checksum. This resolves each component from its own
# publisher and records the checksum the PUBLISHER states - never one computed
# from a file we already downloaded, which would only prove the file matches itself.
#
# Version pin comes from docs/decisions.md D-0011: Minecraft 1.21.11.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = Split-Path -Parent $PSScriptRoot
$hdr  = @{ 'User-Agent' = 'LaughTail-SMP/day-zero (manifest resolution)' }
$MC   = '1.21.11'

$rows = New-Object System.Collections.Generic.List[object]

function Add-Row {
  param($Name, $Role, $Version, $File, $Algo, $Hash, $Url, $Source, $Notes = '')
  $rows.Add([pscustomobject]@{
    name = $Name; role = $Role; version = $Version; file = $File
    algo = $Algo; hash = $Hash; url = $Url; source = $Source; notes = $Notes
  })
  Write-Output ("  resolved {0,-20} {1,-24} {2}" -f $Name, $Version, $Algo)
}

# ---- Paper -------------------------------------------------------------------
Write-Output '=== Paper ==='
$builds = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri ("https://fill.papermc.io/v3/projects/paper/versions/{0}/builds" -f $MC)
$pb = @($builds | Where-Object { $_.channel -eq 'STABLE' })[0]
$pj = $pb.downloads.'server:default'

# Spec 4.2: "Use the JDK the current Paper build asks for." That lives on the
# version object, not the build object.
$javaMin = 'unknown'
try {
  $verObj = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri ("https://fill.papermc.io/v3/projects/paper/versions/{0}" -f $MC)
  if ($verObj.version.java.version.minimum) { $javaMin = $verObj.version.java.version.minimum }
  elseif ($verObj.java.version.minimum)     { $javaMin = $verObj.java.version.minimum }
  elseif ($verObj.version.java.minimum)     { $javaMin = $verObj.version.java.minimum }
} catch { }
Write-Output ("  java minimum stated by PaperMC: " + $javaMin)

Add-Row 'paper' 'Server software (4.1)' ("{0}-{1}" -f $MC, $pb.id) $pj.name 'sha256' $pj.checksums.sha256 $pj.url 'fill.papermc.io/v3' ("java_minimum {0}; jar size {1} bytes; built {2}" -f $javaMin, $pj.size, $pb.time)

# ---- GeyserMC family (own API, states sha256) --------------------------------
Write-Output '=== GeyserMC ==='
foreach ($g in @(
    @{ p = 'geyser';    art = 'spigot'; role = 'Bedrock crossplay (4.4)' },
    @{ p = 'floodgate'; art = 'spigot'; role = 'Bedrock authentication (4.4)' })) {
  $proj = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri ("https://download.geysermc.org/v2/projects/{0}" -f $g.p)
  $ver  = $proj.versions[-1]
  $b    = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri ("https://download.geysermc.org/v2/projects/{0}/versions/{1}/builds/latest" -f $g.p, $ver)
  $d    = $b.downloads.($g.art)
  $url  = "https://download.geysermc.org/v2/projects/$($g.p)/versions/$ver/builds/$($b.build)/downloads/$($g.art)"
  Add-Row $g.p $g.role ("{0}-b{1}" -f $ver, $b.build) $d.name 'sha256' $d.sha256 $url 'download.geysermc.org/v2' ''
}

# ---- Modrinth-published components (state sha512 and sha1) -------------------
Write-Output '=== Modrinth ==='
$mod = @(
  @{ s = 'viaversion';        role = 'Older Java client support (4.3)';     match = 'ViaVersion' }
  @{ s = 'viabackwards';      role = 'Older Java client support (4.3)';     match = 'ViaBackwards' }
  @{ s = 'luckperms';         role = 'Permissions ladder (Section 17)';     match = 'Bukkit' }
  @{ s = 'chunky';            role = 'World pregeneration (Phase 2)';       match = 'Chunky' }
  @{ s = 'grimac';            role = 'Simulation anti-cheat (14.1)';        match = 'grimac|Grim' }
  @{ s = 'simple-voice-chat'; role = 'Proximity voice (Section 13)';        match = 'bukkit' }
)

foreach ($m in $mod) {
  $vs = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 -Uri "https://api.modrinth.com/v2/project/$($m.s)/version"
  # Must state support for our exact pin, and load on Paper.
  $ok = @($vs | Where-Object {
    $_.game_versions -contains $MC -and
    ($_.loaders -contains 'paper' -or $_.loaders -contains 'bukkit' -or $_.loaders -contains 'spigot')
  })
  if ($ok.Count -eq 0) { Write-Output ("  ! {0}: no build states support for {1} on paper/bukkit/spigot" -f $m.s, $MC); continue }

  # Prefer a release channel where one exists; Geyser-style projects publish beta only.
  $rel = @($ok | Where-Object { $_.version_type -eq 'release' })
  $pick = if ($rel.Count) { $rel[0] } else { $ok[0] }

  $files = @($pick.files | Where-Object { $_.filename -match $m.match })
  $f = if ($files.Count) { $files[0] } else { @($pick.files | Where-Object { $_.primary })[0] }
  if (-not $f) { $f = $pick.files[0] }

  $note = if ($pick.version_type -ne 'release') { "channel $($pick.version_type) - publisher does not ship a release channel" } else { '' }
  if ($m.s -eq 'chunky' -and $pick.version_number -ne '1.5.3') {
    $note = ("newest Chunky release is 1.5.3 but it does NOT state {0} support; {1} does. Spec 4.2 requires stated support for the exact version." -f $MC, $pick.version_number)
  }
  Add-Row $m.s $m.role $pick.version_number $f.filename 'sha512' $f.hashes.sha512 $f.url 'api.modrinth.com/v2' $note
}

# ---- emit ---------------------------------------------------------------------
$out = New-Object System.Collections.Generic.List[string]
$out.Add('# LaughTail SMP - plugin and server manifest')
$out.Add('#')
$out.Add('# Never-break rule 9: never install a plugin that is not in this manifest')
$out.Add('# with a pinned version and a checksum. Spec 4.2: never a floating latest tag.')
$out.Add('#')
$out.Add('# Every checksum here is stated by the PUBLISHER, fetched from its own API.')
$out.Add('# Regenerate with scripts/manifest-resolve.ps1. Verify with scripts/verify-manifest.ps1.')
$out.Add('#')
$out.Add(('# Resolved {0} against Minecraft {1} (decision D-0011).' -f (Get-Date -Format 'yyyy-MM-dd'), $MC))
$out.Add('#')
$out.Add('# NOT YET PROVEN: every entry still needs an aarch64 load-proof on laughtail-dev')
$out.Add('# before it is considered accepted. See docs/progress.md deviation D5.')
$out.Add('')
$out.Add(('minecraft_version: "{0}"' -f $MC))
$out.Add('architecture_required: "aarch64"')
$out.Add('')
$out.Add('# Bundled with the server - deliberately NOT a separate jar.')
$out.Add('bundled:')
$out.Add('  - name: "spark"')
$out.Add('    role: "MSPT and CPU profiling (Law 5, 6.7, rows 19 20 25 60)"')
$out.Add('    why_not_pinned: "PaperMC docs: Starting with 1.21, Paper bundles the spark profiler."')
$out.Add('    access: "/spark via the server console; no plugin jar to install"')
$out.Add('    note: "The running stock server has a leftover plugins/spark config directory but NO spark jar."')
$out.Add('')
$out.Add('components:')
foreach ($r in $rows) {
  $out.Add(('  - name: "{0}"'        -f $r.name))
  $out.Add(('    role: "{0}"'        -f $r.role))
  $out.Add(('    version: "{0}"'     -f $r.version))
  $out.Add(('    file: "{0}"'        -f $r.file))
  $out.Add(('    checksum_algo: "{0}"' -f $r.algo))
  $out.Add(('    checksum: "{0}"'    -f $r.hash))
  $out.Add(('    url: "{0}"'         -f $r.url))
  $out.Add(('    checksum_source: "{0}"' -f $r.source))
  $out.Add(('    arm64_load_proof: "not yet run"'))
  if ($r.notes) { $out.Add(('    notes: "{0}"' -f $r.notes)) }
}

$dest = Join-Path $repo 'server\manifest.yml'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
Set-Content -LiteralPath $dest -Value $out -Encoding UTF8
Write-Output ''
Write-Output ("wrote server/manifest.yml with {0} components, {1} lines" -f $rows.Count, $out.Count)
