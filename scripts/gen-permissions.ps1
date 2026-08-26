# gen-permissions.ps1 - reads server/permissions.yml and emits:
#   scripts/remote/apply-permissions.sh   - builds the ladder in LuckPerms
#   scripts/remote/verify-permissions.sh  - acceptance 17.5, node by node
#
# Both drive LuckPerms through RCON, because LuckPerms has no file-based import that
# is safe to hand-edit and its own storage format is an implementation detail. Its
# commands are the supported interface, and they are idempotent - setting a
# permission that is already set is a no-op that reports as such.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $repo 'server\permissions.yml'

# ---- parse the fixed shape of permissions.yml --------------------------------
$groups = @()
$never  = @()
$tests  = @()
$reals  = @()
$section = ''
$curGroup = $null
$curNever = $null
$curTest = $null
$curReal = $null

foreach ($raw in Get-Content -LiteralPath $src) {
  if ($raw -match '^\s*#') { continue }
  if ($raw -match '^groups:\s*$')              { $section = 'groups'; continue }
  if ($raw -match '^never_grant_to_admin:\s*$'){ if ($curGroup) { $groups += [pscustomobject]$curGroup; $curGroup = $null }; $section = 'never'; continue }
  if ($raw -match '^real_accounts:\s*$')       { if ($curGroup) { $groups += [pscustomobject]$curGroup; $curGroup = $null }; $section = 'real'; continue }
  if ($raw -match '^test_accounts:\s*$')       { if ($curNever) { $never += [pscustomobject]$curNever; $curNever = $null }; $section = 'tests'; continue }
  if ($raw -match '^\S' -and $raw -notmatch '^\s') { $section = ''; continue }

  switch ($section) {
    'groups' {
      if ($raw -match '^\s*-\s+name:\s*(\S+)\s*$') {
        if ($curGroup) { $groups += [pscustomobject]$curGroup }
        $curGroup = @{ name = $Matches[1]; inherits = @(); granted = @(); weight = 0; display = '' }
        continue
      }
      if ($null -eq $curGroup) { continue }
      if ($raw -match '^\s+display:\s*(.+?)\s*$') { $curGroup.display = $Matches[1]; continue }
      if ($raw -match '^\s+weight:\s*(\d+)\s*$')  { $curGroup.weight  = [int]$Matches[1]; continue }
      if ($raw -match '^\s+inherits:\s*\[\s*\]\s*$') { $curGroup.inherits = @(); continue }
      if ($raw -match '^\s+inherits:\s*\[(.+?)\]\s*$') {
        $curGroup.inherits = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        continue
      }
      if ($raw -match '^\s+granted:\s*$') { continue }
      if ($raw -match '^\s+-\s+(\S+)\s*$') { $curGroup.granted += $Matches[1]; continue }
    }
    'never' {
      if ($raw -match "^\s*-\s+node:\s*'?(.+?)'?\s*$") {
        if ($curNever) { $never += [pscustomobject]$curNever }
        $curNever = @{ node = $Matches[1]; why = '' }
        continue
      }
      if ($null -ne $curNever -and $raw -match '^\s+why:\s*"(.*)"\s*$') { $curNever.why = $Matches[1]; continue }
    }
    'tests' {
      if ($raw -match "^\s*-\s+uuid:\s*'(.+?)'\s*$") {
        if ($curTest) { $tests += [pscustomobject]$curTest }
        $curTest = @{ uuid = $Matches[1]; name = ''; group = ''; purpose = '' }
        continue
      }
      if ($null -eq $curTest) { continue }
      if ($raw -match "^\s+name:\s*'(.+?)'\s*$")    { $curTest.name  = $Matches[1]; continue }
      if ($raw -match '^\s+group:\s*(\S+)\s*$')     { $curTest.group = $Matches[1]; continue }
      if ($raw -match "^\s+purpose:\s*'(.*)'\s*$")  { $curTest.purpose = $Matches[1]; continue }
    }
    'real' {
      if ($raw -match "^\s*-\s+uuid:\s*'(.+?)'\s*$") {
        if ($curReal) { $reals += [pscustomobject]$curReal }
        $curReal = @{ uuid = $Matches[1]; name = ''; group = ''; note = '' }
        continue
      }
      if ($null -eq $curReal) { continue }
      if ($raw -match "^\s+name:\s*'(.+?)'\s*$")  { $curReal.name  = $Matches[1]; continue }
      if ($raw -match '^\s+group:\s*(\S+)\s*$')   { $curReal.group = $Matches[1]; continue }
      if ($raw -match "^\s+note:\s*'(.*)'\s*$")   { $curReal.note  = $Matches[1]; continue }
    }
  }
}
if ($curGroup) { $groups += [pscustomobject]$curGroup }
if ($curNever) { $never  += [pscustomobject]$curNever }
if ($curTest)  { $tests  += [pscustomobject]$curTest }
if ($curReal)  { $reals  += [pscustomobject]$curReal }

