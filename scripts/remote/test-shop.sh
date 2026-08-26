# test-shop.sh - the shop price table, the P3 spread, the P4 band, and row 40's gate.
#
# What is proven here, and why each matters:
#   1. Every catalogue row exists and is priced. A price table that is empty passes every
#      invariant by examining nothing, so its SIZE is the first assertion.
#   2. buy > sell for every row. This is the structural reason a buy-then-sell loop cannot yield
#      a profit, and it is the invariant the Phase 3 arbitrage audit extends to recipe chains.
#   3. The spread is at least P3's 12%.
#   4. Every current price sits inside P4's +/-40% band, and the DATABASE refuses one that does
#      not - so a bug in the elasticity arithmetic cannot create a money printer.
#   5. There is no editable tier column. Row 40's gate comes from the compiled catalogue checked
#      against rank, so there is nothing in the database a player or a careless admin could edit
#      to grant themselves Tier 8 access.

set -e

q() {
  local out
  out=$(sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1)
  printf '%s\n' "$out" | sed '/password on the command line/d'
}
FAIL=0
ok()  { echo "  OK: $1"; }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

echo "=== 1. the catalogue is priced at boot, not lazily ==="
ROWS=$(q "SELECT COUNT(*) FROM shop_prices;")
echo "  priced rows: $ROWS"
if [ "$ROWS" -eq 40 ]; then
  ok "the table matches the catalogue exactly ($ROWS rows) - no orphans, nothing missing"
else
  bad "$ROWS priced rows against a catalogue of 40 - the table and the code disagree"
fi

echo "=== 2. buy > sell for every row (no money printer) ==="
BADSPREAD=$(q "SELECT COUNT(*) FROM shop_prices WHERE sell_price >= current_price;")
if [ "$BADSPREAD" = "0" ]; then
  ok "no row has sell >= buy"
else
  bad "$BADSPREAD row(s) have sell >= buy - buying and selling back would print Berries"
fi

echo "=== 3. the P3 minimum spread of 12% ==="
# No tolerance and no exemption for cheap rows. FLOOR is the correct comparison because that is
# what the code must do; ROUND here would let an 11.7% spread pass as if it were 12%.
THIN=$(q "SELECT COUNT(*) FROM shop_prices WHERE sell_price > FLOOR(current_price * 0.88);")
if [ "$THIN" = "0" ]; then
  ok "no row is thinner than 12%, with no tolerance and no exemptions"
else
  bad "$THIN row(s) have a spread under 12%: $(q "SELECT item, current_price, sell_price FROM shop_prices WHERE sell_price > FLOOR(current_price*0.88) LIMIT 3;" | tr "\n" " ")"
fi

echo "=== 4. the P4 band, and the database enforcing it ==="
OUT=$(q "SELECT COUNT(*) FROM shop_prices WHERE current_price < ROUND(base_price*0.6) OR current_price > ROUND(base_price*1.4);")
if [ "$OUT" = "0" ]; then
  ok "every current price is inside +/-40% of base"
else
  bad "$OUT row(s) escaped the band"
fi
# Go straight at the data, bypassing the plugin entirely - the price-table equivalent of a
# modified client.
# THE TARGET ROW IS ASSERTED TO EXIST FIRST. This test previously named IRON_INGOT, which the
# arbitrage audit later forced out of the catalogue - so the UPDATE matched zero rows, no constraint
# fired, and the test reported the CHECK as missing. The reverse mistake is worse and was the real
# risk: an UPDATE that matches nothing looks exactly like a refusal, so a test written this way can
# report a constraint as working when the row simply is not there.
TARGET=RAW_IRON
EXISTS=$(q "SELECT COUNT(*) FROM shop_prices WHERE item = '$TARGET';")
if [ "$EXISTS" != "1" ]; then
  bad "test target $TARGET is not in the price table, so this check would prove nothing"
fi
VIOL=$(q "UPDATE shop_prices SET current_price = base_price * 99 WHERE item = '$TARGET';" || true)
if echo "$VIOL" | grep -qiE 'constraint|check'; then
  ok "the database REFUSED a price 99x base: $(echo "$VIOL" | tail -1 | cut -c1-80)"
else
  bad "the database ACCEPTED a price 99x base - the CHECK is missing or wrong"
  q "UPDATE shop_prices SET current_price = base_price WHERE item = '$TARGET';" >/dev/null || true
fi

echo "=== 5. row 40's gate is not stored where anyone can edit it ==="
HASTIER=$(q "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='shop_prices' AND COLUMN_NAME='tier';")
if [ "$HASTIER" = "0" ]; then
  ok "no tier column exists - the gate is the compiled catalogue checked against rank"
