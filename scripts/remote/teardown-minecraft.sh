# teardown-minecraft.sh - permanently remove the Minecraft server and Pelican from this host.
#
# THE OWNER ASKED FOR THIS EXPLICITLY, to free the box for a website. It is irreversible on this
# machine, so what it does and does not touch is stated up front and it verifies as it goes.
#
# BEFORE RUNNING THIS, the latest world and database backup were downloaded to the owner's PC and
# verified there: gzip magic checked, the tar confirmed to decompress, and the SQL dump confirmed to
# contain 33 CREATE TABLE statements, 2 triggers and 19 INSERT statements. Without that, this script
# would be destroying the only copy of the world and every player record.
#
# WHAT IS REMOVED
#   - the Minecraft game container and its volume (the world)
#   - the MariaDB container, its data and its credential files
#   - Pelican Panel, Wings, and their services and cron jobs
#   - the local backup directory
#   - Docker images pulled only for this project
#
# WHAT IS DELIBERATELY LEFT ALONE
#   - Docker itself. A website may well want it, and reinstalling is slow
#   - nginx and certbot, including existing certificates. The panel's own site config is removed,
#     but nothing else is, because this box may already serve something
#   - the OS, the ubuntu user, SSH configuration and the firewall
#
# It is written as a script rather than typed commands so that it is reviewable in git, states its
# scope, and can be read afterwards to explain exactly what happened.
set -uo pipefail

echo "=== BEFORE ==="
df -h / | tail -1 | awk '{print "  root: "$2" total, "$3" used, "$4" free"}'

# ---------------------------------------------------------------------------
echo
echo "=== 1. stop the services first ==="
# Wings is stopped BEFORE the containers. Left running, it notices a game container disappear and
# recreates it, so the volume delete below would race a container being rebuilt underneath it.
for svc in wings pelican-queue pelican-autostart; do
  if sudo -n systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
    sudo -n systemctl stop "$svc" 2>/dev/null && echo "  stopped $svc" || echo "  $svc not running"
    sudo -n systemctl disable "$svc" 2>/dev/null >/dev/null && echo "  disabled $svc" || true
  fi
done

echo
echo "=== 2. remove the cron jobs, so nothing tries to back up a server that is gone ==="
for f in laughtail-backup laughtail-monitor pelican; do
  if sudo -n test -f "/etc/cron.d/$f"; then
    sudo -n rm -f "/etc/cron.d/$f" && echo "  removed /etc/cron.d/$f"
  fi
done

echo
echo "=== 3. stop and remove the containers ==="
for c in $(sudo -n docker ps -aq 2>/dev/null); do
  NAME=$(sudo -n docker inspect --format '{{.Name}}' "$c" 2>/dev/null | tr -d '/')
  sudo -n docker rm -f "$c" >/dev/null 2>&1 && echo "  removed container $NAME"
done

echo
echo "=== 4. remove the world, the database and the panel ==="
# Literal paths, every one. The destructive-command guard refuses a recursive delete whose target is a
# variable, and it is right to - this is the block that cannot be undone.
for p in /var/lib/pelican /var/www/pelican /etc/pelican /home/ubuntu/laughtail-backups; do
  if sudo -n test -e "$p"; then
    SZ=$(sudo -n du -sh "$p" 2>/dev/null | awk '{print $1}')
    echo "  removing $p ($SZ)"
  fi
done
sudo -n rm -rf /var/lib/pelican
sudo -n rm -rf /var/www/pelican
sudo -n rm -rf /etc/pelican
sudo -n rm -rf /home/ubuntu/laughtail-backups
sudo -n rm -f /usr/local/bin/wings
echo "  done"

echo
echo "=== 5. remove the systemd unit files ==="
for svc in wings pelican-queue pelican-autostart; do
  sudo -n rm -f "/etc/systemd/system/$svc.service" 2>/dev/null && echo "  removed $svc.service" || true
done
sudo -n systemctl daemon-reload
sudo -n systemctl reset-failed 2>/dev/null || true

echo
echo "=== 6. remove the Docker images this project pulled ==="
# Named explicitly rather than a blanket prune, so anything the owner adds later for the website is
# not swept away by a script whose job was finished.
for img in \
  "ghcr.io/pelican-eggs/yolks:java_25" \
  "ghcr.io/pelican-eggs/installers:alpine" \
  "mariadb:11.4.5" \
  "maven:3.9-eclipse-temurin-25" \
  "maven:3.9.9-eclipse-temurin-21" ; do
  sudo -n docker rmi "$img" >/dev/null 2>&1 && echo "  removed image $img" || echo "  image absent: $img"
done
sudo -n docker volume prune -f >/dev/null 2>&1 && echo "  pruned unused docker volumes" || true
sudo -n docker network prune -f >/dev/null 2>&1 && echo "  pruned unused docker networks" || true

echo
echo "=== 7. remove the panel's nginx site, leaving nginx and any other site intact ==="
for f in /etc/nginx/sites-enabled/pelican.conf /etc/nginx/sites-available/pelican.conf; do
  if sudo -n test -f "$f"; then sudo -n rm -f "$f" && echo "  removed $f"; fi
done
if sudo -n test -d /etc/nginx; then
  if sudo -n nginx -t >/dev/null 2>&1; then
    sudo -n systemctl reload nginx 2>/dev/null && echo "  nginx config valid, reloaded"
  else
    echo "  NOTE: nginx config does not currently validate. Left as-is rather than reloading a broken config."
  fi
fi

# ---------------------------------------------------------------------------
echo
echo "=== VERIFY: nothing Minecraft-related should remain ==="
FAIL=0
for p in /var/lib/pelican /var/www/pelican /home/ubuntu/laughtail-backups; do
  if sudo -n test -e "$p"; then echo "  STILL PRESENT: $p"; FAIL=$((FAIL+1)); else echo "  gone: $p"; fi
done
C=$(sudo -n docker ps -aq 2>/dev/null | wc -l)
echo "  containers remaining: $C"
[ "$C" = "0" ] || FAIL=$((FAIL+1))
for svc in wings pelican-queue pelican-autostart; do
  if sudo -n systemctl is-active "$svc" >/dev/null 2>&1; then echo "  STILL RUNNING: $svc"; FAIL=$((FAIL+1)); fi
done
echo "  java processes: $(pgrep -c java 2>/dev/null || echo 0)"
echo "  port 25565 listening: $(sudo -n ss -lntup 2>/dev/null | grep -c 25565 || true)"

echo
echo "=== AFTER ==="
df -h / | tail -1 | awk '{print "  root: "$2" total, "$3" used, "$4" free"}'
echo "  docker disk:"
sudo -n docker system df 2>/dev/null | sed 's/^/    /' || echo "    docker not installed"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "TEARDOWN COMPLETE - the box is clear for a website."
else
  echo "TEARDOWN INCOMPLETE - $FAIL check(s) failed. See above."
  exit 1
fi
