# verify-owner-identity.sh - READ ONLY. Touches nothing on the server.
#
# Proves which of the three ops.json UUIDs can actually authenticate under
# online-mode=true, by asking Mojang rather than by inferring it.
#
# Why this matters: a UUID's version nibble says whether Mojang issued it.
# Premium accounts get a version 4 UUID; an offline-mode server invents a
# version 3 UUID from the player name. A version 3 entry in ops.json is dead
# under online-mode=true, and worse, it is a level-4 grant waiting for anyone who
# takes that name if online-mode is ever turned off.
#
# Only public profile data is requested. No credential leaves the host.

for U in 5139b372-eba4-3bf7-b8a7-0da708433c5e \
         263645f0-7a1b-4d45-a0c9-16d9b0d345d0 \
         7d6a728a-8c62-31b4-89e5-2555c96ba89c; do
  # The version nibble is the first character of the third dash-separated group.
  VER=$(echo "$U" | cut -d- -f3 | cut -c1)
  STRIPPED=$(echo "$U" | tr -d '-')
  BODY=$(curl -sS --max-time 15 "https://sessionserver.mojang.com/session/minecraft/profile/$STRIPPED" || echo "REQUEST_FAILED")
  if [ -z "$BODY" ]; then
    RESULT="not a Mojang account (empty response = unknown UUID)"
  else
    RESULT=$(echo "$BODY" | head -c 300)
  fi
  echo "uuid=$U  version=$VER"
  echo "  mojang: $RESULT"
done

echo "=== name lookup: which UUID does the name IgnisClaw currently own? ==="
curl -sS --max-time 15 "https://api.mojang.com/users/profiles/minecraft/IgnisClaw" || echo "(lookup failed)"
echo
echo "=== END ==="
