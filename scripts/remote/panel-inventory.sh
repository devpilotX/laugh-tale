P=/var/www/pelican
echo "=== bulk-power help ==="
sudo -n bash -c "cd $P && php artisan help p:server:bulk-power" 2>&1 | head -30
echo "=== servers in the panel ==="
sudo -n bash -c "cd $P && php artisan tinker --execute='foreach(\App\Models\Server::all() as \$s){ echo \$s->id.\" | \".\$s->uuid.\" | \".\$s->name.\" | node=\".\$s->node_id.\" | mem=\".\$s->memory.\" | disk=\".\$s->disk.\" | cpu=\".\$s->cpu.PHP_EOL; }'" 2>&1 | tail -5
echo "=== allocations ==="
sudo -n bash -c "cd $P && php artisan tinker --execute='foreach(\App\Models\Allocation::all() as \$a){ echo \$a->id.\" | \".\$a->ip.\":\".\$a->port.\" | server=\".(\$a->server_id ?? \"free\").PHP_EOL; }'" 2>&1 | tail -5
echo "=== nodes ==="
sudo -n bash -c "cd $P && php artisan tinker --execute='foreach(\App\Models\Node::all() as \$n){ echo \$n->id.\" | \".\$n->name.\" | \".\$n->fqdn.\" | mem=\".\$n->memory.\" | overalloc=\".\$n->memory_overallocate.PHP_EOL; }'" 2>&1 | tail -5
echo "=== eggs ==="
sudo -n bash -c "cd $P && php artisan tinker --execute='foreach(\App\Models\Egg::all() as \$e){ echo \$e->id.\" | \".\$e->name.\" | \".\$e->uuid.PHP_EOL; }'" 2>&1 | tail -5
echo "=== END ==="
