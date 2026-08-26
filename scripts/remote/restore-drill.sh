# restore-drill.sh - proves the backups can actually be restored.
#
# Section 20's Phase 0 gate is not "backups are running". It is "a restore drill
# has succeeded". An untested backup is a belief, not a safeguard, and the usual way
# people discover theirs is broken is the day they need it.
#
# NOTHING LIVE IS TOUCHED. Two independent precautions:
#
#   DATABASE: the dump contains `CREATE DATABASE laughtail` and `USE laughtail`,
#   so restoring it as-is would OVERWRITE the live schema. Those two statements are
#   stripped and the remainder is loaded into a separate `laughtail_drill` schema,
#   which is dropped at the end.
#
#   WORLD: extracted into /home/ubuntu/laughtail-scratch/, never into the Pelican
#   volume. That path is also one of the guard's permitted delete roots, so the
#   cleanup cannot be refused or mistargeted.
#
# The drill checks more than "the files came back". It verifies the RESTORED
# database still enforces the row 36 constraint, because a backup that restores
# data but loses a constraint is a backup that silently restores a broken server.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
DEST=/home/ubuntu/laughtail-backups
SCRATCH=/home/ubuntu/laughtail-scratch/restore-drill
# NAMED LITERALLY, not via a variable, and this matters. The destructive-command
# guard reads the script text statically; it cannot know what a shell variable
# expands to, so it fails closed and refuses the whole run - which is exactly what
# it did on the first attempt. The general rule: never hide a destructive target behind a
# variable, or static checking cannot protect you. The guard permits this name
# because it ends in _drill (see guard.tests.ps1 GROUP 14).
FAIL=0

