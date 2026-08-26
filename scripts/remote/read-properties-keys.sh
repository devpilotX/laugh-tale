# read-properties-keys.sh - READ ONLY.
#
# Lists the KEY NAMES in the live server.properties and nothing else. Values are
# never printed, because this file holds the RCON password and the management
# server secret and neither may enter an agent transcript or the repository
# (never-break rule 5).
#
# Purpose: before deploying the repository template, prove which keys would be
# dropped. A dropped key is not neutral - Paper rewrites the file at boot and
# regenerates its default, which for a secret means silently rotating it.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
LIVE="$D/server.properties"

echo "=== volume ==="
echo "$V"

echo "=== is the container running? ==="
if sudo -n docker ps --format '{{.Names}} {{.Status}}' | grep -q "$V"; then
  sudo -n docker ps --format '{{.Names}} {{.Status}}' | grep "$V"
  echo "STATE: RUNNING"
else
  echo "STATE: stopped"
fi

echo "=== live server.properties: file facts ==="
sudo -n stat -c 'owner=%u:%g mode=%a size=%s mtime=%y' "$LIVE"

echo "=== live keys, names only, sorted ==="
sudo -n grep -o '^[a-z0-9._-]*=' "$LIVE" | tr -d '=' | sort

echo "=== count ==="
sudo -n grep -c '^[a-z0-9._-]*=' "$LIVE"

echo "=== which keys hold a NON-EMPTY value? (names only) ==="
sudo -n grep -E '^[a-z0-9._-]+=.+' "$LIVE" | grep -o '^[a-z0-9._-]*' | sort

echo "=== END ==="
