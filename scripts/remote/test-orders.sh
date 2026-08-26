q() {
  sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'
}
FAIL=0
ok()  { echo "  OK: $1"; }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
A=263645f0-7a1b-4d45-a0c9-16d9b0d345d0
B=00000000-0000-4000-8000-0000000000f1

echo "=== setup ==="
q "INSERT INTO players (uuid, current_name, first_join, last_seen, created_at, updated_at) VALUES ('$B','TestPartner',UTC_TIMESTAMP(3),UTC_TIMESTAMP(3),UTC_TIMESTAMP(3),UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE current_name='TestPartner';" >/dev/null
q "DELETE FROM order_fills;" >/dev/null
q "DELETE FROM orders;" >/dev/null
echo "  clean book: $(q "SELECT COUNT(*) FROM orders;") orders, $(q "SELECT COUNT(*) FROM order_fills;") fills"

echo "=== 1. the schema refuses an order that oversells its own size ==="
q "INSERT INTO orders (player, side, material, unit_price, quantity, remaining, state, created_at, updated_at) VALUES ('$A','sell','RAW_IRON',20,10,10,'open',UTC_TIMESTAMP(3),UTC_TIMESTAMP(3));" >/dev/null
OVER=$(q "UPDATE orders SET remaining = 11 WHERE player='$A' AND material='RAW_IRON';" || true)
if echo "$OVER" | grep -qiE 'constraint|check'; then
  ok "remaining cannot exceed quantity: $(echo "$OVER" | tail -1 | cut -c1-70)"
else
  bad "an order was allowed to have more remaining than it ever ordered"
fi

echo "=== 2. a fill cannot reference an order that does not exist ==="
ORPHAN=$(q "INSERT INTO order_fills (buy_order_id, sell_order_id, material, quantity, unit_price, buyer, seller, occurred_at) VALUES (999999, 999998, 'RAW_IRON', 1, 20, '$A', '$B', UTC_TIMESTAMP(3));" || true)
if echo "$ORPHAN" | grep -qiE 'foreign key|constraint'; then
  ok "an orphan fill was REFUSED - a trade record cannot exist without its orders"
else
  bad "a fill referencing nonexistent orders was accepted"
fi

echo "=== 3. a fill of zero is refused ==="
ZERO=$(q "INSERT INTO order_fills (buy_order_id, sell_order_id, material, quantity, unit_price, buyer, seller, occurred_at) SELECT id, id, 'RAW_IRON', 0, 20, '$A', '$B', UTC_TIMESTAMP(3) FROM orders LIMIT 1;" || true)
if echo "$ZERO" | grep -qiE 'constraint|check'; then
  ok "a zero-quantity fill was refused"
else
  bad "a zero-quantity fill was accepted, which would be a trade that did not happen"
fi

echo "=== 4. escrow columns cannot go negative (they are UNSIGNED) ==="
NEG=$(q "UPDATE orders SET escrow_items = escrow_items - 100 WHERE player='$A' AND material='RAW_IRON';" || true)
if echo "$NEG" | grep -qiE 'out of range|constraint|BIGINT|INT'; then
  ok "escrow cannot underflow: $(echo "$NEG" | tail -1 | cut -c1-70)"
else
  bad "escrow was allowed to go negative, which would mint items"
fi

echo "=== 5. the matching index exists, so the book does not table-scan ==="
IDX=$(q "SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='orders' AND INDEX_NAME='idx_book';")
if [ "$IDX" -ge 5 ]; then
  ok "idx_book covers $IDX columns (material, side, state, price, created_at)"
else
  bad "idx_book has $IDX columns; matching would scan the whole table as the book grows"
fi

q "DELETE FROM orders WHERE player='$A' AND material='RAW_IRON';" >/dev/null
echo
if [ "$FAIL" -eq 0 ]; then echo "ORDER BOOK SCHEMA: all pass"; else echo "ORDER BOOK SCHEMA: $FAIL failure(s)"; exit 1; fi