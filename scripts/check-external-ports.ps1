# check-external-ports.ps1 - acceptance row 5 evidence, from OUTSIDE the host.
#
# Row 5 says "external scan shows only the intended ports; RCON unreachable".
# Reading ufw on the box cannot prove that, for two reasons: Docker's published
# ports bypass ufw entirely, and a rule can exist while a security group above it
# still blocks or allows the traffic. The only honest test is from off the box.
#
# This runs from the owner's PC, which is outside AWS, so it exercises the real
# path: internet -> security group -> host -> docker -> container.
#
# The address is NEVER hardcoded (acceptance row 2). It is derived from
# scripts/host.env.ps1, which is git-ignored.
#
# LIMITATION, stated rather than hidden: this checks TCP only. Row 6 needs UDP
# 24454 and 19132 proven with a UDP-aware method, which a TCP connect cannot do.
# A closed TCP port and a filtered UDP port look identical from here.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$cfg = Join-Path $PSScriptRoot 'host.env.ps1'
if (-not (Test-Path -LiteralPath $cfg)) { throw 'Missing scripts/host.env.ps1' }
. $cfg

if ($LT_SSH_DEST -notmatch '@(.+)$') { throw "Cannot derive a host from LT_SSH_DEST" }
$target = $Matches[1]

# port, what it is, and whether reachable-from-here is a PASS or a FAIL
$ports = @(
  @{ Port = 22;    Name = 'SSH';             Expect = 'open'   }
  @{ Port = 25565; Name = 'Minecraft TCP';   Expect = 'open'   }
  @{ Port = 25575; Name = 'RCON';            Expect = 'closed' }
  @{ Port = 8443;  Name = 'Pelican/Wings';   Expect = 'open'   }
  @{ Port = 443;   Name = 'Panel HTTPS';     Expect = 'open'   }
  @{ Port = 80;    Name = 'Panel HTTP';      Expect = 'open'   }
  @{ Port = 2022;  Name = 'Pelican SFTP';    Expect = 'closed' }
  @{ Port = 8080;  Name = 'stray HTTP';      Expect = 'closed' }
  @{ Port = 3306;  Name = 'MySQL';           Expect = 'closed' }
)

Write-Output ("external TCP probe of {0} - {1}" -f $target, (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Write-Output ''

$fail = 0
foreach ($p in $ports) {
  $client = [System.Net.Sockets.TcpClient]::new()
  $open = $false
  try {
    $iar = $client.BeginConnect($target, $p.Port, $null, $null)
    $open = $iar.AsyncWaitHandle.WaitOne(4000, $false) -and $client.Connected
  } catch { $open = $false } finally { $client.Close() }

  $actual = if ($open) { 'open' } else { 'closed' }
  $verdict = if ($actual -eq $p.Expect) { 'PASS' } else { 'FAIL' }
  if ($verdict -eq 'FAIL') { $fail++ }
  Write-Output ("  {0,-5} {1,-18} expected {2,-6} actual {3,-6} {4}" -f $p.Port, $p.Name, $p.Expect, $actual, $verdict)
}

Write-Output ''
if ($fail -eq 0) {
  Write-Output 'ROW 5 TCP PORTION: PASS - RCON is not reachable from outside and no unexpected port answered.'
} else {
  Write-Output ("ROW 5 TCP PORTION: FAIL - {0} port(s) did not match expectation. Do not treat row 5 as satisfied." -f $fail)
}
Write-Output 'UDP 24454 and 19132 are NOT covered here. Row 6 remains open (needs OA-06 and a UDP-aware test).'
exit $fail