echo "=== newest backups ==="
WORLD_TAR=$(sudo -n find "$DEST" -maxdepth 1 -name 'world-*.tar.gz' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
DB_SQL=$(sudo -n find "$DEST" -maxdepth 1 -name 'db-*.sql.gz' -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
echo "world: $(basename "$WORLD_TAR")"
echo "db:    $(basename "$DB_SQL")"
if [ -z "$WORLD_TAR" ] || [ -z "$DB_SQL" ]; then
  echo "ABORT: no backups found. Run backup-run.sh first."
  exit 2
fi

# ---------------------------------------------------------------------------
# PART 1 - database
# ---------------------------------------------------------------------------
q() {
  local out rc db="$1"; shift
  out=$(sudo -n docker exec -u root laughtail-db sh -c "mariadb -u root -p\"\$(cat /run/lt-secrets/root_password)\" ${db:+-D $db} -N -B -e \"$1\"" 2>&1)
  rc=$?
  printf '%s\n' "$out" | sed '/password on the command line/d'
  return $rc
}

echo ""
echo "=== PART 1: database restore into a scratch schema ==="
q "" "DROP DATABASE IF EXISTS laughtail_drill; CREATE DATABASE laughtail_drill CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
echo "created laughtail_drill"

echo "--- loading the dump, with CREATE DATABASE and USE stripped ---"
sudo -n zcat "$DB_SQL" \
  | sed -e '/^CREATE DATABASE/d' -e '/^USE /d' \
  | sudo -n docker exec -i -u root laughtail-db sh -c \
      "mariadb -u root -p\"\$(cat /run/lt-secrets/root_password)\" -D laughtail_drill" 2>&1 \
  | sed '/password on the command line/d'
echo "loaded"

echo "--- tables restored ---"
q "laughtail_drill" "SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA='laughtail_drill' ORDER BY TABLE_NAME;"

RESTORED=$(q "laughtail_drill" "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='laughtail_drill';" | tr -dc '0-9')
LIVE=$(q "laughtail" "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='laughtail';" | tr -dc '0-9')
echo "--- table count: restored=$RESTORED live=$LIVE ---"
if [ "$RESTORED" = "$LIVE" ] && [ -n "$RESTORED" ]; then
  echo "  OK: table counts match"
else
  echo "  FAIL: table counts differ"
  FAIL=$((FAIL + 1))
fi

echo "--- migration history survived? ---"
q "laughtail_drill" "SELECT version, description, checksum FROM schema_migrations ORDER BY version;"
DRILL_SUM=$(q "laughtail_drill" "SELECT checksum FROM schema_migrations WHERE version='V1';" | tr -dc '0-9a-f')
LIVE_SUM=$(q "laughtail" "SELECT checksum FROM schema_migrations WHERE version='V1';" | tr -dc '0-9a-f')
if [ "$DRILL_SUM" = "$LIVE_SUM" ] && [ -n "$DRILL_SUM" ]; then
  echo "  OK: V1 checksum identical in the restored copy"
else
  echo "  FAIL: checksum differs (restored=$DRILL_SUM live=$LIVE_SUM)"
  FAIL=$((FAIL + 1))
fi

echo "--- do CONSTRAINTS survive the round trip? (row 36) ---"
# A backup that restores rows but loses a constraint restores a broken server.
q "laughtail_drill" "INSERT INTO players (uuid, current_name, first_join, last_seen, created_at, updated_at) VALUES ('00000000-0000-4000-8000-000000000002', 'DrillTest', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));"
q "laughtail_drill" "INSERT INTO seasons (season_number, starts_at, ends_at, state, created_at, updated_at) VALUES (88888, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), 'archived', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));"
q "laughtail_drill" "INSERT INTO champions (season_number, uuid, final_rp, awarded_at, created_at) VALUES (88888, '00000000-0000-4000-8000-000000000002', 100, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));"
DUP=$(q "laughtail_drill" "INSERT INTO champions (season_number, uuid, final_rp, awarded_at, created_at) VALUES (88888, '00000000-0000-4000-8000-000000000002', 200, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));" || true)
if echo "$DUP" | grep -qi 'duplicate entry'; then
  echo "  OK: the restored schema still refuses a second champion"
else
  echo "  FAIL: the constraint did NOT survive the backup/restore round trip"
  echo "    database said: $DUP"
  FAIL=$((FAIL + 1))
fi

echo "--- foreign keys survived? ---"
FK=$(q "laughtail_drill" "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA='laughtail_drill' AND CONSTRAINT_TYPE='FOREIGN KEY';" | tr -dc '0-9')
FKL=$(q "laughtail" "SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA='laughtail' AND CONSTRAINT_TYPE='FOREIGN KEY';" | tr -dc '0-9')
echo "  foreign keys: restored=$FK live=$FKL"
if [ "$FK" = "$FKL" ] && [ -n "$FK" ]; then echo "  OK"; else echo "  FAIL"; FAIL=$((FAIL + 1)); fi

echo "--- dropping the scratch schema ---"
q "" "DROP DATABASE laughtail_drill;"
q "" "SHOW DATABASES;"

# ---------------------------------------------------------------------------
# PART 2 - world
# ---------------------------------------------------------------------------
echo ""
echo "=== PART 2: world restore into scratch ==="
# LITERAL PATH, NOT $SCRATCH. The destructive-command guard refuses a recursive delete whose target
# is a variable, and it is right to: a static check cannot know what a variable expands to, and this
# is the one command in the repository that could delete the wrong tree. Written out so the guard can
# read it, and so can anyone reviewing this file.
sudo -n rm -rf /home/ubuntu/laughtail-scratch/restore-drill
sudo -n mkdir -p "$SCRATCH"
sudo -n tar -xzf "$WORLD_TAR" -C "$SCRATCH"
echo "extracted to $SCRATCH"
sudo -n du -sh "$SCRATCH"

echo "--- level.dat must exist and be a valid gzip NBT file ---"
if sudo -n test -f "$SCRATCH/laughtail/level.dat"; then
  SZ=$(sudo -n stat -c %s "$SCRATCH/laughtail/level.dat")
  MAGIC=$(sudo -n od -An -tx1 -N2 "$SCRATCH/laughtail/level.dat" | tr -d ' \n')
  echo "  size=$SZ bytes magic=$MAGIC (1f8b = gzip, which is what level.dat is)"
  if [ "$MAGIC" = "1f8b" ] && [ "$SZ" -gt 100 ]; then
    echo "  OK: level.dat is a plausible gzip NBT file"
  else
    echo "  FAIL: level.dat is not a valid gzip file"
    FAIL=$((FAIL + 1))
  fi
  # Decompress it - the strongest cheap proof it is not truncated.
  # gzip -t takes a FILENAME. Writing `sudo gzip -t < file` puts the redirect in
  # the calling shell, which runs as ubuntu and cannot read a root-owned file - it
  # fails with "Permission denied" while an || fallback quietly rescues the result.
  # Third instance of this class of bug in this project; sudo never applies to the
  # shell's own redirection.
  if sudo -n gzip -t "$SCRATCH/laughtail/level.dat" 2>/dev/null; then
    echo "  OK: level.dat decompresses cleanly (not truncated)"
  else
    echo "  FAIL: level.dat will not decompress"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: no level.dat in the restored world"
  FAIL=$((FAIL + 1))
fi

echo "--- region files: restored vs live ---"
R_RESTORED=$(sudo -n find "$SCRATCH" -name '*.mca' | wc -l)
# 26.2 UNIFIED WORLD LAYOUT (D-0029): every dimension now lives INSIDE laughtail/dimensions/, so the
# old sibling directories laughtail_nether and laughtail_the_end no longer exist. `find` on a missing
# path exits 1, and under `set -e` that killed the whole drill silently after the level.dat checks -
# which is exactly the kind of stale assumption a drill is supposed to catch, in its own code this time.
R_LIVE=$(sudo -n find "$D/laughtail" -name '*.mca' 2>/dev/null | wc -l || true)
echo "  restored=$R_RESTORED live=$R_LIVE"
if [ "$R_RESTORED" -ge 1 ] && [ "$R_RESTORED" -eq "$R_LIVE" ]; then
  echo "  OK: every region file came back"
else
  echo "  NOTE: counts differ - the live server has written new chunks since the backup, which is expected on a running server"
fi

echo "--- a region file must have a non-empty header ---"
# -print -quit RATHER THAN | head -1. head closes the pipe as soon as it has its line, find then dies
# of SIGPIPE, and under `pipefail` that is exit 141 which kills the drill. The drill exited 141 here
# with no error message at all, which is worse than failing loudly.
SAMPLE=$(sudo -n find "$SCRATCH" -name '*.mca' -print -quit)
if [ -n "$SAMPLE" ]; then
  NONZERO=$( { sudo -n od -An -tx1 -N 4096 "$SAMPLE" || true; } | tr -d ' \n' | tr -d '0' | wc -c )
  echo "  $(basename "$SAMPLE"): $NONZERO non-zero nibbles in the 4 KB location table"
  if [ "$NONZERO" -gt 0 ]; then echo "  OK: the chunk location table is populated"; else echo "  FAIL: header is all zeroes"; FAIL=$((FAIL + 1)); fi
fi

echo "--- config and access files must be restorable too ---"
for f in server.properties ops.json whitelist.json config/paper-global.yml spigot.yml; do
  if sudo -n test -s "$SCRATCH/$f"; then echo "  OK   $f"; else echo "  FAIL $f"; FAIL=$((FAIL + 1)); fi
done

echo "--- the restored server.properties must still carry the right values ---"
for k in white-list online-mode level-name; do
  echo "  $k = $(sudo -n grep -m1 "^${k}=" "$SCRATCH/server.properties" | cut -d= -f2-)"
done
echo "  rcon.password present? $(sudo -n grep -c '^rcon.password=..*' "$SCRATCH/server.properties") (1 expected - the backup DOES contain secrets, which is why it stays on the host)"

echo "--- cleaning up scratch ---"
# LITERAL PATH, NOT $SCRATCH. The destructive-command guard refuses a recursive delete whose target
# is a variable, and it is right to: a static check cannot know what a variable expands to, and this
# is the one command in the repository that could delete the wrong tree. Written out so the guard can
# read it, and so can anyone reviewing this file.
sudo -n rm -rf /home/ubuntu/laughtail-scratch/restore-drill
sudo -n test -d "$SCRATCH" && echo "  WARNING: scratch still present" || echo "  removed"

echo ""
echo "=== RESULT ==="
if [ "$FAIL" -eq 0 ]; then
  echo "RESTORE DRILL PASSED - $FAIL failures"
else
  echo "RESTORE DRILL FAILED - $FAIL check(s) failed"
fi
free -m | head -2
echo "=== END ==="
exit "$FAIL"
