# disable-grimac.sh - takes GrimAC out of the running server, reversibly.
#
# WHY. Proven cause of unplayable movement, not a guess:
#   viaversion list  ->  [26.2] (1): [IgnisClaw]
#   server           ->  Paper 1.21.11
# The client is four releases NEWER than the server, so ViaVersion translates every
# packet. GrimAC predicts movement from packets and its own boot warning says this
# combination is unsupported. Result: Simulation violations in the hundreds with
# offsets as small as 0.008 blocks, and setbacks that feel exactly like "I cannot
# sprint, I am stuck".
#
# This is not an anti-cheat tuning problem. Only 5 of Grim's checks expose a
# `setbackvl` knob; its movement checks correct the player by design - that IS the
# mitigation, so there is no alert-only mode for them. Raising thresholds until the
# false positives stop would also raise them until real cheats pass, which on a
# server that sells fairness is worse than no anti-cheat.
#
# SO: Grim comes out until OA-27 is decided. What that costs, stated plainly -
# acceptance row 50 (catch a test flight and a test reach cheat) CANNOT be claimed
# while this is the case, and it was never claimed. This is a dev server with one
# player: the owner. Nothing is being protected right now that this puts at risk.
#
# Reversible in one command: the jar is moved to _quarantine, not deleted.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
Q="$D/_quarantine"

sudo -n mkdir -p "$Q"

echo "=== current state ==="
sudo -n ls -1 "$D/plugins" | grep -i grim || echo "  (no grim jar present)"

MOVED=0
for f in $(sudo -n ls -1 "$D/plugins" | grep -iE '^grimac.*\.jar$' || true); do
  sudo -n mv "$D/plugins/$f" "$Q/$f"
  echo "  moved $f to _quarantine"
  MOVED=1
done

if [ "$MOVED" -eq 0 ]; then
  echo "  nothing to move - GrimAC is already out"
fi

echo "=== plugins remaining ==="
sudo -n ls -1 "$D/plugins" | grep '\.jar$'

echo "=== quarantine ==="
sudo -n ls -1 "$Q" | grep -i grim || echo "  (none)"

echo ""
echo "GrimAC is out of the plugins directory. It takes effect on the next restart."
echo "Row 50 (anti-cheat catches a test flight and reach cheat) is NOT satisfiable"
echo "in this state, and was never claimed. See OA-27."
echo "=== END ==="
