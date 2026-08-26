# db-assess.sh - READ ONLY. Can this box afford a database, and which one?
#
# Spec 5.2 names MariaDB. Session 1 measured mariadb and redis-server as present
# but INACTIVE. Before starting anything, this establishes what is installed, what
# it would cost, and whether a data directory already exists that must not be
# trampled.
#
# Why the memory question is not academic: docs/baselines.md B1 records 645 MB
# host memory available with the game server up, and MariaDB's default InnoDB
# buffer pool alone is 128 MB before per-connection buffers and the OS. This lands
# directly on Q-41.

echo "=== is mariadb installed, and which version? ==="
dpkg -l | grep -E '^ii\s+(mariadb|mysql)' | awk '{print $2, $3}' || echo "(no mariadb/mysql packages)"
command -v mariadbd mysqld mariadb mysql 2>/dev/null || echo "(no server or client binary on PATH)"

echo "=== service state ==="
for s in mariadb mysql redis-server; do
  printf '%-14s %s\n' "$s" "$(systemctl is-active $s 2>/dev/null || echo not-found)/$(systemctl is-enabled $s 2>/dev/null || echo -)"
done

echo "=== does a data directory already exist? (must not be trampled) ==="
if sudo -n test -d /var/lib/mysql; then
  echo "/var/lib/mysql exists:"
  sudo -n du -sh /var/lib/mysql 2>/dev/null
  echo "databases present:"
  sudo -n ls -1 /var/lib/mysql 2>/dev/null | grep -vE '\.(pem|frm|ibd|log|index|cnf)$|^(ib_|ibdata|aria_|mysql_upgrade|multi-master|tc\.log|undo)' | head -10
else
  echo "/var/lib/mysql does not exist - a start would initialise a fresh instance"
fi

echo "=== current innodb buffer pool setting, if configured ==="
sudo -n grep -rhE '^\s*(innodb_buffer_pool_size|key_buffer_size|max_connections|performance_schema)' /etc/mysql/ 2>/dev/null || echo "(no explicit tuning found - defaults would apply)"

echo "=== what the Pelican Panel uses (it must NOT be disturbed) ==="
sudo -n grep -E '^DB_CONNECTION|^DB_DATABASE|^DB_HOST' /var/www/pelican/.env 2>/dev/null

echo "=== memory right now, with the game server running ==="
free -m
echo "=== disk ==="
df -h --output=target,avail,pcent / | tail -1
echo "=== END ==="
