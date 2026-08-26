# LaughTail SMP - Open Questions

Everything in the specification that is contradictory, or stated but not specified precisely enough to build without guessing. Nothing here has been silently resolved. Where I have a reading, I say so and I say what I am doing meanwhile - but AGENTS.md section 7 and spec 32.1 both forbid picking silently, so each one is recorded.

**How this was produced.** Nine agents read the whole specification in parallel, each assigned a group of section files, and reported only findings they could quote both sides of. Raw output is in `docs/spec/.findings/G1.md` to `G9.md` - **117 contradictions and 254 ambiguities before de-duplication**. What follows is the de-duplicated set that actually changes a build decision, severity-ordered. The rest are real but cosmetic, and are in the raw files.

Spec 33.5 says a plan with no questions about a document this size has not been read properly. This is the honest answer to that test.

**Severity key.**
`IRREVERSIBLE` - getting it wrong destroys something that cannot be recovered.
`BLOCKING` - a phase cannot start or an acceptance row cannot pass.
`SERIOUS` - will cause rework or a wrong number shipped.
`MINOR` - inconsistency worth fixing, no build impact.

---

## A. Contradictions

### Q-01 | IRREVERSIBLE | Rotate every secret, versus never regenerate the APP_KEY

* **22.7** requires "Every secret has been rotated", **22.6 step 2** says the environment file is "recreated with **freshly rotated secrets** - never reuse the old ones", and **22.11 step 37** says "Rotate every credential".
* **22.12 step 7** says restore `.env` with the "**identical `APP_KEY`**... **Do not regenerate the key.** If a tool offers to, refuse", and **22-3** requires "The `APP_KEY` was preserved unchanged". Never-break rule 6 agrees.

The `APP_KEY` is a secret, and it lives in the same `.env` file that 22.6 says to recreate with fresh secrets. A literal reading of 22.7 permanently destroys all encrypted Panel data, and database backups do not help.

**Narrowest question:** does "every secret" in 22.7 explicitly exclude the Panel `APP_KEY`?
**My reading:** yes - never-break rule 6 is absolute and outranks the runbook. **Meanwhile:** I will treat the `APP_KEY` as carved out, and I will not run any rotation step that touches it without asking again at the time.

### Q-02 | BLOCKING | Ten acceptance tables have no criterion IDs

Nine sections use explicit IDs (`22-1`..`22-15`, `27-1`..`27-9`, `28-1`..`28-10`, `29-1`..`29-17`, `30-1`..`30-6`, `31-1`..`31-18`, `32-1`..`32-6`, `33-1`..`33-9`, `8-1`..`8-5`, `9-1`..`9-7`). But **3.9, 5.7, 6.9, 11.6, 12.6, 13.5, 14.10, 17.5, 18.7 and 22.7** are unnumbered checkbox lists. AGENTS.md section 6 step 2 requires stating "the acceptance criteria you are targeting, **by number**", which is impossible for those.

**Narrowest question:** may I assign positional IDs (`3-1`..`3-8`, `5-1`..`5-n`, and so on) and record them in `docs/acceptance.md` as the canonical numbering?
**Meanwhile:** I have done exactly that, marked as derived, not stated. Sections 7, 10, 15, 16 and 19 define no criteria at all and rely on Section 21.

### Q-03 | SERIOUS | The mandated .gitignore makes the mandated migrations uncommittable

* **33.3 step 2** requires excluding `*.sql`.
* **33.3 step 4** requires a `db/migrations/` directory, **Appendix D** says "migrations from the first commit", and **22-2** tests the restored schema version against what the migration tool expects.

Schema migrations are code, contain no secrets, and are worthless if not in history.

**Narrowest question:** confirm that a `!db/migrations/**/*.sql` carve-out is correct.
**Meanwhile:** applied, commented in `.gitignore`, recorded as decision **D-0001**. Database *dumps* remain excluded via `*.dump` and `backups/`.

### Q-04 | SERIOUS | Five worlds or four

