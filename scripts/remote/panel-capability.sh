P=/var/www/pelican
echo "=== dir perms ==="
sudo -n stat -c '%U:%G %a %n' "$P" 2>/dev/null
echo "=== panel version ==="
sudo -n bash -c "cd $P && php artisan --version" 2>&1 | head -3
echo "=== p: namespace commands ==="
sudo -n bash -c "cd $P && php artisan list --raw" 2>/dev/null | grep -E '^p:' || echo "(no p: namespace)"
echo "=== users ==="
sudo -n bash -c "cd $P && php artisan p:user:list" 2>&1 | head -15
echo "=== db config ==="
sudo -n grep -E '^(DB_CONNECTION|DB_DATABASE|DB_HOST|APP_URL|APP_ENV|APP_DEBUG)=' "$P/.env" 2>/dev/null
echo "=== sqlite present ==="
sudo -n ls -la "$P/database" 2>/dev/null | grep -i sqlite || echo "(no sqlite file)"
echo "=== node + allocation count via tinker-free query ==="
sudo -n bash -c "cd $P && php artisan tinker --execute='echo \"nodes=\".\App\Models\Node::count().\" servers=\".\App\Models\Server::count().\" allocations=\".\App\Models\Allocation::count().\" eggs=\".\App\Models\Egg::count().\" users=\".\App\Models\User::count();'" 2>&1 | tail -3
echo "=== END ==="
