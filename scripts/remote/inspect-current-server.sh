V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
echo "volume: $V"
echo "=== ownership of existing files (this is what new files must match) ==="
sudo -n stat -c '%U:%G %u:%g %a  %n' "$D" "$D/server.properties" "$D/server.jar" "$D/plugins" 2>/dev/null
echo "=== container user ==="
sudo -n docker inspect "$V" --format 'User={{.Config.User}} Image={{.Config.Image}}' 2>/dev/null
sudo -n docker exec "$V" id 2>/dev/null || echo "(cannot exec: container may not allow it)"
echo "=== current server.jar identity ==="
sudo -n sha256sum "$D/server.jar" 2>/dev/null
sudo -n ls -l "$D/server.jar" 2>/dev/null
echo "=== version from the jar manifest ==="
sudo -n unzip -p "$D/server.jar" META-INF/MANIFEST.MF 2>/dev/null | tr -d '\r' | grep -Ei 'Implementation-Version|Specification-Version|Main-Class|Premain' || echo "(no manifest fields)"
echo "=== version-history / build info ==="
sudo -n cat "$D/version_history.json" 2>/dev/null || echo "(no version_history.json)"
echo "=== what the log says about the version ==="
sudo -n ls -1t "$D/logs" 2>/dev/null | head -5
sudo -n zgrep -h -m3 -iE 'This server is running|Starting minecraft server version' "$D"/logs/*.log.gz 2>/dev/null | head -5
sudo -n grep -h -m3 -iE 'This server is running|Starting minecraft server version' "$D"/logs/latest.log 2>/dev/null || echo "(latest.log has no version line)"
echo "=== is the container running ==="
sudo -n docker ps --filter "name=$V" --format '{{.Names}} {{.Status}}'
echo "=== players online right now (query the console log tail) ==="
sudo -n tail -20 "$D/logs/latest.log" 2>/dev/null || echo "(no latest.log)"
echo "=== END ==="
