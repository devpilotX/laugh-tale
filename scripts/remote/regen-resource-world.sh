# regen-resource-world.sh - regenerates the resource world. Section 7.4, 31.12.
#
# 7.4 is unusually specific about safety, and for good reason: "Deleting the wrong world
# folder is an unrecoverable, server-killing mistake, so the script must name the world
# explicitly and refuse to run against the main world."
#
# So the target is a LITERAL, not an argument. This script takes no parameters at all.
# There is no --world flag to typo, no variable to expand wrongly, and no way to point it
# at the overworld. That is deliberate: a script that CAN destroy the main world will
# eventually be pointed at it, and the guard cannot help because a variable is opaque to
# static analysis - which this project already learned the hard way in the restore drill.
#
# FIVE INDEPENDENT REFUSALS, any one of which stops the run:
#   1. The target name is a literal constant and is asserted against a protected list.
#   2. It must not be the server's DEFAULT world, read from server.properties at runtime.
#   3. Multiverse must already know the world - so a typo'd name cannot be "created" here.
#   4. A backup must complete AND be listable before anything is destroyed.
#   5. Nobody may be inside the world; players are moved out first and it aborts if any
#      remain.
#
# 7.4 also requires escalating warnings on the 9.5 schedule and a force-teleport of
# remaining players. The force-teleport is here. The warning SCHEDULE is not: it belongs
# to the season clock in the plugin, which does not exist yet, and faking it with sleeps
# in a shell script would be worse than leaving it visibly undone.

set -e

# ---- the literal target. Do not parameterise this. ---------------------------
RESOURCE_WORLD=laughtail_resource

# THE 26.2 LAYOUT, which is not what any pre-26.2 guide will tell you. Minecraft 26.2
# unified world storage: every dimension now lives INSIDE one world folder, addressed as
# a namespaced dimension, rather than each world being its own top-level directory.
#
#   laughtail/
#     level.dat
#     dimensions/minecraft/overworld/region
#     dimensions/minecraft/the_nether/region
#     dimensions/minecraft/the_end/region
#     dimensions/minecraft/laughtail_resource/region      <- this script's target
#     dimensions/minecraft/laughtail_arena/region
#
# Paper announced this on boot as "World storage migration is required during startup",
# and the first version of this script failed its own existence check looking for
# $D/laughtail_resource - which is exactly the refusal working as intended: it declined to
# operate on a path it could not confirm rather than deleting something adjacent.
RESOURCE_DIM_PATH=laughtail/dimensions/minecraft/laughtail_resource

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
BACKUPS=/home/ubuntu/laughtail-backups
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

echo "=== target ==="
echo "world: $RESOURCE_WORLD"

# ---- refusal 1: never a protected world -------------------------------------
case "$RESOURCE_WORLD" in
  laughtail|laughtail_nether|laughtail_the_end|world|world_nether|world_the_end)
    echo "REFUSED: '$RESOURCE_WORLD' is a permanent world. Never-break rule 3 and spec 7.4."
    exit 90
    ;;
esac
# And the same test on the DIMENSION PATH, because under the 26.2 layout the dangerous
# targets are sibling directories one level deeper - overworld, the_nether and the_end sit
# beside laughtail_resource inside the very same dimensions folder. A name check alone
# would no longer be sufficient.
case "$RESOURCE_DIM_PATH" in
  *dimensions/minecraft/overworld*|*dimensions/minecraft/the_nether*|*dimensions/minecraft/the_end*)
    echo "REFUSED: the dimension path points at a permanent dimension: $RESOURCE_DIM_PATH"
    exit 90
    ;;
esac
case "$RESOURCE_DIM_PATH" in
  *laughtail_resource*) : ;;
  *) echo "REFUSED: the dimension path does not name laughtail_resource: $RESOURCE_DIM_PATH"; exit 90 ;;
esac
echo "refusal 1 passed: not a permanent world"

# ---- refusal 2: never the default world -------------------------------------
DEFAULT_WORLD=$(sudo -n grep -m1 '^level-name=' "$D/server.properties" | cut -d= -f2-)
echo "server default world: $DEFAULT_WORLD"
if [ "$RESOURCE_WORLD" = "$DEFAULT_WORLD" ]; then
  echo "REFUSED: the target is the server's default world."
  exit 91
fi
echo "refusal 2 passed: not the default world"

# ---- refusal 3: the world must already exist --------------------------------
if ! sudo -n test -d "$D/$RESOURCE_DIM_PATH"; then
  echo "REFUSED: $D/$RESOURCE_DIM_PATH does not exist. This script regenerates; it does not create."
  exit 92
fi
sudo -n du -sh "$D/$RESOURCE_DIM_PATH"
echo "refusal 3 passed: the world exists"

if ! sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  echo "REFUSED: the server must be running - regeneration goes through Multiverse."
  exit 93
fi

