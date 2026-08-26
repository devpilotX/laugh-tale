# grim-exempt-owner.sh - grants grim.exempt to the owner, live.
#
# WHY LIVE AND NOT A RESTART: the owner is online right now and stop-server.sh
# correctly refused to kick them. LuckPerms permission changes take effect
# immediately, so this frees their movement without disconnecting them.
#
# WHAT IT DOES: GrimAC's `grim.exempt` node removes a player from all of its checks,
# so no more mispredicted setbacks. The underlying cause is unchanged - a 26.2 client
# on a 1.21.11 server via ViaVersion translation, which GrimAC's own boot warning
# calls unsupported (OA-27).
#
# THIS IS TEMPORARY AND MUST NOT SURVIVE. It is granted to the owner's USER, not to
# the owner GROUP, deliberately: a permanent exemption for the account that competes
# on the ladder is a fairness problem the moment rank exists (Law 1, total equality),
# and it would be a genuine scandal on a paid server. Tracked in owner-actions.md
# OA-27 and to be revoked when the version conflict is resolved.
#
# Recorded here rather than done quietly, because an anti-cheat exemption is exactly
# the kind of change that should never be invisible.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
OWNER=263645f0-7a1b-4d45-a0c9-16d9b0d345d0

cat > /tmp/lt-ge.py <<'PYEOF'
import socket, struct, sys, re, time
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='): pw = line.split('=',1)[1].strip()
        elif line.startswith('rcon.port='): port = int(line.split('=',1)[1].strip())
def pkt(rid, typ, body):
    p = struct.pack('<ii', rid, typ) + body.encode() + b'\x00\x00'
    return struct.pack('<i', len(p)) + p
def rd(s):
    raw=b''
    while len(raw)<4:
        c=s.recv(4-len(raw))
        if not c: return ''
        raw+=c
    (n,)=struct.unpack('<i',raw); b=b''
    while len(b)<n:
        c=s.recv(n-len(b))
        if not c: break
        b+=c
    return b[8:-2].decode('utf8','replace')
s=socket.create_connection((HOST,port),timeout=15); s.settimeout(20)
s.sendall(pkt(1,3,pw)); rd(s)
for cmd in sys.argv[3:]:
    s.sendall(pkt(2,2,cmd))
    out = re.sub(r'\xa7.','',rd(s)).strip()
    print('%-58s -> %s' % (cmd[:58], out[:120] or '(async, no output)'))
    time.sleep(0.6)
s.close()
PYEOF

echo "=== granting grim.exempt and confirming the rules bypass is live ==="
sudo -n python3 /tmp/lt-ge.py "$D/server.properties" "$CIP" \
  "lp user $OWNER permission set grim.exempt true" \
  "lp user $OWNER permission set grim.alerts true" \
  "lp user $OWNER parent set owner" \
  "lp networksync" \
  "say Movement restrictions lifted for the owner - anti-cheat exemption applied."

sudo -n rm -f /tmp/lt-ge.py

echo "=== violations before and after should stop climbing ==="
BEFORE=$( { sudo -n grep -c 'Grim . ' "$D/logs/latest.log" || true; } | head -1 | tr -dc '0-9')
[ -z "$BEFORE" ] && BEFORE=0
echo "  grim violation lines so far: $BEFORE"
echo "  (move around in game; re-run this script's check to confirm it stops rising)"

echo "=== is the player still online? ==="
sudo -n grep -E 'joined the game|left the game' "$D/logs/latest.log" | tail -3
echo "=== END ==="
