# read-monitor-state.sh - READ ONLY. Shows what the monitor has recorded.
S=/home/ubuntu/laughtail-monitor
echo "=== last sample ==="
sudo -n cat "$S/last-sample.json" 2>/dev/null || echo "(none)"
echo "=== alerts recorded ==="
sudo -n tail -20 "$S/alerts.log" 2>/dev/null || echo "(no alerts ever)"
echo "=== history (last 8 samples) ==="
sudo -n tail -8 "$S/history.csv" 2>/dev/null || echo "(no history)"
echo "=== cron entries for laughtail ==="
sudo -n ls -l /etc/cron.d/ | grep laughtail
echo "=== END ==="