* **Section 20 Phase 2**: "All **five** worlds created". **Section 23**: "Overworld, Nether, End, Resource, Arena" with borders 6,000 / 2,000 / 3,000 / 3,000 / small.
* **22.9** lists the irreplaceable folders as "(overworld, nether, end, resource world)" - four - and **22.11 step 21** requires "correct borders on all **four** worlds".

A migration verified against four worlds silently skips the fifth.

**Narrowest question:** is the Arena world exempt from migration verification because it is regenerated between events anyway?
**My reading:** yes, that is the likely intent, and it is defensible - but it must be written down, because "we can always regenerate it" is also how worlds get lost.

### Q-05 | BLOCKING | Acceptance row 14 can never pass as written

Row 14 requires a repository grep for "betting, gambling, crate, **key**, lottery, spin, casino, wager, stake, coinflip and dice" to find nothing. The specification itself mandates `APP_KEY` handling text throughout Sections 22 and 29, deploy keys in 32.3 row 6, and `*.key` in the `.gitignore`. No exclusion list, case rule or word-boundary rule is given.

**Narrowest question:** should row 14 match whole words, case-insensitively, restricted to game-logic source paths, with `APP_KEY`, "API key", "deploy key", "SSH key" and "licence key" excluded?
**Meanwhile:** I will write the grep that way and put the exact pattern and exclusion list in the script, so the rule is auditable rather than argued.

### Q-06 | SERIOUS | Never auto-punish, versus the required auto-mute

* **Section 25** rejects "Automated moderation that punishes without review... **Always alert, never auto-punish**", and **14b** requires "code review confirms no punishment path exists from detector output".
* **Row 48** requires "200 messages per second results in an **auto-mute**".

A mute is a punishment applied without review.

**Narrowest question:** is chat flood rate-limiting a carve-out from never-auto-punish, or should row 48 be satisfied by a rate limit plus an alert rather than a mute?
**My reading:** a short, automatic, self-expiring chat cooldown is a rate limit, not a sanction, and satisfies both if it is never recorded as a punishment. I would build that. Confirm.

### Q-07 | SERIOUS | Acceptance 31-13's evidence cannot exist in git history

**31-13** requires evidence as a "Signed checklist in `docs/private/`", but **33.3 step 2** git-ignores `docs/private/`. Never-break rule 5 and 29.11 both require that directory stay out of git.

**Narrowest question:** is a checklist stored locally and referenced by hash from `docs/acceptance.md` acceptable evidence?
**Meanwhile:** that is what I will do - the evidence lives in `docs/private/`, and `docs/acceptance.md` records its filename, date and SHA-256 so tampering is detectable without publishing content.

### Q-08 | SERIOUS | "Champion" names two different things

* **9.3** lists ten ladder tiers, and Champion is one of them - a mid-to-high rank a player can hold.
* **9.6, 23 and row 36** use Champion for the unique season winner, "exactly one per season".

Two players can hold the Champion *rank* while exactly one is the Champion. Every message, prefix, leaderboard and database column touching either is now ambiguous, and row 36's uniqueness constraint is on the wrong noun if this is not settled.

**Narrowest question:** rename one of them. Which - the ladder tier, or the season title?
**My reading:** rename the ladder tier and keep Champion for the season winner, because the season title is the emotional core of the product and appears on the Hall of Fame monument. This is player-facing naming, so it is your call.

### Q-09 | BLOCKING | Phase 8's gate requires evidence only Phase 9 can produce

* **Section 20 Phase 8 gate**: "every acceptance test in Section 21 passes". **Section 21 header**: every row must pass "before the first paying player connects".
* **Row 51** requires "One full week of normal play produces zero punishments of honest players", and rows **34** and **36** in their live form require a real season. Phase 9 is where paying players first appear.

**Narrowest question:** do soft-launch players count as "the first paying player" for the purposes of the launch gate?
**My proposal:** deviation **D3** in `docs/progress.md` - split the gate into a pre-soft-launch set (79 rows) and a pre-public-launch set (all 81). Approve or reject.

