# spark-baseline.sh - deviation D2: the empty-server MSPT and memory baseline.
#
# Law 5 and 6.8: measurement precedes tuning, and every later number is a delta
# against something. Without this, Phase 6 cannot attribute cost to any feature.
#
# HOW IT TALKS TO THE SERVER, AND WHY.
# Two cheaper channels were tried first and both failed, recorded so nobody
# repeats them:
#   - writing to /proc/1/fd/0: PID 1 is tini, which does not forward stdin.
#   - writing to the JVM's own /proc/<pid>/fd/0: Wings holds that pipe, so the
#     server never sees the bytes.
# So RCON it is. There is no rcon client installed, and never-break rule 13 says
# do not install packages on the game box mid-build, so the client is ~40 lines of
# python3 - already present - implementing the protocol directly.
#
# THE SECRET IS NEVER PRINTED. It is read from the live server.properties inside
# the python process and used to authenticate. It is not echoed, not logged, not
# passed as a command-line argument (which would expose it in `ps`), and not
# written to any file. Consistent with D-0019.
#
# RCON is reachable only on the host loopback - the container does not publish it,
# proven externally by scripts/check-external-ports.ps1.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
CIP=$(sudo -n docker inspect "$V" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "container ip: $CIP"

cat > /tmp/lt-rcon.py <<'PYEOF'
import socket, struct, sys, re, time

PROPS = sys.argv[1]
HOST  = sys.argv[2]

# Read the password from the live file. Never printed, never in argv.
pw, port = None, 25575
with open(PROPS, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='):
            pw = line.split('=', 1)[1].strip()
        elif line.startswith('rcon.port='):
            try:
                port = int(line.split('=', 1)[1].strip())
            except ValueError:
                pass

if not pw:
    print('ABORT: rcon.password is empty in server.properties')
    sys.exit(3)

def pkt(rid, typ, body):
    payload = struct.pack('<ii', rid, typ) + body.encode('utf8') + b'\x00\x00'
    return struct.pack('<i', len(payload)) + payload

def read_pkt(s):
    raw = b''
    while len(raw) < 4:
        c = s.recv(4 - len(raw))
        if not c:
            return None, None
        raw += c
    (length,) = struct.unpack('<i', raw)
    body = b''
    while len(body) < length:
        c = s.recv(length - len(body))
        if not c:
            break
        body += c
    rid, typ = struct.unpack('<ii', body[:8])
    return rid, body[8:-2].decode('utf8', errors='replace')

s = socket.create_connection((HOST, port), timeout=15)
s.settimeout(20)
s.sendall(pkt(1, 3, pw))
rid, _ = read_pkt(s)
if rid == -1:
    print('ABORT: RCON authentication failed')
    sys.exit(4)
print('rcon: authenticated (password never displayed)')

for cmd in sys.argv[3:]:
    s.sendall(pkt(2, 2, cmd))
    time.sleep(0.4)
    _, resp = read_pkt(s)
    clean = re.sub(r'\xa7.', '', resp or '')
    print('=== %s ===' % cmd)
    print(clean.strip() if clean.strip() else '(no output)')
s.close()
PYEOF

echo "=== baseline measurement over RCON ==="
# spark is bundled with Paper but its profiler is disabled by default and reports
# "The spark profiler is currently disabled" for every subcommand. Paper's own
# /tps and /mspt give exactly what deviation D2 needs - tick rate and tick
# duration percentiles - with nothing to enable and nothing to install.
sudo -n python3 /tmp/lt-rcon.py \
  "/var/lib/pelican/volumes/$V/server.properties" \
  "$CIP" \
  "tps" \
  "mspt" \
  "list"

rm -f /tmp/lt-rcon.py

echo "=== container resource use at the same moment ==="
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}} ({{.MemPerc}})' "$V"
echo "=== host ==="
free -m | head -2
uptime
echo "=== END ==="
