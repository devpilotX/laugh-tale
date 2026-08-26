# db-up.sh - brings up the `db` MariaDB container from spec 5.2.
#
# WHY A CONTAINER AND NOT AN APT INSTALL. MariaDB is not installed on this host at
# all - db-assess.sh showed no packages and `systemctl is-enabled` returning
# not-found, correcting session 1's note that it was merely "inactive". So a host
# install would mean apt on the game box, which the guard requires confirmation for
# and which 33.2 item 4 says needs a fresh snapshot first - and OA-03 means no
# snapshot exists. A container needs no host packages, is capped, and is removable
# with one command. It is also what spec 5.2 actually specifies: a `db` container.
#
# MEMORY IS THE BINDING CONSTRAINT, not CPU. baselines.md B1 records 650 MB
# available with the game running. MariaDB's defaults would take 128 MB of InnoDB
# buffer pool plus performance_schema plus per-connection buffers. So this is tuned
# down hard and hard-capped by the container. Every setting below is chosen for a
# server with tens of players and tiny tables, where correctness and footprint
# matter and throughput does not.
#
# NOT EXPOSED. Published on 127.0.0.1 only. Spec 5.2 line 353 says port 3306 must
# be "container network only", and acceptance row 5 requires MySQL invisible from
# outside. check-external-ports.ps1 already probes 3306 and expects closed.
#
# CREDENTIALS. Generated on the host, written to a root-only file, and passed to
# the container as *_FILE secrets rather than -e values - an environment variable
# is visible forever in `docker inspect`. Nothing is printed and nothing reaches
# git (never-break rule 5).
#
# Data lives OUTSIDE the Pelican volume, deliberately: it keeps the 33.1 ownership
# trap away from it, and keeps database backups separable from world backups, which
# have completely different consistency requirements (5.4).

set -e

IMAGE="mariadb:11.4.5"
NAME="laughtail-db"
BASE=/home/ubuntu/laughtail-db
SECRETS="$BASE/secrets"

echo "=== refusing to clobber an existing container ==="
if sudo -n docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  echo "container $NAME already exists:"
  sudo -n docker ps -a --filter "name=$NAME" --format '  {{.Names}} {{.Status}}'
  echo "Nothing done. Remove it deliberately if you meant to recreate it."
  exit 0
fi

sudo -n mkdir -p "$BASE/data" "$BASE/conf" "$SECRETS"
sudo -n chmod 700 "$SECRETS"

echo "=== generating credentials (values never printed) ==="
for f in root_password app_password; do
  if sudo -n test -f "$SECRETS/$f"; then
    echo "  $f already exists, keeping it"
  else
    sudo -n bash -c "openssl rand -base64 33 | tr -d '\n=+/' | cut -c1-32 > '$SECRETS/$f'"
    sudo -n chmod 600 "$SECRETS/$f"
    LEN=$(sudo -n bash -c "tr -d '\n' < '$SECRETS/$f' | wc -c")
    echo "  $f created ($LEN chars, value deliberately not shown)"
  fi
done

echo "=== writing tuned config ==="
sudo -n tee "$BASE/conf/zz-laughtail.cnf" > /dev/null <<'CNF'
# LaughTail SMP - MariaDB tuning for a 2 vCPU / 3.8 GB box that is ALSO running
# a Paper server with a fixed 2 GiB heap and a Pelican Panel.
#
# The goal is a small, predictable footprint. Every value is deliberate.
[mysqld]
# 64M, not the 128M default. Total data will be a few MB for years: 24 players,
# a transaction ledger and a few thousand combat events. A buffer pool larger
# than the entire dataset is wasted memory taken from the page cache that Paper's
# chunk I/O depends on (sync-chunk-writes is false, so that cache matters).
innodb_buffer_pool_size = 64M
innodb_log_file_size    = 32M

# Durability over speed. The default (1) flushes on every commit, which is what
# we want: a Berry transaction that is acknowledged must survive a power loss.
# Appendix D requires cross-table writes to be transactional; there is no point
# in a transaction that a crash can forget.
innodb_flush_log_at_trx_commit = 1

