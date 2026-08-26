# test-console-injection.sh - can we reach the server console without RCON?
#
# Why not RCON: the password lives in server.properties, and D-0019 commits to
# never reading that file's secret values again.
#
# NOTE ON THE PREVIOUS VERSION, which reported a false pass: it used
#   BEFORE=$(sudo -n wc -l < "$L")
# where the REDIRECT is performed by the calling shell as ubuntu, which cannot
# read the file - so BEFORE was empty, the tail showed the whole log, and the grep
# matched old content. sudo applies to the command, never to the shell's
# redirection. This is the same class of bug as the bare [ -f ] in the installer.
#
# The probe is now "list", whose reply names the exact max-players value, so it
# cannot be confused with anything already in the log.

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
L="/var/lib/pelican/volumes/$V/logs/latest.log"

BEFORE=$(sudo -n wc -l "$L" | awk '{print $1}')
echo "log lines before: $BEFORE"

echo "=== process tree in the container: which PID is the JVM? ==="
sudo -n docker exec "$V" sh -c 'for p in /proc/[0-9]*; do pid=${p#/proc/}; cmd=$(tr "\0" " " < $p/cmdline 2>/dev/null | cut -c1-40); [ -n "$cmd" ] && echo "$pid $cmd"; done' 2>&1 | head -6

echo "=== sending 'list' to the JVM's OWN stdin (not tini's) ==="
# tini is PID 1 and does not forward stdin to the child, so /proc/1/fd/0 is the
# wrong target. Find the java process and write to its stdin directly.
JPID=$(sudo -n docker exec "$V" sh -c 'for p in /proc/[0-9]*; do pid=${p#/proc/}; if tr "\0" " " < $p/cmdline 2>/dev/null | grep -q "^java "; then echo $pid; break; fi; done' | tr -dc '0-9')
echo "java pid in container: ${JPID:-not found}"
if [ -n "$JPID" ]; then
  sudo -n docker exec "$V" sh -c "echo list > /proc/$JPID/fd/0" 2>&1 || echo "  injection failed"
else
  echo "  cannot locate the java process"
fi
sleep 4

echo "=== log lines added since ==="
sudo -n sed -n "$((BEFORE + 1)),\$p" "$L"

echo "=== verdict ==="
if sudo -n sed -n "$((BEFORE + 1)),\$p" "$L" | grep -qE 'players online|max of'; then
  echo "CONSOLE INJECTION WORKS"
else
  echo "NO RESPONSE - this channel does not work; spark would need RCON or the Panel"
fi
echo "=== END ==="
