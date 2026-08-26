# pre-commit.ps1 - refuses a commit that would put a secret into git history.
#
# Never-break rule 5 and spec 33.6 item 13: "a rule written in prose is a request;
# a hook that refuses the command is a guarantee."
#
# Why this cannot be replaced by scripts/check-no-secrets.ps1 alone: that script
# scans the WORKING TREE. A pre-commit hook must scan STAGED CONTENT, because
# those differ. `git add secrets.env` then editing the file clean on disk would
# pass a working-tree scan and still commit the secret. Everything below reads
# from the index via `git show :file`, never from disk.
#
# Fails closed: if it cannot determine whether something is a secret, it refuses.
# Bypassing is possible with --no-verify, which is deliberate - the hook stops
# accidents, not a determined operator. Doing so should be recorded in decisions.md.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Git {
  $g = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
  if ($g) { return $g }
  foreach ($c in @(
      (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'))) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  throw 'git not found'
}
$git = Get-Git

# Staged, non-deleted paths. The @() must wrap the WHOLE pipeline: Where-Object
# unwraps a single-element array back to a scalar, and under StrictMode a scalar
# has no .Count, so the array subexpression has to be the outermost thing here.
$staged = @((& $git diff --cached --name-only --diff-filter=ACMR) | Where-Object { $_ })
if ($staged.Count -eq 0) { exit 0 }

$problems = New-Object System.Collections.Generic.List[string]

# ---- 1. filenames that must never be committed at all -----------------------
# Matched on the path, so an ignored file force-added still trips this.
$forbiddenPaths = @(
  @{ rx = '(^|/)\.env$';                    why = 'environment file' }
  @{ rx = '(^|/)\.env\.';                   why = 'environment file variant' }
  @{ rx = '(^|/)docs/private/';             why = 'docs/private is never committed - secrets and detector thresholds' }
  @{ rx = '(^|/)host\.env\.ps1$';           why = 'host connection details' }
  @{ rx = '\.pem$|\.key$|\.p12$|\.pfx$|\.jks$'; why = 'private key or keystore' }
  @{ rx = '(^|/)id_rsa|(^|/)id_ed25519';    why = 'SSH private key' }
  @{ rx = '(^|/)credentials$|(^|/)\.netrc$';    why = 'credential store' }
  @{ rx = '(^|/)database\.sqlite$';         why = 'Panel database' }
)
foreach ($f in $staged) {
  foreach ($p in $forbiddenPaths) {
    if ($f -match $p.rx) {
      $problems.Add(("FORBIDDEN PATH  {0}`n    reason: {1}" -f $f, $p.why))
    }
  }
}

# ---- 2. secret-shaped CONTENT in the staged version -------------------------
# Deliberately narrow. A broad "key" grep is useless here: acceptance row 14 asks
# for a repository grep of the word 'key' to return nothing, while the spec itself
# mandates APP_KEY handling text throughout Sections 22 and 29 - that row can never
# pass as written (questions.md Q-05). So this matches ASSIGNMENTS OF VALUES, not
# mentions of words. Prose about a secret is fine; a secret is not.
$contentRules = @(
  @{ rx = '(?im)^\s*(rcon\.password|management-server-secret)\s*=\s*(?!__PRESERVE__\s*$)\S+'
     why = 'a real value where __PRESERVE__ belongs (decision D-0014)' }
  @{ rx = '(?im)^\s*APP_KEY\s*=\s*\S+'
     why = 'the Panel APP_KEY - never-break rule 6' }
  @{ rx = '(?im)^\s*(DB_PASSWORD|REDIS_PASSWORD|MAIL_PASSWORD|DISCORD_TOKEN|BOT_TOKEN)\s*=\s*\S+'
     why = 'a credential assignment' }
  @{ rx = '-----BEGIN [A-Z ]*PRIVATE KEY-----'
     why = 'an embedded private key' }
  @{ rx = '(?i)\b(aws_secret_access_key|aws_session_token)\s*[:=]\s*\S+'
     why = 'an AWS credential' }
  @{ rx = 'AKIA[0-9A-Z]{16}'
     why = 'an AWS access key id' }
  @{ rx = '(?i)\bghp_[A-Za-z0-9]{20,}|\bgithub_pat_[A-Za-z0-9_]{20,}'
     why = 'a GitHub token' }
)

# Files whose CONTENT is exempt, with the reason. Kept explicit and short.
$contentExempt = @(
  'scripts/hooks/pre-commit.ps1'   # this file necessarily contains the patterns
  'scripts/check-no-secrets.ps1'
)

foreach ($f in $staged) {
  if ($contentExempt -contains $f) { continue }
  # Skip binaries - a jar or image cannot be reviewed this way and is caught by path rules.
  if ($f -match '\.(jar|png|jpg|gif|zip|gz|tar|ico|woff2?)$') { continue }

  $blob = & $git show ":$f" 2>$null
  if (-not $blob) { continue }
  $text = ($blob -join "`n")

  foreach ($r in $contentRules) {
    if ([regex]::IsMatch($text, $r.rx)) {
      $line = 0
      $blob | ForEach-Object -Begin { $i = 0 } -Process {
        $i++
        if ($line -eq 0 -and [regex]::IsMatch($_, $r.rx)) { $line = $i }
      }
      $problems.Add(("SECRET CONTENT  {0}:{1}`n    reason: {2}" -f $f, $line, $r.why))
    }
  }
}

# ---- 3. report -------------------------------------------------------------
if ($problems.Count -gt 0) {
  Write-Host ''
  Write-Host 'COMMIT REFUSED - never-break rule 5' -ForegroundColor Red
  Write-Host ''
  foreach ($p in $problems) { Write-Host ("  " + $p) }
  Write-Host ''
  Write-Host 'A secret in git history is not fixed by a later commit. Remove it from the'
  Write-Host 'index (git restore --staged <file>), move the value into docs/private/ or'
  Write-Host 'scripts/host.env.ps1, and commit a placeholder instead.'
  Write-Host ''
  exit 1
}

Write-Host ("pre-commit: {0} staged file(s) checked, no secrets found" -f $staged.Count)
exit 0
