## SECTION 21 - THE MASTER ACCEPTANCE TEST TABLE

This is the launch gate. **Every row must be marked pass, with evidence, before the first paying player connects.** "Evidence" means a log line, a screenshot, a spark report, a query result, or a recorded number - never an opinion.

Record results in `docs/acceptance.md` with the date, the tester, and the evidence reference.

| # | Test | Pass condition | Evidence |
|---|---|---|---|
| 1 | Cold start | Fresh checkout plus one command brings the whole stack up with no manual steps | Terminal log |
| 2 | Hardcoded values | Grep for IP addresses and absolute host paths across the repo returns nothing | Grep output |
| 3 | Fresh-VPS rebuild | Full stack rebuilt on a brand-new machine in under 30 minutes | Timed log |
| 4 | Restore drill | Backup restored into a scratch environment, world and database intact | Drill log entry |
| 5 | Port exposure | External scan shows only the intended ports; RCON unreachable | Scan output |
| 6 | UDP voice port | Verified open using a UDP-aware method, not a TCP checker | Test command output |
| 7 | Paid gate | An unpaid account is rejected at login | Login attempt log |
| 8 | Store to whitelist | Test purchase grants access within one minute | Transaction plus grant log |
| 9 | Duplicate webhook | A replayed payment webhook produces exactly one grant | Grant log |
| 10 | Offline purchase | A purchase made while the server is down applies on next start | Queue plus grant log |
| 11 | Refund path | Test refund removes access and is logged | Refund log |
| 12 | Whitelist audit | Whitelist matches paid transactions exactly, with zero unexplained entries | Audit output |
| 13 | **No-advantage audit** | No purchasable item, rank, permission, slot, or cosmetic grants any capability another paying player lacks | Written audit against 3.2 |
| 14 | **No-gambling audit** | Repo grep for betting, gambling, crate, key, lottery, spin, casino, wager, stake, coinflip and dice finds no randomised-for-value mechanic, and none of the forbidden commands in 3.5.1 are registered | Grep output plus in-game tab-complete check |
| 14a | **Wagering detector works** | Staged test: two accounts fight, one dies, the loser pays the winner within 60 seconds. The combat-correlated signature fires and appears in the staff alert queue | Alert record with timestamps |
| 14b | **Detector cannot auto-punish** | 20 staged innocent payments (loot splits, loan repayments, instalments) produce zero automated sanctions, and code review confirms no punishment path exists from detector output | Test log plus code review note |
| 14c | **No wagering escrow exists** | Repo grep for escrow and stake-holding logic returns nothing, and `docs/rejected.md` contains the wagering-escrow rejection with its reasoning | Grep output plus the rejection entry |
| 15 | Deterministic rewards | Every reward source publishes its exact contents in advance | Screenshots |
| 16 | Legal pages | Terms, Privacy, and Refund policy are live and linked before any payment is possible | URLs |
| 17 | Rules gate | A new player cannot move, build or chat before accepting; acceptance is stored with a version | Database row |
| 18 | Rules consistency | Rules text is identical across website, in game, and Discord | Diff output |
| 19 | MSPT at cap | Under 25 ms at the chosen player cap under normal play | Spark report |
| 20 | MSPT in event | Under 40 ms at the event cap with combat active | Spark report |
| 21 | Load test | Bot test at 10, 20, 30, 40 completed; cap set from the measured result | Load-test log |
| 22 | **Watchdog degradation** | Induced load triggers each degradation step in order, and recovery restores everything | Watchdog log |
| 23 | Login time | Under 3 seconds from connect to spawn | Timed measurement |
| 24 | Command latency | Every command responds within 100 ms, or acknowledges and runs async | Timing log |
| 25 | Main-thread database calls | No blocking database call on the main thread anywhere | Spark profile plus code review |
| 26 | Economy audit | Zero positive-yield cycles across all items and all recipe chains | Audit output |
| 27 | Price spread | Buy exceeds sell by the minimum spread at both extremes of the dynamic band | Audit output |
| 28 | Atomic order match | Server killed mid-match creates and destroys nothing | Before and after query |
| 29 | Trade safety | Disconnect, item-swap, and spam-click exploits all fail | Test log |
| 30 | Rank purity | Two hours of mining, farming and building changes RP by exactly zero | Before and after query |
| 31 | Anti-farm | Repeat kills follow the diminishing pattern then award zero | RP log |
| 32 | Alt farming | Same-IP kills award zero RP and raise an alert | Alert log |
| 33 | Combat log | Disconnecting while tagged is resolved as a death | Death log |
| 34 | Reset idempotency | The season reset run twice produces an identical result | Two-run comparison |
| 35 | Reset ordering | Rewards granted before archival, verified by mid-reset failure and re-run | Test log |
| 36 | **One Champion** | Exactly one Champion per season, enforced by a database constraint | Schema plus failed-insert test |
| 37 | **Champion advancement** | The custom advancement is granted, announced, and visible to a Bedrock client via Geyser | Screenshots, both platforms |
| 38 | Champion has no power | The Champion gains no Berries, items, stats, permissions or head start | Written audit |
| 39 | Hall of Fame | Monument and web page both update automatically after a season ends | Screenshots |
| 40 | Shop gating | A Tier 1 player cannot buy a Tier 8 item by any means, including a modified client | Test log |
| 41 | Selling ungated | A brand-new player can sell items in their first minute | Test log |
| 42 | Homes | 20 homes reachable, renameable, and home-to-home teleport works | Test log |
| 43 | Home persistence | Homes survive a container rebuild and a simulated migration | Before and after query |
| 44 | Teleport guards | Warmup, combat block, cooldown, and back-after-PvP-death block all verified | Test log |
| 45 | Claims protect blocks | A non-trusted player cannot break blocks or open containers in a claim | Test log |
| 46 | **Claims do not protect players** | A player can be killed inside their own claim | Test log |
| 47 | Fire and flood | Fire and lava do not cross a protected boundary; fireTick is off | Test log |
| 48 | Chat flood | 200 messages per second results in an auto-mute with no MSPT impact | Log plus spark |
| 49 | Packet abuse | A packet-abuse suite does not crash or degrade the server | Test log |
| 50 | Anti-cheat | Test flight and test reach cheats are both caught and logged with evidence | Alert log |
| 51 | Anti-cheat false positives | One full week of normal play produces zero punishments of honest players | Alert review |
| 52 | Rollback restriction | An Admin account cannot execute rollback, restore or purge | Permission test |
| 53 | Rollback dupe | An attempted rollback-based duplication fails and alerts | Test log |
| 54 | Never-grant list | An Admin test account is denied every node in 17.3, checked one by one | Checklist |
| 55 | Staff cannot earn RP | A staff account gets zero RP from a kill | RP log |
| 56 | Audit immutability | Staff actions are logged and a staff account cannot delete them | Test log |
| 57 | Reporting | A report reaches Discord with block-log evidence attached automatically | Discord message |
| 58 | Cosmetics free | No purchase path exists for any cosmetic, in Berries or money | Grep plus review |
| 59 | Cosmetics persist | Cosmetics survive a full season reset | Before and after query |
| 60 | Cosmetic cost | Maximum cosmetics on all players adds under 2 ms MSPT | Spark report |
| 61 | Pack optional | The server is fully playable with the resource pack declined | Test log |
| 62 | Bedrock parity | A Bedrock player can join, play, see particle cosmetics, and use the settings menu | Screenshots |
| 63 | Crossplay versions | The oldest and newest supported client versions both connect and fight | Test log |
| 64 | Voice works | Two Java clients hear each other over the public internet | Recording or screenshots |
| 65 | Voice for everyone | Bedrock and unmodded players have a documented working voice route | Screenshots |
| 66 | Voice moderation | Staff mute in voice works and is logged | Log |
| 67 | Voice off switch | Disabling voice by one flag leaves the server fully functional | Test log |
| 68 | Event integrity | Disconnect at one life eliminates; inventories restore perfectly, including after a crash | Test log |
| 69 | Event re-entry | An eliminated player plays survival immediately and joins the next event | Test log |
| 70 | Arena regeneration | No blocks, items or entities persist from the previous event | Test log |
| 71 | Website separation | The site is not served from the game host | DNS plus IP check |
| 72 | Web database user | The website user cannot write to game data | Failed write attempt |
| 73 | Leaderboard caching | Leaderboards are cached at least 60 seconds | Header or code review |
| 74 | Live map markers | Player markers are absent by default and during a simulated event | Screenshots |
| 75 | Alert routing | Staff alerts go only to a private channel | Channel check |
| 76 | Documentation | Every document in 5.6 exists and is current | File listing |
| 77 | Decision log | Every deviation from this prompt is recorded with its reasoning | Decision log |
| 78 | Migration script | The migration script has been executed successfully at least once, end to end | Migration log |

---