### Q-10 | BLOCKING | The economy has no numbers. This is the largest gap in the document

Section 8 and Appendix B describe the economy completely in prose and supply almost no values. Missing entirely: `target_berries_per_hour`, the **minimum buy/sell spread**, price elasticity, the price recovery rate, daily per-item sell caps, the balance-growth alert multiple, the anti-snipe window, the auction listing slot count, and the transfer-tax threshold and rate.

**Row 27** tests "Buy exceeds sell by **the minimum spread** at both extremes of the dynamic band" - and no minimum spread is stated anywhere. **Row 26** requires zero positive-yield cycles, which cannot be computed without base values.

Phase 3 sits on the critical path, and Phases 5 and 6 sit behind Phase 3.

**Narrowest question:** may I derive a complete numeric model from Appendix B's `base_worth` formula plus the Section 23 constraints that *are* given (±35% band, 25% hard floor, listing fee plus sale tax, small transfer tax above a threshold), publish it as a table in `docs/decisions.md`, and have you approve the table rather than each number?
**Meanwhile:** this is the one place I would rather stop than guess, because 28.8 names the economy model as a frontier problem and Q-39 shows the two stated numbers already conflict.

### Q-11 | SERIOUS | Appendix B's MAX_GAIN of 40 is unreachable

* **Section 23**: Elo with "K of 24... clamp +2 to +40".
* **Appendix B** computes `raw = K * (1 - E)` with `K = 24`. Since `(1 - E) < 1`, `raw < 24` always. The upper clamp of 40 can never bind.

**Narrowest question:** is `K = 24` correct with the clamp being defensive only, or was a multiplier intended after the clamp?
**Note:** Appendix B also states as a test invariant that "the sum of CR changes is zero before clamping", which is untestable if multipliers are applied after the clamp.

### Q-12 | SERIOUS | Two different death floors, and one of them removes demotion

* **9.2**: on death, rating floors at "the bottom of the ladder".
* **Appendix B**: floors at `max(tier_floor(CR_victim), ...)`.

Appendix B's version floors a player at their *current* tier, which means a player can never be demoted. That deletes the entire downside of the ladder and makes rank monotonic - directly against 9.1's intent.

**Narrowest question:** which floor applies - the ladder's absolute bottom, or the player's current tier floor?
**My reading:** the ladder bottom. A ladder that cannot demote is a participation trophy.

### Q-13 | SERIOUS | Two decay formulas, twenty times apart

* **9.2**: decay is "1 per cent per week above the tier floor".
* **Appendix B**: `CR * (1 - DECAY_RATE)`, then clamped.

At CR 2000 with a tier floor near 1800, 9.2 removes about 2 points per week and Appendix B removes about 20. Over a month that is the difference between a nudge and a demotion.

**Narrowest question:** is decay 1% of the *excess above the tier floor*, or 1% of the *whole rating*?
Also unstated: when the first decay tick fires relative to the season start, and whether the 6-hour anti-farm pair window is fixed or rolling.

### Q-14 | SERIOUS | The combat-log penalty cannot be checked against its own rule

**31.3** requires the combat-log penalty be published and "strictly worse than dying". **32.4** recommends 25 RP. But the normal RP loss on death is never stated as a number - it is an Elo output that varies with the rating gap. So 25 RP is worse than *some* deaths and better than others.

**Narrowest question:** should the combat-log penalty be defined as "the normal loss plus 25 RP" rather than a flat 25, so it is strictly worse by construction?
**My reading:** yes, and 32.4's wording "25 RP **on top of** the normal loss" supports it. Confirming because 31.3 reads as a flat value.

### Q-15 | SERIOUS | Mending is both allowed and refused in war arenas

* **31.4**'s item table says Mending is "Allowed" for war events.
* **31-6** requires "Totems and Mending are refused by the arena and finale inventory checks".

**Narrowest question:** is Mending allowed in war events and banned only in the Finale, or banned in both?

### Q-16 | BLOCKING | The MSPT gate has no statistic and no sample window