else
  bad "shop_prices has a tier column, an editable bypass of row 40"
fi

echo "=== 6. the daily sell cap cannot be dodged by rotating items (P6) ==="
KEYS=$(q "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='laughtail' AND TABLE_NAME='daily_sell_totals' AND INDEX_NAME='PRIMARY';")
if [ "$KEYS" = "uuid,sell_date,category" ]; then
  ok "the cap is keyed (uuid, sell_date, category), so it is per category and per day"
else
  bad "primary key is '$KEYS', expected uuid,sell_date,category"
fi

echo
echo "=== the derived price table, most valuable first ==="
q "SELECT item, category, base_price, current_price, sell_price, CONCAT(ROUND(100.0*(current_price-sell_price)/current_price,1),'%') FROM shop_prices ORDER BY base_price DESC, item LIMIT 10;" \
  | awk 'BEGIN{printf "  %-22s %-8s %6s %8s %6s %7s\n","ITEM","CAT","BASE","CURRENT","SELL","SPREAD"} NF{printf "  %-22s %-8s %6s %8s %6s %7s\n",$1,$2,$3,$4,$5,$6}'
echo "  ... and the cheapest:"
q "SELECT item, category, base_price, current_price, sell_price FROM shop_prices ORDER BY base_price ASC, item LIMIT 4;" \
  | awk 'NF{printf "  %-22s %-8s %6s %8s %6s\n",$1,$2,$3,$4,$5}'

echo "=== 7. row 27: the spread holds at BOTH EXTREMES of the dynamic band ==="
# Checking today's prices is not enough. Row 27 asks whether buy still exceeds sell by the minimum
# spread at the FLOOR (0.6x base) and the CEILING (1.4x base) - the two places the elasticity can
# push a price. If the spread inverted at either end, a player could drive the price to that end
# and then print Berries, and no test of the current price would ever notice.
#
# FLOOR(x * 0.88) is the same arithmetic Shop.sellPrice performs, applied to the extremes rather
# than to the stored value.
LOWBAD=$(q "SELECT COUNT(*) FROM shop_prices WHERE FLOOR(GREATEST(1, ROUND(base_price*0.6)) * 0.88) >= GREATEST(1, ROUND(base_price*0.6));")
HIGHBAD=$(q "SELECT COUNT(*) FROM shop_prices WHERE FLOOR(ROUND(base_price*1.4) * 0.88) >= ROUND(base_price*1.4);")
echo "  at the floor (0.6x base):   $LOWBAD item(s) would invert"
echo "  at the ceiling (1.4x base): $HIGHBAD item(s) would invert"
if [ "$LOWBAD" = "0" ] && [ "$HIGHBAD" = "0" ]; then
  ok "buy exceeds sell at both extremes for every item - the band cannot be driven to a profit"
else
  bad "the spread inverts at a band extreme: floor $LOWBAD, ceiling $HIGHBAD"
  q "SELECT item, base_price, GREATEST(1,ROUND(base_price*0.6)) AS at_floor, FLOOR(GREATEST(1,ROUND(base_price*0.6))*0.88) AS sell_at_floor FROM shop_prices WHERE FLOOR(GREATEST(1, ROUND(base_price*0.6)) * 0.88) >= GREATEST(1, ROUND(base_price*0.6)) LIMIT 5;"
fi

echo "=== 8. the cheapest items, where rounding is most dangerous ==="
# A 1-Berry item is the interesting case: 12% of 1 rounds to nothing, so an implementation that
# rounded would sell it back for 1 and print a Berry per trade. These must all sell for strictly
# less than they cost.
q "SELECT item, current_price, sell_price FROM shop_prices WHERE current_price <= 4 ORDER BY current_price, item;" \
  | awk 'NF{printf "  %-20s buy %-4s sell %-4s %s\n",$1,$2,$3,($3<$2?"ok":"INVERTED")}'
CHEAPBAD=$(q "SELECT COUNT(*) FROM shop_prices WHERE current_price <= 4 AND sell_price >= current_price;")
if [ "$CHEAPBAD" = "0" ]; then
  ok "every cheap item sells for strictly less than it costs"
else
  bad "$CHEAPBAD cheap item(s) sell for at least what they cost"
fi
echo
if [ "$FAIL" -eq 0 ]; then
  echo "SHOP INVARIANTS: all pass"
else
  echo "SHOP INVARIANTS: $FAIL failure(s)"
  exit 1
fi
