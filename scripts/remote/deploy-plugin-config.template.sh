# deploy-plugin-config.sh - writes plugins/LaughTail/config.yml on the host.
#
# TWO PROBLEMS SOLVED HERE, and the first one is not obvious.
#
# 1. THE GAME CONTAINER CANNOT REACH THE DATABASE AS ORIGINALLY SET UP.
#    laughtail-db publishes 3306 on the HOST's 127.0.0.1 (D-0023, so it is invisible
#    externally). But the game server runs in a container on Pelican's own bridge -
#    a different network - and a container's 127.0.0.1 is its own loopback, not the
#    host's. Nothing about the config file would have revealed this; the plugin would
#    simply have failed to connect at runtime with a timeout.
#
#    The fix is to attach the database container to the same Docker network as the
#    game server and address it by its IP on that network. That keeps it off every
#    host interface - it is still not published anywhere reachable from outside, so
#    acceptance row 5 is unaffected - while making it reachable by exactly the one
#    container that needs it.
#
#    Rejected alternative: publishing on 0.0.0.0 or on the bridge gateway. Docker's
#    published ports bypass ufw entirely (proven earlier this session), so that would
#    put MariaDB on the public internet behind nothing but a password.
#
# 2. THE PASSWORD MUST NOT ENTER GIT. Same pattern as D-0014: the repository copy
#    carries the literal __PRESERVE__, and the value is read here from the root-only
#    secrets file and written straight into the deployed file. It is never printed.

set -e

V=$(sudo -n ls -1 /var/lib/pelican/volumes | head -1)
D="/var/lib/pelican/volumes/$V"
CFGDIR="$D/plugins/LaughTail"
SECRET=/home/ubuntu/laughtail-db/secrets/app_password
OWN=999:987

echo "=== which network is the game container on? ==="
NET=$(sudo -n docker inspect "$V" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
echo "game container network: $NET"
if [ -z "$NET" ]; then
  echo "ABORT: could not determine the game container's network"
  exit 2
fi

echo "=== is laughtail-db attached to it? ==="
DBNETS=$(sudo -n docker inspect laughtail-db --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
echo "db networks: $DBNETS"
if echo "$DBNETS" | grep -qw "$NET"; then
  echo "  already attached"
else
  echo "  attaching laughtail-db to $NET"
  sudo -n docker network connect "$NET" laughtail-db
  echo "  attached"
fi

DBIP=$(sudo -n docker inspect laughtail-db --format "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}")
echo "database address on $NET: $DBIP"
if [ -z "$DBIP" ]; then
  echo "ABORT: database has no address on $NET"
  exit 3
fi

echo "=== proving the game container can actually reach it ==="
# Testing this here rather than discovering it from a plugin timeout later. bash's
# /dev/tcp needs no tools installed in the container.
if sudo -n docker exec "$V" bash -c "timeout 5 bash -c '</dev/tcp/$DBIP/3306' 2>/dev/null"; then
  echo "  OK: the game container can open a TCP connection to $DBIP:3306"
else
  echo "  FAIL: the game container cannot reach $DBIP:3306 - the plugin would time out"
  exit 4
fi

echo "=== reading the app password (value never printed) ==="
if ! sudo -n test -s "$SECRET"; then
  echo "ABORT: $SECRET is missing or empty. Run db-up.sh."
  exit 5
fi
PW=$(sudo -n cat "$SECRET" | tr -d '\n')
echo "  password read (${#PW} chars)"

echo "=== writing config.yml ==="
sudo -n mkdir -p "$CFGDIR"

# Substituted with python rather than sed: the password is random base64-ish text and
# could contain characters sed would treat as delimiters or backreferences. python
# does a literal replacement and never re-interprets the value.
sudo -n tee /tmp/lt-cfg-src.yml > /dev/null <<'CFGEOF'
__CONFIG_TEMPLATE__
CFGEOF

PW="$PW" DBIP="$DBIP" sudo -n -E python3 - <<'PYEOF'
import os, re
src = open('/tmp/lt-cfg-src.yml', encoding='utf-8').read()
pw = os.environ['PW']

# ANCHORED SUBSTITUTION. The first version did a bare replace of the placeholder
# across the whole file, and the header comment quoted that token - so the real
# password was written into a COMMENT as well as into the value, and then printed
# past a redaction that only masked the "password:" line. See D-0026.
#
# Now: the password is substituted only where it appears as the VALUE of the
# password key, and only once. Everything else is left alone, so a token mentioned
# in prose is inert.
src, n = re.subn(
    r"(?m)^(\s*password:\s*)'[^']*'\s*$",
    lambda m: m.group(1) + "'" + pw + "'",
    src, count=1)
if n != 1:
    raise SystemExit('expected exactly one password key to substitute, found %d' % n)

src = src.replace('__DB_HOST__', os.environ['DBIP'])
if '__DB_HOST__' in src:
    raise SystemExit('host placeholder survived substitution')

# Belt and braces: the password must appear exactly once in the finished file.
if src.count(pw) != 1:
    raise SystemExit('password appears %d times in the output - refusing to install'
                     % src.count(pw))

open('/tmp/lt-cfg-out.yml', 'w', encoding='utf-8').write(src)
print('substituted (password appears exactly once, on the password key)')
PYEOF

sudo -n cp /tmp/lt-cfg-out.yml "$CFGDIR/config.yml"
sudo -n chown $OWN "$CFGDIR/config.yml"
# 640, not 644: this file contains a database password. The container user needs to
# read it; nothing else does.
sudo -n chmod 640 "$CFGDIR/config.yml"
sudo -n rm -f /tmp/lt-cfg-src.yml /tmp/lt-cfg-out.yml

echo "=== installed ==="
sudo -n stat -c '  %n owner=%u:%g mode=%a size=%s' "$CFGDIR/config.yml"

# THE FILE IS NOT PRINTED, not even redacted. The previous version echoed it through
# a sed that masked only the "password:" line, which is why a password substituted
# into a comment sailed straight through (D-0026). Verifying properties is safer than
# displaying content and trusting a filter: a redaction that has to be right about
# every line will eventually be wrong about one.
echo "=== verified by property, without displaying the file ==="
echo "  lines:                 $(sudo -n wc -l "$CFGDIR/config.yml" | awk '{print $1}')"
echo "  host set to:           $(sudo -n grep -m1 '^  host:' "$CFGDIR/config.yml" | cut -d: -f2- | tr -d " '")"
echo "  schema:                $(sudo -n grep -m1 '^  schema:' "$CFGDIR/config.yml" | cut -d: -f2- | tr -d ' ')"
echo "  user:                  $(sudo -n grep -m1 '^  user:' "$CFGDIR/config.yml" | cut -d: -f2- | tr -d ' ')"
RULESVER=$(sudo -n grep -m1 '^  version:' "$CFGDIR/config.yml" | cut -d: -f2- | tr -d " '")
echo "  rules version:         $RULESVER"
PWLEN=$(sudo -n grep -m1 '^  password:' "$CFGDIR/config.yml" | sed -E "s/^  password:[[:space:]]*'([^']*)'.*/\1/" | tr -d '\n' | wc -c)
echo "  password length:       $PWLEN chars (value never displayed)"
echo "  password occurrences:  1 expected - checked during substitution"

echo "=== no placeholder may survive ==="
if sudo -n grep -q '__PRESERVE__\|__DB_HOST__' "$CFGDIR/config.yml"; then
  echo "FAIL: placeholder present"
  exit 6
fi
echo "none"
echo "PLUGIN CONFIG DEPLOYED"
echo "=== END ==="