**Rows 19 and 20**, Phase 6's gate and **6.1** all state MSPT limits - 25 ms normal, 40 ms in events - with no statistic (mean, median, p95, p99), no sample duration, and no definition of "normal play". A pass/fail launch gate with no percentile is not testable, and the difference between mean and p99 MSPT on a 2-core box is large.

**Narrowest question:** is 25 ms a mean or a 95th percentile, over how many minutes, at what player count?
**My proposal:** p95 over a 30-minute window at the measured cap, with the mean and p99 both recorded. Cheap to change now, expensive after Phase 6.

### Q-17 | SERIOUS | The server can sit in a documented hard-fail state silently

* **6.1**: sustained MSPT over 40 ms in normal play is a **hard failure**.
* **6.6**: the watchdog alerts the Owner only above **48 ms sustained for 30 s**.

Between 40 and 48 ms the server is failing by its own definition and nobody is told.

**Narrowest question:** should the alert threshold move to 40 ms to match the failure definition?
Related and also missing: the watchdog has no averaging window, no hysteresis values, and no "cosmetic baseline" to halve, yet **row 22** requires each degradation step fire in order and then recover. Hysteresis is not optional - without it the ladder oscillates.

### Q-18 | BLOCKING | Every land-claim number is missing

**7.3** decides claims protect blocks and containers but never players. It supplies no claim accrual rate, no starting allowance, no minimum claim size, no maximum, no abandoned-claim reclamation threshold, and no trust-level matrix. **Rows 45 and 46** test the block-not-player rule, which is specified, but Phase 2 cannot configure the plugin without the numbers.

**Narrowest question:** may I propose a table of claim numbers scaled to a 6,000-block border and 24 players, for your approval?

### Q-19 | SERIOUS | The Admin never-grant list contradicts the Admin command list

**17.3** forbids Admins from having audit-log access, editing prices, and world editing on live worlds. **19.14** grants Admins `/audit <player>`, `/prices reload`, and `/arena reset`.

**Row 54** requires an Admin test account be "denied every node in 17.3, checked one by one" - so as written, three commands in 19.14 must fail for an Admin, which makes them useless.

**Narrowest question:** for each of the three - does the Admin keep the command, or does 17.3 win?
**My reading:** `/audit <player>` read-only is reasonable for a moderator and 17.3 likely means audit *deletion*; `/prices reload` re-reads a file the Admin cannot edit, so it is safe; `/arena reset` targets a disposable world, not a live one. But that is three judgement calls on a never-grant list, which is exactly the kind of list that should not be interpreted.

### Q-20 | SERIOUS | "Fix, do not add" versus Tier 1 in the first month

* **Section 20 Phase 9**: "**Fix, do not add.** Run one full season... before opening more widely."
* **26.2** is titled "Tier 1 - the retention engine, **first month after launch**" and lists clans, quests, a battle pass and bounties.

The first month after launch *is* the soft-launch season.

**Narrowest question:** does Tier 1 start when Phase 9's gate closes, or when the calendar month turns?
**My recommendation:** when the gate closes. Law 2 and Phase 9 both say so.

### Q-21 | SERIOUS | The proposed bounty system fires the wagering detector by design

**26.2** proposes Berry bounties on players and calls it "close to a perfect feature". **14a** defines the abuse signature as precisely "two accounts fight, one dies, the loser pays the winner within 60 seconds", and **14b** requires staged innocent payments produce zero sanctions.

Every legitimate bounty payout is a combat-correlated Berry transfer.

**Narrowest question:** if bounties ship, must bounty payouts be structurally exempt - paid from an escrow-free system account rather than player to player - so they never look like a wager?
**Note:** **14c** forbids escrow logic entirely, so the exemption cannot be built as escrow. This needs a design decision before Tier 1, not during it.

### Q-22 | BLOCKING | No plugin is ever named, but rule 9 requires pinned versions and checksums

