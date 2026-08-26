# confirm-running-build.sh - READ ONLY. Is the loaded plugin the one just built?
V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
echo "=== container started at ==="
sudo -n docker inspect "$V" --format '{{.State.StartedAt}}'
echo "=== plugin jar on disk ==="
sudo -n stat -c '  %n  %s bytes  mtime=%y' "$D/plugins/LaughTail-0.1.0.jar"
echo "=== the marker only the NEW build logs ==="
sudo -n grep -c 'Anti-farm thresholds loaded' "$D/logs/latest.log" || true
sudo -n grep 'Anti-farm thresholds' "$D/logs/latest.log" | tail -2 || echo "  (absent - the running build predates the trackers)"
echo "=== most recent LaughTail lines ==="
sudo -n grep 'LaughTail' "$D/logs/latest.log" | tail -6
echo "=== most recent Done line ==="
sudo -n grep 'Done (' "$D/logs/latest.log" | tail -2
echo "=== log first and last timestamps, to see whether it was truncated ==="
sudo -n head -1 "$D/logs/latest.log" | cut -c1-40
sudo -n tail -1 "$D/logs/latest.log" | cut -c1-40
echo "=== END ==="
