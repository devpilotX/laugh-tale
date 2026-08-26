# vps-inventory.ps1 - READ ONLY. Changes nothing on the host.
# Purpose: ground the build plan in the real machine instead of assumptions (Law 5).
# Connection details come from host.env.ps1, which is git-ignored, so this file
# contains no IP address and no absolute host path (acceptance row 2, spec 5.1).
$ErrorActionPreference = 'Continue'

$cfg = Join-Path $PSScriptRoot 'host.env.ps1'
if (-not (Test-Path -LiteralPath $cfg)) {
  Write-Output "Missing $cfg. Copy host.env.example.ps1 to host.env.ps1 and fill it in."
  exit 1
}
. $cfg

if (-not (Test-Path -LiteralPath $LT_SSH_KEY)) { Write-Output "KEYFILE MISSING (path is in host.env.ps1)"; exit 1 }
Write-Output "keyfile present"

$remote = @'
echo "=== identity ==="; whoami; id
echo "=== os ==="; . /etc/os-release 2>/dev/null; echo "$PRETTY_NAME"; uname -r
echo "=== cpu ==="; nproc; grep -m1 'model name' /proc/cpuinfo
echo "=== mem ==="; free -m | head -3
echo "=== disk ==="; df -h / 2>/dev/null | grep -v ^Filesystem
echo "=== swap ==="; swapon --show 2>/dev/null || echo "no swap"
echo "=== cpu sample ==="; (command -v mpstat >/dev/null && mpstat 1 2 | tail -2) || (grep -m1 '^cpu ' /proc/stat)
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
echo "=== containers ==="; sudo -n docker ps -a --format '{{.Names}}  {{.Image}}  {{.Status}}' 2>/dev/null || echo "cannot list containers"
echo "=== pelican wings ==="; systemctl is-active wings 2>/dev/null; systemctl is-enabled wings 2>/dev/null
echo "=== pelican panel dir ==="; ls -d /var/www/pelican 2>/dev/null || echo "no panel dir"
echo "=== pelican volumes ==="; sudo -n ls -1 /var/lib/pelican/volumes 2>/dev/null | head -20 || echo "cannot list volumes"
echo "=== listening sockets ==="; sudo -n ss -tulnp 2>/dev/null | grep -Ev '127.0.0.1|::1' | head -30 || ss -tuln | head -30
echo "=== ufw ==="; sudo -n ufw status verbose 2>/dev/null || echo "ufw unknown"
echo "=== java ==="; (command -v java >/dev/null && java -version 2>&1 | head -1) || echo "no host java"
echo "=== git on host ==="; (command -v git >/dev/null && git --version) || echo "no git on host"
echo "=== sshd posture ==="; sudo -n sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|port) '
echo "=== arch ==="; dpkg --print-architecture; uname -m
echo "=== unattended upgrades ==="; grep -hE 'Unattended-Upgrade::' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || echo "20auto-upgrades not found"
echo "=== uptime ==="; uptime
echo "=== END INVENTORY ==="
'@

$remote = $remote -replace "`r`n", "`n"
$tmp = Join-Path $env:TEMP 'lt-inventory.sh'
[System.IO.File]::WriteAllText($tmp, $remote)

Get-Content -LiteralPath $tmp -Raw |
  & ssh -i $LT_SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 $LT_SSH_DEST 'bash -s' 2>&1
Write-Output ("ssh exit code: " + $LASTEXITCODE)
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
