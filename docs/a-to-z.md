# LaughTail SMP - the A to Z check

Written 2026-08-26 because the owner asked to see everything, in order, with nothing hidden.

Rule 11 governs this document: **nothing is called done without evidence.** Where something works but
has not been tested against its acceptance criterion, it says so. Where something is missing, it says
so plainly rather than being described in a way that sounds finished.

---

## A. What a player can actually do right now

Every one of these is built, loads cleanly, and has been exercised at least once.

| They type | It does |
| --- | --- |
| `/menu`, `/lt` | Chest GUI front door. Staff section appears only with permission |
| `/rules`, `/rules accept` | The gate. No movement, building or chat until accepted |
| `/balance`, `/pay`, `/baltop`, `/berries` | The single currency and its ledger |
| `/shop`, `/buy`, `/sell`, `/sell all` | Server shop, 40 items, prices that move with trade |
| `/sell` (bare) | The sell box: drop items in, see the value, one click |
| `/order buy|sell|book|claim|cancel` | The bazaar. Orders fill while you are offline |
| `/sethome`, `/home`, `/homes`, `/delhome`, `/buyhome` | 2 free slots, up to 20 total |
| `/tpa`, `/tpahere`, `/tpaccept`, `/tpdeny` | Player teleports, blocked while in combat |
| `/rtp`, `/wild` | Random teleport into the resource world |
| `/friend add|accept|remove|requests|list` | Friends, consent required both ways |
| `/top rank|kills|streak|playtime` | Leaderboards. No richest list, deliberately |
| `/season status` | Season state |

Automatic, with no command: rank changes from PvP only, the combat tag, the resource-world guard, the
sidebar HUD, the Champion title on join, monthly season rollover, and three self-tests on every boot.

## B. What runs on every single boot, and why that matters

Three properties are re-proven at startup rather than trusted:

1. **Row 25 thread guard.** A deliberately forbidden main-thread database call must be refused.
2. **Order book conservation.** A real match runs and is rolled back, asserting Berries and items are
   conserved, the resting price applies, and self-trading is refused.
3. **Arbitrage audit.** 1,585 recipes checked for money printers, pessimistically.

A check that has to be remembered stops being run. These cannot silently rot: if one fails, the log
says so, and the arbitrage failure additionally **closes the shop**.

## C. Staff and owner

Moderation with a full audit trail (8 commands), manual access grants with a two-directional
whitelist audit, season control, and a staff GUI section. The audit table is append-only **by database
trigger** - UPDATE and DELETE are both refused, so an admin cannot quietly edit history.

## D. What is NOT built

Stated plainly, in rough order of how much it matters.

| Missing | Consequence |
| --- | --- |
| **Anti-cheat** | Row 50 unclaimable. See section F - this is the launch blocker |
| **Auction house commands** | Schema exists in V5; the commands and GUI do not. The bazaar covers fungible goods, so nothing enchanted can be traded yet |
| **Land claims** | Rows 45 and 46. Griefing is currently unprevented |
| **Chat filter and flood control** | Row 48 |
| **Cosmetics** | Appendix D. The menu button is honestly greyed |
| **Roleplay** | D-0033, deliberately undesigned. See section E |
| **Hall of Fame, Champion advancement** | Rows 37 and 39 |
| **TAB / multi-line nametags** | Owner asked for it; needs a plugin decision |
| **RTP queue** | Owner asked for it |
| **Settings page** | Per-player preferences table exists, no interface |
| **Discord integration** | OA-16 |
| **Website, Terms, Privacy, Refund policy** | Row 16. Owner's to write - legally binding text |
| **Load and performance testing** | All of Phase 6. No honest player cap exists yet |

## E. Roleplay - why there is nothing to show

The owner has asked for a "real roleplay system" twice. It is recorded as **D-0033 and deliberately
left undesigned**, and this is the honest reason:

"Roleplay" describes at least five different products, and they contradict each other. It could mean
custom professions and skills; or in-character chat channels with radius and radio; or player-run
towns with law and taxes; or quest and story content with NPCs; or a hard-RP server where breaking
character is a punishable offence.

**Building the wrong one is worse than building nothing**, because a roleplay system touches identity,
chat, progression and land - the four things hardest to change later. And two of those five directly
contradict this server's founding rules: professions that grant advantage break Law 1's total
equality, and player-run towns with taxes create a second economy alongside the Berry ledger the
arbitrage audit depends on.

**What is needed from the owner is one paragraph** describing what a player DOES in an evening of
roleplay on this server. Not a feature list - a description of an evening. That single answer decides
the schema, and the schema decides everything after it.

## F. The three things that are genuinely stuck

**1. Anti-cheat, and it is the launch blocker.** Row 50 requires flight and reach cheats to be caught
and logged. GrimAC was installed and tested twice on Minecraft 26.2 and failed both times
(`NMS_ITEM_STACK_CLASS is null`) - the version is too new for any anti-cheat to support. Three options,
all with real costs: wait for support and delay launch; launch without it and accept cheaters on a
PvP-ranked server, which is the worst option for a product whose entire value is a fair ladder; or
return to 1.21.x, which is what made the owner's own movement unplayable (D-0028). **This needs an
owner decision, not more engineering.**

**2. Bedrock and voice chat are unreachable.** Both are listening inside the container. Only TCP 25565
is published, so nothing outside can reach either. Needs a Pelican allocation change plus an AWS
security group rule - OA-06.

**3. The memory ceiling is unsettled.** About 500 MB free on a 3,825 MB box. No honest player cap can
be given without a load test, and a load test cannot be planned without knowing whether the owner will
pay for a larger instance if 24 players do not fit - Q-41.

Also outstanding: **OA-02**, no git remote. 68 commits exist on one PC with no off-machine copy. A disk
failure loses the entire project. This is the cheapest serious risk to close.

## G. Two-player tests that need the owner

These cannot be done alone and are the main content of the final check:

* **Row 33** - one account attacks, the other disconnects while tagged. Items must drop and a death
  must be recorded.
* **Row 40** - a Tier 1 account must be refused a Tier 8 purchase, in game.
* **Row 29** - disconnect, item-swap and spam-click attempted against the bazaar adversarially.
* **Row 30** - two hours of mining and building must change rating by exactly zero.

## H. Where the ledger stands

81 acceptance rows: **9 pass, 8 partial, 7 built-not-tested, 57 not started.**

Counted mechanically from the Status column of the master table, not from memory. An earlier draft of this document said "9 pass, 9 partial, 8 built, 55 not started" from recollection and every one of the last three numbers was wrong.

The honest summary is that the **economy and the data layer are the strongest part** - single currency,
transactional ledger, arbitrage-audited, conservation-tested, append-only audit trail - and the
**weakest parts are the ones that need either an owner decision (anti-cheat, ports, budget, roleplay
design) or a second player to test.**
