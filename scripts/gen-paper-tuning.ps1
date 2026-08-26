# gen-paper-tuning.ps1 - reads server/paper-tuning.yml and emits two scripts:
#   scripts/remote/apply-paper-tuning.sh   - sets the managed keys
#   scripts/remote/check-paper-drift.sh    - reports on them, changes nothing
#
# The registry is parsed here rather than on the host so a malformed entry fails on
# the build PC instead of halfway through editing a live config.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $repo 'server\paper-tuning.yml'

# Minimal parser for the fixed shape this file uses. Deliberately strict: anything
# unexpected throws rather than being skipped, because a silently ignored entry
# would mean a setting nobody applied and nobody noticed.
$entries = @()
$cur = $null
$inManaged = $false
foreach ($raw in Get-Content -LiteralPath $src) {
  $line = $raw
  if ($line -match '^\s*#') { continue }
  if ($line -match '^managed:\s*$') { $inManaged = $true; continue }
  if (-not $inManaged) { continue }
  if ($line -match '^\S') { $inManaged = $false; continue }   # next top-level block
  if ($line -match '^\s*-\s+file:\s*(\S+)\s*$') {
    if ($cur) { $entries += [pscustomobject]$cur }
    $cur = @{ file = $Matches[1] }
    continue
  }
  if ($null -eq $cur) { continue }
  if ($line -match '^\s+key:\s*(\S+)\s*$')        { $cur.key   = $Matches[1]; continue }
  if ($line -match '^\s+type:\s*(\S+)\s*$')       { $cur.type  = $Matches[1]; continue }
  if ($line -match '^\s+value:\s*(.+?)\s*$')      { $cur.value = $Matches[1]; continue }
  if ($line -match '^\s+why:\s*"(.*)"\s*$')       { $cur.why   = $Matches[1]; continue }
}
if ($cur) { $entries += [pscustomobject]$cur }

if ($entries.Count -eq 0) { throw 'No managed entries parsed from server/paper-tuning.yml' }
foreach ($e in $entries) {
  foreach ($p in 'file', 'key', 'value', 'type', 'why') {
    if (-not $e.PSObject.Properties.Name.Contains($p)) {
      throw "Entry for key '$($e.key)' is missing '$p'"
    }
  }
  if ($e.type -notin @('bool', 'int', 'str')) { throw "Unknown type '$($e.type)' for $($e.key)" }
}

