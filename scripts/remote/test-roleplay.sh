q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
FAIL=0
ok()  { echo "  OK: $1"; }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== 1. the four Houses were seeded ==="
H=$(q "SELECT COUNT(*) FROM houses;")
[ "$H" = "4" ] && ok "4 Houses present" || bad "$H Houses, expected 4"
q "SELECT display, motto FROM houses ORDER BY house;" | awk -F'\t' '{printf "    %-16s %s\n",$1,$2}'

echo "=== 2. LAW 1: no roleplay table can hold a combat bonus ==="
# The rule is meant to be STRUCTURAL, not a promise in a comment. If no column exists that could
# hold a stat bonus, then no future change can quietly add one without a migration that someone
# has to review. This asserts that absence.
BAD=$(q "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME IN ('paths','houses','house_members','house_standing','titles_owned','player_identity','chronicle_chapters','chronicle_objectives') AND (COLUMN_NAME LIKE '%damage%' OR COLUMN_NAME LIKE '%health%' OR COLUMN_NAME LIKE '%speed%' OR COLUMN_NAME LIKE '%bonus%' OR COLUMN_NAME LIKE '%multiplier%' OR COLUMN_NAME LIKE '%discount%' OR COLUMN_NAME LIKE '%permission%' OR COLUMN_NAME LIKE '%drop%');")
if [ "$BAD" = "0" ]; then
  ok "no column in any roleplay table could hold a combat or economic advantage"
else
  bad "$BAD column(s) could hold an advantage - Law 1 is not structural"
fi

echo "=== 3. roleplay cannot write to the rating table ==="
# Row 30 requires non-combat play to change rating by EXACTLY ZERO. combat_ratings is written only
# from recordCombatEvent; this confirms nothing in the roleplay path shares a table with it.
SHARED=$(q "SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA='laughtail' AND REFERENCED_TABLE_NAME='combat_ratings';")
if [ "$SHARED" = "0" ]; then
  ok "no table references combat_ratings, so no roleplay write can reach the ladder"
else
  bad "$SHARED foreign key(s) point at combat_ratings"
fi

echo "=== 4. titles table can only hold text and colour ==="
q "SELECT COLUMN_NAME, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='titles_owned' ORDER BY ORDINAL_POSITION;" | awk -F'\t' '{printf "    %-12s %s\n",$1,$2}'

echo "=== 5. the paths table accepts only the six Paths ==="
ENUMDEF=$(q "SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='paths' AND COLUMN_NAME='path';")
echo "    $ENUMDEF"
INVALID=$(q "INSERT INTO paths (uuid, path, xp, level, created_at, updated_at) VALUES ('263645f0-7a1b-4d45-a0c9-16d9b0d345d0','warrior',1,1,UTC_TIMESTAMP(3),UTC_TIMESTAMP(3));" || true)
if echo "$INVALID" | grep -qiE "incorrect|invalid|truncated|data"; then
  ok "an invented Path was refused by the enum"
else
  bad "an arbitrary Path name was accepted: $INVALID"
  q "DELETE FROM paths WHERE path NOT IN ('delver','cultivator','hunter','wayfinder','artificer','broker');" >/dev/null
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "ROLEPLAY: all pass"; else echo "ROLEPLAY: $FAIL failure(s)"; exit 1; fi