# LaughTail SMP - Acceptance

Every acceptance criterion and its evidence. **Never-break rule 11: no task is complete without evidence.** A log line, a command output, a screenshot, a query result, or a passing test. Intent is not evidence, and neither is "it loaded without errors" (spec 0.3).

**Status vocabulary.** `Not started` / `In progress` / `PASS` / `FAIL` / `BLOCKED` / `VOID (superseded)`. Nothing is ever silently removed - spec 32-2 forbids skipping, weakening or commenting out a test for lack of access.

**Nothing in this file has been attempted yet.** This session produced a plan only (spec 33.5). All 81 rows below are `Not started`.

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
| **12** | Whitelist audit | Whitelist matches paid transactions exactly, with zero unexplained entries | Audit output | 1 | Not started | - |
| **13** | No-advantage audit | No purchasable item, rank, permission, slot, or cosmetic grants any capability another paying player lacks | Written audit against 3.2 | 1, re-audit 8 | Not started | - |
| **14** | No-gambling audit | Repo grep for betting, gambling, crate, key, lottery, spin, casino, wager, stake, coinflip and dice finds no randomised-for-value mechanic, and none of the forbidden commands in 3.5.1 are registered | Grep output plus in-game tab-complete check | 1, re-audit 8 | Not started | - |
| **14a** | Wagering detector works | Staged test: two accounts fight, one dies, the loser pays the winner within 60 seconds. The combat-correlated signature fires and appears in the staff alert queue | Alert record with timestamps | 4 | Not started | - |
| **14b** | Detector cannot auto-punish | 20 staged innocent payments (loot splits, loan repayments, instalments) produce zero automated sanctions, and code review confirms no punishment path exists from detector output | Test log plus code review note | 4 | Not started | - |
| **14c** | No wagering escrow exists | Repo grep for escrow and stake-holding logic returns nothing, and `docs/rejected.md` contains the wagering-escrow rejection with its reasoning | Grep output plus the rejection entry | 1 | Not started | - |
| **15** | Deterministic rewards | Every reward source publishes its exact contents in advance | Screenshots | 4 | Not started | - |
| **16** | Legal pages | Terms, Privacy, and Refund policy are live and linked before any payment is possible | URLs | 1 payment path, 8 pages | Not started | - |
| **17** | Rules gate | A new player cannot move, build or chat before accepting; acceptance is stored with a version | Database row | 1 | Not started | - |
| **18** | Rules consistency | Rules text is identical across website, in game, and Discord | Diff output | 1 in-game, 8 web and Discord | Not started | - |
| **19** | MSPT at cap | Under 25 ms at the chosen player cap under normal play | Spark report | 6 | Not started | - |
| **20** | MSPT in event | Under 40 ms at the event cap with combat active | Spark report | 6 budget, 7 real event | Not started | - |
| **21** | Load test | Bot test at 10, 20, 30, 40 completed; cap set from the measured result | Load-test log | 6 | Not started | - |
| **22** | Watchdog degradation | Induced load triggers each degradation step in order, and recovery restores everything | Watchdog log | 6 | Not started | - |
| **23** | Login time | Under 3 seconds from connect to spawn | Timed measurement | 6 | Not started | - |
| **24** | Command latency | Every command responds within 100 ms, or acknowledges and runs async | Timing log | 6 | Not started | - |
| **25** | Main-thread database calls | No blocking database call on the main thread anywhere | Spark profile plus code review | 0 rule, 6 proof | Not started | - |
| **26** | Economy audit | Zero positive-yield cycles across all items and all recipe chains | Audit output | 3 | Not started | - |
| **27** | Price spread | Buy exceeds sell by the minimum spread at both extremes of the dynamic band | Audit output | 3 | Not started | - |
| **28** | Atomic order match | Server killed mid-match creates and destroys nothing | Before and after query | 3 | Not started | - |
| **29** | Trade safety | Disconnect, item-swap, and spam-click exploits all fail | Test log | 3 | Not started | - |
| **30** | Rank purity | Two hours of mining, farming and building changes RP by exactly zero | Before and after query | 4 | Not started | - |
| **31** | Anti-farm | Repeat kills follow the diminishing pattern then award zero | RP log | 4 | Not started | - |
| **32** | Alt farming | Same-IP kills award zero RP and raise an alert | Alert log | 4 | Not started | - |
| **33** | Combat log | Disconnecting while tagged is resolved as a death | Death log | 4 | Not started | - |
| **34** | Reset idempotency | The season reset run twice produces an identical result | Two-run comparison | 4 test, 9 live | **Test half PASS 2026-08-26** | `scripts/remote/test-seasons.sh`: `season end` run twice on season 1. First run crowned one Champion (1420 RP) and set `reset_completed=1`; second run returned "already completed - nothing to do (idempotent)" and the champion count stayed **exactly 1**. Idempotency is structural, not defensive - `reset_completed` is checked first and returns early, the champion insert relies on V1's `PRIMARY KEY (season_number)` so a duplicate is refused *by the database*, and every step is conditional. That matters because 31.1 puts the reset on a clock, and a clock-driven job will eventually be interrupted by a restart and re-run. **Live half** needs a real season, which is Phase 9 |
| **35** | Reset ordering | Rewards granted before archival, verified by mid-reset failure and re-run | Test log | 4 | Not started | - |
| **36** | One Champion | Exactly one Champion per season, enforced by a database constraint | Schema plus failed-insert test | 4 test, 9 live | **PASS 2026-08-26 (schema, failed-insert AND lifecycle)** | `db/migrations/V1__init.sql` declares `champions` with `PRIMARY KEY (season_number)`, so the guarantee is in the engine, not in application code. Failed-insert test in `scripts/remote/db-migrate.sh`: first champion for test season 99999 inserted, second rejected with `ERROR 1062 (23000): Duplicate entry '99999' for key 'PRIMARY'`, count still 1, test rows removed. Repeatable - it re-ran clean on three consecutive runs. Also exercised through the real code path: `test-seasons.sh` crowned one Champion for season 1 and a second `season end` left the count at exactly 1. **Live half** still needs a genuine month-long season, which is Phase 9 |
| **37** | Champion advancement | The custom advancement is granted, announced, and visible to a Bedrock client via Geyser | Screenshots, both platforms | 4 Java, 7 Bedrock | Not started | - |
| **38** | Champion has no power | The Champion gains no Berries, items, stats, permissions or head start | Written audit | 4 | Not started | - |
| **39** | Hall of Fame | Monument and web page both update automatically after a season ends | Screenshots | 4 monument, 8 web page | Not started | - |
| **40** | Shop gating | A Tier 1 player cannot buy a Tier 8 item by any means, including a modified client | Test log | 5 | Not started | - |
| **41** | Selling ungated | A brand-new player can sell items in their first minute | Test log | 3 rule, 5 enforcement | Not started | - |
| **42** | Homes | 20 homes reachable, renameable, and home-to-home teleport works | Test log | 5 | Not started | - |
| **43** | Home persistence | Homes survive a container rebuild and a simulated migration | Before and after query | 5 | Not started | - |
| **44** | Teleport guards | Warmup, combat block, cooldown, and back-after-PvP-death block all verified | Test log | 5 | Not started | - |
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
