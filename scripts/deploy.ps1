# deploy.ps1 - THE one command. Acceptance rows 1 and 3.
#
# Row 1: "Server starts from a clean checkout with one command."
# Row 3: "Bare-VPS rebuild under 30 minutes."
#
# Spec 30.2 rule 1 and 29.x: the repository is the only path files take to the VPS.
# Until now that path existed as a dozen scripts run by hand in the right order,
# which is not a deploy - it is a memory test. This is the order, executed.
#
# EVERY STAGE IS IDEMPOTENT. Running this twice in a row must be safe and must
# produce the same result, because that is the only way a deploy is trustworthy:
#   fetch      re-verifies checksums, downloads only what is missing
#   install    copies pinned jars over whatever is there
#   properties carries secrets across from the live file, aborts if any is missing
#   tuning     sets only keys that already exist, reports "ok" when already correct
#   access     rewrites whitelist and ops from the repository's single entry
#   database   creates the container only if absent; migrations skip if applied
#   start      boots and verifies all eight plugins load
#
# WHAT THIS CANNOT PROVE, stated rather than glossed: row 3's "bare-VPS rebuild"
# needs a genuinely empty second VPS. Wiping this host to test that would destroy
# the Panel, and there is no `pre-build` snapshot to recover from (OA-03). So this
# times the full deploy against an existing host, which measures every step except
# provisioning the box and installing Docker and Pelican. That is the honest claim.
#
# Usage:
#   deploy.ps1                 full deploy, stops and restarts the server
#   deploy.ps1 -DryRun         print the plan, touch nothing
#   deploy.ps1 -SkipFetch      artefacts already staged on the host
#   deploy.ps1 -NoRestart      config and database only, leave the server alone

param(
  [switch]$DryRun,
  [switch]$SkipFetch,
  [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

$remote = Join-Path $PSScriptRoot 'remote.ps1'
$overall = [System.Diagnostics.Stopwatch]::StartNew()
$results = New-Object System.Collections.Generic.List[object]

function Invoke-Stage {
  param(
    [string]$Name,
    [string]$Script,
    [switch]$Confirmed,
    [string]$Reason,
    [switch]$Local,
    [string]$LocalScript,
    [switch]$AllowFailure
  )

  Write-Output ''
  Write-Output ('=' * 78)
  Write-Output ("STAGE  {0}" -f $Name)
  Write-Output ('=' * 78)

  if ($DryRun) {
    Write-Output ("  DRY RUN - would run {0}" -f $(if ($Local) { $LocalScript } else { $Script }))
    $results.Add([pscustomobject]@{ Stage = $Name; Seconds = 0; Result = 'dry-run' })
    return
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  if ($Local) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $LocalScript)
  } else {
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $remote, '-ScriptFile', $Script, '-Reason', $Reason)
    if ($Confirmed) { $args += '-Confirmed' }
    & powershell @args
  }
  $code = $LASTEXITCODE
  $sw.Stop()

  $verdict = if ($code -eq 0) { 'ok' } else { "FAILED (exit $code)" }
  $results.Add([pscustomobject]@{ Stage = $Name; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1); Result = $verdict })

  if ($code -ne 0 -and -not $AllowFailure) {
    Write-Output ''
    Write-Output ("DEPLOY ABORTED at stage '{0}' with exit {1}." -f $Name, $code)
    Write-Output 'Nothing further has run. Fix the cause and re-run - every stage is idempotent.'
    Show-Summary
    exit $code
  }
}

function Show-Summary {
  $overall.Stop()
  Write-Output ''
  Write-Output ('=' * 78)
  Write-Output 'DEPLOY SUMMARY'
  Write-Output ('=' * 78)
  $results | ForEach-Object { Write-Output ("  {0,-34} {1,7} s   {2}" -f $_.Stage, $_.Seconds, $_.Result) }
  Write-Output ''
  Write-Output ("  TOTAL {0:n1} s ({1:n1} minutes)" -f $overall.Elapsed.TotalSeconds, $overall.Elapsed.TotalMinutes)
  Write-Output ''
  if ($overall.Elapsed.TotalMinutes -lt 30) {
    Write-Output '  ROW 3 (under 30 minutes): PASS for the deploy portion.'
    Write-Output '  Excludes provisioning the VPS and installing Docker and Pelican - see the'
    Write-Output '  header. A true bare-VPS timing needs a second box.'
  } else {
    Write-Output '  ROW 3: the deploy alone exceeded 30 minutes. Investigate before claiming row 3.'
  }
}

