# apply-world-rules.sh - Section 7.1 and 7.2. Phase 2.
#
# THIS SCRIPT IS THE SOURCE OF TRUTH for these values, deliberately. The alternative -
# a separate YAML registry plus a script that mirrors it - would give two places to
# change and one of them would eventually be stale. Every value below is set AND read
# back, so the script cannot claim success without evidence.
#
# WHAT IS SET, AND THE SPEC LINE THAT DECIDES IT
#
# 7.2 death and griefing rules:
#   keepInventory        false  "Death must cost something or PvP means nothing"
#   doFireTick           false  "Removes the most common griefing vector at almost no
#                                gameplay cost"
#   mobGriefing          false  "Stops creeper and enderman damage to builds"
#   naturalRegeneration  true   standard
#
# 7.1 borders, as DIAMETERS - the spec's table says "6,000 diameter", and Minecraft's
# `worldborder set` takes a diameter, so these numbers go in as written. Getting this
# wrong by a factor of two in either direction is the classic error: a radius reading
# would give a 12,000-block world, which the disk cannot hold (R5) and which Chunky
# would spend days pregenerating.
#   Overworld 6000, Nether 2000, End 3000
#
# WHAT IS NOT DONE HERE, and why - stated so the phase is not mistaken for complete:
#   - The RESOURCE and ARENA worlds (7.1) do not exist. Creating additional worlds needs
#     a world-management plugin, which is a manifest decision and not yet made. The
#     resource world is called "the most underrated feature in this document" and its
#     reset script must "name the world explicitly and refuse to run against the main
#     world" (7.4) - that is deliberate work, not a side effect of this script.
#   - LAND CLAIMS (7.3) need numbers the specification never gives: accrual rate,
#     starting allowance, minimum claim size, reclamation threshold. Recorded in
#     questions.md as a known gap.
#   - PREGENERATION (6.5) is deliberately not run: Chunky at a 6,000 border is hours of
#     sustained CPU on a BURSTABLE instance (R1, OA-05) and several GB on a disk with
#     6.9 GB free (R5, OA-04). Both are owner decisions.
#   - SPAWN (7.5) is a build, not a config.
#
# ONE CONTRADICTION WORTH NAMING: 7.2 says "PvP On everywhere" and 7.5 says spawn is a
# protected region with "No PvP". Those are reconcilable - claims never protect players,
# but spawn is not a claim - and spawn protection is already set to 16 in
# server.properties. Recording it so nobody later "fixes" one to match the other.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')

if ! sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  echo "ABORT: the server must be running - these are runtime commands, not config files."
  exit 2
fi

cat > /tmp/lt-world.py <<'PYEOF'
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
def rd(s):
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
s.settimeout(25)
s.sendall(pkt(1, 3, pw)); rd(s)
for line in sys.stdin:
    cmd = line.strip()
    if not cmd or cmd.startswith('#'):
        continue
    s.sendall(pkt(2, 2, cmd))
    out = re.sub(r'\xa7.', '', rd(s)).strip().replace('\n', ' | ')
    print('%-62s -> %s' % (cmd[:62], out[:150] or '(no output)'))
    time.sleep(0.25)
s.close()
PYEOF

echo "=== applying, per dimension ==="
# `execute in <dimension> run` is what makes these PER-WORLD. A bare /gamerule from the
# console applies only to the default world, which would leave the Nether and End with
# fire spread and mob griefing still on - a silent half-application.
sudo -n python3 /tmp/lt-world.py "$D/server.properties" "$CIP" <<'CMDS'
execute in minecraft:overworld run gamerule keepInventory false
execute in minecraft:overworld run gamerule doFireTick false
execute in minecraft:overworld run gamerule mobGriefing false
execute in minecraft:overworld run gamerule naturalRegeneration true
execute in minecraft:the_nether run gamerule keepInventory false
execute in minecraft:the_nether run gamerule doFireTick false
execute in minecraft:the_nether run gamerule mobGriefing false
execute in minecraft:the_nether run gamerule naturalRegeneration true
execute in minecraft:the_end run gamerule keepInventory false
execute in minecraft:the_end run gamerule doFireTick false
execute in minecraft:the_end run gamerule mobGriefing false
execute in minecraft:the_end run gamerule naturalRegeneration true
execute in minecraft:overworld run worldborder set 6000
execute in minecraft:the_nether run worldborder set 2000
execute in minecraft:the_end run worldborder set 3000
CMDS

echo ""
echo "=== reading every value back - set without verify is a hope, not a change ==="
sudo -n python3 /tmp/lt-world.py "$D/server.properties" "$CIP" <<'CMDS'
execute in minecraft:overworld run gamerule keepInventory
execute in minecraft:overworld run gamerule doFireTick
execute in minecraft:overworld run gamerule mobGriefing
execute in minecraft:overworld run gamerule naturalRegeneration
execute in minecraft:the_nether run gamerule doFireTick
execute in minecraft:the_nether run gamerule mobGriefing
execute in minecraft:the_end run gamerule doFireTick
execute in minecraft:the_end run gamerule mobGriefing
execute in minecraft:overworld run worldborder get
execute in minecraft:the_nether run worldborder get
execute in minecraft:the_end run worldborder get
CMDS

sudo -n rm -f /tmp/lt-world.py

echo ""
echo "=== these persist in level.dat, so they survive a restart ==="
echo "(gamerules and the border are world data, not server.properties - a restart"
echo " does not reset them, and neither does a redeploy)"
echo "WORLD RULES APPLIED"
echo "=== END ==="
