# read-world-dirs.sh - READ ONLY. Where are the worlds on disk?
V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
echo "=== everything at the volume root starting with laughtail or world ==="
sudo -n ls -1 "$D" | grep -E '^(laughtail|world)' || echo "(none)"
echo "=== full volume root listing ==="
sudo -n ls -1 "$D"
echo "=== does Multiverse store worlds elsewhere? ==="
sudo -n find "$D" -maxdepth 2 -name 'level.dat' 2>/dev/null | head -12
echo "=== Multiverse config: what does it think the folders are? ==="
sudo -n ls -1 "$D/plugins/Multiverse-Core" 2>/dev/null || echo "(no MV dir)"
echo "=== worlds.yml or worlds.json ==="
for f in worlds.yml worlds.json worlds2.yml; do
  if sudo -n test -f "$D/plugins/Multiverse-Core/$f"; then
    echo "--- $f ---"
    sudo -n head -40 "$D/plugins/Multiverse-Core/$f"
  fi
done
echo "=== END ==="
