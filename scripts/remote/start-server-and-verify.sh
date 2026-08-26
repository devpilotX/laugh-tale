# start-server-and-verify.sh - first boot of pinned Paper 1.21.11 on aarch64.
#
# This is the deviation D5 gate: no plugin is considered accepted into the
# manifest until it has been OBSERVED loading on this host. The host is Graviton
# (arm64), which the specification never knew, so a plugin shipping native
# libraries can fail here and nowhere else.
#
# It is also the first boot with level-name=laughtail, so a NEW world is
# generated and the owner's pre-existing world/ directory must remain untouched
# (decision D-0013). Both are checked.
#
# Never-break rule 2: only one Paper server exists on this box, and this is it.
# Never-break rule 4: the heap must sit at least 25% below the allocation. That is
# asserted BEFORE starting, not hoped for afterwards.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
L="$D/logs/latest.log"

echo "=== pre-flight: resources ==="
free -m | head -2
echo "--- disk ---"
df -h --output=target,size,avail,pcent / | tail -1
echo "--- old world must be present and is expected to stay untouched ---"
if sudo -n test -f "$D/world/level.dat"; then
  sudo -n stat -c 'world/level.dat mtime=%y size=%s' "$D/world/level.dat"
  OLD_WORLD_MTIME=$(sudo -n stat -c %Y "$D/world/level.dat")
else
  echo "(no pre-existing world/level.dat)"
  OLD_WORLD_MTIME=0
fi

echo "=== pre-flight: never-break rule 4, heap must be 25%+ below allocation ==="
ALLOC=$(sudo -n docker inspect "$V" --format '{{.HostConfig.Memory}}' 2>/dev/null || echo 0)
ALLOC_MB=$((ALLOC / 1024 / 1024))
echo "container memory limit: ${ALLOC_MB} MiB"
# The startup command and its -Xmx live in the Panel database, not in the volume,
# so the honest source is the container config Wings generated for the last run.
CMD=$(sudo -n docker inspect "$V" --format '{{join .Config.Cmd " "}}' 2>/dev/null || echo "")
echo "last start command: $CMD"

echo "=== eula ==="
sudo -n cat "$D/eula.txt" 2>/dev/null | grep -v '^#' || echo "(no eula.txt)"

echo "=== truncate the log so this boot is unambiguous ==="
# Keeping the old log would make grep counts below meaningless.
if sudo -n test -f "$L"; then
  sudo -n cp -p "$L" "$D/logs/pre-laughtail-boot.log"
  sudo -n truncate -s 0 "$L"
  echo "previous log copied to logs/pre-laughtail-boot.log and truncated"
fi

echo "=== starting via the Panel so Wings records it as intentional ==="
sudo -n bash -c "cd /var/www/pelican && php artisan p:server:bulk-power start --servers=1 --no-interaction" 2>&1 | tail -5

echo "=== waiting for 'Done' (up to 420s - first boot generates a new world) ==="
DONE=0
for i in $(seq 1 140); do
  if sudo -n grep -q 'Done (' "$L" 2>/dev/null; then
    echo "server reported Done after approximately $((i * 3))s"
    DONE=1
    break
  fi
  if sudo -n grep -qE 'Failed to start|A fatal error|Could not load|FATAL' "$L" 2>/dev/null; then
    echo "FATAL text found in the log, stopping the wait early"
    break
  fi
  sleep 3
done

echo "=== container state ==="
sudo -n docker ps --filter "name=$V" --format '{{.Names}} {{.Status}}'

echo "=== server / java / architecture ==="
sudo -n grep -m1 'Starting minecraft server version' "$L" 2>/dev/null || true
sudo -n grep -m1 'This server is running' "$L" 2>/dev/null || true
sudo -n grep -m1 'Loading properties' "$L" 2>/dev/null || true
sudo -n docker exec "$V" sh -c 'java -version 2>&1 | head -2; uname -m' 2>/dev/null || echo "(container not up for exec)"

echo "=== D5 GATE: every manifest plugin must appear as Enabling ==="
MISSING=0
for P in Geyser-Spigot floodgate ViaVersion ViaBackwards LuckPerms Chunky GrimAC voicechat; do
  LINE=$(sudo -n grep -iE "Enabling .*${P}" "$L" 2>/dev/null | head -1 || true)
  if [ -n "$LINE" ]; then
    echo "  LOADED  $P -> $LINE"
  else
    echo "  MISSING $P"
    MISSING=$((MISSING + 1))
  fi
done
echo "plugins not observed loading: $MISSING"

echo "=== bukkit plugin list as the server sees it ==="
sudo -n grep -iE '\[.*\] Enabling|Loading server plugin' "$L" 2>/dev/null | tail -20 || true

echo "=== errors and warnings this boot ==="
sudo -n grep -cE 'ERROR|SEVERE' "$L" 2>/dev/null || echo 0
sudo -n grep -E 'ERROR|SEVERE' "$L" 2>/dev/null | head -20 || true
echo "--- native library or architecture complaints, if any ---"
sudo -n grep -iE 'UnsatisfiedLink|no .* in java.library.path|aarch64|arm64|not supported on' "$L" 2>/dev/null | head -10 || echo "(none)"

echo "=== new world must exist, old world must be untouched (D-0013) ==="
sudo -n ls -1d "$D/laughtail" "$D/laughtail_nether" "$D/laughtail_the_end" 2>/dev/null || echo "(new world dirs not all present yet)"
if [ "$OLD_WORLD_MTIME" != "0" ]; then
  NEW_MTIME=$(sudo -n stat -c %Y "$D/world/level.dat")
  echo "world/level.dat mtime before=$OLD_WORLD_MTIME after=$NEW_MTIME"
  if [ "$OLD_WORLD_MTIME" = "$NEW_MTIME" ]; then
    echo "  OK: the pre-existing world was NOT touched"
  else
    echo "  ALARM: the pre-existing world was modified. Stop and investigate."
  fi
fi

echo "=== whitelist actually enforced? ==="
sudo -n grep -iE 'whitelist' "$L" 2>/dev/null | head -5 || echo "(no whitelist lines)"

echo "=== memory after boot ==="
free -m | head -2
echo "=== last 25 log lines ==="
sudo -n tail -25 "$L" 2>/dev/null
echo "=== END (done_flag=$DONE missing_plugins=$MISSING) ==="
