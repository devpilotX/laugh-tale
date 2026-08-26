V=$(sudo -n ls -1 /var/lib/pelican/volumes 2>/dev/null | head -1)
P="/var/lib/pelican/volumes/$V/plugins"
echo "=== jars present ==="
sudo -n find "$P" -maxdepth 1 -name '*.jar' -printf '%f\t%s bytes\n' 2>/dev/null
echo "=== sha256 of each jar ==="
sudo -n find "$P" -maxdepth 1 -name '*.jar' -exec sha256sum {} \; 2>/dev/null | sed "s|$P/||"
echo "=== spark jar name and plugin.yml version ==="
for j in $(sudo -n find "$P" -maxdepth 1 -iname '*spark*.jar' 2>/dev/null); do
  echo "jar: $j"
  sudo -n unzip -p "$j" plugin.yml 2>/dev/null | grep -Ei '^(name|version|api-version|main):' || echo "  (no plugin.yml readable)"
done
echo "=== spark dir contents ==="
sudo -n ls -1 "$P/spark" 2>/dev/null | head
echo "=== is spark loaded? grep the latest log ==="
L="/var/lib/pelican/volumes/$V/logs/latest.log"
sudo -n grep -iE 'spark|chunky|fastasync|geyser' "$L" 2>/dev/null | head -20
echo "=== END ==="
