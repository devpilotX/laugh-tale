# monitor.sh - Phase 0.7. Samples the things that go wrong and records them.
#
# WHAT THIS IS AND IS NOT. This is the monitoring and detection half. The alerting
# half - pushing to a private Discord channel - needs OA-16 (a webhook), which does
# not exist yet. Rather than stall the whole task on a credential, detection is
# built now and writes to a state file and a log; a webhook becomes six lines later.
# The order matters: a channel with nothing to say is useless, a detector with
# nowhere to shout is still a detector.
#
# THIS IS NOT THE 6.6 WATCHDOG. That one lives inside the LaughTail core plugin,
# reacts within a tick, and degrades cosmetics automatically. This is an external
# sampler that runs every few minutes and cannot see individual ticks. They are
# complementary: this catches "the server has been unwell for minutes", the in-game
# watchdog catches "this tick was too slow". Building this first also produces the
# history that Phase 6 needs to choose the watchdog's thresholds from measurement
# rather than from assertion (Law 5).
#
# THRESHOLDS. Deliberately conservative and derived from measurement, not taste:
# baselines.md B1 records idle MSPT at 0.2 ms and TPS 20.0, so anything sustained
# above a few ms with nobody online is already abnormal. The MSPT ladder mirrors
# 6.6's numbers so the two agree when the in-game one arrives. Memory is the tight
# resource on this box (Q-41), so it gets the strictest treatment.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CIP=$(sudo -n docker inspect "$V" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")
STATE=/home/ubuntu/laughtail-monitor
LOG=/var/log/laughtail-monitor.log
sudo -n mkdir -p "$STATE"

STAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ALERTS=""
add_alert() { ALERTS="${ALERTS}${1}\n"; echo "  ALERT: $1"; }

echo "=== monitor sample $STAMP ==="

# ---------------------------------------------------------------------------
# 1. Is the server process even up? The most basic question, asked first.
# ---------------------------------------------------------------------------
if sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  SERVER_UP=1
  echo "server: up"
else
  SERVER_UP=0
  add_alert "GAME SERVER IS DOWN (container not running)"
fi

# ---------------------------------------------------------------------------
# 2. Is the database up? Phase 1 onward cannot function without it, and a paid
#    grant that cannot be written is a refund request.
# ---------------------------------------------------------------------------
if sudo -n docker ps --format '{{.Names}}' | grep -qx laughtail-db; then
  if sudo -n docker exec -u root laughtail-db sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "SELECT 1;"' >/dev/null 2>&1; then
    echo "database: up and accepting queries"
  else
    add_alert "DATABASE CONTAINER IS UP BUT NOT ACCEPTING QUERIES"
  fi
else
  add_alert "DATABASE IS DOWN (container not running)"
fi

# ---------------------------------------------------------------------------
# 3. Tick health, via RCON. Only meaningful if the server is up.
# ---------------------------------------------------------------------------
TPS=""
MSPT=""
PLAYERS=""
if [ "$SERVER_UP" -eq 1 ] && [ -n "$CIP" ]; then
  cat > /tmp/lt-mon-rcon.py <<'PYEOF'
import socket, struct, sys, re
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='):
            pw = line.split('=', 1)[1].strip()
        elif line.startswith('rcon.port='):
            port = int(line.split('=', 1)[1].strip())
if not pw:
    sys.exit(3)
def pkt(rid, typ, body):
    p = struct.pack('<ii', rid, typ) + body.encode() + b'\x00\x00'
    return struct.pack('<i', len(p)) + p
def rd(s):
    raw = b''
    while len(raw) < 4:
        c = s.recv(4 - len(raw))
        if not c: return ''
        raw += c
    (n,) = struct.unpack('<i', raw)
    b = b''
    while len(b) < n:
        c = s.recv(n - len(b))
        if not c: break
        b += c
    return b[8:-2].decode('utf8', errors='replace')
