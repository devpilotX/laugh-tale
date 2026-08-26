V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
S=/home/ubuntu/laughtail-stage
Q="$D/_quarantine"
OWN=999:987

# NOTE: every file test must run under sudo. The ubuntu user cannot traverse
# /var/lib/pelican/volumes, so a bare [ -f ... ] silently returns false and the
# script takes the wrong branch without any error. That bug made an earlier run
# report "already exists" for a backup it had never checked.

echo "=== does server.jar.prebuild actually exist? ==="
if sudo -n test -f "$D/server.jar.prebuild"; then
  echo "  yes: $(sudo -n stat -c '%s bytes, %y' "$D/server.jar.prebuild")"
  sudo -n sha256sum "$D/server.jar.prebuild"
else
  echo "  NO - it was never created. The original jar is still in the tar backup."
  echo "  restoring the original jar from the volume tar into place as .prebuild"
  BK=$(ls -1t /home/ubuntu/laughtail-backups/prebuild-volume-*.tar.gz | head -1)
  sudo -n tar -xzf "$BK" -C /tmp "$V/server.jar"
  sudo -n mv "/tmp/$V/server.jar" "$D/server.jar.prebuild"
  sudo -n chown $OWN "$D/server.jar.prebuild"
  sudo -n rm -rf "/tmp/$V"
  echo "  recovered: $(sudo -n stat -c '%s bytes' "$D/server.jar.prebuild")"
  sudo -n sha256sum "$D/server.jar.prebuild"
fi

echo "=== quarantine non-manifest plugins (sudo test this time) ==="
sudo -n mkdir -p "$Q"
for f in Geyser-ViaProxy.jar FastAsyncWorldEdit-Paper-2.15.4.jar Chunky-Bukkit-1.5.3.jar; do
  if sudo -n test -f "$D/plugins/$f"; then
    sudo -n mv "$D/plugins/$f" "$Q/$f"
    echo "  quarantined $f"
  else
    echo "  not present: $f"
  fi
done

echo "=== quarantine plugin CONFIG dirs that no longer have a jar ==="
for dir in FastAsyncWorldEdit spark bStats; do
  if sudo -n test -d "$D/plugins/$dir"; then
    sudo -n mv "$D/plugins/$dir" "$Q/$dir"
    echo "  quarantined dir $dir"
  fi
done

sudo -n chown -R $OWN "$Q"

echo "=== plugins directory now (jars only) ==="
# The glob must NOT be written as "$D/plugins"/*.jar - that is expanded by the
# calling shell, which runs as ubuntu and cannot traverse the volume, so it stays
# literal, sudo ls fails, and xargs basename dies with "missing operand". The
# resulting non-zero exit looks like a real failure. Filter after listing instead.
sudo -n ls -1 "$D/plugins" | grep '\.jar$' || echo "(no jars)"
echo "=== plugins directory (all entries) ==="
sudo -n ls -1 "$D/plugins"
echo "=== quarantine ==="
sudo -n ls -1 "$Q"
echo "=== END ==="
