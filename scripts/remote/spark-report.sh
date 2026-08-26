# spark-report.sh - runs `spark health` and then reads the report out of the log.
#
# spark replies to the command channel with only "Generating server health
# report..." and prints the report itself asynchronously a moment later. Over RCON
# that means the useful output never reaches the caller - it goes to the console.
# So: note the log length, issue the command, wait, and read what was added.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
L="$D/logs/latest.log"
CIP=$(sudo -n docker inspect "$V" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

BEFORE=$(sudo -n wc -l "$L" | awk '{print $1}')

cat > /tmp/lt-rcon-min.py <<'PYEOF'
import socket, struct, sys
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
s = socket.create_connection((HOST, port), timeout=15)
s.settimeout(15)
s.sendall(pkt(1, 3, pw))
s.recv(4096)
for cmd in sys.argv[3:]:
    s.sendall(pkt(2, 2, cmd))
    try:
        s.recv(4096)
    except socket.timeout:
        pass
s.close()
print('commands sent')
PYEOF

sudo -n python3 /tmp/lt-rcon-min.py "$D/server.properties" "$CIP" "spark health" "spark tps"
sudo -n rm -f /tmp/lt-rcon-min.py

echo "=== waiting 12s for spark to finish generating ==="
sleep 12

echo "=== what spark wrote to the console ==="
sudo -n sed -n "$((BEFORE + 1)),\$p" "$L" | sed 's/\x1b\[[0-9;]*m//g' | head -60
echo "=== END ==="
