# verify-exposure.sh - READ ONLY. Acceptance row 5 evidence, host side.
#
# The boot log says "RCON running on 0.0.0.0:25575". Inside the container that is
# harmless on its own - what decides reachability is whether Wings PUBLISHED the
# port to the host, and whether anything filters it.
#
# The trap being tested for: Docker inserts its own iptables rules in the
# DOCKER-USER and DOCKER chains, which are traversed BEFORE ufw's chains. A
# published container port is therefore reachable from the internet even when
# "ufw status" shows default deny incoming. Reading ufw alone would produce a
# confident and wrong answer, which is why the published bindings and the raw nat
# table are both read here, and why an external probe is run separately from the
# owner's PC.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)

echo "=== published port bindings (the thing that actually matters) ==="
sudo -n docker inspect "$V" --format '{{json .HostConfig.PortBindings}}'
echo
echo "=== docker port ==="
sudo -n docker port "$V" 2>/dev/null || echo "(no published ports)"

echo "=== what is listening on the HOST, and on which address ==="
sudo -n ss -lntup 2>/dev/null | grep -E '25565|25575|19132|24454|LISTEN' | head -25

echo "=== docker nat rules that forward into this container ==="
sudo -n iptables -t nat -S 2>/dev/null | grep -E 'DNAT|MASQUERADE' | head -20 || echo "(none readable)"

echo "=== DOCKER-USER chain: this is what could filter published ports ==="
sudo -n iptables -S DOCKER-USER 2>/dev/null || echo "(no DOCKER-USER chain)"

echo "=== ufw, for completeness - note it does NOT govern published docker ports ==="
sudo -n ufw status verbose 2>/dev/null | head -20

echo "=== has Paper rewritten server.properties since deploy? ==="
D="/var/lib/pelican/volumes/$V"
sudo -n stat -c 'server.properties mtime=%y size=%s' "$D/server.properties"
echo "--- are the repository comments still present? ---"
CMT=$(sudo -n grep -c '^#' "$D/server.properties")
echo "comment lines remaining: $CMT"
echo "--- do the decisive values still hold? ---"
for k in white-list enforce-whitelist online-mode level-name view-distance simulation-distance management-server-enabled; do
  printf '  %-28s %s\n' "$k" "$(sudo -n grep -m1 "^${k}=" "$D/server.properties" | cut -d= -f2-)"
done

echo "=== END ==="
