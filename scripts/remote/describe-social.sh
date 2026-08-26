q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
echo "--- seasons ---"
q "SELECT season_number, state, starts_at, ends_at FROM seasons ORDER BY season_number;"
echo "--- scheduler audit rows ---"
q "SELECT action, parameters, occurred_at FROM staff_audit WHERE staff_name='SCHEDULER' ORDER BY id DESC LIMIT 5;"