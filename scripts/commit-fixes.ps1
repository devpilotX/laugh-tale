$ErrorActionPreference = 'Stop'
$git = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $git) { $git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe' }
Set-Location (Split-Path -Parent $PSScriptRoot)

& $git add -A
if ($LASTEXITCODE -ne 0) { throw "git add failed" }

Write-Output "--- staged ---"
& $git diff --cached --name-status

$msg = @'
Remove hardcoded host values and add the row 2 check (spec 5.1, Appendix E)

scripts/check-hardcoded.ps1 implements the acceptance row 2 grep and failed
on 14 violations in this session's own Day Zero scripts: the VPS address, an
absolute path to the SSH key, and C:\Laugh-Tale hardcoded twelve times.

Fixed:
  connection details moved to scripts/host.env.ps1, git-ignored, with
    scripts/host.env.example.ps1 committed as the template
  every script derives the repository root from $PSScriptRoot
  git.exe resolved from PATH with fallbacks, never by absolute path

Re-run: 0 hits across 12 deployable files. verify-split.ps1 and
verify-docs.ps1 both still pass, and vps-inventory2.ps1 was re-run against
the live host through the new config path returning identical values.

Scoping decision recorded as docs/decisions.md D-0010: the check covers
deployable artefacts, not docs/spec/, because rewriting the verbatim
specification would break the lossless-split guarantee that 33-4 depends on.

Also: OA-01 marked resolved (git installed, three Day Zero commits made),
acceptance 33-2 now PASS with the root-commit evidence, pre-flight item 5
now PASS, pre-flight total 8 of 15.
'@

& $git commit -m $msg
if ($LASTEXITCODE -ne 0) { throw "git commit failed" }

Write-Output "`n--- history ---"
& $git log --oneline
Write-Output "`n--- status ---"
& $git status --short
Write-Output "(clean if nothing above)"
