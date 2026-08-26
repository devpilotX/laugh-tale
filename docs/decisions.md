# LaughTail SMP - Decisions

**Append-only.** Never silently reverse an entry (AGENTS.md section 3). Every deviation from the specification is recorded here with what the specification said, what I did instead, why, and what I verified afterwards (spec 0.2). Acceptance row 77 and criterion `32-5` are satisfied by this file.

---

## D-0001 | 2026-08-26 | `.gitignore` carve-out for schema migrations

**The specification says:** 33.3 step 2, the minimum `.gitignore` must exclude `*.sql`.

**Also says:** 33.3 step 4 requires a `db/migrations/` directory; Appendix D says "migrations from the first commit"; `22-2` tests the restored schema version against what the migration tool expects.

**What I did:** included the spec's minimum list verbatim, then added `!db/migrations/` and `!db/migrations/**/*.sql` as a commented carve-out.

**Why:** schema migrations are source code, contain no secrets, and are worthless outside version control. Database *dumps* - the thing `*.sql` is protecting against - remain excluded via `*.dump`, `backups/` and the absence of any dump path in the repository.

**Verified:** `.gitignore` written before any other file entered the repository, as 33.3 step 2 requires. Not yet verified against a real `git status`, because git is not installed - `docs/owner-actions.md` OA-01. **This is the one open verification on this decision.**

**Recorded as** `docs/questions.md` **Q-03** for owner confirmation.

---

## D-0002 | 2026-08-26 | Access model built to support both one-time and recurring, with no price hardcoded

**The specification says:** 24.1 leaves the price and its recurrence open and calls it "the single most consequential unanswered question". 32.4 lists it as owner-only.

**What I did:** took 24.1's own stated default - key access on a boolean plus a **nullable** expiry timestamp. Null expiry means permanent access.

