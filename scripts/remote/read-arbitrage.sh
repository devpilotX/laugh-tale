V=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
sleep 45
echo "--- scheduler and chronicle log ---"
sudo -n grep "season\|Season\|Chronicle" /var/lib/pelican/volumes/$V/logs/latest.log | tail -4
echo "--- seasons ---"
q "SELECT season_number, state, starts_at, ends_at FROM seasons;"
echo "--- chronicle ---"
q "SELECT chapter, title, state FROM chronicle_chapters ORDER BY chapter;"
echo "--- audit ---"
q "SELECT action, parameters FROM staff_audit WHERE staff_name='SCHEDULER' ORDER BY id DESC LIMIT 2;"