V=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
L=/var/lib/pelican/volumes/$V/logs/latest.log
echo "--- row 25 boot evidence ---"
N=$(sudo -n grep -c "Row 25" "$L" || true)
echo "matches: $N"
sudo -n grep "Row 25\|ROW 25" "$L" | tail -3 || echo "ABSENT"