if ($groups.Count -eq 0) { throw 'No groups parsed' }
if ($never.Count -eq 0)  { throw 'No never-grant nodes parsed - refusing to generate a ladder with no denials' }
if ($tests.Count -eq 0)  { throw 'No test accounts parsed - 17.5 cannot be verified' }

foreach ($t in $tests) {
  if ($t.uuid -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
    throw "Test account UUID '$($t.uuid)' is not a valid version 4 UUID. LuckPerms will reject it."
  }
}

# The RCON client used by both scripts. Written once here.
function Add-RconClient {
  param([System.Collections.Generic.List[string]]$o)
  $a = { param($s) $o.Add($s) }
  & $a 'V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)'
  & $a 'D="/var/lib/pelican/volumes/$V"'
  & $a 'CIP=$(sudo -n docker inspect "$V" --format ''{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'')'
  & $a ''
  & $a 'if ! sudo -n docker ps --format ''{{.Names}}'' | grep -q "$V"; then'
  & $a '  echo "ABORT: the server is not running. LuckPerms is driven through RCON, which needs a live server."'
  & $a '  exit 2'
  & $a 'fi'
  & $a ''
  & $a 'cat > /tmp/lt-lp.py <<''LT_PY_EOF'''
  & $a 'import socket, struct, sys, time, re'
  & $a 'PROPS, HOST = sys.argv[1], sys.argv[2]'
  & $a 'pw, port = None, 25575'
  & $a 'with open(PROPS, "r", encoding="utf-8", errors="replace") as f:'
  & $a '    for line in f:'
  & $a '        if line.startswith("rcon.password="):'
  & $a '            pw = line.split("=", 1)[1].strip()'
  & $a '        elif line.startswith("rcon.port="):'
  & $a '            port = int(line.split("=", 1)[1].strip())'
  & $a 'if not pw:'
  & $a '    print("NO_RCON_PASSWORD"); sys.exit(3)'
  & $a ''
  & $a 'def pkt(rid, typ, body):'
  & $a '    p = struct.pack("<ii", rid, typ) + body.encode("utf8") + b"\x00\x00"'
  & $a '    return struct.pack("<i", len(p)) + p'
  & $a ''
  & $a 'def rd(s):'
  & $a '    raw = b""'
  & $a '    while len(raw) < 4:'
  & $a '        c = s.recv(4 - len(raw))'
  & $a '        if not c: return ""'
  & $a '        raw += c'
  & $a '    (n,) = struct.unpack("<i", raw)'
  & $a '    b = b""'
  & $a '    while len(b) < n:'
  & $a '        c = s.recv(n - len(b))'
  & $a '        if not c: break'
  & $a '        b += c'
  & $a '    return b[8:-2].decode("utf8", errors="replace")'
  & $a ''
  & $a 's = socket.create_connection((HOST, port), timeout=20)'
  & $a 's.settimeout(30)'
  & $a 's.sendall(pkt(1, 3, pw))'
  & $a 'rd(s)'
  & $a ''
  & $a '# Commands are read from stdin, one per line, so a long ladder needs one'
  & $a '# connection rather than one per command.'
  & $a 'for line in sys.stdin:'
  & $a '    cmd = line.strip()'
  & $a '    if not cmd or cmd.startswith("#"):'
  & $a '        continue'
  & $a '    s.sendall(pkt(2, 2, cmd))'
  & $a '    out = rd(s)'
  & $a '    out = re.sub(r"\xa7.", "", out).strip().replace("\n", " | ")'
  & $a '    print("%-64s -> %s" % (cmd[:64], out[:200]))'
  & $a '    time.sleep(0.15)'
  & $a 's.close()'
  & $a 'LT_PY_EOF'
  & $a ''
}

# ---- applier ----------------------------------------------------------------
$o = New-Object System.Collections.Generic.List[string]
$a = { param($s) $o.Add($s) }

