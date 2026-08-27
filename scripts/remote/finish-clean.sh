# finish-clean.sh - remove the last leftovers a deep check found after the main cleanup.
#
# The main cleanup removed the software and its data. A deeper look found four things it does not
# occur to most people to check, which is exactly why they get left on machines for years:
#
#   1. The `pelican` system user and its group, and the `docker` group. Orphaned accounts are not
#      merely untidy - a UID that still exists can own files a later install creates, and a group
#      that still exists can silently grant access if its GID is reused.
#   2. Firewall rules still opening 8443 and 25565 to the whole internet for services that no longer
#      exist, plus DENY rules for Wings ports that are now meaningless.
#   3. Three packages removed but not purged, including an old kernel still holding ~200 MB.
#   4. Nothing in bash history, which was already clean.
#
# ON THE FIREWALL, AND WHY THIS IS NOT `ufw reset`: a reset drops every rule including SSH, and on a
# remote machine the connection dies with the rule that was keeping it alive. The guard refuses
# `ufw reset` for that reason. Rules are deleted individually and 22 is verified still present at the
# end, before anything else is touched.
#
# WHAT IS KEPT: 22 for SSH, and 80 and 443. A website needs 80 and 443, and the owner is about to host
# one - deleting them now to reinstate them in an hour is churn, not cleanliness. The stale comments on
# those rules are corrected so nothing claims to be for a panel that no longer exists.
set -uo pipefail

echo "=== 1. firewall: remove rules for services that no longer exist ==="
echo "  before:"
sudo -n ufw status numbered 2>/dev/null | sed 's/^/    /'

# Deleted by RULE SPECIFICATION rather than by number. Numbers shift as each delete lands, so deleting
# "rule 5" four times removes four different rules than intended - a classic way to delete the SSH rule
# by accident.
for spec in "8443/tcp" "25565/tcp" "8080/tcp" "2022/tcp"; do
  sudo -n ufw --force delete allow "$spec" >/dev/null 2>&1 || true
  sudo -n ufw --force delete deny "$spec"  >/dev/null 2>&1 || true
  echo "  deleted rules for $spec"
done

# Re-add 80 and 443 with honest comments, replacing ones that referenced the panel.
sudo -n ufw --force delete allow 443/tcp >/dev/null 2>&1 || true
sudo -n ufw --force delete allow 80/tcp  >/dev/null 2>&1 || true
sudo -n ufw allow 80/tcp  comment 'HTTP'  >/dev/null 2>&1 && echo "  re-added 80/tcp (HTTP)"
sudo -n ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1 && echo "  re-added 443/tcp (HTTPS)"

echo "  after:"
sudo -n ufw status 2>/dev/null | sed 's/^/    /'

# THE SAFETY CHECK. If SSH is no longer allowed, say so loudly - the session is still open, so it can
# still be repaired, but only until it is closed.
if sudo -n ufw status 2>/dev/null | grep -q "^22/tcp .*ALLOW"; then
  echo "  OK: SSH on 22 is still allowed"
else
  echo "  DANGER: SSH is NOT allowed. Re-adding it now while this session is still open."
  sudo -n ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
fi

echo
echo "=== 2. remove the orphaned system accounts ==="
if id pelican >/dev/null 2>&1; then
  sudo -n userdel pelican >/dev/null 2>&1 && echo "  removed user pelican" || echo "  could not remove user pelican"
fi
for g in pelican docker; do
  if getent group "$g" >/dev/null 2>&1; then
    sudo -n groupdel "$g" >/dev/null 2>&1 && echo "  removed group $g" || echo "  could not remove group $g"
  fi
done

echo
echo "=== 3. purge the packages that were removed but not purged ==="
RC=$(dpkg -l 2>/dev/null | awk '/^rc/ {print $2}' | tr '\n' ' ')
if [ -n "${RC// /}" ]; then
  echo "  purging: $RC"
  sudo -n DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq $RC >/dev/null 2>&1 \
    && echo "  purged" || echo "  purge reported an error"
else
  echo "  nothing in residual-config state"
fi
# Old kernels are removed by autoremove once a newer one is running and confirmed working, which it is.
sudo -n DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y -qq >/dev/null 2>&1 && echo "  autoremoved"

echo
echo "=== VERIFY ==="
FAIL=0
id pelican >/dev/null 2>&1 && { echo "  STILL PRESENT: user pelican"; FAIL=$((FAIL+1)); } || echo "  gone: user pelican"
getent group pelican >/dev/null 2>&1 && { echo "  STILL PRESENT: group pelican"; FAIL=$((FAIL+1)); } || echo "  gone: group pelican"
getent group docker  >/dev/null 2>&1 && { echo "  STILL PRESENT: group docker";  FAIL=$((FAIL+1)); } || echo "  gone: group docker"
R=$(dpkg -l 2>/dev/null | grep -c '^rc' || true)
echo "  residual-config packages: $R"
[ "$R" = "0" ] || FAIL=$((FAIL+1))
echo "  ufw rules now:"
sudo -n ufw status 2>/dev/null | tail -n +4 | sed 's/^/    /'
sudo -n ufw status 2>/dev/null | grep -q "^22/tcp .*ALLOW" || { echo "  DANGER: SSH not allowed"; FAIL=$((FAIL+1)); }
echo "  kernels installed:"
dpkg -l 2>/dev/null | awk '/^ii  linux-image-[0-9]/ {print "    "$2}'
echo "  running kernel: $(uname -r)"
echo
df -h / | tail -1 | awk '{print "  disk: "$3" used of "$2", "$4" free"}'
echo
[ "$FAIL" -eq 0 ] && echo "FULLY CLEAN." || { echo "$FAIL item(s) remain."; exit 1; }
