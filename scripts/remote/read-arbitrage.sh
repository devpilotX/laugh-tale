V=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
sleep 40
echo "--- scheduler log ---"
sudo -n grep "season\|Season" /var/lib/pelican/volumes/$V/logs/latest.log | tail -4 || echo "none"
q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
echo "--- seasons now ---"
q "SELECT season_number, state, ends_at FROM seasons ORDER BY season_number;"
echo "--- scheduler audit ---"
q "SELECT action, parameters FROM staff_audit WHERE staff_name='SCHEDULER' ORDER BY id DESC LIMIT 3;"