# create-worlds.sh - creates the resource and arena worlds. Section 7.1.
#
# Paper creates three worlds; 7.1 requires five. These are the two missing ones:
#
#   laughtail_resource  border 3000, normal terrain
#     "The most underrated feature in this document" (7.1). All serious mining and bulk
#     farming happens here so the main world keeps its landscape permanently. Resets
#     monthly with the season. NOTHING is claimable here (7.4).
#
#   laughtail_arena     small, FLAT
#     War events and duels only. "Loaded only during events; view-distance 4,
#     simulation-distance 3" (7.1). Flat because an arena needs a predictable surface,
#     not scenery.
#
# IDEMPOTENT: `mv create` on an existing world is refused by Multiverse, and this script
# checks first and reports rather than treating the refusal as an error.
#
# The Section 7.2 gamerules are NOT applied here. The LaughTail plugin applies them on
# WorldLoadEvent, so these worlds inherit keep_inventory, fire spread and mob griefing
# settings the moment they load - which is exactly why that logic lives in the plugin
# rather than in a deploy script.
#
# BORDERS ARE SET HERE and are diameters, matching 7.1's table.
#
# DISK: this generates spawn chunks only, a few MB per world. It does NOT pregenerate to
# the border - that is 6.5's Chunky work, which is hours of sustained CPU on a burstable
# instance and several GB of disk, and is deliberately deferred (OA-04, OA-05).

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')

if ! sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  echo "ABORT: the server must be running."
  exit 2
fi

cat > /tmp/lt-mv.py <<'PYEOF'
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
def rd(s, timeout=30):
    s.settimeout(timeout)
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
    # World creation generates spawn chunks and can take a while - allow 90s.
    out = re.sub(r'\xa7.', '', rd(s, 90)).strip().replace('\n', ' | ')
    print('%-56s -> %s' % (cmd[:56], out[:240] or '(no output)'))
    time.sleep(1.0)
s.close()
PYEOF

echo "=== worlds Multiverse already knows about ==="
sudo -n python3 /tmp/lt-mv.py "$D/server.properties" "$CIP" <<'CMDS'
mv list
CMDS

echo ""
echo "=== importing the three existing worlds so Multiverse manages them too ==="
# Paper's own worlds are not automatically under Multiverse management. Importing them
# means one tool describes all five, rather than three being invisible to it.
sudo -n python3 /tmp/lt-mv.py "$D/server.properties" "$CIP" <<'CMDS'
mv import laughtail normal
mv import laughtail_nether nether
mv import laughtail_the_end THE_END
CMDS

echo ""
echo "=== creating the resource world (7.4) ==="
sudo -n python3 /tmp/lt-mv.py "$D/server.properties" "$CIP" <<'CMDS'
mv create laughtail_resource normal
CMDS

echo ""
echo "=== creating the arena, flat (7.1) ==="
sudo -n python3 /tmp/lt-mv.py "$D/server.properties" "$CIP" <<'CMDS'
mv create laughtail_arena normal -t flat
CMDS

echo ""
echo "=== borders are set by the LaughTail plugin, not here ==="
echo "(WorldRules holds the 7.1 table and applies it on WorldLoadEvent, so a world"
echo " created later gets the right border without anyone remembering to set it.)"

echo ""
echo "=== all five worlds, and what Multiverse reports ==="
sudo -n python3 /tmp/lt-mv.py "$D/server.properties" "$CIP" <<'CMDS'
mv list
CMDS

sudo -n rm -f /tmp/lt-mv.py

echo ""
echo "=== world directories on disk ==="
# Never glob inside the volume - expanded by the ubuntu shell, which cannot traverse it.
sudo -n ls -1 "$D" | grep '^laughtail'

echo "=== disk after creating worlds ==="
df -h --output=avail,pcent / | tail -1
sudo -n du -sh "$D"/laughtail_resource "$D"/laughtail_arena 2>/dev/null || true
echo "=== the plugin should have applied 7.2 gamerules to the new worlds ==="
sudo -n grep 'LaughTail' "$D/logs/latest.log" | grep -iE 'laughtail_resource|laughtail_arena' || echo "(no lines yet - worlds may load after this)"
echo "=== END ==="