**Appendix A** deliberately selects plugins by **category**, not brand - a defensible choice. But never-break rule 9 forbids installing any plugin "that is not in the manifest with a pinned version and a checksum", **30-5** tests the manifest, and **17.5** effectively requires permission node strings that only exist once a permissions plugin is chosen. Sections 17 and 19 contain no permission node strings at all, which makes **row 54**'s node-by-node check unrunnable as written.

**Narrowest question:** may I choose the plugin set, publish it as a manifest with pinned versions, checksums and an ARM64 load-proof for each, and have you approve the list once?
**Meanwhile:** the standing bias in AGENTS.md section 10 (prefer the boring, well-supported plugin) gives me enough to propose. I will not install anything before you see the list.

### Q-23 | SERIOUS | Law 3 has no exceptions, except the one in 3.2

* **Law 3**: "Identical price, identical access, identical capability... **No exceptions, not for donors, not for friends, not for staff.**"
* **3.2**: "Admin and staff tooling is the only permitted exception."

The derived criterion `3-3` tests for no capability differences.

**Narrowest question:** confirm the rule is "no *gameplay* advantage for anyone, and moderation tooling is not gameplay"?
**My reading:** that is clearly the intent, and it is consistent with row 55 (staff earn zero RP) and row 52 (Admins cannot roll back). Worth stating explicitly because it is a legal argument as well as a design one.

### Q-24 | SERIOUS | Acceptance 29-2 requires a local stack that Section 30 abolishes

**29-2** requires a local Docker Compose environment constrained to `cpus: "2.0"` and `memory: 3g`. **Section 30** says "**Do not build on the owner's PC. This is final**", and 29.8's deploy step 1 requires a plugin to load clean "on a fresh local server" that is not permitted to exist.

**Narrowest question:** is `29-2` void, superseded by Section 30?
**My reading:** yes - Section 30 is later, explicit and final. **Meanwhile:** I will mark `29-2` void-by-supersession in `docs/acceptance.md` rather than skip it, because 32-2 forbids quietly dropping a test.

### Q-25 | SERIOUS | Two acceptance rows require Pelican API keys that the spec forbids requesting

**29-14** and **29-15** require Pelican API keys. **29.13** states the owner will create "no Pelican API keys at all" and "Do not ask the owner for API keys", and **33.1** plus **32.3 rows 1-2** strike them out as NOT REQUIRED, superseded by root SSH.

**Narrowest question:** are `29-14` and `29-15` void, or must they be restated in terms of SSH?
**My reading:** restate them in SSH terms so the *intent* (reproducible runtime configuration) still gets tested. Marked accordingly.

### Q-26 | SERIOUS | 30.2's own dev heap breaks the rule stated in the same subsection

**30.2** offers `laughtail-dev` at 1.5 GB allocation with `-Xmx 1.0 GB` (512 MB outside the heap) or 1.0 GB with `-Xmx 768m` (256 MB outside). Both violate the rule that section itself repeats: leave at least **25 per cent or 768 MB** outside the heap. Never-break rule 4 makes this the failure mode that *freezes* rather than crashes.

**Narrowest question:** for a dev server, is the 768 MB absolute minimum waived in favour of the 25 per cent rule?
**My reading:** on a 3.8 GB box, 25 per cent is the only workable reading, so a 1.5 GB allocation with `-Xmx 1152m` (384 MB, 25%) is the closest compliant option - but it is below the stated 768 MB floor. This wants your explicit yes, because rule 4 is a never-break rule.

### Q-27 | MINOR but arithmetic | 22.13's allocation formula fails its own acceptance criterion

**22.13**: allocation is "heap **plus** at least 25 per cent". **22-8**: `-Xmx` must be at least 25 per cent **below** the allocation. A 9 GB heap plus 25 per cent gives 11.25 GB, and 9 GB is only 20 per cent below 11.25 GB - so following the formula fails the test.

**Narrowest question:** which side of the ratio does the 25 per cent apply to? `allocation = heap / 0.75` satisfies both readings; `allocation = heap * 1.25` does not.

### Q-28 | SERIOUS | drift.sh cannot tell "behind" from "hand-edited", which blocks every deploy

