## SECTION 23 - THE DEFAULTS AND DECISIONS TABLE

Every decision already made, in one place. **If you are about to ask the owner a question, check here first.** Anything marked OPEN is a genuine question for Section 24; everything else is decided.

| Key | Decision |
|---|---|
| Server name and brand | LaughTail SMP |
| Currency | Berries. One currency only |
| **Access model** | **Paid whitelist only. Nobody joins without paying** |
| **Price structure** | **One price, the same for everyone. No tiers, no bundles, no discounts that create unequal capability** |
| **Price amount and recurrence** | **OPEN** (24.1) |
| **Donor ranks and perks** | **None. Deleted from the design entirely** (3.2) |
| **Gambling, crates, lotteries, betting** | **None. Prohibited and grepped for** (3.5) |
| **What is sold** | **Access, and nothing else, ever** (3.6) |
| Gameplay style | Survival SMP with unrestricted PvP and a combat-only ladder |
| Difficulty | Hard |
| Keep inventory | Off |
| Land claims | On. Protect blocks and containers, never players (7.3) |
| PvP inside claims | Enabled. There is no safe zone |
| Fire tick | Off |
| Mob griefing | Off |
| Worlds | Overworld, Nether, End, Resource, Arena |
| World borders | 6,000 / 2,000 / 3,000 / 3,000 / small |
| Resource world | Yes, regenerated monthly with the season (7.4) |
| Homes | Base allowance for all, expandable with Berries to a hard cap of 20 |
| Home rename | Yes |
| Home to home teleport | Yes |
| Personal vault pages | Identical count for every player |
| Transfer tax | Small, above a threshold only |
| Auction listing slots | Identical for every player. Never purchasable |
| Auction fees | Listing fee plus sale tax |
| Order book | Yes, with atomic matching (8.4) |
| Safe trade GUI | Yes, mandatory |
| Dynamic pricing | Plus or minus 35 percent band, 25 percent hard floor |
| Arbitrage audit | In CI and nightly. Build fails on any positive cycle |
| **Rank source** | **PvP only. Zero contribution from anything else** |
| Rating system | Elo, K of 24, start 1000, clamp +2 to +40 |
| Rank tiers | Ten, Wanderer to Mythic |
| Season length | One month |
| Season reset | 1st of the month, 00:00 server time |
| Reset type | Soft: compress toward 1000 at 0.35 |
| Reset warnings | Nine steps from 3 days to 1 minute (9.5) |
| Never reset | Berries, items, homes, claims, cosmetics, achievements, Hall of Fame |
| **Season champion** | **Exactly one per season. No podium, no shared titles** |
| **Champion decided by** | **Top 32 qualify by RP, then the Finale decides. Dragon finale** |
| **Champion reward** | **Custom datapack advancement, permanent title, crown cosmetic, Hall of Fame entry, season-exclusive set** |
| **Champion power gained** | **None. Glory only** |
| Hall of Fame | Physical monument at spawn plus a permanent web page |
| Shop access | Open to all. **Buying is rank-gated across eight tiers** |
| Selling | Never gated |
| Locked shop items | Shown greyed out, never hidden |
| Shop tier at reset | drop_one by default. **OPEN** for owner preference (24.2) |
| **Animations** | **Kept. Pack-driven animation costs the server nothing; particles are budgeted and watchdog-governed** (Section 11) |
| Cosmetic source | Earned by rank only. Never sold, for any currency |
| Cosmetic persistence | Kept forever, across all resets |
| Resource pack | Optional. Never forced |
| War events | Weekly or fortnightly, 48-hour prep, 3 lives |
| Elimination scope | Per event, never per season |
| Event player cap | 20 to 24 now, 40 after migration, 60 at full scale. Always from measurement |
| Season finale | Double elimination, top 32, dragon finish |
| **Voice chat** | **On. Discord day one, proximity voice as the flagship, a no-mod route for Bedrock and unmodded players** |
| **Voice port** | **A dedicated UDP port, conventionally 24454** |
| **Voice requirement** | **Never required for any feature, event or reward** |
| **Voice provider choice** | **OPEN** (24.3) |
| Anti-cheat | A free simulation-based movement anti-cheat first, in alert-only mode, then tuned. A combat layer added only on evidence |
| Auto-ban | Never on a single flag. Human decision plus evidence |
| Packet protection | Mandatory, a launch blocker |
| Punishment ladder | Published, identical in three places (14.4) |
| Bans refunded | No. Stated before purchase |
| Rules acceptance | Required on first join, version-stamped |
| Rollback rights | **Owner only.** Admins get preview only |
| Staff play accounts | Separate from staff accounts. Staff accounts earn zero RP |
| Audit log | Permanent, and staff cannot delete from it |
| AFK and auto-farm policy | Published explicitly. Macros and auto-clickers not permitted |
| Platform | Paper |
| Version policy | Latest stable that all critical plugins support. Never snapshots. Never a floating latest tag |
| Crossplay | Java plus Bedrock via Geyser and Floodgate, with legacy Java version support |
| Online mode | **True, permanently. Never disabled for any reason** |
| Player cap | 24 initially, set from measurement thereafter |
| View and simulation distance | 6 and 4 |
| MSPT target | Under 25 ms normal, under 40 ms in events |
| Watchdog | Built in-house, four-step degradation ladder (6.6) |
| Degradation policy | Degrade cosmetics and conveniences. **Never degrade gameplay** |
| Anti-lag plugins | None. No entity clearers, no mob stackers |
| Deployment | Docker Compose, all state under one directory |
| Database | Containerised, with schema migrations |
| Backups | Hourly database, six-hourly world, offsite, encrypted |
| Restore drills | Monthly, logged |
| Website hosting | **Separate from the game host. Non-negotiable** |
| Store integration | Established platform, idempotent grants, UUID-keyed |
| Leaderboards | Read-only database user, cached 60 seconds minimum |
| Live map | Optional. Player markers off by default, forcibly off during events |
| Appeals | One route, a Discord form or ticket bot |
| Datapacks | Yes, for recipes, advancements, loot tables. Never for permissions, currency or tick-heavy logic |
| Staff list | Published on the website |
| Documentation | Complete set in 5.6, kept current |
| Decision log | Every deviation recorded with reasoning |
| Language | English, with the option to add more later |

---

