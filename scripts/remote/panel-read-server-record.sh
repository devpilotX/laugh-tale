# panel-read-server-record.sh - READ ONLY. Reads, changes nothing.
#
# Goal: find the least dangerous route to satisfying pre-flight 33.6 items 9 and
# 10 ("laughtail-dev exists with its own allocation, heap 25% below it").
#
# Decision D-0012 established that Pelican has no `p:server:make`, so a server
# cannot be CREATED over SSH. But the box already has exactly one server, which
# now runs pinned Paper with our config, at the right allocation and heap. If it
# can be RENAMED, that satisfies items 9 and 10 without creating anything, without
# a second allocation, and without duplicating 3 GB of allocation on a 3.8 GB box.
#
# This script establishes whether that route exists and what the record looks like.

echo "=== is tinker available? (the only scriptable write path to a Panel model) ==="
sudo -n bash -c "cd /var/www/pelican && php artisan list 2>/dev/null | grep -iE '^\s*(tinker|db)' " || echo "(no tinker/db commands)"

echo "=== does the panel use sqlite, and where? ==="
sudo -n grep -E '^DB_CONNECTION|^DB_DATABASE' /var/www/pelican/.env 2>/dev/null || echo "(cannot read DB_ keys)"

echo "=== the server record, via the app's own models (read-only) ==="
sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"
\\\$s = \\App\\Models\\Server::first();
if (!\\\$s) { echo 'NO SERVER FOUND'; }
else {
  echo 'id=' . \\\$s->id . PHP_EOL;
  echo 'uuid=' . \\\$s->uuid . PHP_EOL;
  echo 'name=' . \\\$s->name . PHP_EOL;
  echo 'memory=' . \\\$s->memory . PHP_EOL;
  echo 'swap=' . \\\$s->swap . PHP_EOL;
  echo 'cpu=' . \\\$s->cpu . PHP_EOL;
  echo 'disk=' . \\\$s->disk . PHP_EOL;
  echo 'egg_id=' . \\\$s->egg_id . PHP_EOL;
  echo 'startup=' . \\\$s->startup . PHP_EOL;
  echo 'image=' . \\\$s->image . PHP_EOL;
}
\" 2>&1 | tail -20"

echo "=== allocations ==="
sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"
foreach (\\App\\Models\\Allocation::all() as \\\$a) {
  echo \\\$a->id . ' ' . \\\$a->ip . ':' . \\\$a->port . ' server_id=' . var_export(\\\$a->server_id, true) . PHP_EOL;
}
\" 2>&1 | tail -10"

echo "=== egg variables that decide the startup jar and heap ==="
sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"
foreach (\\App\\Models\\ServerVariable::all() as \\\$v) {
  echo \\\$v->variable_id . ' => ' . \\\$v->variable_value . PHP_EOL;
}
\" 2>&1 | tail -15"

echo "=== END ==="