& $a '# apply-permissions.sh - GENERATED by scripts/gen-permissions.ps1. Do not edit.'
& $a '# Edit server/permissions.yml and regenerate.'
& $a '#'
& $a ('# Builds {0} groups, {1} explicit denials on admin, and {2} test accounts.' -f $groups.Count, $never.Count, $tests.Count)
& $a '#'
& $a '# LuckPerms commands are idempotent: creating a group that exists, or setting a'
& $a '# permission already set, reports "already" and changes nothing. So this is safe'
& $a '# to re-run and is part of the deploy.'
& $a ''
& $a 'set -e'
Add-RconClient -o $o
& $a 'CMDS=$(mktemp)'
& $a 'trap ''rm -f "$CMDS" /tmp/lt-lp.py'' EXIT'
& $a ''
& $a 'cat > "$CMDS" <<''LT_CMD_EOF'''
& $a '# --- groups ---'
foreach ($g in $groups) {
  & $a ("lp creategroup {0}" -f $g.name)
}
& $a '# --- display names and weights (weight decides prefix precedence) ---'
foreach ($g in $groups) {
  if ($g.display) { & $a ("lp group {0} meta setdisplayname {1}" -f $g.name, $g.display) }
  & $a ("lp group {0} meta set weight {1}" -f $g.name, $g.weight)
}
& $a '# --- inheritance ---'
foreach ($g in $groups) {
  foreach ($p in $g.inherits) { & $a ("lp group {0} parent add {1}" -f $g.name, $p) }
}
& $a '# --- granted nodes ---'
foreach ($g in $groups) {
  foreach ($n in $g.granted) { & $a ("lp group {0} permission set {1} true" -f $g.name, $n) }
}
& $a '# --- the never-grant list, as EXPLICIT DENIALS on admin ---'
& $a '# An explicit false beats an inherited true in LuckPerms, so these keep working'
& $a '# even if someone later grants the node further up the chain.'
foreach ($n in $never) {
  & $a ("lp group admin permission set {0} false" -f $n.node)
}
& $a '# --- real accounts: the mapping from a human to a group ---'
& $a '# `parent set` rather than `parent add`: it replaces whatever the user had, so'
& $a '# re-running cannot accumulate group memberships and a demotion actually demotes.'
foreach ($r in $reals) {
  & $a ("lp user {0} parent set {1}" -f $r.uuid, $r.group)
}
& $a '# --- test accounts for acceptance 17.5 ---'
foreach ($t in $tests) {
  & $a ("lp user {0} parent set {1}" -f $t.uuid, $t.group)
}
& $a 'LT_CMD_EOF'
& $a ''
& $a 'echo "=== applying $(grep -vc ''^#'' "$CMDS") LuckPerms commands ==="'
& $a 'sudo -n python3 /tmp/lt-lp.py "$D/server.properties" "$CIP" < "$CMDS"'
& $a ''
& $a 'echo "=== resulting group tree ==="'
& $a 'printf ''lp listgroups\n'' | sudo -n python3 /tmp/lt-lp.py "$D/server.properties" "$CIP"'
& $a 'echo "PERMISSIONS APPLIED"'
& $a 'echo "=== END ==="'

Set-Content -LiteralPath (Join-Path $repo 'scripts\remote\apply-permissions.sh') -Value $o -Encoding UTF8

# ---- verifier ---------------------------------------------------------------
# Built from scripts/remote/verify-permissions.template.sh with the never-grant
# list injected, so the check can never drift from server/permissions.yml.
#
# It analyses an `lp export` snapshot rather than `lp permission check`, because
# LuckPerms returns nothing to an RCON sender and the check-based version produced
# a FALSE PASS against 31 empty responses. See the template's header.
$tplPath = Join-Path $repo 'scripts\remote\verify-permissions.template.sh'
if (-not (Test-Path -LiteralPath $tplPath)) { throw "Missing $tplPath" }
$tpl = Get-Content -LiteralPath $tplPath
$neverList = ($never | ForEach-Object { $_.node }) -join "`n"

$v = New-Object System.Collections.Generic.List[string]
foreach ($line in $tpl) {
  if ($line.Trim() -eq '__NEVER_LIST__') {
    foreach ($n in $never) { $v.Add($n.node) }
  } else {
    $v.Add($line)
  }
}
$v.Insert(0, ('# verify-permissions.sh - GENERATED by scripts/gen-permissions.ps1 from ' +
              'verify-permissions.template.sh. Do not edit by hand.'))
$v.Insert(1, ("# Carries {0} never-grant nodes from server/permissions.yml." -f $never.Count))

Set-Content -LiteralPath (Join-Path $repo 'scripts\remote\verify-permissions.sh') -Value $v -Encoding UTF8


Write-Output ("parsed {0} groups, {1} never-grant nodes, {2} test accounts" -f $groups.Count, $never.Count, $tests.Count)
$groups | ForEach-Object { Write-Output ("  group {0,-8} weight {1,-4} inherits [{2}]  {3} granted" -f $_.name, $_.weight, ($_.inherits -join ','), $_.granted.Count) }
Write-Output 'wrote scripts/remote/apply-permissions.sh and scripts/remote/verify-permissions.sh'
