# verify-heap-and-swap.sh - READ ONLY. Never-break rule 4 and deviation D7.
#
# The Panel record is an intention. This reads what the CONTAINER and the JVM
# actually got, because Wings only applies memory and startup changes when it
# recreates the container - so a Panel edit without a restart proves nothing.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)

echo "=== the JVM command line as the kernel sees it ==="
sudo -n docker top "$V" 2>/dev/null | grep -o '\-Xms[0-9]*M \-Xmx[0-9]*M' | head -1

echo "=== container limits ==="
MEM=$(sudo -n docker inspect "$V" --format '{{.HostConfig.Memory}}')
SWP=$(sudo -n docker inspect "$V" --format '{{.HostConfig.MemorySwap}}')
echo "Memory      = $MEM bytes = $((MEM / 1024 / 1024)) MiB"
echo "MemorySwap  = $SWP bytes = $((SWP / 1024 / 1024)) MiB"
if [ "$MEM" = "$SWP" ]; then
  echo "  D7 PASS: MemorySwap equals Memory, so the JVM cannot swap. It will OOM"
  echo "           cleanly instead of stalling for seconds (Law 8: fail loud)."
else
  echo "  D7 FAIL: the JVM can still swap ($(( (SWP - MEM) / 1024 / 1024 )) MiB of swap reachable)."
fi

echo "=== rule 4 arithmetic against the PANEL ALLOCATION ==="
ALLOC=$(sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"echo App\\Models\\Server::find(1)->memory;\"" 2>/dev/null | tr -dc '0-9')
XMX=$(sudo -n docker top "$V" 2>/dev/null | grep -o '\-Xmx[0-9]*M' | head -1 | tr -dc '0-9')
echo "allocation = ${ALLOC} MiB"
echo "xmx        = ${XMX} MiB"
if [ -n "$ALLOC" ] && [ -n "$XMX" ]; then
  OUT=$((ALLOC - XMX))
  PCT=$((OUT * 100 / ALLOC))
  echo "outside heap = ${OUT} MiB (${PCT}%)"
  if [ "$PCT" -ge 25 ] || [ "$OUT" -ge 768 ]; then
    echo "  RULE 4 PASS (needs 25% or 768 MB outside the heap)"
  else
    echo "  RULE 4 FAIL"
  fi
fi

echo "=== actual container memory use right now ==="
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}} ({{.MemPerc}})' "$V"

echo "=== host memory, and is any swap in use? ==="
free -m

echo "=== panel record name (pre-flight 33.6 item 9) ==="
sudo -n bash -c "cd /var/www/pelican && php artisan tinker --execute=\"echo App\\Models\\Server::find(1)->name;\"" 2>/dev/null | tail -1

echo "=== errors this boot ==="
sudo -n grep -cE 'ERROR|SEVERE' "/var/lib/pelican/volumes/$V/logs/latest.log"
echo "=== END ==="
