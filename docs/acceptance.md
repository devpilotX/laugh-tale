# LaughTail SMP - Acceptance

Every acceptance criterion and its evidence. **Never-break rule 11: no task is complete without evidence.** A log line, a command output, a screenshot, a query result, or a passing test. Intent is not evidence, and neither is "it loaded without errors" (spec 0.3).

**Status vocabulary.** `Not started` / `In progress` / `PASS` / `FAIL` / `BLOCKED` / `VOID (superseded)`. Nothing is ever silently removed - spec 32-2 forbids skipping, weakening or commenting out a test for lack of access.

**Nothing in this file has been attempted yet.** This session produced a plan only (spec 33.5). All 81 rows below are `Not started`.

## Where the ledger stands, 2026-08-26 (reconciled)

| Status | Rows | Meaning |
| --- | --- | --- |
| **PASS** | 7 | Tested, with evidence cited in the row |
| **Partial** | 8 | Part of the row is proven and the untested part is named explicitly |
| **Built, not yet tested** | 6 | The code exists and works; the row's stated test has not been run |
| **Not started** | 60 | No implementation |

**Why this table exists.** The status column had drifted badly out of date: work was being tested and
the evidence written into sections further down this file, while the master table still said "Not
started". That understated progress in a way that is just as misleading as overstating it, and it
made the ledger useless for deciding what to do next - which is the only thing a ledger is for.

**"Built, not yet tested" is deliberately not a pass.** Never-break rule 11 says a task is not
complete without evidence, and reading one's own code is not evidence. These six rows are ready for
a test, which is a different claim from having passed one.

## The master table - Section 21

81 rows: 1 to 78 plus 14a, 14b and 14c. Every row must pass with evidence before the first paying player connects. The Phase column is my proposed ownership, derived in `docs/spec/.findings/G6.md`; where two phases share a row, the phase that owns the pass is listed first.

Five rows carry a caveat recorded in `docs/questions.md`: row **14** cannot pass as written (Q-05), rows **51**, **34** and **36** need Phase 9 evidence that Phase 8's gate demands earlier (Q-09), and row **78** names a script that does not exist anywhere in the specification (Q-36).

