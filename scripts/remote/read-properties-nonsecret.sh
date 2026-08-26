# read-properties-nonsecret.sh - READ ONLY.
#
# Prints the values of ONLY the keys named below. Every key in this list is
# non-secret by inspection. The two secret-bearing keys in the live file -
# rcon.password and management-server-secret - are deliberately absent and are
# never printed by any script in this repository (never-break rule 5).
#
# Purpose: the repository template omits twelve keys that exist in the live file.
# Paper rewrites server.properties at boot and regenerates a default for every
# missing key, so omission is a silent change, not a no-op. These are the values
# needed to set those keys deliberately instead of by accident.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
LIVE="/var/lib/pelican/volumes/$V/server.properties"

for k in allow-flight \
         enable-code-of-conduct \
         status-heartbeat-interval \
         text-filtering-config \
         management-server-enabled \
         management-server-host \
         management-server-port \
         management-server-tls-enabled \
         management-server-tls-keystore \
         management-server-tls-keystore-password \
         management-server-allowed-origins; do
  printf '%s -> [%s]\n' "$k" "$(sudo -n grep -m1 "^${k}=" "$LIVE" | cut -d= -f2-)"
done

echo "=== is management-server-secret non-empty? (length only, never the value) ==="
LEN=$(sudo -n grep -m1 '^management-server-secret=' "$LIVE" | cut -d= -f2- | tr -d '\n' | wc -c)
echo "management-server-secret length: $LEN"

echo "=== is rcon.password non-empty? (length only, never the value) ==="
LEN2=$(sudo -n grep -m1 '^rcon.password=' "$LIVE" | cut -d= -f2- | tr -d '\n' | wc -c)
echo "rcon.password length: $LEN2"

echo "=== END ==="
