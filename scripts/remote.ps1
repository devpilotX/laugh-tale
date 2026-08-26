# remote.ps1 - the ONLY way a command reaches the VPS.
#
# Spec 30.2 rule 1 and 30.4 item 3: every state-changing command lives in a
# script, never ad hoc. This is the chokepoint that makes that enforceable -
# it runs guard.ps1 first and refuses to connect if the guard says no.
#
# Usage:
#   remote.ps1 -Command 'free -m'
#   remote.ps1 -Command 'ufw allow 24454/udp' -Confirmed -Reason 'OA-06'
#   remote.ps1 -ScriptFile .\scripts\remote\some-task.sh -Confirmed -Reason 'Phase 0.3'
#
# Every invocation is appended to logs/remote-commands.log with a timestamp,
# the guard decision and the exit code. logs/ is git-ignored.

param(
  [string]$Command,
  [string]$ScriptFile,
  [switch]$Confirmed,
  [string]$Reason = '',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'guard.ps1')

$cfg = Join-Path $PSScriptRoot 'host.env.ps1'
if (-not (Test-Path -LiteralPath $cfg)) {
  throw "Missing scripts/host.env.ps1. Copy host.env.example.ps1 and fill it in."
}
. $cfg

if (-not $Command -and -not $ScriptFile) { throw 'Give -Command or -ScriptFile.' }
if ($Command -and $ScriptFile)           { throw 'Give one of -Command or -ScriptFile, not both.' }

# ---- build the payload -------------------------------------------------------
if ($ScriptFile) {
  $sfPath = if ([System.IO.Path]::IsPathRooted($ScriptFile)) { $ScriptFile } else { Join-Path $repo $ScriptFile }
  if (-not (Test-Path -LiteralPath $sfPath)) { throw "Script not found: $sfPath" }
  $payload = (Get-Content -LiteralPath $sfPath -Raw)
  $label   = "scriptfile:" + (Split-Path -Leaf $sfPath)
} else {
  $payload = $Command
  $label   = $Command
}

# ---- guard every line, not just the whole blob -------------------------------
# A script file is a list of commands. Checking only the concatenation would let
# a bad line hide behind a good one, so each non-comment line is checked.
$lines = @($payload -split "`r?`n" | Where-Object { $_.Trim() -ne '' -and $_.Trim() -notmatch '^#' })
if ($lines.Count -eq 0) { throw 'GUARD: nothing to run after stripping comments. Fail closed.' }

$level = 'plain'
foreach ($l in $lines) {
  $d = Assert-CommandAllowed -Command $l -Confirmed:$Confirmed -Reason $Reason
  if ($d.Level -eq 'confirmed') { $level = 'confirmed' }
}
Write-Output ("GUARD OK ({0}): {1} line(s) approved" -f $level, $lines.Count)

if ($DryRun) {
  Write-Output '--- DRY RUN, nothing sent ---'
  $lines | ForEach-Object { Write-Output ('  ' + $_) }
  exit 0
}

# ---- audit log ---------------------------------------------------------------
$logDir = Join-Path $repo 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir 'remote-commands.log'
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')

# ---- run ---------------------------------------------------------------------
# Normalise every line-ending form to LF, then transport as base64.
#
# Why base64: piping a string to a native command makes PowerShell re-encode it
# and append a platform newline, which arrives at bash as $'\r' and fails with a
# message that points at the wrong line. Base64 removes line endings from the
# transport problem entirely - bash decodes exactly the bytes we encoded.
$payloadUnix = (($payload -split "\r\n|\r|\n") -join "`n") + "`n"
$script = "set -o pipefail`n" + $payloadUnix
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script))

if ($b64.Length -gt 100000) { throw "Payload too large for base64 transport ($($b64.Length) chars). Split the script." }

$remoteCmd = "echo $b64 | base64 -d | bash -s"

& ssh -i $LT_SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=20 $LT_SSH_DEST $remoteCmd 2>&1
$code = $LASTEXITCODE

Add-Content -LiteralPath $logFile -Value ("{0}`tlevel={1}`texit={2}`treason={3}`t{4}" -f $stamp, $level, $code, $Reason, $label)
Write-Output ("`nremote exit code: {0}   (logged to logs/remote-commands.log)" -f $code)
exit $code
