V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
L="$D/logs/latest.log"

echo "=== who is online (joined minus left in the current log) ==="
# CAREFUL: `grep -c` prints "0" AND exits 1 when there are no matches. So the
# obvious `$(grep -c ... || echo 0)` captures BOTH grep's "0" and echo's "0",
# giving "0\n0", which makes the arithmetic below fail with a bash error and
# leaves the online count garbage - in a guard whose entire job is to avoid
# kicking players. Take the first line and keep only digits.
count_lines() {
  local n
  n=$(sudo -n grep -c "$1" "$2" 2>/dev/null | head -1 | tr -dc '0-9')
  [ -z "$n" ] && n=0
  printf '%s' "$n"
}
JOINED=$(count_lines 'joined the game' "$L")
LEFT=$(count_lines 'left the game' "$L")
echo "joined events: $JOINED   left events: $LEFT"
ONLINE=$((JOINED - LEFT))
echo "estimated online: $ONLINE"
echo "--- last 8 join/leave events ---"
sudo -n grep -E 'joined the game|left the game' "$L" 2>/dev/null | tail -8 || echo "(none)"

if [ "$ONLINE" -gt 0 ]; then
  echo "ABORTING: $ONLINE player(s) appear to be online. Not stopping the server."
  exit 2
fi

echo "=== container state before ==="
sudo -n docker ps --filter "name=$V" --format '{{.Names}} {{.Status}}'

echo "=== stopping via the Panel so Wings records it as intentional ==="
sudo -n bash -c "cd /var/www/pelican && php artisan p:server:bulk-power stop --servers=1 --no-interaction" 2>&1 | tail -5

echo "=== waiting for a clean shutdown (up to 60s) ==="
for i in $(seq 1 30); do
  S=$(sudo -n docker ps --filter "name=$V" --format '{{.Status}}')
  if [ -z "$S" ]; then echo "stopped after ${i}x2s"; break; fi
  sleep 2
done

echo "=== container state after ==="
sudo -n docker ps -a --filter "name=$V" --format '{{.Names}} {{.Status}}'
echo "=== did the world save cleanly? ==="
sudo -n tail -12 "$L" 2>/dev/null
echo "=== memory now free ==="
free -m | head -2
echo "=== END ==="
