# panel-fix-server-record.sh - writes four fields on the Panel's server record.
#
# Uses the application's own Eloquent models via tinker, never raw SQL against
# database.sqlite. That distinction matters: the models handle casts, timestamps
# and any encrypted attribute correctly, and hand-editing the Panel database is
# the exact class of change that breaks a Panel silently (the trap spec 33.1
# warns about, and the reason decision D-0012 refused that route).
#
# All four changes are single scalar fields. Every previous value is printed
# before it is overwritten, so reverting is copy and paste.
#
# WHAT IS BEING FIXED, AND WHY EACH ONE MATTERS
#
# 1. name: "Laugh Tale" -> "laughtail-dev"
#    Pre-flight 33.6 items 9 and 10 require a server named laughtail-dev with its
#    own allocation and a heap 25% below it. This server already has the right
#    allocation, the pinned Paper, and our config. Renaming satisfies both items
#    without creating a second server - which matters on a 3.8 GB box, because a
#    second 2.8 GB allocation cannot coexist with this one. AGENTS.md names the dev
#    server, so this is a specified name, not a guessed one.
#
# 2. startup heap: -Xms768M -Xmx2304M -> -Xms2048M -Xmx2048M
#    NEVER-BREAK RULE 4 IS CURRENTLY VIOLATED. The rule says leave at least 25% or
#    768 MB outside the heap. The Panel allocation is 2816 MiB, and 2816 - 2304 =
#    512 MiB = 18.2%. That fails both tests.
#    Session 1 recorded this as "25.6%, satisfied but only just" by measuring
#    against the CONTAINER limit of 3097 MiB. That number is the allocation plus
#    Pelican's own 10% overhead - it is the JVM's non-heap working room, not
#    headroom we are entitled to spend. The honest denominator is 2816.
#    2048 leaves 768 MiB = 27.3%, which passes both tests.
#    Xms is set equal to Xmx because this startup line already uses Aikar's flags,
#    which require it, and because AlwaysPreTouch with Xms=Xmx makes the footprint
#    predictable at boot instead of growing into a box that has no room to grow.
#
# 3. swap: 512 -> 0
#    Deviation D7. With swap available the JVM can swap, and swap on a 20 TPS
#    server turns a memory spike into a multi-second freeze. Law 8 prefers a loud
#    failure to a slow one: with swap 0 the container OOMs cleanly instead.
#
# 4. MINECRAFT_VERSION 26.2 -> 1.21.11, BUILD_NUMBER latest -> 132
#    The egg's install script downloads from fill.papermc.io using these two
#    variables. It runs on install and reinstall, not on boot - so nothing is
#    wrong today. But anyone clicking "Reinstall" would fetch the latest 26.2
#    build, overwrite the pinned jar, and break a world and config built for
#    1.21.11. Never-break rule 9 and Section 29: the runtime must be reproducible
#    from pinned values, so a reinstall should rebuild exactly what the manifest
#    says. "latest" is precisely the floating tag spec 4.2 forbids.
#
# Changes to memory and startup take effect when Wings next recreates the
# container, so the server must be restarted afterwards for 2, 3 and 4 to apply.

set -e

cat > /tmp/lt-panel-fix.php <<'PHP'
$s = App\Models\Server::find(1);
if (!$s) { echo 'ABORT: no server id 1' . PHP_EOL; exit(1); }

echo '--- BEFORE (record these to revert) ---' . PHP_EOL;
echo 'name    = ' . $s->name . PHP_EOL;
echo 'memory  = ' . $s->memory . PHP_EOL;
echo 'swap    = ' . $s->swap . PHP_EOL;
echo 'startup = ' . $s->startup . PHP_EOL;

$old = $s->startup;
$new = str_replace('-Xms768M -Xmx2304M', '-Xms2048M -Xmx2048M', $old);

if ($new === $old) {
    echo 'NOTE: heap flags were not the expected -Xms768M -Xmx2304M, leaving startup untouched.' . PHP_EOL;
} else {
    $s->startup = $new;
}

$s->name = 'laughtail-dev';
$s->swap = 0;
$s->save();

echo '--- AFTER ---' . PHP_EOL;
$s->refresh();
echo 'name    = ' . $s->name . PHP_EOL;
echo 'memory  = ' . $s->memory . PHP_EOL;
echo 'swap    = ' . $s->swap . PHP_EOL;
echo 'startup = ' . $s->startup . PHP_EOL;

echo '--- rule 4 arithmetic, against the ALLOCATION not the container limit ---' . PHP_EOL;
preg_match('/-Xmx(\d+)M/', $s->startup, $m);
$xmx = (int) $m[1];
$alloc = (int) $s->memory;
$outside = $alloc - $xmx;
$pct = round($outside * 100 / $alloc, 1);
echo "allocation={$alloc} MiB  xmx={$xmx} MiB  outside={$outside} MiB ({$pct}%)" . PHP_EOL;
echo 'rule 4 needs 25% OR 768 MB outside the heap: ';
echo (($pct >= 25.0) || ($outside >= 768)) ? 'PASS' : 'FAIL';
echo PHP_EOL;

echo '--- pinning the egg variables so a reinstall reproduces the manifest ---' . PHP_EOL;
foreach (App\Models\ServerVariable::all() as $v) {
    $name = optional($v->variable)->env_variable;
    if ($name === 'MINECRAFT_VERSION') {
        echo "MINECRAFT_VERSION: {$v->variable_value} -> 1.21.11" . PHP_EOL;
        $v->variable_value = '1.21.11';
        $v->save();
    } elseif ($name === 'BUILD_NUMBER') {
        echo "BUILD_NUMBER: {$v->variable_value} -> 132" . PHP_EOL;
        $v->variable_value = '132';
        $v->save();
    }
}

echo '--- egg variables now ---' . PHP_EOL;
foreach (App\Models\ServerVariable::all() as $v) {
    echo optional($v->variable)->env_variable . ' = ' . $v->variable_value . PHP_EOL;
}
echo 'PANEL RECORD UPDATED' . PHP_EOL;
PHP

sudo -n bash -c 'cd /var/www/pelican && php artisan tinker --execute="$(cat /tmp/lt-panel-fix.php)"' 2>&1 | grep -vE '^\s*$'

rm -f /tmp/lt-panel-fix.php
echo "=== END ==="
