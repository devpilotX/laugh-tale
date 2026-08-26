# diagnose-owner-stuck.sh - READ ONLY. Why is the owner unable to move?

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
OWNER_UUID=263645f0-7a1b-4d45-a0c9-16d9b0d345d0

echo "=== did the owner accept the rules? what does the database say? ==="
sudo -n docker exec -u root laughtail-db sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -B -e "
SELECT uuid, current_name, rules_version_accepted, rules_accepted_at, first_join, last_seen FROM players;"' 2>&1 | sed '/password on the command line/d'

echo "=== what groups does the owner actually hold in LuckPerms? ==="
sudo -n docker exec -u root laughtail-db sh -c 'true' >/dev/null 2>&1
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
cat > /tmp/lt-q.py <<'PYEOF'
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
    time.sleep(0.8)
s.close()
PYEOF
sudo -n python3 /tmp/lt-q.py "$D/server.properties" "$CIP" \
  "lp user IgnisClaw info" \
  "list" \
  "laughtail status"
sudo -n rm -f /tmp/lt-q.py

echo "=== tick health right now - is the server itself lagging? ==="
sudo -n grep -E 'Can.t keep up|moved too quickly|moved wrongly|flying' "$D/logs/latest.log" | tail -8 || echo "(no movement complaints)"

echo "=== anything from GrimAC about the owner? ==="
sudo -n grep -i 'grim' "$D/logs/latest.log" | tail -6 || echo "(nothing)"

echo "=== LaughTail lines ==="
sudo -n grep 'LaughTail' "$D/logs/latest.log" | tail -8

echo "=== END ==="
