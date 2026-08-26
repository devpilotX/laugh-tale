# vps-inventory2.ps1 - READ ONLY. Changes nothing on the host.
$ErrorActionPreference = 'Continue'
$key  = 'C:\VPS\AWS-Instance\devpilotX.pem'
$dest = 'ubuntu@13.206.200.102'

$remote = @'
C=4fd2f0a9-6ad6-4a4d-96c8-e11e763bdd22
echo "=== container limits ==="
sudo -n docker inspect "$C" --format 'Name={{.Name}} Mem={{.HostConfig.Memory}} MemSwap={{.HostConfig.MemorySwap}} CpuQuota={{.HostConfig.CpuQuota}} CpuPeriod={{.HostConfig.CpuPeriod}} Restart={{.HostConfig.RestartPolicy.Name}}'
echo "=== java command line (heap flags) ==="
sudo -n docker inspect "$C" --format '{{join .Config.Cmd " "}}' 2>/dev/null
sudo -n docker top "$C" 2>/dev/null | tr -s ' ' | cut -d' ' -f8- | grep -o '\-Xm[sx][0-9]*[MmGg]' | sort -u || echo "no Xmx found via docker top"
echo "=== container stats snapshot ==="
sudo -n docker stats --no-stream --format '{{.Name}} CPU={{.CPUPerc}} MEM={{.MemUsage}} ({{.MemPerc}})' "$C"
echo "=== volume size ==="
sudo -n du -sh /var/lib/pelican/volumes/$C 2>/dev/null
echo "=== volume top-level ==="
sudo -n ls -1 /var/lib/pelican/volumes/$C 2>/dev/null | head -40
echo "=== world dirs present ==="
sudo -n find /var/lib/pelican/volumes/$C -maxdepth 1 -type d -name 'world*' 2>/dev/null
echo "=== server.properties key lines ==="
sudo -n grep -E '^(online-mode|max-players|view-distance|simulation-distance|difficulty|level-name|server-port|enable-rcon|white-list)=' /var/lib/pelican/volumes/$C/server.properties 2>/dev/null
echo "=== paper version ==="
sudo -n ls -1 /var/lib/pelican/volumes/$C/*.jar 2>/dev/null
echo "=== plugins ==="
sudo -n ls -1 /var/lib/pelican/volumes/$C/plugins 2>/dev/null | head -30 || echo "no plugins dir"
echo "=== ownership of volume root ==="
sudo -n stat -c '%U:%G %a %n' /var/lib/pelican/volumes/$C 2>/dev/null
echo "=== disk detail ==="
df -h --output=source,size,used,avail,pcent / ; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | head
echo "=== mariadb / redis presence ==="
systemctl is-active mariadb 2>/dev/null; systemctl is-active redis-server 2>/dev/null; systemctl is-active nginx 2>/dev/null
echo "=== panel queue + cron ==="
systemctl is-active pelican-queue 2>/dev/null || echo "pelican-queue unit not found"
sudo -n crontab -l 2>/dev/null | grep -i pelican || echo "no pelican crontab for root"
echo "=== arch ==="; dpkg --print-architecture; uname -m
echo "=== cpu credit relevant ==="; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "no cpufreq exposed"
echo "=== unattended upgrades ==="; grep -hE 'Unattended-Upgrade::' /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || echo "20auto-upgrades not found"
echo "=== END INVENTORY 2 ==="
'@

$remote = $remote -replace "`r`n", "`n"
$tmp = Join-Path $env:TEMP 'lt-inventory2.sh'
[System.IO.File]::WriteAllText($tmp, $remote)
Get-Content -LiteralPath $tmp -Raw |
  & ssh -i $key -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 $dest 'bash -s' 2>&1
Write-Output ("ssh exit code: " + $LASTEXITCODE)
