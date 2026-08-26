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
