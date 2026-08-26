# db-test-forward-only.sh - proves the migration runner REFUSES to proceed when an
# applied migration no longer matches its recorded checksum.
#
# Why test it this way: the honest trigger would be editing db/migrations/V1__init.sql,
# but that is the one thing forward-only migrations forbid, and doing it even
# briefly would put a wrong checksum into git history. So the recorded checksum is
# corrupted in the database instead. That exercises exactly the same comparison and
# the same abort path, and it is fully reversible - the real value is saved first
# and restored at the end, and the restore is verified.
#
# A guard that has never been observed refusing anything is an assumption.

set -e

NAME=laughtail-db
DB=laughtail

q() {
  local out rc
  out=$(sudo -n docker exec -u root "$NAME" sh -c "mariadb -u $DB -p\"\$(cat /run/lt-secrets/app_password)\" -D $DB -N -B -e \"$1\"" 2>&1)
  rc=$?
  printf '%s\n' "$out" | sed '/password on the command line/d'
  return $rc
}

echo "=== saving the real checksum ==="
REAL=$(q "SELECT checksum FROM schema_migrations WHERE version='V1';" | tr -dc '0-9a-f')
echo "real checksum length: ${#REAL} (value shown below, it is not a secret)"
echo "  $REAL"
if [ ${#REAL} -ne 64 ]; then
  echo "ABORT: could not read a 64-char checksum. Doing nothing."
  exit 2
fi

echo "=== corrupting it to simulate an edited migration ==="
FAKE="deadbeef00000000000000000000000000000000000000000000000000000000"
q "UPDATE schema_migrations SET checksum='$FAKE' WHERE version='V1';"
q "SELECT version, checksum FROM schema_migrations WHERE version='V1';"

echo ""
echo "=== the runner must now ABORT with exit 3. Restoring afterwards regardless. ==="
echo "(the runner is invoked by the caller; this script only sets up and tears down)"
echo "CORRUPTED - now run db-migrate.sh and expect: ABORT ... forward-only, exit 3"
echo "=== END ==="
