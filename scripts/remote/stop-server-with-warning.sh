# stop-server-with-warning.sh - stops the server WITH players online, after warning them.
#
# WHY THIS EXISTS SEPARATELY FROM stop-server.sh. That script refuses when anyone is online,
# and that refusal is correct as a default - a surprise kick mid-fight on a paid server is a
# refund conversation. But a blanket refusal makes the server unrestartable whenever a single
# player leaves a client connected, which during development is most of the time.
#
# So this is a SECOND, EXPLICIT path rather than a flag on the first. A flag would get used
# habitually; a separate script with this header has to be chosen deliberately, and the
# choice is visible in logs/remote-commands.log with its reason.
#
# It does not skip the safety, it changes it: players are TOLD, given time to react, and the
# count is reported honestly rather than assumed to be zero.
#
# NOT FOR PRODUCTION USE with real players online. At that point the correct answer is to
# schedule the restart, which 31.8 requires a daily hour for anyway.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
L="$D/logs/latest.log"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')

if ! sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  echo "already stopped"
  exit 0
fi

cat > /tmp/lt-warn.py <<'PYEOF'
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
s=socket.create_connection((HOST,port),timeout=15); s.settimeout(25)
s.sendall(pkt(1,3,pw)); rd(s)
for cmd in sys.argv[3:]:
    s.sendall(pkt(2,2,cmd))
    print('%-46s -> %s' % (cmd[:46], re.sub(r'\xa7.','',rd(s)).strip()[:120]))
    time.sleep(0.4)
s.close()
PYEOF

echo "=== who is actually online (asked, not inferred) ==="
sudo -n python3 /tmp/lt-warn.py "$D/server.properties" "$CIP" "list"

echo "=== warning them, then saving ==="
sudo -n python3 /tmp/lt-warn.py "$D/server.properties" "$CIP" \
  "say [LaughTail] Restarting in 15 seconds to load a plugin update." \
  "say [LaughTail] You will be able to reconnect in about a minute."
sleep 8
sudo -n python3 /tmp/lt-warn.py "$D/server.properties" "$CIP" \
  "say [LaughTail] Restarting in 5 seconds." \
  "save-all flush"
sleep 6
sudo -n rm -f /tmp/lt-warn.py

echo "=== stopping via the Panel so Wings records it as intentional ==="
sudo -n bash -c "cd /var/www/pelican && php artisan p:server:bulk-power stop --servers=1 --no-interaction" 2>&1 | tail -3

for i in $(seq 1 30); do
  S=$(sudo -n docker ps --filter "name=$V" --format '{{.Status}}')
  if [ -z "$S" ]; then echo "stopped after ${i}x2s"; break; fi
  sleep 2
done

echo "=== did the world save cleanly? ==="
sudo -n tail -6 "$L" 2>/dev/null
echo "=== END ==="
