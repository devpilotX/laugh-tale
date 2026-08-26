V=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
L=/var/lib/pelican/volumes/$V/logs/latest.log
sleep 6
echo "--- arbitrage verdict ---"
sudo -n grep "ARBITRAGE\|Shop catalogue priced\|Row 25" "$L" | tail -6 || echo "ABSENT"