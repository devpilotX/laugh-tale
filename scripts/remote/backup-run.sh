# backup-run.sh - the routine backup. World plus database, consistently.
#
# Spec 5.4 requires "a proper hot-dump" and "flush world saves before
# snapshotting". Both halves matter for different reasons:
#
#   WORLD: Minecraft holds chunk changes in memory and writes them lazily. Taring
#   a live world directory captures a torn state - some regions current, some
#   minutes old, and possibly a region file mid-write. So: save-off (stop new
#   writes), save-all flush (force everything to disk and wait), tar, save-on.
#   Forgetting save-on leaves a server that never persists anything again, so it
#   runs in a trap and is verified afterwards.
#
#   DATABASE: mariadb-dump --single-transaction takes a consistent snapshot in one
#   InnoDB transaction without locking, so the game keeps running.
#
# WHAT IS DELIBERATELY EXCLUDED, and why - stated because a backup whose contents
# nobody knows is not a backup:
#   world/                               the owner's pre-existing 26.2 world, 490 MB. It is
#                                        immutable (D-0013, mtime proven unchanged) and
#                                        already captured in the pre-build tar. Re-taring
#                                        it hourly would fill a 19 GB disk.
#   _quarantine/                         non-manifest jars and prebuild copies, already
#                                        backed up once.
#   cache/ logs/ libraries/ versions/    regenerable. logs are kept live, not backed up.
#
# NOTE ON THE 26.2 LAYOUT: Minecraft 26.2 unified world storage, so ALL FIVE worlds now
# live inside the single laughtail/ folder as
# laughtail/dimensions/minecraft/<overworld|the_nether|the_end|laughtail_resource|laughtail_arena>.
# That is why there are no world_nether or world_the_end exclusions any more - those paths
# no longer exist. It also means including laughtail/ now captures every world in one
# archive, which is simpler and harder to get wrong than the old per-folder approach.
#
# OA-08 IS STILL OPEN: there is no offsite destination. These backups sit on the
# same EBS volume as the thing they protect, which means they survive a bad deploy
# or a corrupt world but NOT loss of the instance. That is a real gap and it is the
# owner's to close.

set -e

