# health-check.sh - READ ONLY. End-of-session state check (never-break rule 14:
# never leave the server in a broken state, and record what the state is).

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
L="/var/lib/pelican/volumes/$V/logs/latest.log"

echo "=== container ==="
sudo -n docker ps --filter "name=$V" --format '{{.Status}}'
echo "=== all containers ==="
sudo -n docker ps --format '{{.Names}}  {{.Status}}'
echo "=== database reachable? ==="
if sudo -n docker ps --format '{{.Names}}' | grep -qx laughtail-db; then
  sudo -n docker exec -u root laughtail-db sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "SELECT COUNT(*) AS migrations_applied FROM schema_migrations;"' 2>&1 | sed '/password on the command line/d'
else
  echo "(laughtail-db not running)"
fi
echo "=== cpu and memory of the game container ==="
sudo -n docker stats --no-stream --format 'cpu={{.CPUPerc}} mem={{.MemUsage}}' "$V"
echo "=== errors since boot (0 expected) ==="
sudo -n grep -cE 'ERROR|SEVERE' "$L"
echo "=== has anyone joined yet? ==="
sudo -n grep -cE 'joined the game' "$L"
echo "=== host memory ==="
free -m | head -2

echo "=== backups: is the last one recent and did it succeed? ==="
# There is no alerting channel yet (OA-16: no Discord webhook), so staleness has to
# be pulled rather than pushed. A silent backup failure is indistinguishable from
# success, which is the worst property a backup can have - so this compares the
# recorded finish time against now and says plainly whether it is late.
S=/home/ubuntu/laughtail-backups/last-status.json
if sudo -n test -f "$S"; then
  RESULT=$(sudo -n grep -o '"result": *"[^"]*"' "$S" | cut -d'"' -f4)
  EPOCH=$(sudo -n grep -o '"epoch": *[0-9]*' "$S" | tr -dc '0-9')
  AGE=$(( $(date -u +%s) - EPOCH ))
  echo "  last result: $RESULT"
  echo "  finished:    $(sudo -n grep -o '"finished_utc": *"[^"]*"' "$S" | cut -d'"' -f4)"
  echo "  age:         $((AGE / 60)) minutes"
  # The hourly database job runs at :17, so anything over 2 hours means a run was
  # missed rather than merely being between runs.
  if [ "$RESULT" != "ok" ]; then
    echo "  ALERT: the last backup did not report success"
  elif [ "$AGE" -gt 7200 ]; then
    echo "  ALERT: the last backup is over 2 hours old - an hourly run has been missed"
  else
    echo "  OK: recent and successful"
  fi
  echo "  archives on disk:"
  sudo -n ls -1 /home/ubuntu/laughtail-backups | grep -cE '^(world|db)-' | sed 's/^/    /'
  sudo -n du -sh /home/ubuntu/laughtail-backups | sed 's/^/    /'
else
  echo "  no status file - backup-run.sh has never completed"
fi

echo "=== is the schedule installed? ==="
if sudo -n test -f /etc/cron.d/laughtail-backup; then
  echo "  cron.d file present, mode $(sudo -n stat -c %a /etc/cron.d/laughtail-backup) (644 required or cron ignores it)"
  echo "  cron service: $(systemctl is-active cron 2>/dev/null || echo inactive)"
  echo "  recent cron log lines:"
  sudo -n tail -3 /var/log/laughtail-backup.log 2>/dev/null | sed 's/^/    /' || echo "    (log empty)"
else
  echo "  NOT SCHEDULED"
fi
echo "=== END ==="
