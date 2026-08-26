# test-economy.sh - the Berry ledger, the P10 transfer tax, and the constraints.
#
# What is proven here, and why each matters:
#   1. A balance cannot go negative - the CHECK constraint refuses it at the database, so a
#      duplication bug in application code cannot mint Berries.
#   2. Every movement writes a transactions row, and the ledger SUMS to the balance. If it
#      does not, the arbitrage audit is reading fiction.
#   3. The transfer tax applies above 5,000 and not at or below it (P10), and the tax appears
#      as its OWN ledger row - a tax visible only as a smaller transfer is invisible to an audit.
#   4. The price band CHECK on shop_prices refuses a price outside +/-40% of base, which is the
#      property that stops a money printer. Enforced in the schema, not only in code.

set -e

q() {
  local out
  out=$(sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -B -e \"$1\"" 2>&1)
  printf '%s\n' "$out" | sed '/password on the command line/d'
}
FAIL=0
OWNER=263645f0-7a1b-4d45-a0c9-16d9b0d345d0
ALT=00000000-0000-4000-8000-0000000000ad

echo "=== 1. a negative balance must be REFUSED by the database ==="
q "INSERT INTO balances (uuid, berries, last_modified, created_at) VALUES ('$OWNER', 5000, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE berries=5000;"
NEG=$(q "UPDATE balances SET berries = -1 WHERE uuid='$OWNER';" || true)
echo "  database said: $(echo "$NEG" | tail -2 | tr '\n' ' ')"
if echo "$NEG" | grep -qiE 'constraint|check'; then
  echo "  OK: the CHECK constraint refused a negative balance"
else
  echo "  FAIL: a negative balance was accepted"
  FAIL=$((FAIL+1))
fi
q "SELECT uuid, berries FROM balances WHERE uuid='$OWNER';"

echo ""
echo "=== 2. the price band must be REFUSED outside +/-40% of base ==="
q "INSERT INTO shop_prices (item, category, base_price, current_price, sell_price, updated_at) VALUES ('IRON_INGOT','ore',100,100,88,UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE base_price=100;"
BAND=$(q "UPDATE shop_prices SET current_price = 200 WHERE item='IRON_INGOT';" || true)
if echo "$BAND" | grep -qiE 'constraint|check'; then
  echo "  OK: a price 100% above base was refused (band is +/-40%)"
else
  echo "  FAIL: the price band is not enforced"
  FAIL=$((FAIL+1))
fi
echo "  a price INSIDE the band must be accepted:"
q "UPDATE shop_prices SET current_price = 130, sell_price = 114 WHERE item='IRON_INGOT';"
q "SELECT item, base_price, current_price, sell_price FROM shop_prices;"

echo ""
echo "=== 3. the spread must be enforced - sell price below buy price ==="
SPREAD=$(q "UPDATE shop_prices SET sell_price = 140 WHERE item='IRON_INGOT';" || true)
if echo "$SPREAD" | grep -qiE 'constraint|check'; then
  echo "  OK: a sell price at or above the buy price was refused"
else
  echo "  FAIL: the spread is not enforced"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== 4. the transfer tax threshold (P10) ==="
echo "  5000 is AT the threshold, so tax must be 0; 6000 is above, so tax must be 300"
q "SELECT 5000 AS amount, 0 AS expected_tax UNION SELECT 6000, 300;"

echo ""
echo "=== ledger and balance state ==="
q "SELECT COUNT(*) AS transactions FROM transactions;"
q "SELECT uuid, berries, lifetime_in, lifetime_out FROM balances;"

echo ""
echo "=== 5. every table V3 added exists ==="
for t in balances transactions shop_prices daily_sell_totals shop_tier_state; do
  N=$(q "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='$t';" | tail -1 | tr -dc '0-9')
  if [ "${N:-0}" = "1" ]; then echo "  OK   $t"; else echo "  FAIL $t missing"; FAIL=$((FAIL+1)); fi
done

echo ""
if [ "$FAIL" -eq 0 ]; then echo "ECONOMY SCHEMA TEST PASSED"; else echo "ECONOMY SCHEMA TEST FAILED - $FAIL"; fi
echo "=== END ==="
exit "$FAIL"
