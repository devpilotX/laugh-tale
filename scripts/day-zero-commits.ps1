# day-zero-commits.ps1 - implements spec 33.3 step 3 and 8, and 33.4 step 5.
# Commit 1: .gitignore ALONE. The guard exists before anything else can be added.
# Commit 2: AGENTS.md, README.md, the spec split and INDEX.md, the scripts.
# Commit 3: the six living documents - the Day Zero plan.
# Nothing is pushed anywhere. No remote is configured (owner action OA-02).

$ErrorActionPreference = 'Stop'

# Resolve git without hardcoding a host path (acceptance row 2).
$git = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) {
  foreach ($c in @(
      (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
      (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'))) {
    if ($c -and (Test-Path -LiteralPath $c)) { $git = $c; break }
  }
}
if (-not $git) { throw "git not found. See docs/owner-actions.md OA-01" }
Set-Location (Split-Path -Parent $PSScriptRoot)

function Git { param([Parameter(ValueFromRemainingArguments=$true)]$a) & $git @a; if ($LASTEXITCODE -ne 0) { throw ("git " + ($a -join ' ') + " failed with " + $LASTEXITCODE) } }

Write-Output ("git version: " + (& $git --version))

if (Test-Path -LiteralPath '.git') {
  Write-Output "repository already initialised - leaving history alone"
} else {
  Git init -b main
  Write-Output "initialised empty repository on branch main"
}

# Identity: repository-local only. Spec/AGENTS.md say leave global git config unchanged.
Git config --local user.name  'Kiro (LaughTail build agent)'
Git config --local user.email 'kiro@laughtail.invalid'
Git config --local core.autocrlf false

# --- Commit 1: .gitignore alone (33.3 step 3) --------------------------------
$ErrorActionPreference = 'Continue'
& $git rev-parse --verify HEAD *> $null
$hasHistory = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = 'Stop'
if (-not $hasHistory) {
  Git add -- .gitignore
  $staged = @(& $git diff --cached --name-only)
  Write-Output ("commit 1 staged files: " + ($staged -join ', '))
  if ($staged.Count -ne 1 -or $staged[0].Trim() -ne '.gitignore') {
    throw "REFUSING: the first commit must contain .gitignore and nothing else. Staged: $($staged -join ', ')"
  }
  Git commit -m "Add .gitignore before anything else (spec 33.3 step 2 and 3)`n`nNever-break rule 5: a secret committed once lives in history forever.`nThe guard must exist before any other file enters the repository.`nIncludes the spec 33.3 minimum exclude list verbatim, plus a documented`ncarve-out for db/migrations/**/*.sql - see docs/decisions.md D-0001."
  Write-Output "commit 1 done"
} else {
  Write-Output "history already exists - skipping commit 1"
}

# --- Commit 2: the repository baseline (33.3 step 8, 33.4 step 5) ------------
Git add -- AGENTS.md README.md scripts docs/spec db
Git commit -m "Add AGENTS.md, README, the split specification and its index (spec 33.3, 33.4)`n`nMASTER.md placed at docs/spec/MASTER.md (3,994 lines) and split into 43 files:`n_preamble, 00- to 33-, appendices A- to G-, _end-of-document.`n`nSplit verified lossless by scripts/verify-split.ps1:`n  part line counts sum to 3,994, equal to MASTER.md`n  all 42 top-level headings appear exactly once`n  reconcatenated parts are byte-for-byte identical to MASTER.md`n`ndocs/spec/INDEX.md maps all 280 headings (43 top-level, 237 subsections)`nto their file with a one-line summary each, plus a load-on-demand`nquick-route table. Zero gaps."
Write-Output "commit 2 done"

# --- Commit 3: the Day Zero plan (33.5) --------------------------------------
Git add -- docs
Git commit -m "Add the Day Zero plan and the six living documents (spec 33.5)`n`nprogress.md      proposed build order: Day Zero plus phases 0-9, each with`n                 what it delivers, the sections it implements, the acceptance`n                 criteria it satisfies, and its dependencies. Plus a measured`n                 host inventory and eight proposed deviations from Section 20.`nowner-actions.md 24 blocked items in the fixed 32.2 format.`nquestions.md     39 contradictions and gaps, severity-ordered, both sides quoted.`ndecisions.md     8 dated decisions including every 32.4 default taken.`nrejected.md      5 rejections including the wagering escrow that row 14c tests for.`nacceptance.md    all 81 Section 21 rows plus the 18 per-section tables.`n`nNo server code was written and no server configuration was changed."
Write-Output "commit 3 done"

Write-Output "`n--- history ---"
& $git log --oneline --stat --format='%h %s' | Select-Object -First 60
Write-Output "`n--- first commit contents (must be .gitignore alone) ---"
& $git show --name-only --format='%h %s' (& $git rev-list --max-parents=0 HEAD)
Write-Output "`n--- working tree status ---"
& $git status --short