try:
    s = socket.create_connection((HOST, port), timeout=10)
    s.settimeout(15)
    s.sendall(pkt(1, 3, pw))
    rd(s)
    out = {}
    for label, cmd in (('tps', 'tps'), ('mspt', 'mspt'), ('list', 'list')):
        s.sendall(pkt(2, 2, cmd))
        out[label] = re.sub(r'\xa7.', '', rd(s))
    s.close()
except Exception as e:
    print('RCON_FAIL %s' % e)
    sys.exit(4)

m = re.search(r'([0-9.]+),\s*([0-9.]+),\s*([0-9.]+)', out.get('tps', ''))
print('TPS1M=%s' % (m.group(1) if m else ''))
# mspt line: "avg/min/max from last 5s, 10s, 1m" - take the 1m average, the last group
groups = re.findall(r'([0-9.]+)/([0-9.]+)/([0-9.]+)', out.get('mspt', ''))
if groups:
    print('MSPT_AVG_1M=%s' % groups[-1][0])
    print('MSPT_MAX_1M=%s' % groups[-1][2])
p = re.search(r'are (\d+) of a max of (\d+)', out.get('list', ''))
if p:
    print('PLAYERS=%s' % p.group(1))
    print('MAXPLAYERS=%s' % p.group(2))
PYEOF
  RCONOUT=$(sudo -n python3 /tmp/lt-mon-rcon.py "$D/server.properties" "$CIP" 2>&1 || true)
  sudo -n rm -f /tmp/lt-mon-rcon.py
  if echo "$RCONOUT" | grep -q 'RCON_FAIL'; then
    add_alert "SERVER IS UP BUT NOT ANSWERING RCON - it may be hung rather than stopped"
  else
    TPS=$(echo "$RCONOUT" | sed -n 's/^TPS1M=//p')
    MSPT=$(echo "$RCONOUT" | sed -n 's/^MSPT_AVG_1M=//p')
    MSPT_MAX=$(echo "$RCONOUT" | sed -n 's/^MSPT_MAX_1M=//p')
    PLAYERS=$(echo "$RCONOUT" | sed -n 's/^PLAYERS=//p')
    echo "tps(1m): ${TPS:-?}   mspt avg(1m): ${MSPT:-?}   mspt max(1m): ${MSPT_MAX:-?}   players: ${PLAYERS:-?}"

    # Integer comparison in tenths, because sh has no floating point.
    if [ -n "$TPS" ]; then
      T10=$(printf '%.0f' "$(echo "$TPS 10" | awk '{print $1*$2}')")
      # 6.1 treats sustained low TPS as a hard failure. 19.0 is the line where
      # players start to feel it.
      [ "$T10" -lt 190 ] && add_alert "TPS is ${TPS} (below 19.0) - players will feel this"
      [ "$T10" -lt 150 ] && add_alert "TPS is ${TPS} - SEVERE, the server is falling behind badly"
    fi
    if [ -n "$MSPT" ]; then
      M10=$(printf '%.0f' "$(echo "$MSPT 10" | awk '{print $1*$2}')")
      # Ladder mirrors 6.6 so this agrees with the in-game watchdog when it exists.
      [ "$M10" -ge 300 ] && add_alert "MSPT average ${MSPT} ms is over 30 - 6.6 says start degrading cosmetics"
      [ "$M10" -ge 400 ] && add_alert "MSPT average ${MSPT} ms is over 40 - 6.1 calls this a hard failure in normal play"
      [ "$M10" -ge 480 ] && add_alert "MSPT average ${MSPT} ms is over 48 - 6.6's top rung; block world-loading commands"
    fi
    # The MAXIMUM matters separately from the average, and this was learned the hard
    # way: the first sample recorded avg 1.6 ms with a max of 756.8 ms in the same
    # minute. Judged on the average alone that is a healthy server; in reality it
    # contained a three-quarter-second freeze, which every player online would have
    # felt as a hitch. This is precisely the gap questions.md Q-16 records - row 19
    # says "MSPT under 25 ms" and names no statistic, so an average-only check can
    # pass while the server visibly stutters.
    #
    # 250 ms is five vanilla ticks' worth of work in one tick. Below that, spikes are
    # normal on chunk load and GC; above it, somebody noticed.
    if [ -n "$MSPT_MAX" ]; then
      X10=$(printf '%.0f' "$(echo "$MSPT_MAX 10" | awk '{print $1*$2}')")
      [ "$X10" -ge 2500 ] && add_alert "a single tick took ${MSPT_MAX} ms in the last minute - players feel this as a freeze"
      [ "$X10" -ge 10000 ] && add_alert "a single tick took ${MSPT_MAX} ms - over a second; investigate with spark"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 4. Memory. The tight resource on this box - see Q-41.