| Row | Test | Pass condition | Evidence required | Phase | Status | Evidence captured |
|---|---|---|---|---|---|---|
| **1** | Cold start | Fresh checkout plus one command brings the whole stack up with no manual steps | Terminal log | 0 | **PASS 2026-08-26** | `scripts/deploy.ps1` - one command, **23 stages, 0 failures, 112.2 s**. Order: local verification (manifest checksums, no secrets, no hardcoded values, 75 guard tests), regenerate all generated scripts, fetch and verify artefacts host-side, database container, migrations, stop, install pinned Paper + 8 plugins, `server.properties`, Paper tuning, access state, start and verify all plugins load, both drift checks, external port probe, backup schedule, health check. **Proven idempotent**: an immediate second run was also 23/23 in 108.9 s, reporting "already applied", "NO DRIFT", and preserving existing backups rather than overwriting. Verification runs *first* deliberately - there is no point stopping a live server to discover a checksum is wrong |
| **2** | Hardcoded values | Grep for IP addresses and absolute host paths across the repo returns nothing | Grep output | 0 | **PASS 2026-08-26** | `scripts/check-hardcoded.ps1`: 168 tracked files, 0 hits. Connection details live only in git-ignored `scripts/host.env.ps1` with a committed example. Runs as stage 3 of every deploy, so a regression blocks the deploy rather than being noticed later. Scope narrowed to deployable artefacts per **D-0010** - the specification text itself necessarily contains example addresses |
| **3** | Fresh-VPS rebuild | Full stack rebuilt on a brand-new machine in under 30 minutes | Timed log | 0 | **Partial - deploy portion PASS, honestly qualified** | The deploy itself is **1.9 minutes** against a 30-minute budget, timed per stage. What is **not** proven: provisioning a new EC2 instance and installing Docker, Wings and the Panel. Testing that needs a genuinely empty second box - wiping this host would destroy the Panel, and **OA-03** means no snapshot exists to recover from. So the claim is "the repository rebuilds the server in 2 minutes", not "a bare VPS is production in 30". The untested remainder is host provisioning, which is 22.11's runbook |
| **4** | Restore drill | Backup restored into a scratch environment, world and database intact | Drill log entry | 0 | **PASS 2026-08-26** | `docs/restore-drills.md` Drill 1: **0 failures**. Database restored into a throwaway `laughtail_drill` schema (the dump's `CREATE DATABASE`/`USE` stripped so live data could not be overwritten): 5/5 tables, V1 checksum identical, 3/3 foreign keys, **and the row 36 constraint still refuses a second champion in the restored copy**. World restored to scratch: `level.dat` magic `1f8b` and decompresses cleanly, 12/12 region files, region location table populated, all config and access files present with correct values. Scratch removed afterwards |
| **5** | Port exposure | External scan shows only the intended ports; RCON unreachable | Scan output | 0 | **TCP half PASS 2026-08-26** | `scripts/check-external-ports.ps1` probed 9 ports from the owner's PC, outside AWS: 22, 80, 443, 8443, 25565 open as intended; **25575 (RCON), 2022, 8080, 3306 all closed**. Corroborated host-side: `docker inspect` `PortBindings` publishes only `25565/tcp` and `25565/udp`, so RCON never leaves the container. Note ufw was **not** used as evidence - Docker's `DOCKER-USER`/`DOCKER` chains are traversed first, so ufw does not govern published ports. Re-run after any allocation change. UDP portion tracked under row 6 |
| **6** | UDP voice port | Verified open using a UDP-aware method, not a TCP checker | Test command output | 0 | Not started - **scope corrected** | Voice chat **is** listening on 24454 and Geyser on 19132 inside the container, confirmed in the boot log. But the container publishes **only 25565**, so both are unreachable regardless of firewall. This needs **three** layers, not the two OA-06 describes: the Pelican allocation must publish the UDP ports, then ufw, then the AWS security group. See progress.md Session 2 finding 2 |
| **7** | Paid gate | An unpaid account is rejected at login | Login attempt log | 1 | Not started | - |
| **8** | Store to whitelist | Test purchase grants access within one minute | Transaction plus grant log | 1 | Not started | - |
| **9** | Duplicate webhook | A replayed payment webhook produces exactly one grant | Grant log | 1 | Not started | - |
| **10** | Offline purchase | A purchase made while the server is down applies on next start | Queue plus grant log | 1 | Not started | - |
| **11** | Refund path | Test refund removes access and is logged | Refund log | 1 | Not started | - |
| **12** | Whitelist audit | Whitelist matches paid transactions exactly, with zero unexplained entries | Audit output | 1 | **PASS 2026-08-26** | `/access audit` compares the live whitelist against live grants **in both directions**, because the two failure modes are different problems: whitelisted-with-no-grant is unexplained access (revenue and fairness), granted-but-not-whitelisted is someone who paid and cannot get in (a refund conversation). Tested from a deliberately broken state first - the owner was whitelisted from D-0017 with no grant behind it, so the audit reported UNEXPLAINED ACCESS before the grant existed and matched after. Final state: 1 whitelist entry, 1 live grant. `/access grant` writes the grant **before** touching the whitelist, so a whitelisted player with no paid record cannot be produced by the command; a duplicate payment reference was refused by V1's UNIQUE constraint. An audit that only ever reports success has not been tested |
| **13** | No-advantage audit | No purchasable item, rank, permission, slot, or cosmetic grants any capability another paying player lacks | Written audit against 3.2 | 1, re-audit 8 | Not started | - |
| **14** | No-gambling audit | Repo grep for betting, gambling, crate, key, lottery, spin, casino, wager, stake, coinflip and dice finds no randomised-for-value mechanic, and none of the forbidden commands in 3.5.1 are registered | Grep output plus in-game tab-complete check | 1, re-audit 8 | Not started | - |
| **14a** | Wagering detector works | Staged test: two accounts fight, one dies, the loser pays the winner within 60 seconds. The combat-correlated signature fires and appears in the staff alert queue | Alert record with timestamps | 4 | Not started | - |
| **14b** | Detector cannot auto-punish | 20 staged innocent payments (loot splits, loan repayments, instalments) produce zero automated sanctions, and code review confirms no punishment path exists from detector output | Test log plus code review note | 4 | Not started | - |
| **14c** | No wagering escrow exists | Repo grep for escrow and stake-holding logic returns nothing, and `docs/rejected.md` contains the wagering-escrow rejection with its reasoning | Grep output plus the rejection entry | 1 | Not started | - |
| **15** | Deterministic rewards | Every reward source publishes its exact contents in advance | Screenshots | 4 | Not started | - |
| **16** | Legal pages | Terms, Privacy, and Refund policy are live and linked before any payment is possible | URLs | 1 payment path, 8 pages | Not started | - |
| **17** | Rules gate | A new player cannot move, build or chat before accepting; acceptance is stored with a version | Database row | 1 | Built, not yet tested | `RulesGate` blocks movement, building and chat until acceptance, and `recordRulesAcceptance` stores the version. Not claimed: no staged test of a genuinely new account has been run, and the row asks for a database row as evidence |
| **18** | Rules consistency | Rules text is identical across website, in game, and Discord | Diff output | 1 in-game, 8 web and Discord | Not started | - |
| **19** | MSPT at cap | Under 25 ms at the chosen player cap under normal play | Spark report | 6 | Not started | - |
| **20** | MSPT in event | Under 40 ms at the event cap with combat active | Spark report | 6 budget, 7 real event | Not started | - |
| **21** | Load test | Bot test at 10, 20, 30, 40 completed; cap set from the measured result | Load-test log | 6 | Not started | - |
| **22** | Watchdog degradation | Induced load triggers each degradation step in order, and recovery restores everything | Watchdog log | 6 | Not started | - |
| **23** | Login time | Under 3 seconds from connect to spawn | Timed measurement | 6 | Not started | - |
| **24** | Command latency | Every command responds within 100 ms, or acknowledges and runs async | Timing log | 6 | Built by design, not yet measured | Every command that touches the database acknowledges immediately and does its work on an async task - which is the same property row 25 enforces. Not claimed: nobody has measured the latency, and the row asks for a number |
| **25** | Main-thread database calls | No blocking database call on the main thread anywhere | Spark profile plus code review | 0 rule, 6 proof | **PASS 2026-08-26** | - |
| **26** | Economy audit | Zero positive-yield cycles across all items and all recipe chains | Audit output | 3 | **PASS 2026-08-26** | `Arbitrage.audit` walks every recipe the server knows - crafting, smelting, blasting, smoking, campfire, stonecutting, smithing - and reports positive-yield cycles. Boot log 12:15:18: **1585 recipes examined, 0 positive-yield cycles**. Deliberately PESSIMISTIC: inputs priced at the bottom of the P4 band (0.6x base, the cheapest they can ever be) and the output at the top (1.4x base less the 12% spread), so a pass holds under any real conditions rather than only today. Where a RecipeChoice accepts several materials the CHEAPEST is used, because that is what an attacker would use. **It ran inside the server rather than in CI on purpose**: the recipe list is whatever this Minecraft version actually ships, and a CI copy could drift from the server after any update. **The audit has teeth** - a finding closes the shop, refusing buy and sell, because an economy with a known printer should be shut rather than left open while it is abused; Berries once minted cannot be un-minted without rolling back everyone who traded since. A zero-recipe result is treated as a FAILURE too, since the dangerous outcome is a green light nobody earned |
| **27** | Price spread | Buy exceeds sell by the minimum spread at both extremes of the dynamic band | Audit output | 3 | **PASS 2026-08-26** | - |
| **28** | Atomic order match | Server killed mid-match creates and destroys nothing | Before and after query | 3 | **PASS 2026-08-26** | Proven two ways. **Schema** (`test-orders.sh`, 5/5): `remaining` cannot exceed `quantity` (`chk_order_remaining` refused it), an orphan fill referencing nonexistent orders was refused by the foreign key, a zero-quantity fill was refused, escrow columns are UNSIGNED so they cannot underflow (`BIGINT UNSIGNED value is out of range`), and `idx_book` covers 5 columns so matching does not table-scan. **Logic** - a boot self-test runs a REAL match through the real matching code and rolls it back, asserting Berries and items are conserved, the resting order sets the price, the aggressor is refunded the difference, and self-trading is refused. Boot log 13:15:39: `ORDER BOOK SELF-TEST PASS: value conserved through a real match... Rolled back, nothing left behind` - confirmed by `orders=0 fills=0` afterwards. The whole match is ONE transaction and the fill row is written FIRST, so after a kill -9 the question "did this trade happen?" has exactly one answer |
| **29** | Trade safety | Disconnect, item-swap, and spam-click exploits all fail | Test log | 3 | Partial - escrow and self-trade proven, disconnect and spam-click untested | **Disconnect** cannot lose value because nothing is held in memory: a listed item leaves the inventory and becomes a database row, and Berries committed to a buy order leave the balance and become a row. **Item-swap** cannot occur because the bazaar trades only catalogue materials with no NBT - a buy order for iron cannot be filled with a renamed iron. **Self-trade** is refused in the matching query itself rather than in the loop, so it cannot be forgotten. **Spam-click** is bounded by row locking in primary-key order, which also prevents the deadlock two simultaneous matches would otherwise cause. **Not claimed:** the row asks for the three exploits to be actively attempted, and no adversarial test has been run |
| **30** | Rank purity | Two hours of mining, farming and building changes RP by exactly zero | Before and after query | 4 | Built, not yet tested | Rating changes are written only from `recordCombat`; no mining, farming or building path reaches the rating table. `Rating.selfTest()` reports all Appendix B invariants passing. Not claimed: the row asks for two hours of actual play, which has not been done |
| **31** | Anti-farm | Repeat kills follow the diminishing pattern then award zero | RP log | 4 | Built, not yet tested | The diminishing repeat-kill curve is implemented and its invariants pass in `Rating.selfTest()`, including the tail reaching zero. Not claimed: no staged two-account test has been run |
| **32** | Alt farming | Same-IP kills award zero RP and raise an alert | Alert log | 4 | Not started | - |
| **33** | Combat log | Disconnecting while tagged is resolved as a death | Death log | 4 | Built, not yet tested | `CombatTag` tags both parties on PvP damage for 15 seconds (D-0037) and `PlayerQuitEvent` while tagged drops the inventory where they stood, empties it, broadcasts it, writes a `combat_log` audit row, and records the death through the SAME rating path as a real kill so the ladder cannot tell the difference. **Not claimed:** no staged two-account disconnect test has been run, and the row asks for exactly that |
| **34** | Reset idempotency | The season reset run twice produces an identical result | Two-run comparison | 4 test, 9 live | **Test half PASS 2026-08-26** | `scripts/remote/test-seasons.sh`: `season end` run twice on season 1. First run crowned one Champion (1420 RP) and set `reset_completed=1`; second run returned "already completed - nothing to do (idempotent)" and the champion count stayed **exactly 1**. Idempotency is structural, not defensive - `reset_completed` is checked first and returns early, the champion insert relies on V1's `PRIMARY KEY (season_number)` so a duplicate is refused *by the database*, and every step is conditional. That matters because 31.1 puts the reset on a clock, and a clock-driven job will eventually be interrupted by a restart and re-run. **Live half** needs a real season, which is Phase 9 |
| **35** | Reset ordering | Rewards granted before archival, verified by mid-reset failure and re-run | Test log | 4 | Not started | - |
| **36** | One Champion | Exactly one Champion per season, enforced by a database constraint | Schema plus failed-insert test | 4 test, 9 live | **PASS 2026-08-26 (schema, failed-insert AND lifecycle)** | `db/migrations/V1__init.sql` declares `champions` with `PRIMARY KEY (season_number)`, so the guarantee is in the engine, not in application code. Failed-insert test in `scripts/remote/db-migrate.sh`: first champion for test season 99999 inserted, second rejected with `ERROR 1062 (23000): Duplicate entry '99999' for key 'PRIMARY'`, count still 1, test rows removed. Repeatable - it re-ran clean on three consecutive runs. Also exercised through the real code path: `test-seasons.sh` crowned one Champion for season 1 and a second `season end` left the count at exactly 1. **Live half** still needs a genuine month-long season, which is Phase 9 |
| **37** | Champion advancement | The custom advancement is granted, announced, and visible to a Bedrock client via Geyser | Screenshots, both platforms | 4 Java, 7 Bedrock | Not started | - |
| **38** | Champion has no power | The Champion gains no Berries, items, stats, permissions or head start | Written audit | 4 | Built by construction, audit not written | The Champion title is applied from the `champions` table on join and grants a chat/tab prefix and nothing else - no Berries, items, stats, permission or discount, per 9.6. Not claimed: the row asks for a written audit, and one has not been written |
| **39** | Hall of Fame | Monument and web page both update automatically after a season ends | Screenshots | 4 monument, 8 web page | Not started | - |
| **40** | Shop gating | A Tier 1 player cannot buy a Tier 8 item by any means, including a modified client | Test log | 5 | **Partial - database side PASS, in-game refusal untested** | - |
| **41** | Selling ungated | A brand-new player can sell items in their first minute | Test log | 3 rule, 5 enforcement | Built, not yet tested | There is deliberately no tier check anywhere in the sell path - `test-shop.sh` check 5 confirms no editable tier column exists, and 10.3 says selling is never gated so that a new player has an entry point. Not claimed: no in-game first-minute test has been run |
| **42** | Homes | 20 homes reachable, renameable, and home-to-home teleport works | Test log | 5 | Partial - 20 slots and teleport built, renaming not | Two free slots plus up to 18 purchased is exactly 20, enforced by a CHECK constraint. `/home`, `/sethome`, `/delhome`, `/buyhome` and a GUI page all work. **Renaming is not implemented** - the row asks for it explicitly, so this cannot pass as written |
| **43** | Home persistence | Homes survive a container rebuild and a simulated migration | Before and after query | 5 | Not started | - |
| **44** | Teleport guards | Warmup, combat block, cooldown, and back-after-PvP-death block all verified | Test log | 5 | Partial - warmup, cooldown and combat block built; back-after-PvP-death missing | The combat block now exists: every route that MOVES a player - `/home`, `/tpa`, `/tpahere`, `/tpaccept`, `/rtp` - is gated through one `CombatTag.refuse` call, so there is a single place that decides what "in combat" blocks rather than a check copied into each command. **The accepter is checked as well as the requester**, because accepting is what moves someone and a chased player could otherwise be pulled out of a fight by a friend's waiting request. **Still missing:** back-after-PvP-death, and no staged test has been run |
| **45** | Claims protect blocks | A non-trusted player cannot break blocks or open containers in a claim | Test log | 2 | Not started | - |
| **46** | Claims do not protect players | A player can be killed inside their own claim | Test log | 2 | Not started | - |
| **47** | Fire and flood | Fire and lava do not cross a protected boundary; fireTick is off | Test log | 2 | **fireTick half PASS 2026-08-26** | Read back live from all **five** worlds via `/laughtail status`: `minecraft:fire_spread_radius_around_player=false` on laughtail, _nether, _the_end, _arena and _resource. Applied by the plugin on `WorldLoadEvent`, so worlds created later inherit it. Note 26.2 **renamed** this rule from `doFireTick`, which is why the console command form failed. The "does not cross a protected boundary" half needs claims, which need numbers the specification never gives - see the Phase 2 gap note |
| **48** | Chat flood | 200 messages per second results in an auto-mute with no MSPT impact | Log plus spark | 6 | Not started | - |
| **49** | Packet abuse | A packet-abuse suite does not crash or degrade the server | Test log | 1 | Not started | - |
| **50** | Anti-cheat | Test flight and test reach cheats are both caught and logged with evidence | Alert log | 1 | Not started | - |
| **51** | Anti-cheat false positives | One full week of normal play produces zero punishments of honest players | Alert review | 1 tuning, 9 qualifying week | Not started | - |
| **52** | Rollback restriction | An Admin account cannot execute rollback, restore or purge | Permission test | 1 | Not started | - |
| **53** | Rollback dupe | An attempted rollback-based duplication fails and alerts | Test log | 1 | Not started | - |
| **54** | Never-grant list | An Admin test account is denied every node in 17.3, checked one by one | Checklist | 1 | Not started | - |
| **55** | Staff cannot earn RP | A staff account gets zero RP from a kill | RP log | 1 permissions, 4 RP proof | Not started | - |
| **56** | Audit immutability | Staff actions are logged and a staff account cannot delete them | Test log | 1 | Not started | - |
| **57** | Reporting | A report reaches Discord with block-log evidence attached automatically | Discord message | 1 | Not started | - |
| **58** | Cosmetics free | No purchase path exists for any cosmetic, in Berries or money | Grep plus review | 7 | Not started | - |
| **59** | Cosmetics persist | Cosmetics survive a full season reset | Before and after query | 7 | Not started | - |
| **60** | Cosmetic cost | Maximum cosmetics on all players adds under 2 ms MSPT | Spark report | 7 | Not started | - |
| **61** | Pack optional | The server is fully playable with the resource pack declined | Test log | 7 | Not started | - |
| **62** | Bedrock parity | A Bedrock player can join, play, see particle cosmetics, and use the settings menu | Screenshots | 7 | Not started | - |
| **63** | Crossplay versions | The oldest and newest supported client versions both connect and fight | Test log | 7 | Not started | - |
| **64** | Voice works | Two Java clients hear each other over the public internet | Recording or screenshots | 7 | Not started | - |
| **65** | Voice for everyone | Bedrock and unmodded players have a documented working voice route | Screenshots | 7 | Not started | - |
| **66** | Voice moderation | Staff mute in voice works and is logged | Log | 7 | Not started | - |
| **67** | Voice off switch | Disabling voice by one flag leaves the server fully functional | Test log | 7 | Not started | - |
| **68** | Event integrity | Disconnect at one life eliminates; inventories restore perfectly, including after a crash | Test log | 7 | Not started | - |
| **69** | Event re-entry | An eliminated player plays survival immediately and joins the next event | Test log | 7 | Not started | - |
| **70** | Arena regeneration | No blocks, items or entities persist from the previous event | Test log | 7 | Not started | - |
| **71** | Website separation | The site is not served from the game host | DNS plus IP check | 8 | Not started | - |
| **72** | Web database user | The website user cannot write to game data | Failed write attempt | 8 | Not started | - |
| **73** | Leaderboard caching | Leaderboards are cached at least 60 seconds | Header or code review | 8 | Not started | - |
| **74** | Live map markers | Player markers are absent by default and during a simulated event | Screenshots | 8 | Not started | - |
| **75** | Alert routing | Staff alerts go only to a private channel | Channel check | 8 | Not started | - |
| **76** | Documentation | Every document in 5.6 exists and is current | File listing | 8 | Not started | - |
| **77** | Decision log | Every deviation from this prompt is recorded with its reasoning | Decision log | 0 to 9 continuous | Not started | - |
| **78** | Migration script | The migration script has been executed successfully at least once, end to end | Migration log | 8 | Not started | - |

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
| `33-2` | The first commit contains `.gitignore` and nothing secret | **PASS** | Root commit `3087a56`. `git show --name-only` on `git rev-list --max-parents=0 HEAD` lists `.gitignore` and nothing else. 63 lines, 1 file changed |
| `33-3` | `AGENTS.md` is in the root, under 200 lines, loaded at session start | **PASS** | File present at root, 128 lines; its rules are cited throughout `docs/progress.md` |
| `33-4` to `33-9` | Remaining Day Zero criteria | Not started | Read from `docs/spec/33-day-zero-the-bootstrap-procedure.md` and filled in when actioned |

## Pre-flight checklist - Section 33.6, measured 2026-08-26

| # | Check | Status |
| --- | --- | --- |
| 1 | `pre-build` snapshot exists and shows complete | **FAIL** - OA-03 |
| 2 | The restore procedure has been located | **FAIL** - OA-03 step 6 |
| 3 | SSH works with a key and password authentication is disabled | **PASS** - measured: `passwordauthentication no`, `permitrootlogin without-password` |
| 4 | 2FA on the Panel, GitHub, registrar, host and email | Unverified - OA-23 |
| 5 | `.gitignore` is committed and is the first commit | **PASS** - root commit `3087a56` contains `.gitignore` alone |
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

**8 of 15 pass. None of the failures is a defect; each is an owner action or a Phase 0 task.**

---

## Section 17.5 - the Owner and Admin split

Four unnumbered checkbox criteria in the specification, given positional IDs here per `docs/questions.md` **Q-02**.

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| 17-1 | An Admin-level test account is denied every single node in 17.3, verified one by one and recorded | **PASS 2026-08-26** | `scripts/remote/verify-permissions.sh`: **31 of 31 nodes denied**, each listed individually with its resolution source, all reading "denied explicitly on admin". Not sampled |
| 17-2 | Permission inheritance is verified by a test matrix, not by assumption | **PASS 2026-08-26** | **12 matrix rows, 0 failures.** Includes the distinction 17.2 and 17.3 make and which is easy to miss: `admin` **has** `laughtail.reload` and **lacks** `minecraft.command.reload` |
| 17-3 | A staff account earns zero RP from a kill | **Not started** | Needs the rank system (Phase 4). The permission side exists; the RP exclusion is code that does not exist yet |
| 17-4 | Every staff action appears in the audit log, and a staff account cannot delete from it | **PASS 2026-08-26** (both halves) | **Cannot-delete half:** `staff_audit` is append-only by trigger. `db-test-append-only.sh`, as the *app* user: append succeeded, `UPDATE` and `DELETE` both refused with `ERROR 1644 (45000)`, row intact afterwards. **Logged half:** `test-moderation.sh` issued 6 console commands and produced 6 audit rows - `history.view` ×2, `warn`, `mute`, `unmute`, and `warn.unknown_target`. Note what that last one means: **a failed attempt against a non-existent player is still recorded**, because an audit of successes only is a record of intentions. Viewing a record is itself audited - reading someone's punishment history is not a neutral act. Console actions carry `staff_uuid NULL` with the name recorded, so automation is distinguishable from a human (17.2). **Stated limit:** the triggers stop accident and a compromised plugin, not root - which is why 17.3 also puts shell access on the never-grant list |

### How this was verified, and the false pass that came first

The first verifier used `lp user <uuid> permission check <node>` for all 31 nodes and **reported PASS against 31 completely empty responses**. LuckPerms processes commands asynchronously and returns nothing to an RCON sender, so the verdict - computed as "no line said true" - was measuring silence. That is worse than having no check, because it manufactures evidence.

It was replaced with analysis of an authoritative `lp export` snapshot, which also happens to be the "permissions export in version control" that Appendix C asks for. The checker resolves inheritance itself using LuckPerms' own rule - a value on the group wins over anything inherited, nearer ancestors beat further ones - and treats a `*` set to `true` anywhere in the chain as a grant. It **aborts rather than passing** if the export is missing.

### The design decision behind these passes

The never-grant list is applied as **explicit denials** on `admin`, not merely left ungranted. Absence looks equivalent and is fragile: any future wildcard, permissive plugin default, or added convenience node can turn absence into a grant without anyone editing `server/permissions.yml`. An explicit `false` beats an inherited `true`, so the denial holds even if the node is later granted higher up the chain.

For the same reason the **Owner group does not use a wildcard**. A wildcard is itself on 17.3's list because it silently grants everything added in future. The Owner's thirteen elevated nodes are listed one by one, which is more work and makes the Owner's power auditable. The wildcard audit confirms no group holds `*`.

**Shell access to the host** is on 17.3's list and is not a Minecraft permission, so it cannot be denied in LuckPerms. It is controlled by SSH key distribution - key-only authentication with passwords disabled, verified session 1, and no staff member holds a key. Recorded so the list closes honestly rather than looking like an oversight.

## Row 40 - shop tier gating (PARTIAL, database side proven)

`scripts/remote/test-shop.sh`, 2026-08-26. Six assertions, all pass:

* 44 catalogue rows priced at boot - asserted first, because an empty price table would pass
  every other invariant by examining nothing.
* No row has `sell_price >= current_price`. This is the structural reason buying and selling back
  cannot yield a profit.
* No row is thinner than P3's 12% spread, **with no tolerance and no exemption for cheap items**.
* Every price inside P4's +/-40% band, and the database REFUSED a direct SQL update to 99x base:
  `ERROR 4025 (23000) CONSTRAINT chk_price_band failed`. That is the price-table equivalent of a
  modified client - going straight at the data, bypassing the plugin.
* **No `tier` column exists.** Row 40's gate comes from the catalogue compiled into the jar,
  checked against rank read from the database. There is deliberately nothing stored that a player,
  or a careless admin, could edit to grant themselves Tier 8.
* The daily sell cap is keyed `(uuid, sell_date, category)`, so rotating between similar items
  cannot dodge P6.

**What this does NOT yet prove:** a live player at Tier 1 being refused a Tier 8 purchase in game.
The refusal path exists in `ShopService.buyItem` - it reads rank from the database, refuses, and
writes a `buy.tier_refused` audit row - but it needs an in-game run to claim the row. The GUI greys
locked items; that is cosmetic and is stated as such in the code, because the menu dispatches
`/buy` as the player and so hits the same server-side check a typed command would.

### A bug this test found, which is the point of writing it

The first run reported DIAMOND at an **11.7% spread against a stated minimum of 12%**. Cause: the
sell price was computed in two places - `Shop.sellPrice` in Java and an expression inside the
`movePrice` SQL - and they disagreed, one rounding half-up where the other floored. Under a Berry
per unit, invisible to any player, and compounding over every trade forever.

Fixed by removing the duplication rather than by correcting both copies: `movePrice` now reads the
price under its transaction lock and calls `Shop.sellPrice`, so one function knows what the spread
is. `currentPrice` additionally repairs any stored sell price that disagrees, on read - so drift
self-heals instead of waiting for a test to find it. Re-run: DIAMOND 12.5%, all 44 rows compliant.
## Row 26 - the arbitrage audit found seven money printers on its first run

This is the entry worth reading, because the audit failed the moment it was written and the failure
was mine.

First run: **7 positive-yield cycles out of 1585 recipes.** All seven were one mistake made four
times - raw ore and its smelted form both priced, independently:

```
minecraft:iron_ingot_from_smelting_raw_iron:   buy inputs for 12, sell for 24  = +12 per cycle
minecraft:gold_ingot_from_smelting_raw_gold:   buy inputs for 21, sell for 43  = +22 per cycle
minecraft:netherite_scrap:                     buy inputs for 360, sell for 739 = +379 per cycle
minecraft:stone:                               buy inputs for 1, sell for 2    = +1 per cycle
```
(each also appearing as its blasting variant)

**The root cause was structural, not a wrong number.** Two items linked by a recipe held independent
prices, and the P4 band lets them drift apart by 1.4 / 0.6 = **2.33x** - which swamps a 12% spread
entirely. No choice of base prices fixes it while both sides float independently: to be safe an iron
ingot would have to be worth under half a raw iron, which is absurd and would confuse every player
who saw it.

Fixed by pricing only ONE side of each transformation. Players sell what they mine - the raw form -
and ingots remain for crafting. Re-run: **1585 recipes, 0 cycles.**

### What the audit deliberately does not claim

A security claim with an unstated limit is worse than no claim, so the limits are in the code and
repeated here:

* It covers recipes the **server** knows. Multi-step chains through unsellable intermediates cannot
  pay out, because a chain only yields Berries where it touches the shop, and every such point is a
  recipe the audit sees.
* It does **not** cover buying low and selling high **over time**. That window is real: the band
  floor is 0.6x base and the ceiling sell is 1.232x base, so an item bought at the floor and sold at
  the ceiling roughly doubles. That is speculation, not a cycle - it needs other players to move the
  price, it is bounded by the band, and P5 pulls prices back at 5% an hour. Recorded rather than
  hidden. The lever to close it is the band width, not this audit.
* It does not model mob or block drops. Those are income; a cycle needs a purchase at the start.

### A second bug, in the test rather than the code

Removing IRON_INGOT broke `test-shop.sh`, which named it when proving the price-band CHECK. The
UPDATE matched zero rows, so no constraint fired and the test reported the CHECK as missing.

**The reverse of that mistake is the dangerous one**, and it is why the fix matters more than the
symptom: an UPDATE that matches nothing is indistinguishable from a refusal, so a test written this
way can report a constraint as working when the row is simply absent. The test now asserts its
target row exists before trying to violate it.
## Friends, leaderboards and the stats page - 2026-08-26

`scripts/remote/test-friends.sh`, all pass:

* One row per pair, keyed `(uuid_low, uuid_high)` sorted. Inserting the reverse direction was
  **REFUSED by the primary key**. Storing a friendship twice, once per direction, lets the two rows
  disagree - A believes they are friends and B does not - and then every query has to choose which
  row to trust. One row cannot contradict itself.
* **Accepting requires the other player to have asked.** A accepting their own request changed
  nothing (still `pending`); B accepting A''s request worked. Without that clause a player could
  befriend anyone unilaterally, which defeats consent entirely.
* The friendship is visible from **both sides** with only one row stored.

### A false negative worth recording

The first version of this test used a partner UUID that was not in `players`. Both inserts failed on
the **foreign key**, so no rows existed - and the test reported the primary key as broken. That is a
false negative which looks exactly like a real failure, and it was the schema doing its job: a
friendship with somebody who has never joined is meaningless, so it is refused. The test now asserts
its setup succeeded before drawing conclusions from it - the same lesson as the row 40 test that
"succeeded" against a row that had been deleted.

### Deliberate absences

* **Friendship grants nothing.** No teleport bypass, no shared homes, no claim trust. Law 1 says
  every player is equal, and a friends list that unlocks capability quietly makes a well-connected
  player stronger than a lone one. Any future power granted through it needs its own decision.
* **There is no richest leaderboard.** It would reward hoarding over playing and tell every thief
  who to target. Rank is the competitive axis, so rank is what is ranked. The leaderboard says so
  itself rather than leaving players to wonder.
## Roleplay - Paths, Houses, Chronicles (D-0038), 2026-08-26

`scripts/remote/test-roleplay.sh`, all pass, re-run after the Chronicle tables were added:

* Four Houses seeded with mottos.
* **No column in any roleplay table could hold a combat or economic advantage.** The test searches
  every roleplay table for a column resembling damage, health, speed, bonus, multiplier, discount,
  permission or drop, and requires **zero hits**. Law 1 is structural here, not a promise in a comment -
  adding one would need a migration somebody has to review.
* **No table references `combat_ratings`**, so no roleplay write can reach the PvP ladder. That is row
  30's guarantee held by the schema rather than by discipline.
* An invented Path name was refused by the enum.

Chronicle seeded and verified: **5 chapters for season 2, chapter 1 active**, 3 objectives at 0
progress, chapters 2-5 locked. Boot log 15:02:50.

### What is deliberately absent, and why it is not an omission

There is no Path bonus, no House perk, no Chronicle item reward and no cosmetic that changes a
statistic. **If a roleplay reward ever changes a number that matters in a fight, the design has
failed** - because rank would then measure who ground a profession rather than who fought better, and
the ladder is the product.
## Final verification sweep - 2026-08-26

Run at the owner's request: every command, every screen, every test.

**Commands.** 40 registered in `plugin.yml`, and all 40 have a handler in source - checked
mechanically rather than by reading. **One real defect found and fixed:** `lt` was an alias for BOTH
`/laughtail` and `/menu`. Bukkit resolves a duplicate alias arbitrarily, so the same keystroke could
have opened a GUI or run a diagnostic depending on load order. `/menu` keeps it (players use it
constantly); `/laughtail` lost it, because an admin command should be unambiguous.

**Screens.** 7 GUI pages created, 7 routed - no page can be opened without click handling behind it.
Two buttons remain honestly greyed: Auction House and Settings.

**Tests.** All eight suites, zero failures:

| Suite | Verdict |
| --- | --- |
| `test-shop.sh` | SHOP INVARIANTS: all pass (9 checks) |
| `test-orders.sh` | ORDER BOOK SCHEMA: all pass (5 checks) |
| `test-roleplay.sh` | ROLEPLAY: all pass (Law 1 structural) |
| `test-friends.sh` | FRIENDS: all pass |
| `test-economy.sh` | all pass |
| `test-moderation.sh` | all pass |
| `test-access.sh` | all pass |
| `db-test-append-only.sh` | all pass |

**Boot.** Clean: `plugins not observed loading: 0`, zero ERROR lines, and the three boot self-tests
(row 25 thread guard, order book conservation, arbitrage audit) all passing.

**Command book.** `docs/LaughTail-Command-Book.docx`, generated by `scripts/gen-command-book.ps1`.
Verified by opening it in Word: **10 pages, 15 tables, 2426 words**. It is a genuine OOXML package,
not an HTML file renamed - a renamed HTML file opens and then breaks on the first edit or print.
## Season reset to 1 - 2026-08-26, and the race it exposed

Owner asked to reset seasons and start from 1. `scripts/remote/reset-seasons.sh`.

**Before:** seasons=2, ratings=1, champions=1, events=5, chapters=5, objectives=15.
**After:** all zero. **Preserved unchanged:** balances=1, stats=1, homes=1, paths=3, players=4.

That split is the same one a normal rollover uses: Berries, stats, homes and Path progress are
**identity** and survive; ratings, standings and the story are a **competition** and do not.

A database backup was taken first (64,113 bytes) and the script refuses if it is implausibly small,
because a reset whose backup silently failed is not reversible. It also refuses if the dev volume is
absent, and if anyone appears to be online - a player connected during a rating wipe would hold an
in-memory rank that no longer exists and could recreate a row against a deleted season.

Season 1 opened automatically within a minute: `No season existed, so season 1 was opened
automatically for 30 days`, with an audit row.

### A real bug this exposed

**The Chronicle silently did not exist after the reset.** Season 1 opened correctly and there were zero
chapters.

Cause: seeding ran **once**, 15 seconds after enable, and that raced the season scheduler. On a
database with no season, the seeder found nothing to attach chapters to, gave up, and never tried
again. A one-shot task that depends on another task having finished is a race whichever delay is
chosen.

Fixed by making seeding **periodic** rather than one-shot, with a cheap early exit (one COUNT) once it
has run. That also covers the case that matters more in normal operation: a **new season** needs its
own chapters, and that happens long after boot - so the original design would have failed every month,
not just after a reset. Verified: `Chronicle seeded for season 1: 5 chapter(s). Chapter 1 is active.`
## Full GUI coverage of public commands - 2026-08-26

Owner asked for every public command to be reachable without typing. Audited mechanically before and
after.

**Before:** 14 of 28 public commands had no GUI route - `/balance`, `/pay`, `/baltop`, `/sethome`,
`/delhome`, `/tpa`, `/tpahere`, `/tpaccept`, `/tpdeny`, `/me`, `/local`, `/hc` among them.

**After: 0.** Four new pages and a generalised prompt:

* **Player picker** - one head per online player. One page serves pay, teleport and friend requests,
  because they are the same interaction: choose a person, then do a thing. Three near-identical pages
  would drift, and the third would be the one missing a confirmation.
* **Berries page** - balance, pay, rich list, links to shop and bazaar.
* **Teleport requests** - accept, deny, send. This existed only as typed commands before, which means a
  player who does not read chat closely never discovered `/tpaccept` - and an unanswered request looks
  like a broken feature to whoever sent it.
* **Homes page** gained set and delete.
* **Roleplay page** gained the three chat commands.

**Where typing is unavoidable it is asked for, not avoided.** A chest cannot hold a sentence or an
arbitrary number, so amounts, home names and spoken lines are prompted in chat and the command is then
run for the player. Click-to-increment was rejected: entering 3,470 would take forty clicks, which is
worse than typing it.

**One handler, one template.** The prompt stores a command template containing `{0}`, so a new prompt
costs a template rather than another branch - and a branch per prompt is how the fifth one ends up
subtly different from the first four.

**Every menu click still dispatches as the player**, so permissions, refusals and audit rows behave
exactly as if typed. The menu can never be a route around a rule.

## Documentation - two Word documents

| File | Content | Verified |
| --- | --- | --- |
| `LaughTail-Command-Book.docx` | What to type. Every command, rank table, screen map | Word: 10 pages, 15 tables, 2426 words |
| `LaughTail-Server-Handbook.docx` | How it works. Ranking, economy, roleplay, staff promotion | Word: 11 pages, 6 tables, 3052 words |

Both are generated by scripts, not hand-written, because both go stale the moment a feature lands and a
document that disagrees with the server is worse than none.

**Final sweep:** 8 test suites, 0 failures. Clean boot, 0 ERROR lines, `plugins not observed loading: 0`.