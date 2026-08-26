# vps-inventory2.ps1 - READ ONLY. Changes nothing on the host.
# Inspects the Pelican game container: allocation, heap flags, disk, config.
# Connection details come from host.env.ps1 (git-ignored), so this file contains
# no IP address and no absolute host path (acceptance row 2, spec 5.1).
$ErrorActionPreference = 'Continue'

$cfg = Join-Path $PSScriptRoot 'host.env.ps1'
if (-not (Test-Path -LiteralPath $cfg)) {
  Write-Output "Missing $cfg. Copy host.env.example.ps1 to host.env.ps1 and fill it in."
  exit 1
}
. $cfg

# If no volume is pinned in config, let the remote side pick the only one present.
$volLine = if ($LT_VOLUME) { "C='$LT_VOLUME'" } else { 'C=$(sudo -n ls -1 /var/lib/pelican/volumes 2>/dev/null | head -1)' }

$remote = @'
__VOLUME__
if [ -z "$C" ]; then echo "no pelican volume found"; exit 1; fi
echo "=== container limits ==="
sudo -n docker inspect "$C" --format 'Mem={{.HostConfig.Memory}} MemSwap={{.HostConfig.MemorySwap}} CpuQuota={{.HostConfig.CpuQuota}} CpuPeriod={{.HostConfig.CpuPeriod}} Restart={{.HostConfig.RestartPolicy.Name}}'
echo "=== heap flags ==="
sudo -n docker top "$C" 2>/dev/null | grep -o '\-Xm[sx][0-9]*[MmGg]' | sort -u || echo "no Xmx found"
echo "=== stats snapshot ==="
sudo -n docker stats --no-stream --format 'CPU={{.CPUPerc}} MEM={{.MemUsage}} ({{.MemPerc}})' "$C"
echo "=== volume size ==="
sudo -n du -sh "/var/lib/pelican/volumes/$C" 2>/dev/null | awk '{print $1}'
echo "=== world dirs ==="
sudo -n find "/var/lib/pelican/volumes/$C" -maxdepth 1 -type d -name 'world*' -printf '%f\n' 2>/dev/null
echo "=== server.properties ==="
sudo -n grep -E '^(online-mode|max-players|view-distance|simulation-distance|difficulty|level-name|server-port|enable-rcon|white-list)=' "/var/lib/pelican/volumes/$C/server.properties" 2>/dev/null
echo "=== plugins ==="
sudo -n ls -1 "/var/lib/pelican/volumes/$C/plugins" 2>/dev/null | head -30 || echo "no plugins dir"
echo "=== volume ownership ==="
sudo -n stat -c '%U:%G %a' "/var/lib/pelican/volumes/$C" 2>/dev/null
echo "=== disk ==="
df -h --output=source,size,used,avail,pcent / | tail -1
echo "=== panel services ==="
for u in mariadb redis-server nginx pelican-queue; do printf "%s=" "$u"; systemctl is-active "$u" 2>/dev/null || echo "unknown"; done
echo "=== END INVENTORY 2 ==="
'@

$remote = $remote.Replace('__VOLUME__', $volLine) -replace "`r`n", "`n"
$tmp = Join-Path $env:TEMP 'lt-inventory2.sh'
[System.IO.File]::WriteAllText($tmp, $remote)
Get-Content -LiteralPath $tmp -Raw |
  & ssh -i $LT_SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 $LT_SSH_DEST 'bash -s' 2>&1
Write-Output ("ssh exit code: " + $LASTEXITCODE)
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
