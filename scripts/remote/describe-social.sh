q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
echo "--- tables with a season_number column ---"
q "SELECT TABLE_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND COLUMN_NAME='season_number' ORDER BY TABLE_NAME;"
echo "--- foreign keys pointing at seasons ---"
q "SELECT TABLE_NAME, CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA='laughtail' AND REFERENCED_TABLE_NAME='seasons';"
echo "--- current row counts ---"
q "SELECT CONCAT('seasons=',(SELECT COUNT(*) FROM seasons),' ratings=',(SELECT COUNT(*) FROM combat_ratings),' champions=',(SELECT COUNT(*) FROM champions),' house_standing=',(SELECT COUNT(*) FROM house_standing),' chapters=',(SELECT COUNT(*) FROM chronicle_chapters),' objectives=',(SELECT COUNT(*) FROM chronicle_objectives),' titles=',(SELECT COUNT(*) FROM titles_owned));"
echo "--- seasons ---"
q "SELECT season_number, state FROM seasons ORDER BY season_number;"