# Off. It costs several tens of MB and this project has no query-tuning workload
# that would justify it on a box with 650 MB free.
performance_schema = 0

# 40, not 151. Sources of connections: the game server pool, the migration
# runner, the read-only leaderboard user, backups. 40 is generous for that and
# caps the per-connection buffer exposure.
max_connections = 40

# Never resolve client hostnames - it adds DNS latency to every connect and the
# only clients are on the container network anyway.
skip_name_resolve = 1

# UTC everywhere, matching the DATETIME(3) convention in V1__init.sql. A database
# that reports timestamps in local time makes the season reset instant ambiguous.
default_time_zone = '+00:00'

character_set_server = utf8mb4
collation_server     = utf8mb4_unicode_ci

# Slow queries are a symptom worth seeing on a 2 vCPU box.
slow_query_log      = 1
slow_query_log_file = /var/lib/mysql/slow.log
long_query_time     = 0.5
CNF

echo "=== pulling the pinned image ==="
sudo -n docker pull "$IMAGE"
echo "--- image digest, for the manifest ---"
sudo -n docker inspect "$IMAGE" --format '{{index .RepoDigests 0}}'
sudo -n docker inspect "$IMAGE" --format 'arch={{.Architecture}} os={{.Os}}'

echo "=== starting the container ==="
# --memory-swap equal to --memory means it cannot swap, for the same reason the
# game container cannot (deviation D7, Law 8: fail loud, not slow).
sudo -n docker run -d \
  --name "$NAME" \
  --restart unless-stopped \
  --memory 320m \
  --memory-swap 320m \
  --cpus 0.5 \
  -p 127.0.0.1:3306:3306 \
  -v "$BASE/data":/var/lib/mysql \
  -v "$BASE/conf":/etc/mysql/conf.d:ro \
  -v "$SECRETS":/run/lt-secrets:ro \
  -e MARIADB_ROOT_PASSWORD_FILE=/run/lt-secrets/root_password \
  -e MARIADB_DATABASE=laughtail \
  -e MARIADB_USER=laughtail \
  -e MARIADB_PASSWORD_FILE=/run/lt-secrets/app_password \
  "$IMAGE" > /dev/null

echo "=== waiting for readiness (up to 90s) ==="
# NOT `mariadb-admin ping`. The entrypoint starts a TEMPORARY server to run its
# initialisation SQL, and ping reports "mysqld is alive" against that temp server -
# before the root password, the database and the app user exist. Using ping as the
# gate produced a confident "ready after 21s" followed immediately by
# "Access denied for user 'root'". Readiness is an AUTHENTICATED QUERY against the
# application database, which is the thing the migration runner actually needs.
READY=0
for i in $(seq 1 30); do
  if sudo -n docker exec -u root "$NAME" sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "SELECT 1;"' >/dev/null 2>&1; then
    echo "ready after approximately $((i * 3))s (authenticated query succeeded)"
    READY=1
    break
  fi
  sleep 3
done

if [ "$READY" -ne 1 ]; then
  echo "NOT READY - last 25 log lines:"
  sudo -n docker logs --tail 25 "$NAME"
  exit 2
fi

echo "=== version and settings actually in effect ==="
sudo -n docker exec -u root "$NAME" sh -c 'mariadb -u root -p"$(cat /run/lt-secrets/root_password)" -N -B -e "
SELECT VERSION();
SELECT @@innodb_buffer_pool_size/1024/1024 AS buffer_pool_mb;
SELECT @@max_connections;
SELECT @@performance_schema;
SELECT @@time_zone;
SELECT @@character_set_server;
SHOW DATABASES;"' 2>&1 | grep -v 'password on the command line'

echo "=== port exposure: must be loopback only ==="
sudo -n docker port "$NAME"
sudo -n ss -lntp 2>/dev/null | grep 3306 || echo "(nothing listening on 3306 externally)"

echo "=== cost: what did this take? ==="
sudo -n docker stats --no-stream --format '{{.Name}} cpu={{.CPUPerc}} mem={{.MemUsage}}' "$NAME" "$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)"
free -m | head -2
sudo -n du -sh "$BASE/data"
echo "=== END ==="