**29.6** and **29-7** require a drift detector that hashes tracked config on the VPS and exits non-zero on any difference. **29.8 step 0** then says "Stop if it reports drift". But a legitimate pending deploy *is* a difference, so the gate blocks the very action it precedes.

**Narrowest question:** should drift compare the VPS against the **last deployed commit** rather than the working tree, so "VPS is behind HEAD" and "VPS was hand-edited" are distinguishable?
**Meanwhile:** that is how I will build it, recording the deployed commit hash on the host.

### Q-29 | SERIOUS | 3.5.1 publishes detector thresholds; rule 10 forbids it

**3.5.1** describes the wagering detector and asks for its detail in a committed file. Never-break rule 10 and **31.10** forbid publishing detector thresholds because it teaches evasion.

**Narrowest question:** confirm all thresholds live in `docs/private/` with only the *existence* of detection published?
**Meanwhile:** proceeding that way. Proposed as deviation **D8**.

### Q-30 | MINOR | 27.3's prescribed split does not match the split it asks for

**27.3** prescribes filenames for the split, lists no file for sections **29, 30 or 33**, and names the migration file `22-migration.md`, while **29-10** and **30-6** call it `docs/06-migration.md`. **27-1** tests the split against 27.3's list, so it fails as written.

**Meanwhile:** I split by actual document structure - 43 files covering every section including 29, 30 and 33 - and verified it losslessly. That satisfies 33.4, which is the later and more specific instruction. Recorded as decision **D-0004**.

### Q-31 | MINOR | Spawn is both PvP and no-PvP

**7.2** sets "PvP on everywhere" and **7.3** states there is "no safe zone anywhere in the survival world". **7.5** gives spawn "No PvP".

**Narrowest question:** is spawn a protected region and therefore not "the survival world" for this purpose? A spawn where players can be killed on login is a bad first minute; a spawn that is safe is a place to flee to. Both are defensible; pick one.

### Q-32 | SERIOUS | online-mode must never be disabled, but the load test needs 40 bots

**6.4** and **0.3** make `online-mode=true` mandatory and never to be disabled "not for testing, not temporarily, not ever". **6.8** requires a bot load test at 10, 20, 30 and 40 concurrent clients, and **row 21** makes it a launch gate.

Offline-mode bots cannot join an online-mode server, and 40 licensed accounts is not realistic.

**Narrowest question:** is the load test run against a temporary, isolated, non-production dev server with `online-mode=false`, on the explicit understanding that the flag is never touched on `laughtail` or on any internet-reachable server?
**This is the one place I can see no compliant path**, and Phase 6's entire output depends on resolving it. Alternatives are a proxy that fakes authentication, or synthetic in-process load that does not use the network stack at all - the latter measures less but breaks no rule.

### Q-33 | MINOR | 5.6's documentation set omits the documents every session must update

**5.6** lists the required `docs/` tree and does not include `progress.md`, `owner-actions.md`, `acceptance.md`, `questions.md`, `private/` or `spec/` - all of which 27.5, 32.5 and 33.3 require. **Row 76** tests "every document in 5.6 exists", so it passes while the important files could be missing.

**Meanwhile:** I will treat 5.6 as a subset and test for the union of 5.6, 27.5 and 33.3.

### Q-34 | SERIOUS | Cosmetics are kept unconditionally and also disabled during events

* **11.1**: cosmetics cost the server "Zero. Literally none. **Keep. Unconditionally.**"
* **12.4**: during events, "Disable all cosmetics". **11.5** says particles are "off by default" while **12.3** calls them a "hard mechanical requirement".

**Narrowest question:** the distinction is presumably pack-driven animation (free, always on) versus server-spawned particles (costly, budgeted, disabled in events). Confirm that reading, because as written 11.1 and 12.4 are flatly opposed.

### Q-35 | SERIOUS | The Finale needs 32 players on a box rated for 20 to 24

**Section 23** and **12.5**: the Finale is "top 32 qualify by RP, then the Finale decides", double elimination, dragon finish. **1.4** and **6.4**: realistic healthy cap is 20-24, and `max-players` is 24.

