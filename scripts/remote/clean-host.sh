# clean-host.sh - remove everything this project installed, then update the OS.
#
# The Minecraft server, Pelican and the backups were already removed by teardown-minecraft.sh. This
# takes the box the rest of the way: the packages that were only ever installed for the game server,
# the build leftovers in the home directory, and then a full package update.
#
# WHAT IS PRESERVED, AND WHY THESE SPECIFICALLY
#   - ~/.ssh/authorized_keys. Deleting it locks everyone out of the box permanently, including whoever
#     is running this script. It is the one file here that cannot be recovered without console access.
#   - ~/.bashrc, ~/.profile, ~/.bash_logout. Shell defaults; removing them makes the account awkward
#     to use for no benefit.
#   - The OS, the ubuntu user, sudo configuration and the firewall.
#
# WHAT IS REMOVED THAT THE OWNER SHOULD KNOW ABOUT
#   - The TLS certificate for panel.devpilotx.com. It was issued for the Pelican panel, which no longer
#     exists, so it now certifies nothing. Certbot reissues one in seconds if that subdomain is ever
#     wanted again, so this is reversible - but it is a deliberate deletion rather than a side effect.
#   - nginx and certbot themselves. The owner asked for nothing to remain. A website will need a web
#     server, and installing the one they actually want on a clean box beats inheriting a config that
#     was shaped around a game panel.
#
# ORDER MATTERS: packages are purged BEFORE their data directories are deleted. Purging afterwards can
# recreate directories through postrm scripts, leaving the box in a state that looks cleaned and is not.
set -uo pipefail

echo "=== BEFORE ==="
df -h / | tail -1 | awk '{print "  root: "$2" total, "$3" used, "$4" free"}'
echo "  /home/ubuntu: $(sudo -n du -sh /home/ubuntu 2>/dev/null | awk '{print $1}')"

# ---------------------------------------------------------------------------
echo
echo "=== 1. stop and disable the services being removed ==="
for svc in docker docker.socket containerd nginx; do
  if sudo -n systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    sudo -n systemctl stop "$svc" 2>/dev/null && echo "  stopped $svc" || true
    sudo -n systemctl disable "$svc" >/dev/null 2>&1 && echo "  disabled $svc" || true
  fi
done

echo
echo "=== 2. purge the packages installed for the game server ==="
PKGS=""
for p in docker-ce docker-ce-cli docker-ce-rootless-extras docker-buildx-plugin \
         docker-compose-plugin containerd.io docker.io containerd runc \
         nginx nginx-common nginx-core certbot python3-certbot-nginx \
         mariadb-client mariadb-client-core mysql-common ; do
  if dpkg -l "$p" 2>/dev/null | grep -q "^ii"; then PKGS="$PKGS $p"; fi
done
# Java and PHP are matched by pattern because the exact package names vary by version.
for p in $(dpkg -l 2>/dev/null | awk '/^ii/ {print $2}' | grep -E "^(openjdk-|temurin-|php[0-9])"); do
  PKGS="$PKGS $p"
done
if [ -n "$PKGS" ]; then
  echo "  purging:$PKGS"
  sudo -n DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq $PKGS >/dev/null 2>&1 \
    && echo "  purged" || echo "  purge reported an error; continuing"
else
  echo "  nothing to purge"
fi

echo
echo "=== 3. remove the data directories those packages left behind ==="
for p in /var/lib/docker /var/lib/containerd /etc/docker /etc/nginx /var/log/nginx \
         /var/www /etc/letsencrypt /var/lib/letsencrypt /var/log/letsencrypt ; do
  if sudo -n test -e "$p"; then
    echo "  removing $p ($(sudo -n du -sh "$p" 2>/dev/null | awk '{print $1}'))"
  fi
done
# Literal paths, every one. The guard refuses a recursive delete whose target is a variable.
sudo -n rm -rf /var/lib/docker
sudo -n rm -rf /var/lib/containerd
sudo -n rm -rf /etc/docker
sudo -n rm -rf /etc/nginx
sudo -n rm -rf /var/log/nginx
sudo -n rm -rf /var/www
sudo -n rm -rf /etc/letsencrypt
sudo -n rm -rf /var/lib/letsencrypt
sudo -n rm -rf /var/log/letsencrypt
echo "  done"

