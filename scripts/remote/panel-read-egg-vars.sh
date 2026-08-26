# panel-read-egg-vars.sh - READ ONLY.
#
# variable_id 1, 3 and 4 hold "latest", "26.2" and "server.jar". Guessing which is
# which and writing to the wrong one is how a Panel gets broken quietly, so the
# names are read first.

echo "=== egg variables: id, name, env var, rules, default ==="
sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"
foreach (\\App\\Models\\EggVariable::all() as \\\$v) {
  echo \\\$v->id . ' | ' . \\\$v->name . ' | ' . \\\$v->env_variable . ' | ' . \\\$v->rules . ' | default=' . \\\$v->default_value . PHP_EOL;
}
\" 2>&1 | tail -20"

echo "=== the egg itself: does its install script download on every boot? ==="
sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"
\\\$e = \\App\\Models\\Egg::find(1);
echo 'name=' . \\\$e->name . PHP_EOL;
echo 'update_url=' . var_export(\\\$e->update_url, true) . PHP_EOL;
echo '--- install script, first 40 lines ---' . PHP_EOL;
echo implode(PHP_EOL, array_slice(explode(PHP_EOL, \\\$e->script_install), 0, 40));
\" 2>&1 | tail -50"

echo "=== END ==="
