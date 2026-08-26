# test-moderation.sh - exercises the punishment commands and checks the audit trail.
#
# Acceptance 17.5 item 4 has two halves. The "cannot delete" half is already proven by
# db-test-append-only.sh. This is the "every staff action appears in the audit log" half.
#
# Commands are issued from the CONSOLE over RCON, which is the right test identity for two
# reasons: 17.2 defines Console as automation with full authority, and it means the test does
# not depend on a player being online. Console actions must appear in the audit with a NULL
# staff_uuid and the name recorded - distinguishable from a human action, which 17.2 requires.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
TARGET=IgnisClaw

cat > /tmp/lt-mod.py <<'PYEOF'
import socket, struct, sys, re, time
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='): pw = line.split('=',1)[1].strip()
        elif line.startswith('rcon.port='): port = int(line.split('=',1)[1].strip())
def pkt(rid, typ, body):
    p = struct.pack('<ii', rid, typ) + body.encode() + b'\x00\x00'
    return struct.pack('<i', len(p)) + p
def rd(s):
    raw=b''
    while len(raw)<4:
        c=s.recv(4-len(raw))
        if not c: return ''
        raw+=c
    (n,)=struct.unpack('<i',raw); b=b''
    while len(b)<n:
        c=s.recv(n-len(b))
        if not c: break
        b+=c
    return b[8:-2].decode('utf8','replace')
s=socket.create_connection((HOST,port),timeout=20); s.settimeout(25)
s.sendall(pkt(1,3,pw)); rd(s)
for line in sys.stdin:
    cmd=line.strip()
    if not cmd or cmd.startswith('#'): continue
    s.sendall(pkt(2,2,cmd))
    out=re.sub(r'\xa7.','',rd(s)).strip().replace('\n',' | ')
    print('%-48s -> %s' % (cmd[:48], out[:200] or '(async - result appears in the log)'))
    time.sleep(1.2)
s.close()
PYEOF

q() {
  local out rc
  out=$(sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -B -e \"$1\"" 2>&1)
  rc=$?
  printf '%s\n' "$out" | sed '/password on the command line/d'
  return $rc
}

echo "=== audit rows before ==="
BEFORE=$(q "SELECT COUNT(*) FROM staff_audit;" | tail -1 | tr -dc '0-9')
PBEFORE=$(q "SELECT COUNT(*) FROM punishments;" | tail -1 | tr -dc '0-9')
echo "  staff_audit=$BEFORE punishments=$PBEFORE"

echo ""
echo "=== issuing commands from the console ==="
sudo -n python3 /tmp/lt-mod.py "$D/server.properties" "$CIP" <<CMDS
history $TARGET
warn $TARGET testing the audit trail, please ignore
mute $TARGET 5m testing mute enforcement
history $TARGET
unmute $TARGET test complete
warn NoSuchPlayerHere this target does not exist
CMDS

echo "waiting for the async writes to land"
sleep 4
sudo -n rm -f /tmp/lt-mod.py

echo ""
echo "=== punishments recorded ==="
q "SELECT id, type, LEFT(reason,40) AS reason, issued_by, expires_at, revoked_at FROM punishments ORDER BY id;"

echo ""
echo "=== the audit trail ==="
q "SELECT id, IFNULL(staff_uuid,'NULL') AS staff_uuid, staff_name, action, target_name, LEFT(IFNULL(parameters,''),50) AS params FROM staff_audit ORDER BY id;"

echo ""
echo "=== counts after ==="
AFTER=$(q "SELECT COUNT(*) FROM staff_audit;" | tail -1 | tr -dc '0-9')
PAFTER=$(q "SELECT COUNT(*) FROM punishments;" | tail -1 | tr -dc '0-9')
echo "  staff_audit=$AFTER (was $BEFORE)  punishments=$PAFTER (was $PBEFORE)"

FAIL=0
if [ "${AFTER:-0}" -gt "${BEFORE:-0}" ]; then
  echo "  OK: staff actions were audited"
else
  echo "  FAIL: nothing was written to staff_audit"
  FAIL=$((FAIL+1))
fi
if [ "${PAFTER:-0}" -gt "${PBEFORE:-0}" ]; then
  echo "  OK: punishments were recorded"
else
  echo "  FAIL: no punishment rows"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== a Console action must be distinguishable from a human one (17.2) ==="
NULLSTAFF=$(q "SELECT COUNT(*) FROM staff_audit WHERE staff_uuid IS NULL AND staff_name IS NOT NULL;" | tail -1 | tr -dc '0-9')
echo "  console rows with a NULL uuid but a recorded name: $NULLSTAFF"
if [ "${NULLSTAFF:-0}" -gt 0 ]; then echo "  OK"; else echo "  FAIL"; FAIL=$((FAIL+1)); fi

echo ""
echo "=== an attempt against an unknown player must still be audited ==="
q "SELECT action, target_name FROM staff_audit WHERE action LIKE '%unknown_target%';"
UNK=$(q "SELECT COUNT(*) FROM staff_audit WHERE action LIKE '%unknown_target%';" | tail -1 | tr -dc '0-9')
if [ "${UNK:-0}" -gt 0 ]; then
  echo "  OK: a failed attempt is recorded, not just successes"
else
  echo "  FAIL: failed attempts are invisible in the audit"
  FAIL=$((FAIL+1))
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "MODERATION AND AUDIT TEST PASSED"
else
  echo "MODERATION AND AUDIT TEST FAILED - $FAIL check(s)"
fi
echo "=== END ==="
exit "$FAIL"