# ---------------------------------------------------------------------------
AVAIL=$(free -m | awk '/^Mem:/ {print $7}')
echo "host memory available: ${AVAIL} MB"
# THRESHOLDS CALIBRATED FROM MEASUREMENT, not from a round number.
#
# The first version warned under 400 MB. Eight consecutive samples then showed the
# idle steady state oscillating between 277 and 370 MB, so the alert fired every
# time - and an alert that always fires is noise that trains everyone to ignore the
# channel. Same failure as a drift check that reports drift on every boot.
#
# The steady state itself is the problem, and it is not a per-sample alert: it is
# Q-41, an owner decision about instance size. What this should catch is a
# DEPARTURE from that steady state, so the warn line sits below the measured floor.
#
# Recalibrate if the baseline moves - and record why, or the next person will read
# these numbers as arbitrary.
[ "$AVAIL" -lt 220 ] && add_alert "host memory available is ${AVAIL} MB - below the measured idle floor of ~277 MB, so something is consuming more than usual"
[ "$AVAIL" -lt 120 ] && add_alert "host memory available is ${AVAIL} MB - SEVERE, the OOM killer is a real risk and it may choose the Panel rather than the game"

SWAPUSED=$(free -m | awk '/^Swap:/ {print $3}')
echo "host swap in use: ${SWAPUSED} MB"
# The game container cannot swap (deviation D7), so host swap use means the Panel
# or the OS is under pressure - which shows up as backup failures and heartbeat
# loss rather than as game lag (22.13's failure mode).
[ "${SWAPUSED:-0}" -gt 300 ] && add_alert "host swap in use is ${SWAPUSED} MB - the Panel or OS is under memory pressure"

# ---------------------------------------------------------------------------
# 5. Disk. Pregeneration and backups both eat it, and a full disk corrupts worlds.
# ---------------------------------------------------------------------------
DISKPCT=$(df --output=pcent / | tail -1 | tr -dc '0-9')
DISKAVAIL=$(df -h --output=avail / | tail -1 | tr -d ' ')
echo "disk: ${DISKPCT}% used, ${DISKAVAIL} available"
[ "$DISKPCT" -ge 80 ] && add_alert "disk is ${DISKPCT}% full - world corruption risk if it reaches 100"
[ "$DISKPCT" -ge 90 ] && add_alert "disk is ${DISKPCT}% full - SEVERE, act now"

# ---------------------------------------------------------------------------
# 6. Backup freshness. A silent backup failure is the worst kind.
# ---------------------------------------------------------------------------
BS=/home/ubuntu/laughtail-backups/last-status.json
if sudo -n test -f "$BS"; then
  BEPOCH=$(sudo -n grep -o '"epoch": *[0-9]*' "$BS" | tr -dc '0-9')
  BRESULT=$(sudo -n grep -o '"result": *"[^"]*"' "$BS" | cut -d'"' -f4)
  BAGE=$(( $(date -u +%s) - BEPOCH ))
  echo "last backup: $BRESULT, $((BAGE / 60)) minutes ago"
  [ "$BRESULT" != "ok" ] && add_alert "the last backup did not report success"
  [ "$BAGE" -gt 7200 ] && add_alert "last backup was $((BAGE / 3600)) hours ago - the hourly job has not run"