Write-Output 'LaughTail SMP deploy'
Write-Output ("repository : {0}" -f $repo)
Write-Output ("started    : {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Write-Output ("mode       : {0}" -f $(if ($DryRun) { 'DRY RUN' } else { 'live' }))

# ---- 1. verify the repository is deployable before touching the server --------
# Checked first and locally: there is no point stopping a running server to find
# out a checksum is wrong or a secret was committed.
Invoke-Stage -Name 'verify manifest checksums' -Local -LocalScript 'verify-manifest.ps1'
Invoke-Stage -Name 'no secrets in the repository' -Local -LocalScript 'check-no-secrets.ps1'
Invoke-Stage -Name 'no hardcoded host values (row 2)' -Local -LocalScript 'check-hardcoded.ps1'
Invoke-Stage -Name 'destructive-command guard tests' -Local -LocalScript 'guard.tests.ps1'

# ---- 2. regenerate everything that is generated ------------------------------
# A generated script that is stale is worse than one that is missing, because it
# looks current. Regenerating here means the deploy cannot use a stale artefact.
Invoke-Stage -Name 'regenerate fetch script' -Local -LocalScript 'gen-fetch-artefacts.ps1'
Invoke-Stage -Name 'regenerate properties deploy' -Local -LocalScript 'gen-deploy-server-properties.ps1'
Invoke-Stage -Name 'regenerate paper tuning' -Local -LocalScript 'gen-paper-tuning.ps1'
Invoke-Stage -Name 'regenerate db migrate' -Local -LocalScript 'gen-db-migrate.ps1'
Invoke-Stage -Name 'regenerate backup schedule' -Local -LocalScript 'gen-schedule-backups.ps1'
Invoke-Stage -Name 'regenerate permissions' -Local -LocalScript 'gen-permissions.ps1'
Invoke-Stage -Name 'regenerate monitor schedule' -Local -LocalScript 'gen-schedule-monitor.ps1'

# ---- 3. artefacts onto the host, verified there -------------------------------
if (-not $SkipFetch) {
  Invoke-Stage -Name 'fetch and verify artefacts' -Script 'scripts/remote/fetch-artefacts.sh' `
    -Reason 'deploy: stage pinned artefacts and verify checksums on the host'
}

# ---- 4. the database can come up while the server is still running -----------
Invoke-Stage -Name 'database container' -Script 'scripts/remote/db-up.sh' -Confirmed `
  -Reason 'deploy: ensure the db container exists'
Invoke-Stage -Name 'schema migrations' -Script 'scripts/remote/db-migrate.sh' `
  -Reason 'deploy: apply pending migrations'

# ---- 5. stop, deploy config, start -------------------------------------------
# server.properties and the Paper YAML are read at boot and REWRITTEN at shutdown,
# so they can only be deployed to a stopped server. This is the only stage that
# interrupts play, and it is deliberately as short as possible.
if (-not $NoRestart) {
  Invoke-Stage -Name 'stop server' -Script 'scripts/remote/stop-server.sh' -Confirmed `
    -Reason 'deploy: config is read at boot and rewritten at shutdown'
  Invoke-Stage -Name 'install paper and plugins' -Script 'scripts/remote/install-paper-and-plugins.sh' -Confirmed `
    -Reason 'deploy: install pinned server jar and manifest plugins'
  Invoke-Stage -Name 'deploy server.properties' -Script 'scripts/remote/deploy-server-properties.sh' `
    -Reason 'deploy: repository config with secrets preserved host-side'
  Invoke-Stage -Name 'apply paper tuning' -Script 'scripts/remote/apply-paper-tuning.sh' `
    -Reason 'deploy: managed Paper keys'
  Invoke-Stage -Name 'deploy access state' -Script 'scripts/remote/deploy-access-state.sh' `
    -Reason 'deploy: whitelist and ops from the repository'
  Invoke-Stage -Name 'start and verify' -Script 'scripts/remote/start-server-and-verify.sh' `
    -Reason 'deploy: boot and prove all manifest plugins load'
  # Permissions need a running server: LuckPerms is driven through its commands,
  # which are the only supported interface - its storage format is an
  # implementation detail and hand-editing it is how permission systems break.
  Invoke-Stage -Name 'apply permission ladder' -Script 'scripts/remote/apply-permissions.sh' `
    -Reason 'deploy: Section 17 staff ladder with the never-grant list as explicit denials'
  Invoke-Stage -Name 'verify permissions (17.5)' -Script 'scripts/remote/verify-permissions.sh' `
    -Reason 'deploy: prove every never-grant node is denied and inheritance is correct'
}

# ---- 6. prove the result matches the repository ------------------------------
Invoke-Stage -Name 'properties drift check' -Script 'scripts/remote/check-properties-drift.sh' `
  -Reason 'deploy: prove the live config matches the repository'
Invoke-Stage -Name 'paper tuning drift check' -Script 'scripts/remote/check-paper-drift.sh' `
  -Reason 'deploy: prove the managed Paper keys match the repository'
Invoke-Stage -Name 'external port exposure (row 5)' -Local -LocalScript 'check-external-ports.ps1'
Invoke-Stage -Name 'backup schedule' -Script 'scripts/remote/schedule-backups.sh' -Confirmed `
  -Reason 'deploy: ensure backups are scheduled'
Invoke-Stage -Name 'monitor schedule' -Script 'scripts/remote/schedule-monitor.sh' -Confirmed `
  -Reason 'deploy: ensure monitoring is scheduled, and take one sample now'
Invoke-Stage -Name 'health check' -Script 'scripts/remote/health-check.sh' `
  -Reason 'deploy: final state check'

Show-Summary
Write-Output ''
Write-Output 'DEPLOY COMPLETE'
