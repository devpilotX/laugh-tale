# db-diagnose-auth.sh - READ ONLY. Why did the root connection fail?
#
# Three candidate causes, tested in order rather than guessed at:
#   1. `docker exec` runs as the image's USER (mysql, uid 999), which may not be
#      able to read a 0600 root-owned secrets file - giving an empty password.
#   2. The entrypoint's *_FILE handling strips the trailing newline while `cat`
#      inside my test did not, so the two strings differed.
#   3. root@localhost may be configured for unix_socket auth rather than password.

NAME=laughtail-db

echo "=== who does docker exec run as? ==="
sudo -n docker exec "$NAME" id

echo "=== can that user read the secrets? ==="
sudo -n docker exec "$NAME" sh -c 'ls -l /run/lt-secrets/ 2>&1; echo "--- read test ---"; wc -c < /run/lt-secrets/root_password 2>&1 || echo "CANNOT READ"'

echo "=== does the file have a trailing newline? (byte count only) ==="
sudo -n bash -c 'wc -c < /home/ubuntu/laughtail-db/secrets/root_password'
sudo -n bash -c 'tr -d "\n" < /home/ubuntu/laughtail-db/secrets/root_password | wc -c'

echo "=== how are the accounts actually configured? (as the OS mysql user, socket auth) ==="
sudo -n docker exec -u root "$NAME" sh -c 'mariadb --protocol=socket -u root -N -B -e "SELECT user, host, plugin FROM mysql.user;" 2>&1' | head -10

echo "=== try root WITH the password, as root inside the container ==="
sudo -n docker exec -u root "$NAME" sh -c 'mariadb -u root -p"$(cat /run/lt-secrets/root_password)" -N -B -e "SELECT 1 AS ok;" 2>&1' | head -3

echo "=== try the app user, which is what the migration runner will use ==="
sudo -n docker exec -u root "$NAME" sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" -D laughtail -N -B -e "SELECT 1 AS ok, DATABASE() AS db;" 2>&1' | head -3

echo "=== container health ==="
sudo -n docker ps --filter "name=$NAME" --format '{{.Status}}'
echo "=== END ==="