else
  add_alert "no backup status file - backup-run.sh has never completed"
fi

# ---------------------------------------------------------------------------
# 7. Errors in the server log since the last sample. Rising errors precede
#    outages, and nobody reads logs by hand.
# ---------------------------------------------------------------------------
L="$D/logs/latest.log"
if sudo -n test -f "$L"; then
  # `grep -c` exits 1 when the count is zero. Under `set -o pipefail` that makes the
  # whole substitution fail, and under `set -e` the script dies - on a log that is
  # simply clean. Third appearance of this trap in this project, so: brace the grep
  # with `|| true` INSIDE the substitution, before any pipe.
  ERRS=$( { sudo -n grep -cE 'ERROR|SEVERE' "$L" 2>/dev/null || true; } | head -1 | tr -dc '0-9' )
  [ -z "$ERRS" ] && ERRS=0
  PREV=0
  if sudo -n test -f "$STATE/last-errors"; then
    PREV=$( { sudo -n cat "$STATE/last-errors" || true; } | tr -dc '0-9' )
    [ -z "$PREV" ] && PREV=0
  fi
  echo "log errors: $ERRS total (was $PREV)"
  if [ "$ERRS" -gt "$PREV" ]; then
    add_alert "$((ERRS - PREV)) new ERROR/SEVERE line(s) in the server log"
    sudo -n grep -E 'ERROR|SEVERE' "$L" | tail -3 | sed 's/^/      /'
  fi
  echo "$ERRS" | sudo -n tee "$STATE/last-errors" > /dev/null
fi

# ---------------------------------------------------------------------------
# 8. Record the sample, and the alerts if any.
# ---------------------------------------------------------------------------
ALERT_COUNT=$( { printf "$ALERTS" | grep -c . || true; } | tr -dc '0-9' )
[ -z "$ALERT_COUNT" ] && ALERT_COUNT=0

sudo -n tee "$STATE/last-sample.json" > /dev/null <<JSON
{
  "sampled_utc": "$STAMP",
  "epoch": $(date -u +%s),
  "server_up": $SERVER_UP,
  "tps_1m": "${TPS:-}",
  "mspt_avg_1m": "${MSPT:-}",
  "mspt_max_1m": "${MSPT_MAX:-}",
  "players": "${PLAYERS:-}",
  "host_mem_available_mb": $AVAIL,
  "host_swap_used_mb": ${SWAPUSED:-0},
  "disk_used_pct": $DISKPCT,
  "alert_count": $ALERT_COUNT
}
JSON

# A CSV history, so Phase 6 can choose watchdog thresholds from measurement rather
# than assertion, and so a slow degradation over days is visible at all.
if ! sudo -n test -f "$STATE/history.csv"; then
  echo "utc,server_up,tps_1m,mspt_avg_1m,mspt_max_1m,players,mem_avail_mb,swap_mb,disk_pct,alerts" \
    | sudo -n tee "$STATE/history.csv" > /dev/null
fi
echo "$STAMP,$SERVER_UP,${TPS:-},${MSPT:-},${MSPT_MAX:-},${PLAYERS:-},$AVAIL,${SWAPUSED:-0},$DISKPCT,$ALERT_COUNT" \
  | sudo -n tee -a "$STATE/history.csv" > /dev/null

if [ -n "$ALERTS" ]; then
  echo "=== ALERTS THIS SAMPLE ==="
  printf "$ALERTS"
  printf "[%s]\n%b\n" "$STAMP" "$ALERTS" | sudo -n tee -a "$STATE/alerts.log" > /dev/null
  # OA-16: this is where a Discord webhook POST goes when there is one.
  echo "(not pushed anywhere - OA-16, no webhook yet. Recorded in $STATE/alerts.log)"
else
  echo "=== no alerts ==="
fi

echo "=== history so far ==="
sudo -n tail -5 "$STATE/history.csv"
echo "=== END ==="
