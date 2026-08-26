# paper-config-assess.sh - READ ONLY.
#
# Establishes two things before any Paper config is touched:
#   1. What tooling exists to edit YAML correctly. Editing YAML with sed is how
#      configs get silently corrupted - a wrong indent changes which parent a key
#      belongs to and Paper falls back to a default without complaining.
#   2. The current values of the keys spec 6.4 and Section 23 actually decide, so
#      the deployment is a reviewed diff rather than a blind overwrite.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"

echo "=== yaml tooling ==="
python3 -c "import yaml; print('python3 yaml OK, version', yaml.__version__)" 2>&1 | head -2
command -v yq 2>/dev/null || echo "(no yq)"

echo "=== which config files exist? ==="
for f in config/paper-global.yml config/paper-world-defaults.yml spigot.yml bukkit.yml; do
  if sudo -n test -f "$D/$f"; then
    sudo -n stat -c '%n  %s bytes  owner=%u:%g' "$D/$f"
  else
    echo "$f MISSING"
  fi
done

echo "=== per-world config? ==="
sudo -n ls -1 "$D/laughtail/" 2>/dev/null | grep -i 'paper-world' || echo "(no per-world paper config yet)"

echo "=== spark section in paper-global.yml (this is why the profiler is off) ==="
sudo -n grep -A6 -E '^spark:' "$D/config/paper-global.yml" 2>/dev/null || echo "(no spark section)"

echo "=== the tuning keys that matter, current values ==="
for k in "chunk-loading-basic" "max-auto-save-chunks-per-tick" "prevent-moving-into-unloaded-chunks" \
         "delay-chunk-unloads-by" "entity-per-chunk-save-limit" "fix-climbing-bypassing-cramming-rule"; do
  echo "--- $k ---"
  sudo -n grep -rn -A3 "$k" "$D/config/paper-world-defaults.yml" 2>/dev/null | head -6 || echo "(not found)"
done

echo "=== spigot.yml view/mob settings ==="
sudo -n grep -nE 'view-distance|mob-spawn-range|entity-activation-range|ticks-per|merge-radius|save-user-cache' "$D/spigot.yml" 2>/dev/null | head -25

echo "=== bukkit.yml spawn limits and tick rates ==="
sudo -n grep -nE 'monsters|animals|water-|ambient|ticks-per|spawn-limits|chunk-gc' "$D/bukkit.yml" 2>/dev/null | head -25

echo "=== END ==="
