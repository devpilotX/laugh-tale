set -e
V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
SRC="/var/lib/pelican/volumes/$V"
BK="/home/ubuntu/laughtail-backups"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$BK/prebuild-volume-$STAMP.tar.gz"

echo "=== disk before ==="
df -h --output=source,size,used,avail,pcent / | tail -1

mkdir -p "$BK"
echo "=== volume to back up ==="
echo "  $SRC"
sudo -n du -sh "$SRC"

echo "=== creating archive (server files only, not the host) ==="
sudo -n tar -czf "$OUT" -C /var/lib/pelican/volumes "$V"
sudo -n chown ubuntu:ubuntu "$OUT"

echo "=== archive ==="
ls -lh "$OUT"
sha256sum "$OUT" | tee "$OUT.sha256"

echo "=== integrity: can it be listed and does it contain the world? ==="
tar -tzf "$OUT" | head -5
echo "  world entries: $(tar -tzf "$OUT" | grep -c "/world/" || true)"
echo "  total entries: $(tar -tzf "$OUT" | wc -l)"

echo "=== disk after ==="
df -h --output=source,size,used,avail,pcent / | tail -1
echo "=== all backups present ==="
ls -lh "$BK"
echo "=== END ==="