**Why:** one nullable column keeps both commercial models open at zero build cost, so no work waits on the decision (spec 32.4's whole purpose). Converting a subscription business to one-time later is much harder than the reverse, so this ordering is also the cheaper mistake.

**Verified:** nothing built yet. Design only.

**Confirmation requested:** `docs/owner-actions.md` **OA-12**.

---

## D-0003 | 2026-08-26 | Repository private until launch

**The specification says:** 29.11 and 32.4 - repository visibility is an owner decision; recommended default is private until launch, then decide.

**What I did:** proceeding on private.

**Why:** never-break rule 5 - a secret committed to a public repository is a permanent incident rather than a fixable mistake. Never-break rule 10 forbids publishing detector thresholds. Private is the reversible option; public is not.

**Verified:** no repository exists yet - OA-02.

---

## D-0004 | 2026-08-26 | The split follows document structure, not 27.3's prescribed filenames

**The specification says:** 27.3 prescribes a set of split filenames. 33.4 step 2 says "split it into one file per section: `00-...md` through `33-...md`, plus one per appendix".

**The conflict:** 27.3's list names no file for sections 29, 30 or 33, and calls the migration file `22-migration.md` while `29-10` and `30-6` call it `docs/06-migration.md`. Criterion `27-1` tests the split against 27.3's list, so it cannot pass as written.

**What I did:** split by actual document structure into 43 files - `_preamble.md`, `00-` through `33-`, appendices `A-` through `G-`, and `_end-of-document.md` - covering every section including 29, 30 and 33.

**Why:** 33.4 is the later, more specific and self-consistent instruction, and it is the one the owner's own first prompt cites. A split that omits three sections defeats the purpose.

**Verified:** `scripts/verify-split.ps1` - part line counts sum to 3,994, equal to `MASTER.md`; all 42 `##` headings appear exactly once; reconcatenating the parts in document order is byte-for-byte identical to `MASTER.md`, zero differing lines. `docs/spec/INDEX.md` maps all 280 headings with no gaps and references all 43 files.

**Recorded as** `docs/questions.md` **Q-30**.

---

## D-0005 | 2026-08-26 | Section 24's seven open questions proceed on their stated defaults

**The specification says:** 24.1 to 24.7 each carry a recommendation and a working default; 32.4 says nothing should wait on a decision that has one.

**What I did:** taking every default as written.

| Question | Default taken |
| --- | --- |
| 24.1 price and recurrence | See D-0002 |
| 24.2 shop tier at reset | `drop_one`, behind one config key so all three behaviours are one line apart |
| 24.3 voice route | Browser-based presented as primary for universality; client mod offered as the quality upgrade |
| 24.4 lifesteal hearts | Built, switched **OFF** at launch |
| 24.5 clans and guilds | Not at launch; roadmap Tier 1 |
| 24.6 Bedrock | Enabled, explicitly labelled best-effort, known limits published |
| 24.7 languages | Every user-facing string in a language file from day one, English only populated |

**Why:** 24.3's default is the one that most deserves comment - leading with browser voice means no paying player is ever excluded from a flagship feature, which is Law 3 applied to a technical choice rather than a commercial one.

**Verified:** design only.

**Confirmation requested:** the table at the end of `docs/owner-actions.md`.

---

## D-0006 | 2026-08-26 | The eight 32.4 owner-only decisions proceed on their recommended defaults

Season end hour 00:00 IST on the 1st (31.1). Combat-log penalty 25 RP on top of the normal loss (31.3) - **with the caveat in `docs/questions.md` Q-14** that 31.3 requires the penalty be strictly worse than dying and the normal death loss is never stated, so I have read 32.4's "on top of" literally and made it additive rather than flat. Daily per-item sell cap at 3x the modelled manual rate (31.5). New-player grace 30 minutes of playtime (31.6). Daily restart 05:00 IST (31.8). Repository visibility per D-0003. Access price per D-0002.

**Why recorded:** `32-5` requires every default taken under 32.4 to be dated here.

**Verified:** design only. Pre-flight 33.6 item 12 is satisfied by this entry - the eight decisions are "explicitly left at their defaults".

---

## D-0007 | 2026-08-26 | Detector thresholds live only in `docs/private/`

**The specification says:** 3.5.1 describes the wagering detector and asks for its detail in a committed file. Never-break rule 10 and 31.10 forbid publishing detector thresholds because publishing them teaches evasion.

**What I did:** all thresholds - wagering, anti-cheat, market manipulation - will live in `docs/private/`, which is git-ignored. Only the *existence* of detection is published, which is what deterrence needs.

**Why:** rule 10 is a never-break rule and outranks a section instruction. A published threshold is an instruction manual for staying just under it.

**Verified:** `docs/private/` exists and is excluded by `.gitignore`. Proposed as deviation **D8** in `docs/progress.md`; recorded as `docs/questions.md` **Q-29**.

---

## D-0008 | 2026-08-26 | Read-only host inspection performed before writing the plan

**The specification says:** nothing either way. 33.5 says the first session produces a plan, not code. Law 5 says measure, never guess.

**What I did:** opened two read-only SSH sessions to the host and collected an inventory: instance type, architecture, CPU, memory, disk, swap, container limits, heap flags, `server.properties`, installed plugins, ufw rules, listening sockets, sshd configuration, and Pelican service state. Nothing was installed, started, stopped, written or changed. Scripts retained as `scripts/vps-inventory.ps1` and `scripts/vps-inventory2.ps1` so the measurement is repeatable.

**Why:** the plan asserts dependencies and risks. Asserting them from the specification alone would have missed all five findings in `docs/questions.md` section B - including that the host is a burstable ARM instance, which changes both the plugin manifest and the credibility of Phase 6's player-cap measurement.

**Verified:** the full output is quoted in `docs/progress.md` section 3. Two sessions, both read-only, both closed.


---

## D-0009 | 2026-08-26 | Host connection details are configuration, never source

**The specification says:** acceptance row 2 - "Grep for IP addresses and absolute host paths across the repo returns nothing". Spec 5.1 requires the stack rebuild anywhere without editing code.

**What happened:** the host inventory scripts I wrote earlier in this session hardcoded the VPS address and an absolute path to the SSH key, and every Day Zero script hardcoded `C:\Laugh-Tale`. I wrote `scripts/check-hardcoded.ps1` to enforce row 2 and it failed with **14 hits, all in my own scripts.**

**What I did:**

* Connection details moved to `scripts/host.env.ps1`, which is git-ignored. `scripts/host.env.example.ps1` is committed as the template with placeholders.
* Every script now derives the repository root from `$PSScriptRoot` rather than naming it.
* `git.exe` is resolved from `PATH` with fallbacks, not by absolute path.

**Why it is recorded rather than quietly fixed:** the check found the violation in the same session that created it, which is the only reason it did not become permanent. That is the argument for having the check in CI from the first commit rather than from Phase 0, and it is why Appendix E lists it.

**Verified:** `scripts/check-hardcoded.ps1` now reports **0 hits** across 12 deployable files. `scripts/verify-split.ps1` and `scripts/verify-docs.ps1` both still pass after the refactor, so nothing was broken in the process. `scripts/vps-inventory2.ps1` was re-run against the live host and returned identical values through the new configuration path.

---

## D-0010 | 2026-08-26 | The row 2 grep is scoped to deployable artefacts, not to the specification

**The problem:** row 2 says "across the repo". Taken literally it includes `docs/spec/`, which is the verbatim specification - and editing that would break the lossless-split guarantee that `33-4` and `27-1` depend on. It would also flag `169.254.169.254`, the AWS metadata endpoint, which is a fixed constant and not host-specific.

**What I did:** `scripts/check-hardcoded.ps1` scans tracked files under `scripts/`, `server/`, `db/`, plus any compose, Dockerfile or `.env.example` - the things that actually get deployed. It allow-lists `169.254.169.254`, `127.0.0.1`, `0.0.0.0` and `255.255.255.255`. It scans `docs/*.md`, `README.md` and `AGENTS.md` for **secrets** (private key headers, AWS key ids, GitHub and Slack token shapes) but permits a host address in owner-facing prose, because telling the owner which machine to click on is the point of that prose.

**Why:** 5.1's intent is portability of the deployable artefact. A specification that quotes an example IP is not a portability defect; a deploy script that hardcodes one is.

**Verified:** 91 tracked files, 12 deployable scanned, 8 documentation files scanned for secrets, 0 hits. Recorded here because narrowing the scope of a launch-gate test is exactly the kind of change that must not happen silently - `32-2` forbids weakening a test, and this is a scoping decision the owner can overrule.