The single most important match of the season is also the worst concurrent-combat case, and it is above the cap.

**Narrowest question:** does the Finale run in brackets small enough to fit the measured cap, or does the qualifier count drop from 32 to the cap?
**Note:** the dragon finale also loads the End on top of the survival and arena worlds. This is the highest host risk in the build.

### Q-36 | SERIOUS | Row 78's "migration script" does not exist anywhere

**Row 78** requires "The migration script has been executed successfully at least once, end to end". Section 22 is a runbook of manual steps plus two `mysqldump` calls, and names no such script. Phase 0 separately requires "database with schema migrations".

**Narrowest question:** does row 78 mean the database schema migration tool (Phase 0), or a script automating the 22.11 node transfer (Phase 8)?
**Meanwhile:** assigned to Phase 8 in the plan, flagged as a guess.

### Q-37 | MINOR | Flyway is named once and never chosen

**22.11 step 15** says "confirm the schema version matches what **Flyway** expects". **22-2** says only "the migration tool". No section selects one.

**Narrowest question:** is Flyway the choice, or an example? On ARM64 and a 4 GB box, a lighter option may be preferable.

### Q-38 | MINOR | The fifth 2FA account differs between two sections

**31.9** names the store account as the fifth; **33.6 item 4** names the host account; **31-13** demands "all five owner-controlled accounts". There are six candidates.

**Meanwhile:** `docs/owner-actions.md` **OA-23** asks for all six. Over-covering costs nothing.

### Q-39 | SERIOUS | The dynamic price band makes the hard floor unreachable

**Section 23**: "Dynamic pricing: plus or minus 35 per cent band, 25 per cent hard floor". A ±35 per cent band bottoms out at 65 per cent of base value, which never approaches a floor at 25 per cent of base. One of the two numbers is doing nothing.

**Narrowest question:** is the 25 per cent floor an absolute backstop for a different mechanism (sell-price decay under sustained dumping, per 31.5), or is the band wider than ±35 per cent?
This matters because **row 27** tests the spread "at both extremes of the dynamic band".

---

## B. Things the specification could not have known

Not contradictions - the document was written before anyone looked at this machine. All five are in `docs/progress.md` section 3 with measurements.

| # | Finding | Consequence |
| --- | --- | --- |
| **H-1** | The host is a **t4g.medium**, a burstable T-series instance | Sustained CPU work exhausts credits and throttles below the 20 TPS product requirement. Makes Phase 6's measured player cap non-reproducible. `docs/owner-actions.md` **OA-05** |
| **H-2** | The host is **arm64 / aarch64** (Graviton) | Appendix A picks plugins by category, so nothing is baked in yet - but every plugin needs an ARM64 load-proof before it is pinned. Proposed deviation **D5** |
| **H-3** | **1,458 MB RAM available** with only the stock server running; 22.3 wants a ~2.5 GB heap | Phase 0's restore drill cannot use a parallel scratch stack. Reinforces never-break rule 2 |
| **H-4** | The game container can **swap** (`MemorySwap` 3,785 MB > `Memory` 3,248 MB), plus 2 GB swapfile and 957 MB zram | A memory spike becomes a multi-second freeze rather than a clean failure. Against Law 8. Proposed deviation **D7** |
| **H-5** | **9.5 GB disk free**; the existing container is allocated **1.9 of 2 cores** | Pregeneration will not fit, and Wings, nginx and the Panel are left 0.1 core. `docs/owner-actions.md` **OA-04** |

---

## C. Where the rest is

This file holds what changes a build decision. The complete raw findings - every acceptance criterion catalogued per section, all 117 contradictions with both sides quoted, all 254 ambiguities with a narrowest resolving question each, plus per-section dependency and host-risk lists - are in `docs/spec/.findings/G1.md` through `G9.md`.

They are working notes, not deliverables, and they are noisier than this file. But nothing was discarded, and if a question here looks under-argued, the quoted source is there.
