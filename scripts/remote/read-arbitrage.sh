q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
V=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
sleep 25
echo "--- seeding log ---"
sudo -n grep "Chronicle" /var/lib/pelican/volumes/$V/logs/latest.log | tail -3 || echo "none"
echo "--- chapters ---"
q "SELECT chapter, title, state FROM chronicle_chapters ORDER BY chapter;"
echo "--- active chapter objectives ---"
q "SELECT o.description, o.metric, o.target, o.progress FROM chronicle_objectives o JOIN chronicle_chapters c ON c.id=o.chapter_id WHERE c.state='active';"