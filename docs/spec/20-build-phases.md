## SECTION 20 - BUILD PHASES

Build in this order. Do not start a phase before the previous phase's acceptance criteria all pass. The ordering is deliberate: everything that could destroy data or destroy trust comes first, and everything cosmetic comes last.

### Phase 0 - Foundation

Docker Compose stack, all four services. Repository structure. Environment file and its example. Git initialised, secrets ignored. Paper installed and starting cleanly. Database with schema migrations. Backups running and **one restore drill completed**. Monitoring and alerting live. Firewall configured, ports verified externally including UDP.

**Gate:** the server starts from a clean checkout on a fresh machine with one command, and a restore drill has succeeded.

### Phase 1 - Access, permissions, and the paywall

Whitelist enforcement. Store integration end to end, including a test purchase and a test refund. Permission ladder with the full never-grant list verified. Rules acceptance gate. Punishment tooling and the published ladder. Anti-cheat installed in alert-only mode. Packet-level protection.

**Gate:** an unpaid account cannot connect. A paid test account can. An Admin test account is denied every node in 17.3.

### Phase 2 - The world

All five worlds created, borders set, pregenerated with Chunky. Spawn built and protected. Claims configured with the block-not-player rule verified. Resource world with its reset script, **tested against a copy first**. Difficulty and gamerules set.

**Gate:** the resource world regenerates cleanly and cannot touch the main world.

### Phase 3 - Economy

Berries. Shop with the derived price table. The arbitrage audit script, in CI and nightly. Auction house. Order book with atomic matching. Safe trade GUI. All money sinks. The weekly report.

**Gate:** zero positive-yield cycles, and an atomic-match crash test passes.

### Phase 4 - Combat, rank, and seasons

Combat tagging. Elo rating with every anti-farm protection. The rank ladder. Stats tracking. The season reset job, **tested for idempotency and for mid-run failure**. The countdown campaign. The season archive. **The Champion system, including the datapack advancement, tested on a fake season.**

**Gate:** two hours of mining moves RP by zero; the reset is idempotent; exactly one Champion is produced.

### Phase 5 - Shop gating, homes, and quality of life

The eight shop tiers with server-side enforcement. Homes to 20 with rename and home-to-home. All teleports with every guard. The quality-of-life set. The settings GUI.

**Gate:** a Tier 1 player cannot buy a Tier 8 item by any means, including a modified client.

### Phase 6 - Load testing and tuning

The bot load test at 10, 20, 30 and 40. The event scenario. Spark profiles captured and analysed. Config tuned. **The player cap set from the measured number.** The watchdog built and its degradation ladder verified.

**Gate:** MSPT under 25 ms at the chosen cap, and the watchdog demonstrably degrades and recovers.

### Phase 7 - Voice, cosmetics, and events

Discord voice channels. Proximity voice with the UDP port verified over the real internet. The Bedrock path decided and documented. Cosmetics with the particle budget. War events with full state snapshots. The Finale format.

**Gate:** voice works between two real clients; cosmetics cost under 2 ms; an event runs within the MSPT budget.

### Phase 8 - Web, launch preparation

Website on separate hosting. Store live. Legal pages. Leaderboards through the read-only user. Hall of Fame. Live map with markers off. Status page. Discord fully wired.

**Gate:** every acceptance test in Section 21 passes, and the documentation set in 5.6 is complete.

### Phase 9 - Soft launch

A small group of paying players. Watch MSPT continuously. Fix, do not add. Run one full season, including one real reset and one real Champion, before opening more widely.

**Gate:** one complete season with no data loss, no economy exploit, and no unexplained downtime.

---

