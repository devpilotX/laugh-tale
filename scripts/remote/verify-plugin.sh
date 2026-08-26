# verify-plugin.sh - exercises the LaughTail plugin's commands and checks the DB.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}' | head -c 20)
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')

cat > /tmp/lt-vp.py <<'PYEOF'
import socket, struct, sys, re, time
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='):
            pw = line.split('=', 1)[1].strip()
        elif line.startswith('rcon.port='):
            port = int(line.split('=', 1)[1].strip())
def pkt(rid, typ, body):
    p = struct.pack('<ii', rid, typ) + body.encode() + b'\x00\x00'
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
s = socket.create_connection((HOST, port), timeout=15)
s.settimeout(20)
s.sendall(pkt(1, 3, pw)); rd(s)
for cmd in sys.argv[3:]:
    s.sendall(pkt(2, 2, cmd))
    out = re.sub(r'\xa7.', '', rd(s))
    print('=== %s ===' % cmd)
    print(out.strip() if out.strip() else '(no immediate output - may be async)')
    time.sleep(1.2)
s.close()
PYEOF

echo "=== plugin commands over RCON ==="
sudo -n python3 /tmp/lt-vp.py "$D/server.properties" "$CIP" "laughtail status" "plugins"
sudo -n rm -f /tmp/lt-vp.py

echo "=== anything the plugin logged since boot ==="
sudo -n grep 'LaughTail' "$D/logs/latest.log" | tail -8

echo "=== database: has the plugin's own connectivity check left the schema intact? ==="
sudo -n docker exec -u root laughtail-db sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "
SELECT COUNT(*) AS players_recorded FROM players;
SELECT version FROM schema_migrations;"' 2>&1 | sed '/password on the command line/d'
echo "=== END ==="
