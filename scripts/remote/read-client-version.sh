# read-client-version.sh - READ ONLY. What client version is connecting?
#
# This decides which fix is correct. If the client is NEWER than the server, then
# ViaVersion is translating every packet, and GrimAC is trying to predict movement
# from translated packets - which its own boot warning says is unsupported. That is a
# protocol-translation problem, not an anti-cheat tuning problem, and no amount of
# threshold tweaking makes it right.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"

echo "=== server version ==="
sudo -n grep -m1 'This server is running' "$D/logs/latest.log"

echo "=== ViaVersion protocol activity for connecting players ==="
sudo -n grep -iE 'ViaVersion|protocol|1\.21\.|26\.' "$D/logs/latest.log" | grep -iE 'connect|join|protocol|version' | tail -12 || echo "(nothing explicit)"

echo "=== login lines ==="
sudo -n grep -E 'logged in with entity id|joined the game|UUID of player' "$D/logs/latest.log" | tail -8

echo "=== ask ViaVersion directly what it sees ==="
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
cat > /tmp/lt-cv.py <<'PYEOF'
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
    print('--- %s' % cmd)
    print(re.sub(r'\xa7.','',rd(s)).strip() or '(no output)')
    time.sleep(1.0)
s.close()
PYEOF
sudo -n python3 /tmp/lt-cv.py "$D/server.properties" "$CIP" "viaversion list" "list"
sudo -n rm -f /tmp/lt-cv.py

echo "=== recent Grim violations, with counts ==="
sudo -n grep -c 'Grim' "$D/logs/latest.log" || true
sudo -n grep 'Grim »' "$D/logs/latest.log" | tail -10 || echo "(none)"
echo "=== END ==="