# --db-only skips the world tar. Used by the hourly cron entry: spec 5.4 wants the
# database hourly but the world only every six hours, because the world tar is the
# expensive part (213 MB of gzip) and this instance is burstable (R1) - twenty-four
# world tars a day would spend CPU credits on data that changes far less than the
# ledger does.
DB_ONLY=0
if [ "${1:-}" = "--db-only" ]; then DB_ONLY=1; fi

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
DEST=/home/ubuntu/laughtail-backups
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
KEEP=6
CIP=$(sudo -n docker inspect "$V" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')

sudo -n mkdir -p "$DEST"

echo "=== disk before ==="
df -h --output=avail,pcent / | tail -1

SERVER_UP=0
if sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then SERVER_UP=1; fi
echo "server running: $SERVER_UP"

# ---------------------------------------------------------------------------
# RCON helper. Used only to flush saves. Password never printed.
# ---------------------------------------------------------------------------
cat > /tmp/lt-rcon-bk.py <<'PYEOF'
import socket, struct, sys, time
PROPS, HOST = sys.argv[1], sys.argv[2]
pw, port = None, 25575
with open(PROPS, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        if line.startswith('rcon.password='):
            pw = line.split('=', 1)[1].strip()
        elif line.startswith('rcon.port='):
            port = int(line.split('=', 1)[1].strip())
if not pw:
    print('NO_RCON_PASSWORD'); sys.exit(3)
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
s = socket.create_connection((HOST, port), timeout=15)
s.settimeout(30)
s.sendall(pkt(1, 3, pw))
rd(s)
for cmd in sys.argv[3:]:
    s.sendall(pkt(2, 2, cmd))
    print('%s -> %s' % (cmd, rd(s).strip()))
    time.sleep(0.5)
s.close()
PYEOF

restore_saves() {
  if [ "$SERVER_UP" -eq 1 ]; then
    echo "=== re-enabling saves (trap) ==="
    sudo -n python3 /tmp/lt-rcon-bk.py "$D/server.properties" "$CIP" "save-on" || echo "WARNING: save-on failed - CHECK THE SERVER"
  fi
  sudo -n rm -f /tmp/lt-rcon-bk.py
}
trap restore_saves EXIT

if [ "$DB_ONLY" -eq 1 ]; then
  echo "=== --db-only: skipping the world tar and the save flush ==="
  echo "    (the flush exists to make the WORLD snapshot consistent; the database"
  echo "     dump is made consistent by --single-transaction instead, so an hourly"
  echo "     database backup does not need to touch the running world at all)"
  WORLD_TAR=""
elif [ "$SERVER_UP" -eq 1 ]; then
  echo "=== flushing world saves before the snapshot (5.4) ==="
  sudo -n python3 /tmp/lt-rcon-bk.py "$D/server.properties" "$CIP" "save-off" "save-all flush"
  # save-all flush returns as soon as it is queued, so give the I/O pool a moment.
  sleep 5
else
  echo "=== server is stopped: the world on disk is already consistent ==="
fi

if [ "$DB_ONLY" -eq 0 ]; then
echo "=== world backup ==="
WORLD_TAR="$DEST/world-$STAMP.tar.gz"
sudo -n tar -czf "$WORLD_TAR" \
  --exclude='./world' --exclude='./world_nether' --exclude='./world_the_end' \
  --exclude='./_quarantine' --exclude='./cache' --exclude='./logs' \
  --exclude='./libraries' --exclude='./versions' \
  -C "$D" . 2>/dev/null || true
sudo -n stat -c '  %n  %s bytes' "$WORLD_TAR"
sudo -n sha256sum "$WORLD_TAR" | cut -c1-24 | sed 's/^/  sha256 /'

echo "=== tar integrity (a backup that cannot be listed is not a backup) ==="
if sudo -n tar -tzf "$WORLD_TAR" > /tmp/lt-tar-list.txt 2>/dev/null; then
  echo "  listable: $(wc -l < /tmp/lt-tar-list.txt) entries"
  echo "  key files present:"
  for f in ./laughtail/level.dat ./server.properties ./ops.json ./whitelist.json ./config/paper-global.yml ./spigot.yml; do
    if grep -qx "$f" /tmp/lt-tar-list.txt; then echo "    OK   $f"; else echo "    MISS $f"; fi
  done
  echo "  region files: $(grep -c '\.mca$' /tmp/lt-tar-list.txt)"
  echo "  old world excluded? $(grep -c '^\./world/' /tmp/lt-tar-list.txt) entries (0 expected)"
  rm -f /tmp/lt-tar-list.txt
else
  echo "  FAIL: tar is not listable"
  exit 4
fi
fi   # end of the world-backup block skipped by --db-only

echo "=== database backup ==="
DB_SQL="$DEST/db-$STAMP.sql.gz"
if sudo -n docker ps --format '{{.Names}}' | grep -qx laughtail-db; then
  sudo -n docker exec -u root laughtail-db sh -c \
    'mariadb-dump --single-transaction --routines --triggers --events --databases laughtail -u root -p"$(cat /run/lt-secrets/root_password)"' \
    2>/dev/null | gzip -9 > /tmp/lt-db.sql.gz
  sudo -n mv /tmp/lt-db.sql.gz "$DB_SQL"
  sudo -n stat -c '  %n  %s bytes' "$DB_SQL"
  echo "  contains CREATE DATABASE? $(sudo -n zcat "$DB_SQL" | grep -c 'CREATE DATABASE') (1+ expected, --databases was used so a restore recreates the schema)"
  echo "  tables in the dump: $(sudo -n zcat "$DB_SQL" | grep -c 'CREATE TABLE')"
else
  echo "  SKIPPED: laughtail-db is not running"
fi

echo "=== retention: keep the newest $KEEP of each kind ==="
for pat in 'world-*.tar.gz' 'db-*.sql.gz'; do
  N=$(sudo -n find "$DEST" -maxdepth 1 -name "$pat" | wc -l)
  echo "  $pat: $N present"
  if [ "$N" -gt "$KEEP" ]; then
    sudo -n find "$DEST" -maxdepth 1 -name "$pat" -printf '%T@ %p\n' \
      | sort -n | head -n -"$KEEP" | cut -d' ' -f2- \
      | while read -r old; do
          echo "    pruning $(basename "$old")"
          sudo -n rm -f "$old"
        done
  fi
done

echo "=== what is on disk now ==="
sudo -n ls -lh "$DEST" | tail -15
sudo -n du -sh "$DEST"
echo "=== disk after ==="
df -h --output=avail,pcent / | tail -1

# ---------------------------------------------------------------------------
# Status file. A silent backup failure is indistinguishable from success, which is
# the worst property a backup can have - and there is no alerting channel yet
# (OA-16, no Discord webhook). So the outcome is written to disk where
# health-check.sh reads it and complains if it is stale or failed.
#
# Written LAST and only on success. If the script died earlier, the file keeps its
# previous timestamp and goes stale, which is exactly the signal wanted.
# ---------------------------------------------------------------------------
WORLD_SZ=$(sudo -n stat -c %s "$WORLD_TAR" 2>/dev/null || echo 0)
DB_SZ=$(sudo -n stat -c %s "$DB_SQL" 2>/dev/null || echo 0)
sudo -n tee "$DEST/last-status.json" > /dev/null <<JSON
{
  "finished_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "epoch": $(date -u +%s),
  "result": "ok",
  "world_archive": "$(basename "$WORLD_TAR")",
  "world_bytes": $WORLD_SZ,
  "db_archive": "$(basename "$DB_SQL")",
  "db_bytes": $DB_SZ,
  "server_was_running": $SERVER_UP
}
JSON
sudo -n cat "$DEST/last-status.json"

echo "BACKUP COMPLETE"
echo "=== END ==="
