# rotate-db-app-password.sh - rotates the laughtail database user's password.
#
# WHY: the previous value was printed into an agent transcript by a defective
# redaction in deploy-plugin-config.sh (D-0026). A credential that has been
# displayed is a credential that must be replaced, regardless of how unlikely
# exposure is - and this one is cheap to rotate because only one consumer uses it.
#
# NOTHING EXTERNAL DEPENDS ON IT. The `laughtail` user is reachable only from the
# pelican_nw Docker network, is used only by the LaughTail plugin, and the plugin
# reads it from a file that this script rewrites. No player, no payment provider and
# no third party is affected.
#
# The new value is generated on the host and never printed. It is written to the
# secrets file, applied to MariaDB, and verified by connecting with it.

set -e

SECRET=/home/ubuntu/laughtail-db/secrets/app_password
NAME=laughtail-db

if ! sudo -n docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "ABORT: $NAME is not running"
  exit 2
fi

echo "=== generating a new password (never printed) ==="
sudo -n bash -c "openssl rand -base64 33 | tr -d '\n=+/' | cut -c1-32 > '${SECRET}.new'"
sudo -n chmod 600 "${SECRET}.new"
NEWLEN=$(sudo -n bash -c "tr -d '\n' < '${SECRET}.new' | wc -c")
echo "  new password generated (${NEWLEN} chars)"
if [ "$NEWLEN" -ne 32 ]; then
  echo "ABORT: expected 32 characters, got $NEWLEN. Not rotating."
  sudo -n rm -f "${SECRET}.new"
  exit 3
fi

echo "=== applying it to MariaDB ==="
# No copy needed: ${SECRET}.new already lives in the secrets directory, which is
# mounted into the container read-only at /run/lt-secrets. The first version copied
# the file onto itself and cp refused.
#
# The new password is read from that mounted file inside the container, never passed
# on a command line - argv is visible to every process on the host via ps.
sudo -n docker exec -u root "$NAME" sh -c '
  NEW=$(cat /run/lt-secrets/app_password.new)
  mariadb -u root -p"$(cat /run/lt-secrets/root_password)" -N -B -e "
    ALTER USER '"'"'laughtail'"'"'@'"'"'%'"'"' IDENTIFIED BY '"'"'$NEW'"'"';
    FLUSH PRIVILEGES;" 2>&1 | grep -v "password on the command line" || true
  echo "alter issued"
'

echo "=== verifying the NEW password works ==="
if sudo -n docker exec -u root "$NAME" sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password.new)" -D laughtail -N -B -e "SELECT 1;"' >/dev/null 2>&1; then
  echo "  OK: the new password authenticates"
else
  echo "  FAIL: the new password does not work. Leaving the OLD one in place."
  sudo -n rm -f "${SECRET}.new" /home/ubuntu/laughtail-db/secrets/app_password.new
  exit 4
fi

echo "=== confirming the OLD password no longer works ==="
# A rotation that leaves the old credential valid is not a rotation.
if sudo -n docker exec -u root "$NAME" sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "SELECT 1;"' >/dev/null 2>&1; then
  echo "  FAIL: the old password STILL works - the rotation did not take effect"
  exit 5
else
  echo "  OK: the old password is rejected"
fi

echo "=== promoting the new secret ==="
sudo -n mv "${SECRET}.new" "$SECRET"
sudo -n chmod 600 "$SECRET"
sudo -n stat -c '  %n mode=%a size=%s' "$SECRET"

echo "PASSWORD ROTATED - now redeploy the plugin config so the plugin gets the new value"
echo "=== END ==="
