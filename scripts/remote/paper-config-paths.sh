# paper-config-paths.sh - READ ONLY.
#
# Prints the real dotted key paths for the settings spec 6.4 names, with their
# current values, from the live YAML. Paper renames and moves keys between
# versions, so choosing a path from memory or from a blog is how a "tuned" config
# ends up doing nothing at all - Paper ignores an unknown key without complaint.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"

cat > /tmp/lt-paths.py <<'PY'
import sys, yaml

WANT = ('hopper', 'redstone', 'activation', 'tracking', 'merge', 'spawn',
        'chunk', 'autosave', 'auto-save', 'spark', 'ticks-per', 'despawn',
        'view-distance', 'simulation', 'save-user-cache', 'collisions',
        'entity-per-chunk', 'update-pathfinding', 'grass-spread', 'item-frame')

def walk(node, prefix=''):
    if isinstance(node, dict):
        for k, v in node.items():
            p = f'{prefix}.{k}' if prefix else str(k)
            if isinstance(v, (dict, list)):
                walk(v, p)
            else:
                if any(w in p.lower() for w in WANT):
                    print(f'{p} = {v!r}')
    # lists are not addressable by key path, so they are skipped deliberately

for path in sys.argv[1:]:
    print(f'===== {path} =====')
    try:
        with open(path, 'r', encoding='utf-8') as f:
            walk(yaml.safe_load(f))
    except Exception as e:
        print(f'  ERROR: {e}')
PY

sudo -n python3 /tmp/lt-paths.py \
  "$D/config/paper-global.yml" \
  "$D/config/paper-world-defaults.yml" \
  "$D/spigot.yml" \
  "$D/bukkit.yml"

rm -f /tmp/lt-paths.py
echo "=== END ==="
