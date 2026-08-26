# health-check.sh - READ ONLY. End-of-session state check (never-break rule 14:
# never leave the server in a broken state, and record what the state is).

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
L="/var/lib/pelican/volumes/$V/logs/latest.log"

echo "=== container ==="
sudo -n docker ps --filter "name=$V" --format '{{.Status}}'
echo "=== all containers ==="
sudo -n docker ps --format '{{.Names}}  {{.Status}}'
echo "=== database reachable? ==="
if sudo -n docker ps --format '{{.Names}}' | grep -qx laughtail-db; then
  sudo -n docker exec -u root laughtail-db sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "SELECT COUNT(*) AS migrations_applied FROM schema_migrations;"' 2>&1 | sed '/password on the command line/d'
else
  echo "(laughtail-db not running)"
fi
echo "=== cpu and memory of the game container ==="
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}}' "$V"
echo "=== errors since boot (0 expected) ==="
sudo -n grep -cE 'ERROR|SEVERE' "$L"
echo "=== has anyone joined yet? ==="
sudo -n grep -cE 'joined the game' "$L"
echo "=== host memory ==="
free -m | head -2
echo "=== END ==="
