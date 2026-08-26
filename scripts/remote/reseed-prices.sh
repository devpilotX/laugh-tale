q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
# The repair pass only ever LOWERS a price, and it writes base_price. Prices lowered under the old block
# pricing would stay low forever, so the table is cleared and reseeded from the corrected catalogue.
# Safe because shop_prices is derived data - the catalogue in the jar is the source of truth.
echo "before: $(q "SELECT COUNT(*) FROM shop_prices;") rows"
q "DELETE FROM shop_prices;" >/dev/null
echo "after clear: $(q "SELECT COUNT(*) FROM shop_prices;") rows"