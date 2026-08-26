q() {
  sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'
}
FAIL=0
A=263645f0-7a1b-4d45-a0c9-16d9b0d345d0
B=00000000-0000-4000-8000-0000000000f1
LOW=$A; HIGH=$B
if [ "$A" \> "$B" ]; then LOW=$B; HIGH=$A; fi

echo "=== setup: the friends table has foreign keys to players, so the test partner must exist ==="
# The first version of this test used a UUID that was not in players. Both inserts failed on the
# FOREIGN KEY and the test reported the primary key as broken - a false negative that looked exactly
# like a real failure. The FK is doing its job: a friendship with a player who has never joined is
# meaningless, so the schema refuses it.
q "INSERT INTO players (uuid, current_name, first_join, last_seen, created_at, updated_at) VALUES ('$B','TestPartner',UTC_TIMESTAMP(3),UTC_TIMESTAMP(3),UTC_TIMESTAMP(3),UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE current_name='TestPartner';" >/dev/null
EXISTS=$(q "SELECT COUNT(*) FROM players WHERE uuid IN ('$A','$B');")
echo "  both players present: $EXISTS of 2"
[ "$EXISTS" = "2" ] || { echo "  FAIL: setup incomplete, the rest would prove nothing"; exit 1; }
q "DELETE FROM friends WHERE uuid_low='$LOW' AND uuid_high='$HIGH';" >/dev/null

echo "=== 1. one row per pair, so the two sides cannot disagree ==="
INS=$(q "INSERT INTO friends (uuid_low, uuid_high, requested_by, state, created_at, updated_at) VALUES ('$LOW','$HIGH','$A','pending',UTC_TIMESTAMP(3),UTC_TIMESTAMP(3));" || true)
ROWS=$(q "SELECT COUNT(*) FROM friends WHERE uuid_low='$LOW' AND uuid_high='$HIGH';")
if [ "$ROWS" != "1" ]; then echo "  FAIL: the request was not stored: $INS"; FAIL=$((FAIL+1)); fi
DUP=$(q "INSERT INTO friends (uuid_low, uuid_high, requested_by, state, created_at, updated_at) VALUES ('$LOW','$HIGH','$B','pending',UTC_TIMESTAMP(3),UTC_TIMESTAMP(3));" || true)
if echo "$DUP" | grep -qi 'duplicate'; then
  echo "  OK: the reverse direction was REFUSED by the primary key - one row per pair"
else
  echo "  FAIL: a second row for the same pair was accepted: $DUP"
  FAIL=$((FAIL+1))
fi

echo "=== 2. accepting requires the OTHER player to have asked ==="
# This is the exact WHERE clause friendAccept uses. Run with me as the accepter, so requested_by
# must not be me. A asked, so A accepting must change nothing and B accepting must work.
SELFTRY=$(q "UPDATE friends SET state='accepted' WHERE uuid_low='$LOW' AND uuid_high='$HIGH' AND state='pending' AND requested_by='$B';")
S1=$(q "SELECT state FROM friends WHERE uuid_low='$LOW' AND uuid_high='$HIGH';")
if [ "$S1" = "pending" ]; then
  echo "  OK: A accepting their own request changed nothing - still $S1"
else
  echo "  FAIL: A accepted their own request, state is $S1"
  FAIL=$((FAIL+1))
fi
q "UPDATE friends SET state='accepted' WHERE uuid_low='$LOW' AND uuid_high='$HIGH' AND state='pending' AND requested_by='$A';" >/dev/null
S2=$(q "SELECT state FROM friends WHERE uuid_low='$LOW' AND uuid_high='$HIGH';")
if [ "$S2" = "accepted" ]; then
  echo "  OK: B accepting A's request worked - state $S2"
else
  echo "  FAIL: expected accepted, got $S2"
  FAIL=$((FAIL+1))
fi

echo "=== 3. the list query finds it from BOTH sides ==="
FA=$(q "SELECT COUNT(*) FROM friends WHERE (uuid_low='$A' OR uuid_high='$A') AND state='accepted';")
FB=$(q "SELECT COUNT(*) FROM friends WHERE (uuid_low='$B' OR uuid_high='$B') AND state='accepted';")
echo "  A sees $FA, B sees $FB"
if [ "$FA" = "1" ] && [ "$FB" = "1" ]; then
  echo "  OK: symmetric without a second row"
else
  echo "  FAIL: the friendship is not visible from both sides"
  FAIL=$((FAIL+1))
fi

q "DELETE FROM friends WHERE uuid_low='$LOW' AND uuid_high='$HIGH';" >/dev/null
echo
if [ "$FAIL" -eq 0 ]; then echo "FRIENDS: all pass"; else echo "FRIENDS: $FAIL failure(s)"; exit 1; fi