# The python payload is shared by both scripts. It is written to the host as a file
# rather than inlined into a shell string, because YAML keys contain dots and
# quoting a python program through bash through base64 is where errors hide.
function Get-PythonPayload {
  param([bool]$Apply)
  $py = New-Object System.Collections.Generic.List[string]
  $py.Add('import sys, yaml, io')
  $py.Add('')
  $py.Add('APPLY = ' + ($(if ($Apply) { 'True' } else { 'False' })))
  $py.Add('')
  $py.Add('# path, key, expected value')
  $py.Add('TARGETS = [')
  foreach ($e in $entries) {
    $v = switch ($e.type) {
      'bool' { if ($e.value -eq 'true') { 'True' } else { 'False' } }
      'int'  { [string][int]$e.value }
      'str'  { "'" + ($e.value -replace "'", "\'") + "'" }
    }
    $py.Add(("    ({0}, {1}, {2})," -f ("'" + $e.file + "'"), ("'" + $e.key + "'"), $v))
  }
  $py.Add(']')
  $py.Add('')
  $py.Add('BASE = sys.argv[1]')
  $py.Add('')
  $py.Add('def get_path(doc, parts):')
  $py.Add('    node = doc')
  $py.Add('    for p in parts:')
  $py.Add('        if not isinstance(node, dict) or p not in node:')
  $py.Add('            return (False, None)')
  $py.Add('        node = node[p]')
  $py.Add('    return (True, node)')
  $py.Add('')
  $py.Add('changed_files = {}')
  $py.Add('missing = 0')
  $py.Add('drift = 0')
  $py.Add('docs = {}')
  $py.Add('')
  $py.Add('for rel, key, want in TARGETS:')
  $py.Add('    full = BASE + "/" + rel')
  $py.Add('    if rel not in docs:')
  $py.Add('        with open(full, "r", encoding="utf-8") as f:')
  $py.Add('            docs[rel] = yaml.safe_load(f)')
  $py.Add('    doc = docs[rel]')
  $py.Add('    parts = key.split(".")')
  $py.Add('    exists, have = get_path(doc, parts)')
  $py.Add('    if not exists:')
  $py.Add('        # Fail closed. Paper ignores unknown keys silently, so inventing one')
  $py.Add('        # would look applied and do nothing at all.')
  $py.Add('        print("  MISSING KEY   %s :: %s  - refusing to create it" % (rel, key))')
  $py.Add('        missing += 1')
  $py.Add('        continue')
  $py.Add('    if have == want:')
  $py.Add('        print("  ok            %s :: %s = %r" % (rel, key, have))')
  $py.Add('        continue')
  $py.Add('    drift += 1')
  $py.Add('    if APPLY:')
  $py.Add('        node = doc')
  $py.Add('        for p in parts[:-1]:')
  $py.Add('            node = node[p]')
  $py.Add('        node[parts[-1]] = want')
  $py.Add('        changed_files[rel] = True')
  $py.Add('        print("  SET           %s :: %s  %r -> %r" % (rel, key, have, want))')
  $py.Add('    else:')
  $py.Add('        print("  DRIFT         %s :: %s  live=%r expected=%r" % (rel, key, have, want))')
  $py.Add('')
  $py.Add('if missing:')
  $py.Add('    print("ABORT: %d managed key(s) do not exist in the live config." % missing)')
  $py.Add('    print("Paper may have renamed them. Re-derive paths with paper-config-paths.sh")')
  $py.Add('    print("and update server/paper-tuning.yml. Nothing was written.")')
  $py.Add('    sys.exit(4)')
  $py.Add('')
  if ($Apply) {
    $py.Add('for rel in changed_files:')
    $py.Add('    full = BASE + "/" + rel')
    $py.Add('    tmp = "/tmp/lt-" + rel.replace("/", "_")')
    $py.Add('    with open(tmp, "w", encoding="utf-8") as f:')
    $py.Add('        yaml.safe_dump(docs[rel], f, default_flow_style=False, sort_keys=False, allow_unicode=True)')
    $py.Add('    print("wrote %s" % tmp)')
    $py.Add('print("FILES_TO_INSTALL=" + ",".join(changed_files.keys()))')
    $py.Add('if not changed_files:')
    $py.Add('    print("nothing to change")')
  } else {
    $py.Add('print("drift=%d" % drift)')
    $py.Add('sys.exit(1 if drift else 0)')
  }
  return $py
}

