# check-iam.ps1 - READ ONLY. Looks for an IAM instance profile and AWS tooling.
$ErrorActionPreference = 'Continue'
$cfg = Join-Path $PSScriptRoot 'host.env.ps1'
. $cfg

$remote = @'
TOK=$(curl -s -m 3 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
echo "=== iam info ==="
curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/iam/info; echo
echo "=== iam role name ==="
curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/iam/security-credentials/; echo
echo "=== security groups ==="
curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/security-groups; echo
echo "=== mac / vpc ==="
MAC=$(curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/network/interfaces/macs/ | head -1)
echo "mac=$MAC"
echo "=== root device / volume ==="
curl -s -m 3 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/block-device-mapping/; echo
echo "=== aws cli on host ==="
(command -v aws >/dev/null && aws --version) || echo "no aws cli"
echo "=== ssm agent ==="
snap list amazon-ssm-agent 2>/dev/null | tail -1 || echo "no ssm snap"
systemctl is-active snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || echo "ssm service state unknown"
echo "=== END ==="
'@
$remote = $remote -replace "`r`n", "`n"
$tmp = Join-Path $env:TEMP 'lt-iam.sh'
[System.IO.File]::WriteAllText($tmp, $remote)
Get-Content -LiteralPath $tmp -Raw |
  & ssh -i $LT_SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 $LT_SSH_DEST 'bash -s' 2>&1
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
