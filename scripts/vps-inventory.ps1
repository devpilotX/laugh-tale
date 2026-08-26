# vps-inventory.ps1 - READ ONLY. Changes nothing on the host.
# Purpose: ground the Day Zero plan in the real machine instead of assumptions.
$ErrorActionPreference = 'Continue'
$key  = 'C:\VPS\AWS-Instance\devpilotX.pem'
$dest = 'ubuntu@13.206.200.102'

if (-not (Test-Path -LiteralPath $key)) { Write-Output "KEYFILE MISSING: $key"; exit 1 }
Write-Output "keyfile present: $key"

$remote = @'
echo "=== identity ==="; whoami; id
echo "=== os ==="; . /etc/os-release 2>/dev/null; echo "$PRETTY_NAME"; uname -r
echo "=== cpu ==="; nproc; grep -m1 'model name' /proc/cpuinfo
echo "=== mem ==="; free -m | head -3
echo "=== disk ==="; df -h / /var 2>/dev/null | grep -v ^Filesystem
echo "=== swap ==="; swapon --show 2>/dev/null || echo "no swap"
echo "=== steal/idle snapshot ==="; (command -v mpstat >/dev/null && mpstat 1 2 | tail -2) || (grep -m1 '^cpu ' /proc/stat)
echo "=== ec2 metadata ==="
TOK=$(curl -s -m 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null)
if [ -n "$TOK" ]; then
  for f in instance-type instance-id placement/availability-zone; do
    printf "%s = " "$f"; curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOK" "http://169.254.169.254/latest/meta-data/$f"; echo
  done
else
  echo "IMDSv2 token not obtained"
fi
echo "=== docker ==="; (command -v docker >/dev/null && sudo -n docker --version) || echo "docker not found or sudo needs a password"
echo "=== containers ==="; sudo -n docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null || echo "cannot list containers"
echo "=== pelican wings ==="; systemctl is-active wings 2>/dev/null; systemctl is-enabled wings 2>/dev/null
echo "=== pelican panel dir ==="; ls -d /var/www/pelican 2>/dev/null || echo "no /var/www/pelican"
echo "=== pelican volumes ==="; sudo -n ls -1 /var/lib/pelican/volumes 2>/dev/null | head -20 || echo "cannot list volumes"
echo "=== listening sockets ==="; sudo -n ss -tulnp 2>/dev/null | grep -Ev '127.0.0.1|::1' | head -30 || ss -tuln | head -30
echo "=== ufw ==="; sudo -n ufw status verbose 2>/dev/null || echo "ufw unknown"
echo "=== java ==="; (command -v java >/dev/null && java -version 2>&1 | head -1) || echo "no host java"
echo "=== git on host ==="; (command -v git >/dev/null && git --version) || echo "no git on host"
echo "=== sshd password auth ==="; sudo -n sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|port) ' || grep -hE '^(PasswordAuthentication|PermitRootLogin)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
echo "=== uptime ==="; uptime
echo "=== END INVENTORY ==="
'@

$remote = $remote -replace "`r`n", "`n"
$tmp = Join-Path $env:TEMP 'lt-inventory.sh'
[System.IO.File]::WriteAllText($tmp, $remote)

# PowerShell has no stdin redirection operator; pipe the script in instead.
Get-Content -LiteralPath $tmp -Raw |
  & ssh -i $key -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 $dest 'bash -s' 2>&1
Write-Output ("ssh exit code: " + $LASTEXITCODE)