# ---- applier -----------------------------------------------------------------
$o = New-Object System.Collections.Generic.List[string]
$a = { param($s) $o.Add($s) }
& $a '# apply-paper-tuning.sh - GENERATED by scripts/gen-paper-tuning.ps1. Do not edit.'
& $a '# Edit server/paper-tuning.yml and regenerate.'
& $a '#'
& $a ('# Applies {0} managed key(s). Refuses to create a key that does not already' -f $entries.Count)
& $a '# exist, because Paper ignores unknown keys without any error - an invented key'
& $a '# would look applied and do nothing.'
& $a '#'
& $a '# NOTE: YAML comments in the live files are lost, because PyYAML does not'
& $a '# round-trip them. That is accepted for the same reason it is accepted for'
& $a '# server.properties (D-0015): the reasons live in the repository, which is the'
& $a '# source of truth, and Paper rewrites these files itself anyway. Paper will'
& $a '# regenerate its own comments on the next config migration.'
& $a ''
& $a 'set -e'
& $a 'V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)'
& $a 'D="/var/lib/pelican/volumes/$V"'
& $a 'OWN=999:987'
& $a ''
& $a 'echo "=== container must be stopped ==="'
& $a '# Paper reads these at boot and rewrites them at shutdown, so editing a running'
& $a '# server loses the edit silently - the same trap as server.properties.'
& $a 'if sudo -n docker ps --format ''{{.Names}}'' | grep -q "$V"; then'
& $a '  echo "ABORT: container is running. Stop it first or the edit is discarded at shutdown."'
& $a '  exit 2'
& $a 'fi'
& $a 'echo "confirmed stopped"'
& $a ''
& $a 'echo "=== backing up the config files once ==="'
& $a 'sudo -n mkdir -p "$D/_quarantine/config-prebuild"'
& $a 'for f in config/paper-global.yml config/paper-world-defaults.yml spigot.yml bukkit.yml; do'
& $a '  BN=$(basename "$f")'
& $a '  if sudo -n test -f "$D/$f" && ! sudo -n test -f "$D/_quarantine/config-prebuild/$BN"; then'
& $a '    sudo -n cp -p "$D/$f" "$D/_quarantine/config-prebuild/$BN"'
& $a '    echo "  saved $BN"'
& $a '  fi'
& $a 'done'
& $a ''
& $a 'cat > /tmp/lt-paper-tune.py <<''LT_PY_EOF'''
foreach ($l in (Get-PythonPayload -Apply $true)) { & $a $l }
& $a 'LT_PY_EOF'
& $a ''
& $a 'echo "=== applying managed keys ==="'
& $a 'OUT=$(sudo -n python3 /tmp/lt-paper-tune.py "$D")'
& $a 'echo "$OUT"'
& $a ''
& $a 'FILES=$(echo "$OUT" | sed -n ''s/^FILES_TO_INSTALL=//p'')'
& $a 'if [ -z "$FILES" ]; then'
& $a '  echo "no files needed changing"'
& $a 'else'
& $a '  echo "=== installing changed files ==="'
& $a '  IFS='','' ; for rel in $FILES; do'
& $a '    TMP="/tmp/lt-$(echo "$rel" | tr ''/'' ''_'')"'
& $a '    sudo -n cp "$TMP" "$D/$rel"'
& $a '    sudo -n chown $OWN "$D/$rel"'
& $a '    sudo -n chmod 644 "$D/$rel"'
& $a '    sudo -n stat -c ''  installed %n owner=%u:%g mode=%a size=%s'' "$D/$rel"'
& $a '    # sudo: python3 ran under sudo, so the temp file is root-owned, and /tmp is'
& $a '    # sticky - the ubuntu user cannot remove another user''s file there. Without'
& $a '    # sudo this fails and set -e aborts the loop before later files install.'
& $a '    sudo -n rm -f "$TMP"'
& $a '  done'
& $a '  unset IFS'
& $a 'fi'
& $a 'rm -f /tmp/lt-paper-tune.py'
& $a 'echo "PAPER TUNING APPLIED"'
& $a 'echo "=== END ==="'
Set-Content -LiteralPath (Join-Path $repo 'scripts\remote\apply-paper-tuning.sh') -Value $o -Encoding UTF8

# ---- drift checker -----------------------------------------------------------
$d = New-Object System.Collections.Generic.List[string]
$da = { param($s) $d.Add($s) }
& $da '# check-paper-drift.sh - GENERATED by scripts/gen-paper-tuning.ps1. READ ONLY.'
& $da '#'
& $da '# Reports whether the managed Paper keys still match the repository. Checks ONLY'
& $da '# those keys - Paper owns everything else, and comparing whole files would report'
& $da '# drift on every boot and config migration (see D-0015).'
& $da '#'
& $da '# Safe to run while the server is up: it reads and never writes.'
& $da ''
& $da 'V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)'
& $da 'D="/var/lib/pelican/volumes/$V"'
& $da ''
& $da 'cat > /tmp/lt-paper-drift.py <<''LT_PY_EOF'''
foreach ($l in (Get-PythonPayload -Apply $false)) { & $da $l }
& $da 'LT_PY_EOF'
& $da ''
& $da 'echo "=== managed Paper keys vs the repository ==="'
& $da 'sudo -n python3 /tmp/lt-paper-drift.py "$D"'
& $da 'RC=$?'
& $da 'rm -f /tmp/lt-paper-drift.py'
& $da 'if [ "$RC" -eq 0 ]; then echo "NO DRIFT"; else echo "DRIFT PRESENT (exit $RC)"; fi'
& $da 'echo "=== END ==="'
& $da 'exit $RC'
Set-Content -LiteralPath (Join-Path $repo 'scripts\remote\check-paper-drift.sh') -Value $d -Encoding UTF8

Write-Output ("parsed {0} managed key(s):" -f $entries.Count)
$entries | ForEach-Object { Write-Output ("  {0} :: {1} = {2}" -f $_.file, $_.key, $_.value) }
Write-Output 'wrote scripts/remote/apply-paper-tuning.sh and scripts/remote/check-paper-drift.sh'
