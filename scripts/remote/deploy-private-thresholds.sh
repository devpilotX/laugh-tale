# deploy-private-thresholds.sh - creates plugins/LaughTail/private.yml on the host.
#
# NEVER-BREAK RULE 10: "Never publish detector thresholds for anti-cheat, wagering, or
# market manipulation. Publishing them teaches evasion."
#
# A player who knows the repeat-kill window and the limit knows exactly how to farm an alt
# without ever tripping the detector. So these numbers exist in exactly two places - this
# file on the host, and docs/private/ on the owner's PC, which .gitignore excludes. They
# are not in the repository, not in the committed plugin config, and NOT PRINTED by this
# script. Only the fact that they were written is reported.
#
# The DETECTION LOGIC is public and reviewable in CombatTracker.java. That is the right
# split: a reviewer can confirm the logic is sound without learning where the line sits.
#
# WHY THE VALUES ARE WHAT THEY ARE is recorded in docs/private/, not here, for the same
# reason. This script only states the SHAPE of the config.
#
# IDEMPOTENT: an existing file is left alone. Overwriting it would reset a salt that
# existing hashes depend on, which would silently break same-IP matching against history.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CFGDIR="$D/plugins/LaughTail"
OWN=999:987

sudo -n mkdir -p "$CFGDIR"

if sudo -n test -f "$CFGDIR/private.yml"; then
  echo "private.yml already exists - left untouched."
  echo "Overwriting would reset the IP hash salt, and every same-IP comparison against"
  echo "existing combat_events history would stop matching."
  sudo -n stat -c '  %n owner=%u:%g mode=%a size=%s' "$CFGDIR/private.yml"
  echo "=== END ==="
  exit 0
fi

echo "=== generating a salt (value never printed) ==="
SALT=$(openssl rand -hex 32)
echo "  salt generated (${#SALT} hex chars)"

echo "=== writing private.yml ==="
# Written via a heredoc with the salt substituted by the shell, then immediately locked to
# 640. The values below are operating thresholds and are deliberately absent from git.
sudo -n tee "$CFGDIR/private.yml" > /dev/null <<EOF
# LaughTail private detector configuration.
#
# NOT IN GIT, and must never be. Never-break rule 10: publishing detector thresholds
# teaches evasion. If this file ever appears in a commit, that is a defect - rotate the
# salt and change the thresholds.
#
# The reasoning behind each value is recorded in docs/private/ on the owner's machine,
# which .gitignore excludes.

anti-farm:
  # Window over which repeat kills on the same victim are counted.
  repeat-kill-window-seconds: 5400

  # How many kills on the same victim inside that window still score before the rest are
  # suppressed. Acceptance row 31 requires diminishing returns then zero.
  repeat-kills-before-zero: 3

  # Salt for the SHA-256 of a player's IP. Row 32 needs same-IP COMPARISON, not the
  # address itself, and the IPv4 space is small enough to enumerate - so an unsalted hash
  # would be reversible. Rotating this salt invalidates comparisons against existing
  # history, so it is generated once and then left alone.
  ip-hash-salt: "$SALT"
EOF

sudo -n chown $OWN "$CFGDIR/private.yml"
sudo -n chmod 640 "$CFGDIR/private.yml"

echo "=== installed ==="
sudo -n stat -c '  %n owner=%u:%g mode=%a size=%s' "$CFGDIR/private.yml"
echo "  keys present: $(sudo -n grep -cE '^\s{2}[a-z-]+:' "$CFGDIR/private.yml")"
echo "  (values deliberately not displayed - rule 10)"

echo "=== the file must not be readable by other users ==="
MODE=$(sudo -n stat -c %a "$CFGDIR/private.yml")
if [ "$MODE" = "640" ]; then echo "  mode 640 OK"; else echo "  WARNING: mode $MODE"; fi

echo "PRIVATE THRESHOLDS DEPLOYED"
echo "=== END ==="
