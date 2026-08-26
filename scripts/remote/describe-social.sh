q() {
  sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'
}
echo "=== players.uuid definition ==="
q "SELECT COLUMN_NAME, COLUMN_TYPE, CHARACTER_SET_NAME, COLLATION_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='players' AND COLUMN_NAME='uuid';"
echo "=== how an existing table declares its FK column (homes) ==="
q "SELECT COLUMN_NAME, COLUMN_TYPE, CHARACTER_SET_NAME, COLLATION_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='homes' AND COLUMN_NAME='uuid';"