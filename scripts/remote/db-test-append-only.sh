# db-test-append-only.sh - acceptance 17.5 item 4, second half.
#
# 17.5: "Every staff action appears in the audit log, and a staff account cannot delete
# from it." The first half needs the plugin to write audit rows (not built yet). This
# tests the second half, which is the part that must be true in the DATABASE - because a
# staff member who can edit the record of what staff did makes every other control
# theatre, and 17.3 puts audit access on the never-grant list for exactly that reason.
#
# V2 enforces it with triggers rather than with a comment. A comment saying "do not
# update this" is a request; a trigger raising SQLSTATE 45000 is a guarantee. This proves
# the guarantee holds by trying to break it.
#
# Runs as the APP user - the same identity the plugin uses - so it tests the protection
# the plugin actually operates under, not root's view of it.
#
# STATED LIMIT: this protects against accident and against a compromised plugin. It does
# NOT protect against someone with root on the host, who can drop the triggers. That is
# a real limit and it is why 17.3 also puts shell access on the never-grant list.

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

FAIL=0

echo "=== the triggers must exist ==="
q "SELECT TRIGGER_NAME, EVENT_MANIPULATION FROM information_schema.TRIGGERS WHERE EVENT_OBJECT_TABLE='staff_audit';"

echo ""
echo "=== insert an audit row (this must SUCCEED - append is the whole point) ==="
q "INSERT INTO staff_audit (staff_uuid, staff_name, action, target_name, parameters, occurred_at) VALUES (NULL, 'Console', 'append-only-test', 'nobody', 'inserted by db-test-append-only.sh', UTC_TIMESTAMP(3));"
ID=$(q "SELECT id FROM staff_audit WHERE action='append-only-test' ORDER BY id DESC LIMIT 1;" | tr -dc '0-9')
if [ -n "$ID" ]; then
  echo "  OK: appended as id $ID"
else
  echo "  FAIL: could not append at all - the audit log is unusable, not merely protected"
  exit 2
fi

echo ""
echo "=== now try to REWRITE history - this must be REFUSED ==="
UPD=$(q "UPDATE staff_audit SET action='covered-my-tracks' WHERE id=$ID;" || true)
echo "  database said: $UPD"
if echo "$UPD" | grep -qi 'append-only'; then
  echo "  OK: the update was refused by the trigger"
else
  echo "  FAIL: the audit log ACCEPTED an update - staff could edit the record"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== and try to DELETE it - this must be REFUSED ==="
DEL=$(q "DELETE FROM staff_audit WHERE id=$ID;" || true)
echo "  database said: $DEL"
if echo "$DEL" | grep -qi 'append-only'; then
  echo "  OK: the delete was refused by the trigger"
else
  echo "  FAIL: the audit log ACCEPTED a delete - staff could erase the record"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== the row must still be there, unchanged ==="
q "SELECT id, action, staff_name FROM staff_audit WHERE id=$ID;"
STILL=$(q "SELECT COUNT(*) FROM staff_audit WHERE id=$ID AND action='append-only-test';" | tr -dc '0-9')
if [ "$STILL" = "1" ]; then
  echo "  OK: intact and unmodified after both attempts"
else
  echo "  FAIL: the row was altered or removed"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== the test row is deliberately LEFT IN PLACE ==="
echo "It cannot be removed - that is the point being demonstrated. It is a Console entry"
echo "clearly labelled as a test, which is honest: an append-only log with a tidy-up"
echo "path is not append-only."

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "APPEND-ONLY ENFORCEMENT PASSED - 17.5 item 4, database half"
else
  echo "APPEND-ONLY ENFORCEMENT FAILED - $FAIL check(s)"
fi
echo "=== END ==="
exit "$FAIL"
