# panel-repin-egg.sh - re-pins the egg variables after the version move.
#
# D-0022 pinned these to 1.21.11 / build 132 so a Reinstall would reproduce the
# manifest rather than fetching "latest". The manifest has moved to 26.2 / 119, so
# these must move with it - otherwise a Reinstall would now rebuild the OLD version
# and silently contradict the manifest, which is the same trap D-0022 closed.

set -e

cat > /tmp/lt-repin.php <<'PHP'
$want = ['MINECRAFT_VERSION' => '26.2', 'BUILD_NUMBER' => '119'];
foreach (App\Models\ServerVariable::all() as $v) {
    $name = optional($v->variable)->env_variable;
    if (isset($want[$name])) {
        echo $name . ': ' . $v->variable_value . ' -> ' . $want[$name] . PHP_EOL;
        $v->variable_value = $want[$name];
        $v->save();
    }
}
echo '--- egg variables now ---' . PHP_EOL;
foreach (App\Models\ServerVariable::all() as $v) {
    echo optional($v->variable)->env_variable . ' = ' . $v->variable_value . PHP_EOL;
}
PHP

sudo -n bash -c 'cd /var/www/pelican && php artisan tinker --execute="$(cat /tmp/lt-repin.php)"' 2>&1 | grep -vE '^\s*$'
rm -f /tmp/lt-repin.php
echo "=== END ==="