echo
echo "=== 4. remove the build leftovers in the home directory ==="
# Named individually rather than a wildcard. A glob here would be one typo away from ~/.ssh.
for p in /home/ubuntu/laughtail-db /home/ubuntu/laughtail-monitor /home/ubuntu/laughtail-plugin \
         /home/ubuntu/laughtail-scratch /home/ubuntu/laughtail-stage /home/ubuntu/mcbuild \
         /home/ubuntu/.m2 /home/ubuntu/.cache ; do
  if sudo -n test -e "$p"; then
    echo "  removing $p ($(sudo -n du -sh "$p" 2>/dev/null | awk '{print $1}'))"
  fi
done
sudo -n rm -rf /home/ubuntu/laughtail-db
sudo -n rm -rf /home/ubuntu/laughtail-monitor
sudo -n rm -rf /home/ubuntu/laughtail-plugin
sudo -n rm -rf /home/ubuntu/laughtail-scratch
sudo -n rm -rf /home/ubuntu/laughtail-stage
sudo -n rm -rf /home/ubuntu/mcbuild
sudo -n rm -rf /home/ubuntu/.m2
sudo -n rm -rf /home/ubuntu/.cache
echo "  done"
echo "  PRESERVED: ~/.ssh (removing it would lock everyone out), ~/.bashrc, ~/.profile"

echo
echo "=== 5. remove the docker apt repository, so it stops being fetched on every update ==="
for f in /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc \
         /etc/apt/sources.list.d/pelican.list ; do
  if sudo -n test -f "$f"; then sudo -n rm -f "$f" && echo "  removed $f"; fi
done

# ---------------------------------------------------------------------------
echo
echo "=== 6. update every remaining package ==="
sudo -n DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1 && echo "  package lists refreshed"
BEFORE_UP=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "  $BEFORE_UP package(s) to upgrade"
# -y with the noninteractive frontend and the config options keeps existing config files rather than
# prompting. A prompt here would hang forever, because nothing is attached to answer it.
sudo -n DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
  -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" >/dev/null 2>&1 \
  && echo "  upgrade completed" || echo "  upgrade reported an error - check manually"
AFTER_UP=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "  $AFTER_UP package(s) still upgradable afterwards"

echo
echo "=== 7. remove orphaned packages and clear the package cache ==="
sudo -n DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y -qq >/dev/null 2>&1 && echo "  autoremoved"
sudo -n apt-get autoclean -qq >/dev/null 2>&1 && echo "  cache cleaned"
sudo -n journalctl --vacuum-time=1d >/dev/null 2>&1 && echo "  old journal logs vacuumed" || true

# ---------------------------------------------------------------------------
echo
echo "=== VERIFY ==="
FAIL=0
for p in /var/lib/docker /etc/nginx /var/www /etc/letsencrypt /home/ubuntu/laughtail-plugin ; do
  if sudo -n test -e "$p"; then echo "  STILL PRESENT: $p"; FAIL=$((FAIL+1)); else echo "  gone: $p"; fi
done
echo "  ssh key preserved: $(sudo -n test -f /home/ubuntu/.ssh/authorized_keys && echo YES || echo 'NO - DANGER')"
sudo -n test -f /home/ubuntu/.ssh/authorized_keys || FAIL=$((FAIL+1))
echo "  docker installed: $(command -v docker >/dev/null 2>&1 && echo yes || echo no)"
echo "  java installed:   $(command -v java >/dev/null 2>&1 && echo yes || echo no)"
echo "  listening ports:"
sudo -n ss -lntp 2>/dev/null | tail -n +2 | awk '{print "    "$4}' | sort -u

echo
echo "=== AFTER ==="
df -h / | tail -1 | awk '{print "  root: "$2" total, "$3" used, "$4" free"}'
echo "  /home/ubuntu: $(sudo -n du -sh /home/ubuntu 2>/dev/null | awk '{print $1}')"
if sudo -n test -f /var/run/reboot-required; then
  echo "  REBOOT REQUIRED to finish applying the updates"
else
  echo "  no reboot required"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "HOST CLEANED AND UPDATED."
else
  echo "CLEANUP INCOMPLETE - $FAIL check(s) failed. See above."
  exit 1
fi
