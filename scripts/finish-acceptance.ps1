$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot
$specDir = Join-Path $repo 'docs\spec'
$hdr  = Get-Content -LiteralPath (Join-Path $specDir '.acceptance-header.md')
$body = Get-Content -LiteralPath (Join-Path $specDir '.acceptance-body.md')

$footer = @'

## The per-section criteria tables

Eighteen sections define their own criteria in addition to the master table. Nine use explicit IDs; ten are unnumbered checkbox lists for which I have assigned positional IDs, marked derived. See `docs/questions.md` Q-02.

| Table | Location | Count | IDs | Owning phase | Status |
| --- | --- | --- | --- | --- | --- |
| Legal and commercial | 3.9 | 8 | `3-1`..`3-8` **derived** | 1 | Not started |
| Portability contract | 5.7 | 8 | derived | 0 | Not started |
| Performance | 6.9 | 10 | derived | 0 baseline, 6 proof | Not started |
| Economy | 8.6 | 5 | `8-1`..`8-5` | 3 | Not started |
| Rank and seasons | 9.9 | 7 | `9-1`..`9-7` | 4 | Not started |
| Cosmetics | 11.6 | 6 | derived | 7 | Not started |
| War events | 12.6 | 8 | derived | 7 | Not started |
| Voice | 13.5 | 7 | derived | 7 | Not started |
| Rules and enforcement | 14.10 | 8 | derived | 1 | Not started |
| Permissions | 17.5 | 4 | `17-1`..`17-4` **derived** | 1 | Not started |
| Web and store | 18.7 | 9 | `18-1`..`18-9` **derived** | 8 | Not started |
| Migration, general | 22.7 | 8 | derived | Migration | Not started |
| Pelican migration | 22.15 | 15 | `22-1`..`22-15` | Migration | Not started |
| Agent context | 27.9 | 9 | `27-1`..`27-9` | Day Zero, 0 | `27-1` met, unverified until committed |
| Build procedure | 28.11 | 10 | `28-1`..`28-10` | Day Zero, 0 | Not started |
| Pelican and the repo | 29.14 | 17 | `29-1`..`29-17` | 0 | `29-2` VOID (Q-24), `29-14` and `29-15` need restating (Q-25) |
| Build environment | 30.6 | 6 | `30-1`..`30-6` | 0 | Not started |
| Completeness pass | 31.15 | 18 | `31-1`..`31-18` | spread 1 to 7 | Not started |
| Owner-action protocol | 32.7 | 6 | `32-1`..`32-6` | continuous | `32-1`, `32-3`, `32-4` met this session; `32-5` met; `32-6` BLOCKED on git |
| Day Zero | 33.7 | 9 | `33-1`..`33-9` | Day Zero | See below |

Sections 7, 10, 15, 16 and 19 define no criteria of their own and are covered entirely by the Section 21 table.

## Day Zero status, 2026-08-26

| ID | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| `33-1` | A verified `pre-build` VPS snapshot exists before any change | **BLOCKED** | `docs/owner-actions.md` OA-03. No host change has been made, so nothing is at risk yet |
| `33-2` | The first commit contains `.gitignore` and nothing secret | **BLOCKED** | `.gitignore` written first, 63 lines, staged. Git is not installed - OA-01 |
| `33-3` | `AGENTS.md` is in the root, under 200 lines, loaded at session start | **PASS** | File present at root; its rules are cited throughout `docs/progress.md` |
| `33-4` to `33-9` | Remaining Day Zero criteria | Not started | Read from `docs/spec/33-day-zero-the-bootstrap-procedure.md` and filled in when actioned |

## Pre-flight checklist - Section 33.6, measured 2026-08-26

| # | Check | Status |
| --- | --- | --- |
| 1 | `pre-build` snapshot exists and shows complete | **FAIL** - OA-03 |
| 2 | The restore procedure has been located | **FAIL** - OA-03 step 6 |
| 3 | SSH works with a key and password authentication is disabled | **PASS** - measured: `passwordauthentication no`, `permitrootlogin without-password` |
| 4 | 2FA on the Panel, GitHub, registrar, host and email | Unverified - OA-23 |
| 5 | `.gitignore` is committed and is the first commit | **FAIL** - OA-01 |
| 6 | `AGENTS.md` is in the repository root | **PASS** |
| 7 | The specification is at `docs/spec/MASTER.md` | **PASS** - 3,994 lines, and split losslessly |
| 8 | The six living documents exist | **PASS** - progress, decisions, rejected, owner-actions, questions, acceptance |
| 9 | `laughtail-dev` exists in the Panel and starts and stops cleanly | **FAIL** - only one server exists and it is the stock server |
| 10 | `laughtail-dev` heap is at least 25 per cent below its allocation | Not applicable yet - see `docs/questions.md` Q-26 |
| 11 | The existing stock server is stopped and not yet deleted | **FAIL** - measured: container up 2 days. OA-07 |
| 12 | The eight 32.4 decisions are confirmed or explicitly left at defaults | **PASS by default** - all thirteen recorded in `docs/decisions.md`, flagged for confirmation |
| 13 | A destructive-command guard exists as a hook, not prose | **FAIL** - Phase 0 step 0.2 |
| 14 | The owner knows how to read the Panel console and where logs are | Unverified - ask at approval |
| 15 | The first session's output was a plan, read and approved by the owner | **Plan written. Approval pending** |

**7 of 15 pass. None of the failures is a defect; each is an owner action or a Phase 0 task.**
'@

$all = @($hdr) + @($body) + ($footer -split "`r?`n")
$dest = Join-Path $repo 'docs\acceptance.md'
Set-Content -LiteralPath $dest -Value $all -Encoding UTF8
Write-Output ("acceptance.md lines: " + $all.Count)
$chk = Get-Content -LiteralPath $dest
Write-Output ("Section 21 rows present: " + (($chk | Where-Object { $_ -match '^\| \*\*[0-9]+[abc]?\*\* \|' }).Count))
