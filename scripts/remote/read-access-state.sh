# read-access-state.sh - READ ONLY.
#
# Prints ops.json, whitelist.json and usercache.json so the access state can be
# corrected before the server is started with white-list=true.
#
# HISTORY, kept deliberately: an earlier version of this script also ran
#   cat "$D/server.properties"
# which printed the live RCON password and the management-server secret into an
# agent transcript. That is the exact failure never-break rule 5 exists to stop.
# The dump is removed. Property KEYS are read by read-properties-keys.sh and
# property VALUES only ever by name, excluding the two secret-bearing keys.
# Do not re-add a whole-file cat of server.properties to any script.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"

echo "=== ops.json ==="
sudo -n cat "$D/ops.json" 2>/dev/null || echo "(none)"
echo "=== whitelist.json ==="
sudo -n cat "$D/whitelist.json" 2>/dev/null || echo "(none)"
echo "=== usercache.json ==="
sudo -n cat "$D/usercache.json" 2>/dev/null || echo "(none)"
echo "=== banned-players.json / banned-ips.json ==="
sudo -n cat "$D/banned-players.json" 2>/dev/null || echo "(none)"
sudo -n cat "$D/banned-ips.json" 2>/dev/null || echo "(none)"
echo "=== ownership of the access files ==="
for f in ops.json whitelist.json usercache.json banned-players.json banned-ips.json; do
  if sudo -n test -f "$D/$f"; then
    sudo -n stat -c "%n owner=%u:%g mode=%a size=%s" "$D/$f"
  fi
done
echo "=== END ==="
