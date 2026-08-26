# who-is-online.sh - READ ONLY. Asks the server directly.
#
# stop-server.sh estimates online players by counting join/leave lines in the current log,
# which is a reasonable proxy but drifts: a log archived mid-session loses the leave line,
# and a rejoin after a restart counts fresh. This asks the server, which cannot be wrong.
V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
cat > /tmp/lt-who.py <<'PYEOF'
import socket, struct, sys, re
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
s.sendall(pkt(2,2,'list'))
print(re.sub(r'\xa7.','',rd(s)).strip())
s.close()
PYEOF
sudo -n python3 /tmp/lt-who.py "$D/server.properties" "$CIP"
sudo -n rm -f /tmp/lt-who.py
echo "=== join/leave lines in the current log ==="
sudo -n grep -E 'joined the game|left the game' "$D/logs/latest.log" | tail -6 || echo "(none)"
echo "=== END ==="