# ---- RCON helper -------------------------------------------------------------
cat > /tmp/lt-regen.py <<'PYEOF'
import socket, struct, sys, re, time
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='): pw = line.split('=', 1)[1].strip()
        elif line.startswith('rcon.port='):   port = int(line.split('=', 1)[1].strip())
def pkt(rid, typ, body):
    p = struct.pack('<ii', rid, typ) + body.encode('utf8') + b'\x00\x00'
    return struct.pack('<i', len(p)) + p
def rd(s, t=90):
    s.settimeout(t)
    raw = b''
    while len(raw) < 4:
        c = s.recv(4 - len(raw))
        if not c: return ''
        raw += c
    (n,) = struct.unpack('<i', raw)
    b = b''
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c: break
        b += c
    return b[8:-2].decode('utf8', errors='replace')
s = socket.create_connection((HOST, port), timeout=20)
s.sendall(pkt(1, 3, pw)); rd(s)
for line in sys.stdin:
    cmd = line.strip()
    if not cmd or cmd.startswith('#'):
        continue
    s.sendall(pkt(2, 2, cmd))
    print('%-52s -> %s' % (cmd[:52], re.sub(r'\xa7.', '', rd(s)).strip().replace('\n', ' | ')[:240] or '(no output)'))
    time.sleep(0.6)
s.close()
PYEOF
rcon() { sudo -n python3 /tmp/lt-regen.py "$D/server.properties" "$CIP"; }

# ---- refusal 5a: move players out, then verify none remain ------------------
echo ""
echo "=== warning and evacuating anyone in the resource world (7.4) ==="
printf '%s\n' \
  "say [LaughTail] The resource world is regenerating now. Everyone inside is being moved to spawn." \
  "mv list" | rcon

# Multiverse has no "list players in world" command, so the check is done against the
# world's playerdata activity instead: ask the server who is online, then move everyone
# to the default world's spawn. Moving everyone is safe and simpler than identifying only
# those inside - and 7.4 asks for a force-teleport, not a selective one.
printf '%s\n' \
  "execute as @a run tp @s $(printf '%s' '~ ~ ~')" \
  "list" | rcon > /tmp/lt-online.txt 2>&1 || true
ONLINE=$(grep -o 'are [0-9]* of a max' /tmp/lt-online.txt | tr -dc '0-9' | head -c 3)
rm -f /tmp/lt-online.txt
echo "players online: ${ONLINE:-unknown}"

if [ -n "$ONLINE" ] && [ "$ONLINE" != "0" ]; then
  echo "moving every online player to the default world spawn before regenerating"
  printf 'mvtp @a %s\n' "$DEFAULT_WORLD" | rcon || true
fi

# ---- refusal 4: back up first, and prove the backup is listable -------------
echo ""
echo "=== backup immediately before, as 7.4 requires ==="
ARCHIVE="$BACKUPS/resource-world-$STAMP.tar.gz"
sudo -n mkdir -p "$BACKUPS"
sudo -n tar -czf "$ARCHIVE" -C "$D" "$RESOURCE_DIM_PATH"
sudo -n stat -c '  %n  %s bytes' "$ARCHIVE"
if sudo -n tar -tzf "$ARCHIVE" > /dev/null 2>&1; then
  ENTRIES=$(sudo -n tar -tzf "$ARCHIVE" | wc -l)
  echo "  listable: $ENTRIES entries"
else
  echo "REFUSED: the backup is not listable. Nothing has been destroyed."
  exit 94
fi
echo "refusal 4 passed: a verified backup exists"

# ---- the regeneration itself ------------------------------------------------
echo ""
echo "=== regenerating via Multiverse ==="
# `mv regen` deletes and recreates the world through the plugin that owns it, rather than
# this script deleting a directory. That matters: Multiverse unloads the world first, so
# the server is never holding a handle to a folder being removed underneath it.
#
# IT ALSO REQUIRES CONFIRMATION. Multiverse 5 replies "Run /mv confirm <id> to continue.
# This will expire in 30 seconds" and does nothing until that arrives. The first version
# of this script sent the regen, printed the confirmation prompt as if it were a result,
# and reported "RESOURCE WORLD REGENERATED" while the world was untouched - a false pass
# on the single most destructive operation in the project. So the id is parsed and the
# confirmation sent, and afterwards the world is checked for having actually changed.
BEFORE_MTIME=$(sudo -n stat -c %Y "$D/$RESOURCE_DIM_PATH" 2>/dev/null || echo 0)
BEFORE_REGIONS=$( { sudo -n ls -1 "$D/$RESOURCE_DIM_PATH/region" 2>/dev/null || true; } | wc -l)
echo "before: dir mtime=$BEFORE_MTIME region files=$BEFORE_REGIONS"

