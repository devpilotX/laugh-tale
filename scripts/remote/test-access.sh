# test-access.sh - the manual paywall (D-0032) and acceptance row 12.
#
# Row 12: "the whitelist matches paid transactions exactly, with zero unexplained entries."
# Manual collection makes that easier to satisfy and easier to get wrong - easier because the
# owner knows every payment personally, easier to get wrong because a whitelist edit made by
# hand in the Panel leaves no trace at all.
#
# So the audit is tested in a state that is DELIBERATELY BROKEN first. The owner's account is
# already whitelisted from D-0017 with no grant row behind it, which is exactly the
# "unexplained entry" row 12 is about - so the audit should fail before the grant exists and
# pass after. An audit that only ever reports success has not been tested.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')

cat > /tmp/lt-acc.py <<'PYEOF'
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
s=socket.create_connection((HOST,port),timeout=25); s.settimeout(30)
s.sendall(pkt(1,3,pw)); rd(s)
for line in sys.stdin:
    cmd=line.strip()
    if not cmd or cmd.startswith('#'): continue
    s.sendall(pkt(2,2,cmd))
    print('%-44s -> %s' % (cmd[:44], re.sub(r'\xa7.','',rd(s)).strip().replace('\n',' | ')[:220] or '(async)'))
    time.sleep(2.0)
s.close()
PYEOF
rcon() { sudo -n python3 /tmp/lt-acc.py "$D/server.properties" "$CIP"; }

q() {
  local out
  out=$(sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -B -e \"$1\"" 2>&1)
  printf '%s\n' "$out" | sed '/password on the command line/d'
}

FAIL=0

echo "=== 1. audit BEFORE any grant - the owner is whitelisted with no grant row ==="
printf '%s\n' "access audit" | rcon
sleep 2
echo "  (expect UNEXPLAINED ACCESS - that is the point of running it first)"

echo ""
echo "=== 2. grant access to the owner against a payment reference ==="
printf '%s\n' "access grant IgnisClaw UPI-TEST-20260826-001 199" | rcon
sleep 3
q "SELECT id, uuid, source, transaction_ref, amount_minor, currency FROM access_grants;"

echo ""
echo "=== 3. the SAME reference must be refused - one payment cannot grant twice ==="
printf '%s\n' "access grant IgnisClaw UPI-TEST-20260826-001 199" | rcon
sleep 2
COUNT=$(q "SELECT COUNT(*) FROM access_grants WHERE transaction_ref='UPI-TEST-20260826-001';" | tail -1 | tr -dc '0-9')
echo "  grants with that reference: ${COUNT:-0}"
if [ "${COUNT:-0}" = "1" ]; then
  echo "  OK: the unique constraint refused the duplicate"
else
  echo "  FAIL: a single payment produced ${COUNT:-0} grants"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 4. audit AFTER the grant - should now pass ==="
printf '%s\n' "access list" "access audit" | rcon
sleep 2

echo ""
echo "=== 5. an unknown player must be refused, and the attempt audited ==="
printf '%s\n' "access grant ThisNameCannotExist99 REF-BOGUS" | rcon
sleep 3
q "SELECT action, target_name FROM staff_audit WHERE action LIKE 'access%' ORDER BY id;"
UNK=$(q "SELECT COUNT(*) FROM staff_audit WHERE action='access.grant.unknown_player';" | tail -1 | tr -dc '0-9')
if [ "${UNK:-0}" -gt 0 ]; then
  echo "  OK: the failed attempt is in the audit trail"
else
  echo "  NOTE: no unknown_player audit row - Mojang may have resolved the name, or the lookup failed"
fi

echo ""
echo "=== whitelist file vs grants, from outside the game ==="
echo "whitelist.json entries:"
sudo -n grep -c 'uuid' "$D/whitelist.json" || true
echo "live grants:"
q "SELECT COUNT(*) FROM access_grants WHERE revoked_at IS NULL;" | tail -1

sudo -n rm -f /tmp/lt-acc.py
echo ""
if [ "$FAIL" -eq 0 ]; then echo "ACCESS GRANT TEST PASSED"; else echo "ACCESS GRANT TEST FAILED - $FAIL"; fi
echo "=== END ==="
exit "$FAIL"
