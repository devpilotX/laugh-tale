# read-join-evidence.sh - READ ONLY. Did a real client connect, and what happened?
#
# This is acceptance evidence for the access path: online-mode authentication, the
# whitelist, the rename to IgnisClaw, and Floodgate/Geyser not interfering.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"

echo "=== join and leave events in the current log ==="
sudo -n grep -E 'joined the game|left the game|logged in with entity id|lost connection|Disconnecting' "$D/logs/latest.log" 2>/dev/null | tail -20 || echo "(none in current log)"

echo "=== any whitelist rejections? (proves the paywall gate is live) ==="
sudo -n grep -iE 'not white-?listed|You are not white' "$D/logs/latest.log" 2>/dev/null | tail -5 || echo "(none)"

echo "=== earlier logs, in case the join was before the last restart ==="
sudo -n ls -1t "$D/logs" 2>/dev/null | head -6
for f in $(sudo -n ls -1t "$D/logs"/*.log.gz 2>/dev/null | head -3); do
  echo "--- $f ---"
  sudo -n zcat "$f" 2>/dev/null | grep -E 'joined the game|left the game' | tail -5 || true
done

echo "=== usercache: who has the server actually seen? ==="
sudo -n cat "$D/usercache.json" 2>/dev/null

echo "=== player data files written (proves the world persisted a player) ==="
sudo -n ls -la "$D/laughtail/playerdata" 2>/dev/null | head -10 || echo "(no playerdata yet)"
sudo -n ls -la "$D/laughtail/stats" 2>/dev/null | head -5 || echo "(no stats yet)"

echo "=== END ==="
