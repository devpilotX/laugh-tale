BK="/home/ubuntu/laughtail-backups"
OUT=$(ls -1t "$BK"/prebuild-volume-*.tar.gz | head -1)
LIST=/tmp/lt-archive-list.txt
echo "archive: $OUT"

# Materialise the listing ONCE. Piping tar into grep -q makes grep exit early,
# which SIGPIPEs tar and, under pipefail, reports a false failure per lookup.
tar -tzf "$OUT" > "$LIST"
echo "total entries : $(wc -l < "$LIST")"
echo "world entries : $(grep -c '/world/' "$LIST" || true)"
echo "jar entries   : $(grep -c '[.]jar$' "$LIST" || true)"
echo "=== key files present in archive ==="
for f in server.properties eula.txt server.jar whitelist.json ops.json bukkit.yml spigot.yml; do
  if grep -q "/${f}\$" "$LIST"; then echo "  present: $f"; else echo "  MISSING: $f"; fi
done
echo "=== top-level entries in the archive ==="
sed 's|^[^/]*/||' "$LIST" | awk -F/ 'NF<=1 && $0!="" {print "  "$0}' | sort | head -30
rm -f "$LIST"
echo "=== END ==="
