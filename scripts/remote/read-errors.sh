# read-errors.sh - READ ONLY. Shows any ERROR/SEVERE lines and the world version.
V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
echo "=== error lines this boot ==="
sudo -n grep -n -e ERROR -e SEVERE "$D/logs/latest.log" | head -8 || echo "(none)"
echo "=== warnings worth seeing ==="
sudo -n grep -n -e WARN "$D/logs/latest.log" | grep -viE 'behind the latest|papermc.io/downloads|recommended that you update|\*\*\*' | head -10 || echo "(none)"
echo "=== server version ==="
sudo -n grep -m1 'This server is running' "$D/logs/latest.log"
echo "=== the laughtail world DataVersion after the upgrade ==="
sudo -n python3 - <<'PY'
import gzip, struct, sys, glob
p = glob.glob('/var/lib/pelican/volumes/*/laughtail/level.dat')
if not p:
    print('no level.dat'); sys.exit()
data = gzip.open(p[0], 'rb').read()
i = data.find(b'DataVersion')
if i >= 0:
    print('DataVersion =', struct.unpack('>i', data[i+11:i+15])[0])
else:
    print('DataVersion tag not found')
PY
echo "=== the owner's ORIGINAL 26.2 world must still be untouched ==="
sudo -n stat -c 'world/level.dat mtime=%y' "$D/world/level.dat"
echo "=== END ==="