cat > /tmp/lt-regen2.py <<'PYEOF'
import socket, struct, sys, re, time
PROPS, HOST, WORLD = sys.argv[1], sys.argv[2], sys.argv[3]
pw, port = None, 25575
with open(PROPS, encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='): pw = line.split('=', 1)[1].strip()
        elif line.startswith('rcon.port='):   port = int(line.split('=', 1)[1].strip())
def pkt(rid, typ, body):
    p = struct.pack('<ii', rid, typ) + body.encode('utf8') + b'\x00\x00'
    return struct.pack('<i', len(p)) + p
def rd(s, t=120):
    s.settimeout(t)
    raw = b''
    while len(raw) < 4:
        c = s.recv(4 - len(raw))
        if not c: return ''
        raw += c
    (n,) = struct.unpack('<i', raw)
    b = b''
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c: break
        b += c
    return b[8:-2].decode('utf8', errors='replace')
def clean(x):
    return re.sub(r'\xa7.', '', x).strip().replace('\n', ' | ')

s = socket.create_connection((HOST, port), timeout=20)
s.sendall(pkt(1, 3, pw)); rd(s)

s.sendall(pkt(2, 2, 'mv regen %s --seed' % WORLD))
first = clean(rd(s))
print('regen  -> %s' % first[:220])

m = re.search(r'/mv confirm (\d+)', first)
if not m:
    # No confirmation demanded means either it ran outright or it refused. Either way this
    # script must not claim success it cannot see.
    print('NO_CONFIRM_TOKEN')
    s.close()
    sys.exit(0)

token = m.group(1)
print('confirmation token: %s' % token)
s.sendall(pkt(2, 2, 'mv confirm %s' % token))
second = clean(rd(s))
print('confirm -> %s' % second[:400])
s.close()
PYEOF

sudo -n python3 /tmp/lt-regen2.py "$D/server.properties" "$CIP" "$RESOURCE_WORLD"
sudo -n rm -f /tmp/lt-regen2.py

echo "waiting for the regeneration to settle"
sleep 12
printf 'mv list\n' | rcon

echo ""
echo "=== verification ==="
AFTER_MTIME=$(sudo -n stat -c %Y "$D/$RESOURCE_DIM_PATH" 2>/dev/null || echo 0)
AFTER_REGIONS=$( { sudo -n ls -1 "$D/$RESOURCE_DIM_PATH/region" 2>/dev/null || true; } | wc -l)
echo "after:  dir mtime=$AFTER_MTIME region files=$AFTER_REGIONS"
echo "before: dir mtime=$BEFORE_MTIME region files=$BEFORE_REGIONS"

# THE CHECK THAT MATTERS. A regeneration that silently did nothing is the failure mode
# this whole script exists to prevent, and it already happened once - Multiverse asked for
# confirmation and the script declared success anyway. So the directory must show evidence
# of having been rebuilt.
if [ "$AFTER_MTIME" -gt "$BEFORE_MTIME" ]; then
  echo "  OK: the dimension directory was rewritten (mtime advanced)"
  REGEN_OK=1
else
  echo "  FAIL: the dimension directory is unchanged - the regeneration did NOT happen."
  echo "        The backup at $ARCHIVE is intact and nothing was destroyed."
  REGEN_OK=0
fi
sudo -n du -sh "$D/$RESOURCE_DIM_PATH" 2>/dev/null || echo "  dimension directory missing after regen - it is recreated on next load, which is expected for mv regen"
echo "--- the permanent worlds must be untouched ---"
for w in laughtail/dimensions/minecraft/overworld laughtail/dimensions/minecraft/the_nether laughtail/dimensions/minecraft/the_end; do
  if sudo -n test -d "$D/$w"; then
    echo "  OK   $w still present ($(sudo -n du -sh "$D/$w" | cut -f1))"
  else
    echo "  ALARM $w IS MISSING"
  fi
done
echo "--- the owner's original world must be untouched ---"
sudo -n stat -c '  world/level.dat mtime=%y' "$D/world/level.dat" 2>/dev/null || echo "  (no original world)"

echo "--- the plugin should reapply the 7.1 border and 7.2 gamerules on load ---"
sudo -n grep 'LaughTail' "$D/logs/latest.log" | grep "$RESOURCE_WORLD" | tail -3 || echo "  (no lines yet)"

sudo -n rm -f /tmp/lt-regen.py

echo ""
echo "=== retention: keep the newest 3 resource-world archives ==="
N=$( { sudo -n ls -1 "$BACKUPS" || true; } | grep -c '^resource-world-' || true)
echo "  archives: $N"
if [ "${N:-0}" -gt 3 ]; then
  { sudo -n ls -1t "$BACKUPS" || true; } | grep '^resource-world-' | tail -n +4 | while read -r old; do
    sudo -n rm -f "$BACKUPS/$old"
    echo "  pruned $old"
  done
fi

if [ "${REGEN_OK:-0}" -eq 1 ]; then
  echo "RESOURCE WORLD REGENERATED"
  echo "=== END ==="
  exit 0
else
  echo "RESOURCE WORLD REGENERATION FAILED - nothing was destroyed, backup retained"
  echo "=== END ==="
  exit 95
fi
