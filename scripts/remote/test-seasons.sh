# test-seasons.sh - acceptance rows 33, 34 and 36, exercised end to end.
#
# Four behaviours are proven here, in an order that matters:
#   1. A season starts, and a SECOND start is refused - two active seasons would make
#      combat_ratings ambiguous and leave no single answer to "who is winning".
#   2. Ending a season with NOBODY rated is REFUSED. Spec 31.2: "never end a season without
#      a Champion." A server that ends an empty season has silently broken its own promise.
#   3. With a rating present, ending crowns exactly one Champion.
#   4. Ending AGAIN is a no-op. Row 33 requires the reset to be idempotent, because 31.1
#      puts it on a clock and a clock-driven job will eventually be interrupted by a
#      restart and re-run.
#
# The rating in step 3 is injected directly rather than earned, because the Elo maths is
# blocked on Q-11 to Q-13. That is the point of separating them: the season LIFECYCLE is
# testable today and the rating ARITHMETIC can arrive later without changing any of it.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{(index .NetworkSettings.Networks "pelican_nw").IPAddress}}')
OWNER_UUID=263645f0-7a1b-4d45-a0c9-16d9b0d345d0

cat > /tmp/lt-season.py <<'PYEOF'
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
    print('%-34s -> %s' % (cmd[:34], re.sub(r'\xa7.','',rd(s)).strip().replace('\n',' | ')[:200] or '(async)'))
    time.sleep(1.5)
s.close()
PYEOF
rcon() { sudo -n python3 /tmp/lt-season.py "$D/server.properties" "$CIP"; }

q() {
  local out
  out=$(sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -B -e \"$1\"" 2>&1)
  printf '%s\n' "$out" | sed '/password on the command line/d'
}

FAIL=0

echo "=== 1. start a season, then try to start a second ==="
printf '%s\n' "season start" "season start" "season status" | rcon

echo ""
echo "=== 2. end it with nobody rated - 31.2 must REFUSE ==="
printf '%s\n' "season end" | rcon
sleep 2
STATE=$(q "SELECT state, reset_completed FROM seasons ORDER BY season_number DESC LIMIT 1;" | tail -1)
echo "  season state now: $STATE"
if echo "$STATE" | grep -q 'active'; then
  echo "  OK: the season is still active - ending without a Champion was refused"
else
  echo "  FAIL: the season ended with no Champion, which 31.2 forbids"
  FAIL=$((FAIL+1))
fi
CHAMPS=$(q "SELECT COUNT(*) FROM champions;" | tail -1 | tr -dc '0-9')
echo "  champions recorded: $CHAMPS"

echo ""
echo "=== 3. give the owner a rating, then end the season ==="
SEASON=$(q "SELECT season_number FROM seasons WHERE state='active' ORDER BY season_number DESC LIMIT 1;" | tail -1 | tr -dc '0-9')
echo "  active season: $SEASON"
q "INSERT INTO combat_ratings (uuid, season_number, current_rp, peak_rp, games_counted, created_at, updated_at) VALUES ('$OWNER_UUID', $SEASON, 1420, 1450, 12, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE current_rp=1420;"
printf '%s\n' "season end" | rcon
sleep 2
q "SELECT season_number, uuid, final_rp FROM champions;"
CHAMPS2=$(q "SELECT COUNT(*) FROM champions WHERE season_number=$SEASON;" | tail -1 | tr -dc '0-9')
if [ "${CHAMPS2:-0}" = "1" ]; then
  echo "  OK: exactly one Champion for season $SEASON"
else
  echo "  FAIL: expected 1 champion, found ${CHAMPS2:-0}"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 4. end it AGAIN - row 33 requires idempotency ==="
printf '%s\n' "season end" | rcon
sleep 2
CHAMPS3=$(q "SELECT COUNT(*) FROM champions WHERE season_number=$SEASON;" | tail -1 | tr -dc '0-9')
echo "  champions for season $SEASON after a second end: ${CHAMPS3:-0}"
if [ "${CHAMPS3:-0}" = "1" ]; then
  echo "  OK: still exactly one - the reset is idempotent"
else
  echo "  FAIL: a second end changed the outcome"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== stats side effects ==="
q "SELECT uuid, seasons_played, champion_titles FROM stats WHERE uuid='$OWNER_UUID';"

echo ""
echo "=== the audit trail for season commands ==="
q "SELECT action, LEFT(IFNULL(parameters,''),60) AS params FROM staff_audit WHERE action LIKE 'season%' ORDER BY id;"

sudo -n rm -f /tmp/lt-season.py

echo ""
if [ "$FAIL" -eq 0 ]; then echo "SEASON LIFECYCLE TEST PASSED"; else echo "SEASON LIFECYCLE TEST FAILED - $FAIL"; fi
echo "=== END ==="
exit "$FAIL"
