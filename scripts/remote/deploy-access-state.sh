# deploy-access-state.sh - writes whitelist.json and ops.json on the dev volume.
#
# WHY THIS IS URGENT: server.properties now carries white-list=true and
# enforce-whitelist=true (Section 23, paid access only), while whitelist.json on
# the volume is the empty list []. Starting the server in that state locks out
# every player including the owner. This script closes that window.
#
# WHO GOES IN, AND ON WHAT EVIDENCE. ops.json held three entries. Mojang was
# asked about each one (scripts/remote/verify-owner-identity.sh, session 2):
#
#   5139b372-eba4-3bf7-b8a7-0da708433c5e  v3  dipanshu03j  unknown to Mojang
#   263645f0-7a1b-4d45-a0c9-16d9b0d345d0  v4  IgnisClaw    CONFIRMED by Mojang
#   7d6a728a-8c62-31b4-89e5-2555c96ba89c  v3  IgnisClaw    unknown to Mojang
#
# A version 4 UUID is issued by Mojang. A version 3 UUID is invented by an
# offline-mode server from the player name. Under online-mode=true - mandatory
# per 0.3 and 6.4, and never to be disabled - the two v3 entries can never
# authenticate, so they are not merely useless: they are standing level-4 grants
# that would activate for anyone holding those names if online-mode were ever
# turned off. They are removed, not kept "just in case".
#
# The single remaining entry is the owner's real account. ops.json recorded it
# under the old name dipanshu03j; usercache.json and Mojang both resolve that
# same UUID to IgnisClaw, so the account was renamed. Minecraft matches on UUID,
# so the rename is harmless - but the stale name is corrected anyway, because a
# file that disagrees with reality invites a wrong decision later.
#
# SCOPE: this is laughtail-dev. Acceptance row 12 - "whitelist matches paid
# transactions exactly, with zero unexplained entries" - is a PRODUCTION test.
# The owner is on the dev whitelist because nothing can be tested otherwise, and
# that is an explicit, recorded exception, not a precedent. The production
# whitelist is populated only by the paid grant pipeline built in Phase 1.
#
# UUIDs are public data. Nothing here is a secret.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
Q="$D/_quarantine"
OWN=999:987

OWNER_UUID="263645f0-7a1b-4d45-a0c9-16d9b0d345d0"
OWNER_NAME="IgnisClaw"

echo "=== container must be stopped ==="
if sudo -n docker ps --format '{{.Names}}' | grep -q "$V"; then
  echo "ABORT: container is running. Paper rewrites both files at shutdown and would discard this."
  exit 2
fi
echo "confirmed stopped"

sudo -n mkdir -p "$Q"

# ---- back up the originals once ---------------------------------------------
for f in whitelist.json ops.json; do
  if sudo -n test -f "$D/$f" && ! sudo -n test -f "$Q/$f.prebuild"; then
    sudo -n cp -p "$D/$f" "$Q/$f.prebuild"
    echo "saved $Q/$f.prebuild"
  else
    echo "$f: backup already exists or no original, leaving it"
  fi
done

WL=$(mktemp)
OPS=$(mktemp)
trap 'rm -f "$WL" "$OPS"' EXIT

cat > "$WL" <<JSON
[
  {
    "uuid": "$OWNER_UUID",
    "name": "$OWNER_NAME"
  }
]
JSON

# bypassesPlayerLimit is false. Total equality (Law 1): the owner does not get a
# reserved slot that a paying player cannot have.
cat > "$OPS" <<JSON
[
  {
    "uuid": "$OWNER_UUID",
    "name": "$OWNER_NAME",
    "level": 4,
    "bypassesPlayerLimit": false
  }
]
JSON

# ---- validate before installing. A malformed whitelist.json is read by Paper as
# ---- an empty whitelist, which locks everyone out silently - fail closed here.
echo "=== JSON validation ==="
if command -v python3 >/dev/null 2>&1; then
  for f in "$WL" "$OPS"; do
    python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d,list) and len(d)==1, 'expected a one-element list'; print('  valid JSON, %d entry: %s' % (len(d), d[0]['name']))" "$f"
  done
elif command -v jq >/dev/null 2>&1; then
  for f in "$WL" "$OPS"; do jq -e 'type=="array" and length==1' "$f" >/dev/null && echo "  valid JSON (jq)"; done
else
  echo "ABORT: neither python3 nor jq present, cannot validate JSON. Refusing to install an unvalidated whitelist."
  exit 3
fi

sudo -n cp "$WL"  "$D/whitelist.json"
sudo -n cp "$OPS" "$D/ops.json"
sudo -n chown $OWN "$D/whitelist.json" "$D/ops.json"
sudo -n chmod 644  "$D/whitelist.json" "$D/ops.json"

echo "=== installed whitelist.json ==="
sudo -n cat "$D/whitelist.json"
echo "=== installed ops.json ==="
sudo -n cat "$D/ops.json"
echo "=== ownership ==="
sudo -n stat -c '%n owner=%u:%g mode=%a' "$D/whitelist.json" "$D/ops.json"
echo "expected owner=999:987 mode=644"

echo "=== the two offline-mode UUIDs must be gone from ops.json ==="
for BAD in 5139b372-eba4-3bf7-b8a7-0da708433c5e 7d6a728a-8c62-31b4-89e5-2555c96ba89c; do
  if sudo -n grep -q "$BAD" "$D/ops.json"; then
    echo "FAIL: $BAD is still opped"
    exit 4
  fi
  echo "  removed $BAD"
done

echo "ACCESS STATE DEPLOYED"
echo "=== END ==="
