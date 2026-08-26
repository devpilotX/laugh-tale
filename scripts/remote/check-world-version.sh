V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
echo "=== server version from rotated logs ==="
for f in $(sudo -n ls -1t "$D"/logs/*.log.gz 2>/dev/null | head -6); do
  LINE=$(sudo -n zcat "$f" 2>/dev/null | grep -m1 -iE 'This server is running|Starting minecraft server version' || true)
  if [ -n "$LINE" ]; then echo "$(basename "$f"): $LINE"; fi
done
echo "=== version line in latest.log (whole file) ==="
sudo -n grep -m2 -iE 'This server is running|Starting minecraft server version|Loading Paper' "$D/logs/latest.log" 2>/dev/null || echo "(none - log was truncated on restart)"

echo "=== python3 available? ==="
command -v python3 >/dev/null && python3 --version || echo "no python3"

echo "=== world DataVersion from level.dat ==="
sudo -n cp "$D/world/level.dat" /tmp/lt-level.dat 2>/dev/null && sudo -n chown ubuntu:ubuntu /tmp/lt-level.dat
python3 - <<'PY'
import gzip, struct, sys
try:
    raw = gzip.open('/tmp/lt-level.dat','rb').read()
except Exception as e:
    print("could not read level.dat:", e); sys.exit(0)
# Find the DataVersion tag: 0x03 (TAG_Int) + name length + "DataVersion" + 4-byte value
key = b'DataVersion'
i = raw.find(b'\x03' + struct.pack('>H', len(key)) + key)
if i < 0:
    print("DataVersion tag not found")
else:
    off = i + 1 + 2 + len(key)
    val = struct.unpack('>i', raw[off:off+4])[0]
    print("world DataVersion =", val)
# Also print the Version->Name string if present
k2 = b'Name'
j = raw.find(b'\x08' + struct.pack('>H', len(k2)) + k2)
if j >= 0:
    o = j + 1 + 2 + len(k2)
    ln = struct.unpack('>H', raw[o:o+2])[0]
    print("world Version.Name =", raw[o+2:o+2+ln].decode('utf-8', 'replace'))
PY
rm -f /tmp/lt-level.dat
echo "=== END ==="
