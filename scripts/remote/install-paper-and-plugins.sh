set -e
V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
S=/home/ubuntu/laughtail-stage
Q="$D/_quarantine"
OWN=999:987

echo "=== container must be stopped ==="
if sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  echo "ABORT: container is running"; exit 2
fi
echo "confirmed stopped"

echo "=== preserve the existing server.jar ==="
# sudo on BOTH tests. A bare [ -f ] here is the ORIGINAL instance of this bug: the
# ubuntu user cannot traverse the volume, so both tests returned false, the else
# branch ran, and the script reported "server.jar.prebuild already exists, leaving it"
# for a rollback copy it had never looked at. A reassuring message about a backup that
# does not exist is worse than no message at all.
if sudo -n test -f "$D/server.jar" && ! sudo -n test -f "$D/server.jar.prebuild"; then
  sudo -n cp -p "$D/server.jar" "$D/server.jar.prebuild"
  echo "  saved server.jar.prebuild ($(sudo -n stat -c %s "$D/server.jar.prebuild") bytes)"
else
  echo "  server.jar.prebuild already exists, leaving it"
fi

echo "=== install pinned Paper 26.2 build 119 ==="
sudo -n cp "$S/paper-26.2-119.jar" "$D/server.jar"
sudo -n chown $OWN "$D/server.jar"
sudo -n chmod 644 "$D/server.jar"
sudo -n sha256sum "$D/server.jar"

echo "=== quarantine plugins that are not in the manifest ==="
sudo -n mkdir -p "$Q"
for f in Geyser-ViaProxy.jar FastAsyncWorldEdit-Paper-2.15.4.jar Chunky-Bukkit-1.4.40.jar; do
  # `sudo -n test -f`, NOT a bare [ -f ]. The ubuntu user cannot traverse
  # /var/lib/pelican/volumes, so a bare test returns FALSE for a file that exists and
  # the move is silently skipped. That is exactly what happened here: the old
  # Chunky-Bukkit-1.4.40.jar stayed beside the new 1.5.3, and Paper reported
  # "Ambiguous plugin name 'Chunky'" - two jars claiming the same plugin, with load
  # order decided by chance. Sixth instance of this class in this project.
  if sudo -n test -f "$D/plugins/$f"; then
    sudo -n mv "$D/plugins/$f" "$Q/$f"
    echo "  quarantined $f"
  fi
done

echo "=== install the manifest plugins ==="
# GrimAC IS DELIBERATELY ABSENT FROM THIS LIST. It is pinned in the manifest and
# still downloaded and checksum-verified, but it is not installed, because it makes
# the server unplayable for a client newer than 1.21.11: it predicts movement from
# packets ViaVersion has translated, mispredicts, and sets the player back. Measured
# on the owner's own session - Simulation violations in the hundreds at offsets of
# 0.008 blocks, and "I cannot even sprint".
#
# Without this exclusion, every deploy would reinstall it and undo the fix, which is
# precisely the kind of silent regression a deploy script should never cause.
#
# Re-add it here the moment OA-27 is decided - either the server moves to the client's
# version, or old clients are dropped so no translation happens. Acceptance row 50
# cannot be claimed until then, and has not been.
for f in Geyser-Spigot.jar floodgate-spigot.jar ViaVersion-5.11.0.jar ViaBackwards-5.11.0.jar \
         LuckPerms-Bukkit-5.5.71.jar Chunky-Bukkit-1.5.3.jar \
         voicechat-bukkit-2.6.21.jar; do
  sudo -n cp "$S/$f" "$D/plugins/$f"
  sudo -n chown $OWN "$D/plugins/$f"
  sudo -n chmod 644 "$D/plugins/$f"
  echo "  installed $f"
done

echo "=== fix ownership across everything we touched (the 33.1 ownership trap) ==="
sudo -n chown -R $OWN "$D/plugins" "$Q"
sudo -n chown $OWN "$D/server.jar" "$D/server.jar.prebuild" 2>/dev/null || true

echo "=== plugins directory now ==="
sudo -n ls -l "$D/plugins" | grep -E '\.jar$'
echo "=== quarantine now ==="
sudo -n ls -l "$Q"
echo "=== ownership check: anything not 999:987 under plugins? ==="
sudo -n find "$D/plugins" "$Q" -not -user 999 -o -not -group 987 2>/dev/null | head -10 || true
echo "(empty above means ownership is correct)"
echo "=== END ==="
