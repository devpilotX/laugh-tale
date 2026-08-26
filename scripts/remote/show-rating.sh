V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
cat > /tmp/lt-r.py <<'PY'
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
s=socket.create_connection((HOST,port),timeout=20); s.settimeout(25)
s.sendall(pkt(1,3,pw)); rd(s)
s.sendall(pkt(2,2,'laughtail rating'))
print(re.sub(r'\xa7.','',rd(s)))
s.close()
PY
sudo -n python3 /tmp/lt-r.py "$D/server.properties" "$CIP"
sudo -n rm -f /tmp/lt-r.py