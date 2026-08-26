V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
sleep 12
sudo -n grep "Price repair\|ARBITRAGE\|catalogue priced" /var/lib/pelican/volumes/$V/logs/latest.log | tail -4
q() { sudo -n docker exec -u root laughtail-db sh -c "mariadb -u laughtail -p\"\$(cat /run/lt-secrets/app_password)\" -D laughtail -N -B -e \"$1\"" 2>&1 | sed '/password on the command line/d'; }
echo "=== the prices players will notice ==="
q "SELECT item, current_price, sell_price FROM shop_prices WHERE item IN ('COBBLESTONE','OAK_LOG','COAL','WHEAT','IRON_INGOT','GOLD_INGOT','REDSTONE','DIAMOND','EMERALD','OBSIDIAN','DIAMOND_BLOCK','SHULKER_SHELL','ECHO_SHARD','ANCIENT_DEBRIS','NETHERITE_INGOT','ELYTRA','BEACON','NETHER_STAR','DRAGON_EGG','NETHERITE_BLOCK') ORDER BY base_price;" | awk -F'\t' '{printf "  %-18s buy %-7s sell %s\n",$1,$2,$3}'