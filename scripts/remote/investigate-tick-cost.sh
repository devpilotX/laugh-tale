# investigate-tick-cost.sh - READ ONLY.
#
# baselines.md B1 recorded idle MSPT at 0.2 ms average. The monitor now reports
# ~6 ms average with zero players - a 30x increase on an empty server. That is
# exactly the regression a committed baseline exists to make visible, and it must be
# explained rather than accepted.
#
# Candidate causes, in order of likelihood:
#   1. LuckPerms now holds real data and runs periodic sync tasks. Its default
#      storage on Bukkit is H2, and sync work would show as steady per-tick cost.
#   2. The repeated `lp export` calls left work queued.
#   3. Chunky or another plugin started something.
#   4. The world is genuinely busier - chunks loaded by the earlier deploy activity.
#   5. The monitor's own RCON polling is being measured.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
L="$D/logs/latest.log"
CIP=$(sudo -n docker inspect "$V" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

echo "=== how long has the server been up? ==="
sudo -n docker ps --filter "name=$V" --format '{{.Status}}'

echo "=== repeated MSPT samples, 10s apart, to see whether it is steady or decaying ==="
cat > /tmp/lt-mspt.py <<'PYEOF'
import socket, struct, sys, re, time
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, 'r', encoding='utf-8', errors='replace') as f:
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
s.sendall(pkt(1, 3, pw))
rd(s)
for i in range(6):
    s.sendall(pkt(2, 2, 'mspt'))
    out = re.sub(r'\xa7.', '', rd(s))
    nums = re.findall(r'([0-9.]+)/([0-9.]+)/([0-9.]+)', out)
    if nums:
        print('sample %d  5s=%s/%s/%s   1m=%s/%s/%s' % (i + 1,
              nums[0][0], nums[0][1], nums[0][2],
              nums[-1][0], nums[-1][1], nums[-1][2]))
    if i < 5:
        time.sleep(10)
s.close()
PYEOF
sudo -n python3 /tmp/lt-mspt.py "$D/server.properties" "$CIP"
sudo -n rm -f /tmp/lt-mspt.py

echo "=== anything in the log since boot that looks periodic or noisy? ==="
sudo -n grep -iE 'warn|took|lag|slow|sync|task' "$L" 2>/dev/null | tail -15 || echo "(nothing)"

echo "=== what storage is LuckPerms using, and how big is it? ==="
sudo -n grep -iE '^storage-method|^data:' -A3 "$D/plugins/LuckPerms/config.yml" 2>/dev/null | head -10
sudo -n du -sh "$D/plugins/LuckPerms" 2>/dev/null
sudo -n ls -la "$D/plugins/LuckPerms" 2>/dev/null | head -12

echo "=== container CPU over a few seconds ==="
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}}' "$V"
sleep 5
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}}' "$V"

echo "=== is the exported permissions file still sitting there? ==="
sudo -n ls -la "$D/plugins/LuckPerms"/lt-verify* 2>/dev/null || echo "(no export files)"

echo "=== END ==="
