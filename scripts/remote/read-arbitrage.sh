V=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
L=/var/lib/pelican/volumes/$V/logs/latest.log
sleep 8
echo "--- boot self-tests ---"
sudo -n grep "SELF-TEST\|ARBITRAGE\|Row 25" "$L" | tail -8 || echo "ABSENT"
echo "--- did the rollback leave anything behind? ---"
sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"SELECT CONCAT('orders=', (SELECT COUNT(*) FROM orders), ' fills=', (SELECT COUNT(*) FROM order_fills));\"" 2>&1 | sed '/password on the command line/d'