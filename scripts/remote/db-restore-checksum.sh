# db-restore-checksum.sh - undoes db-test-forward-only.sh.
#
# The real V1 checksum, recorded when the migration was applied at
# 2026-08-26 04:11:42.311 UTC and re-derived from the staged file by the runner:
#   4d3a4fb7bbeb2adee66abe6320a58a135d2c700feba16ec06c6c1a3693bcb7ec
#
# This is not a secret - it is a hash of a file that is in git. It is written here
# rather than recomputed so the restore cannot itself be fooled by a changed file.

set -e

NAME=laughtail-db
DB=laughtail
REAL="4d3a4fb7bbeb2adee66abe6320a58a135d2c700feba16ec06c6c1a3693bcb7ec"

q() {
  local out rc
  out=$(sudo -n docker exec -u root "$NAME" sh -c "mariadb -u $DB -p\"\$(cat /run/lt-secrets/app_password)\" -D $DB -N -B -e \"$1\"" 2>&1)
  rc=$?
  printf '%s\n' "$out" | sed '/password on the command line/d'
  return $rc
}

echo "=== restoring ==="
q "UPDATE schema_migrations SET checksum='$REAL' WHERE version='V1';"

echo "=== verifying the recorded checksum matches the staged file again ==="
FILE_SUM=$(sudo -n sha256sum /home/ubuntu/laughtail-db/migrations/V1__init.sql | cut -d' ' -f1)
REC=$(q "SELECT checksum FROM schema_migrations WHERE version='V1';" | tr -dc '0-9a-f')
echo "file:     $FILE_SUM"
echo "recorded: $REC"
if [ "$FILE_SUM" = "$REC" ]; then
  echo "RESTORED: the runner will proceed normally again."
else
  echo "STILL WRONG - do not leave it in this state."
  exit 2
fi
echo "=== END ==="
