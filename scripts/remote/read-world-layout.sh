# read-world-layout.sh - READ ONLY. What did 26.2's WorldFolderMigration actually do?
#
# Paper 26.2 logged "World storage migration is required during startup" and only
# `laughtail` and `world` now exist at the volume root - yet Multiverse lists five worlds
# and the plugin applied borders to all five. So the data moved somewhere, and every
# script that names a world directory is now wrong until we know where.
#
# This matters beyond curiosity: backup-run.sh excludes world directories BY NAME, and
# regen-resource-world.sh looks for one BY PATH. Both are built on the old layout.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"

echo "=== every level.dat, to 5 levels deep ==="
sudo -n find "$D" -maxdepth 5 -name 'level.dat' 2>/dev/null | sed "s#^$D/#  #"

echo ""
echo "=== inside the laughtail folder ==="
sudo -n ls -1 "$D/laughtail"

echo ""
echo "=== any 'dimensions' directory? ==="
sudo -n find "$D" -maxdepth 4 -type d -name 'dimensions' 2>/dev/null | sed "s#^$D/#  #" || echo "  (none)"

echo ""
echo "=== where are the region files, by directory ==="
sudo -n find "$D" -maxdepth 6 -type d -name 'region' 2>/dev/null | sed "s#^$D/#  #"

echo ""
echo "=== sizes of anything world-shaped ==="
for p in laughtail world; do
  sudo -n du -sh "$D/$p" 2>/dev/null | sed 's/^/  /'
done

echo ""
echo "=== Multiverse worlds.yml - what folder does it record per world? ==="
sudo -n grep -nE 'laughtail|folder|name:|environment' "$D/plugins/Multiverse-Core/worlds.yml" 2>/dev/null | head -40 || echo "  (unreadable)"

echo "=== END ==="
