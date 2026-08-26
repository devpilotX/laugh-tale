# grimac-alert-only.sh - puts GrimAC into ALERT-ONLY mode.
#
# WHY, AND WHY THIS IS THE SPECIFICATION'S OWN INSTRUCTION, not a workaround:
# Section 14 and the Phase 1 plan both say "Anti-cheat installed in ALERT-ONLY mode".
# It was installed with vendor defaults instead, which issue SETBACKS - Grim rejects
# a movement it cannot predict and pulls the player back to where it thinks they
# should be. To the player that is not an anti-cheat message, it is a server that
# will not let them sprint.
#
# Observed on the owner's own first session:
#   Grim » IgnisClaw failed Simulation (x92)  .007980  /gl 1
#   Grim » IgnisClaw failed GroundSpoof (x2)  claimed false
#   Grim » IgnisClaw failed Simulation (x171) .030006  /gl 2
#   Grim » IgnisClaw failed Simulation (x210) .420000  /gl 3
# Violation counts in the hundreds with offsets as small as 0.008 blocks: those are
# not a cheating player, they are mispredictions.
#
# THE LIKELY ROOT CAUSE IS THE CONFLICT ALREADY RAISED AS OA-27 / Q-42. GrimAC warns
# on every boot that ViaBackwards on a 1.21.2+ server is unsupported, and the log
# shows PacketEvents loading block mappings for V_1_21_9 while the server is 1.21.11.
# Grim predicts movement from packets that ViaBackwards has rewritten, so its
# predictions do not match reality. Alert-only stops the harm to players; it does not
# fix the underlying conflict, which is still the owner's decision.
#
# WHAT ALERT-ONLY MEANS HERE: every check still runs and still logs, so acceptance
# row 50 (catch a test flight and a test reach cheat, with evidence) remains provable
# from the alert log. Nothing is disabled. Only the automatic punishment is removed.
#
# HOW: every `setbackvl` in GrimAC's config is set to -1, which is Grim's own way of
# saying "never set back for this check". Applied by walking the parsed YAML rather
# than by regex, so a key nested anywhere is caught and the file stays valid.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CFG="$D/plugins/GrimAC/config.yml"
OWN=999:987

if ! sudo -n test -f "$CFG"; then
  echo "ABORT: $CFG not found"
  exit 2
fi

echo "=== backing up GrimAC config once ==="
sudo -n mkdir -p "$D/_quarantine/config-prebuild"
if ! sudo -n test -f "$D/_quarantine/config-prebuild/GrimAC-config.yml"; then
  sudo -n cp -p "$CFG" "$D/_quarantine/config-prebuild/GrimAC-config.yml"
  echo "  saved"
else
  echo "  backup already exists"
fi

cat > /tmp/lt-grim.py <<'PYEOF'
import sys, yaml

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    doc = yaml.safe_load(f)

changed = []
kept = []

def walk(node, prefix=''):
    if isinstance(node, dict):
        for k in list(node.keys()):
            p = f'{prefix}.{k}' if prefix else str(k)
            v = node[k]
            if isinstance(v, (dict, list)):
                walk(v, p)
            elif k == 'setbackvl':
                if v != -1:
                    node[k] = -1
                    changed.append((p, v))
                else:
                    kept.append(p)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            if isinstance(v, (dict, list)):
                walk(v, f'{prefix}[{i}]')

walk(doc)

# Alerts must stay ON, or this becomes "anti-cheat disabled" rather than
# "alert-only", and row 50 would have no evidence source.
alerts = doc.get('alerts', {})
if isinstance(alerts, dict):
    for key in ('print-to-console', 'enable-on-join'):
        if key in alerts and alerts[key] is not True:
            alerts[key] = True
            changed.append(('alerts.' + key, 'false -> true'))

for p, old in changed:
    print('  SET  %-60s was %s' % (p, old))
print('  already correct: %d' % len(kept))
print('  changed: %d' % len(changed))

if not changed:
    print('NOCHANGE')
else:
    with open('/tmp/lt-grim-out.yml', 'w', encoding='utf-8') as f:
        yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    print('WROTE')
PYEOF

echo "=== setting every setbackvl to -1 (Grim's own 'never set back') ==="
OUT=$(sudo -n python3 /tmp/lt-grim.py "$CFG")
echo "$OUT"

if echo "$OUT" | grep -q '^WROTE$'; then
  sudo -n cp /tmp/lt-grim-out.yml "$CFG"
  sudo -n chown $OWN "$CFG"
  sudo -n chmod 644 "$CFG"
  sudo -n rm -f /tmp/lt-grim-out.yml
  echo "installed"
else
  echo "nothing to change"
fi
sudo -n rm -f /tmp/lt-grim.py

echo "=== verify: any setbackvl left above -1? (0 expected) ==="
sudo -n grep -c 'setbackvl: -1' "$CFG" || true
sudo -n grep 'setbackvl:' "$CFG" | grep -v -- '-1' | head -5 || echo "  none above -1"

echo "=== ownership ==="
sudo -n stat -c '  %n owner=%u:%g mode=%a' "$CFG"
echo "GRIMAC SET TO ALERT-ONLY"
echo "=== END ==="
