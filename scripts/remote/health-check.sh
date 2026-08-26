# health-check.sh - READ ONLY. End-of-session state check (never-break rule 14:
# never leave the server in a broken state, and record what the state is).

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
L="/var/lib/pelican/volumes/$V/logs/latest.log"

echo "=== container ==="
sudo -n docker ps --filter "name=$V" --format '{{.Status}}'
echo "=== cpu and memory of the game container ==="
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}}' "$V"
echo "=== errors since boot (0 expected) ==="
sudo -n grep -cE 'ERROR|SEVERE' "$L"
echo "=== has anyone joined yet? ==="
sudo -n grep -cE 'joined the game' "$L"
echo "=== host memory ==="
free -m | head -2
echo "=== END ==="
