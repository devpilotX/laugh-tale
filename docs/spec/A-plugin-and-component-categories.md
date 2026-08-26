## APPENDIX A - PLUGIN AND COMPONENT CATEGORIES

Select specific plugins at build time by the criteria in 0.3: actively maintained, compatible with the chosen version, configuration read in full before installation, and tick cost measured after installation. **This list is deliberately by category, not by brand**, because a brand recommendation from today may be abandoned software by the time you build.

| Category | Requirement | Notes |
|---|---|---|
| Permissions | Group inheritance, per-world contexts, database storage, an audit trail | The backbone of Section 17. Choose the most widely used option |
| Core commands and homes | Multi-home with rename, teleport request handling, warmups and cooldowns | Must store data in the database, not flat files (15.1) |
| Economy provider | A single-currency ledger with transaction logging and an API | Never trust a plugin that stores balances in a flat file |
| Shop | Per-item permissions or a scriptable gate, dynamic pricing, transaction hooks | Must support the eight-tier gate server-side (10.3) |
| Auction house | Buy-it-now plus bidding, fees, expiry return | The order book is likely custom |
| Land claims | Trust levels, an accrual model, admin overrides, an API | Must allow PvP inside claims (7.3) |
| Region protection | Fine-grained flags including fire and fluid flow | Watch the high-frequency-flag performance setting (14.2) |
| Block logging | Database-backed, inspection, lookup, preview, rollback | Rollback must be permission-separable (14.2) |
| Punishments | Database-backed, cross-instance ready, evidence attachment | |
| Anti-cheat | Simulation-based, off-main-thread, alert-only mode | See 14.1 for the movement-versus-combat gap |
| Packet protection | Malformed-packet and rate protection | Launch blocker |
| Chat management | Rate limits, similarity detection, filters, escalating mutes | |
| Profiler | Tick and memory profiling, per-plugin attribution | Non-negotiable. Law 5 depends on it |
| Chunk pregeneration | Async, resumable | Run before launch, not during |
| Version compatibility | Multi-version client support | Publish one combat-mechanics rule (Section 4) |
| Bedrock bridge | Protocol translation plus authentication linking | (Section 4) |
| Placeholders | A shared placeholder API | Everything else depends on this |
| Scoreboard and tab | Async updates, low cost | Measure it; naive implementations are surprisingly expensive |
| Holograms | Async, packet-based, viewer-limited | Must be disableable by the watchdog (6.6) |
| Cosmetics | Pack-model support plus particle effects, permission-gated | See Section 11 for the animation reasoning |
| Voice chat | Proximity voice plus a no-mod route | Section 13 |
| Discord bridge | Two-way chat, alerts, account linking | Alerts to private channels only |
| Store integration | Idempotent command execution from completed payments | Section 18.3 |
| Live map | Async rendering, marker control | Markers off during events (18.5) |
| Leaderboard display | Reads cached data, not live queries | |
| Backup | Consistent snapshots, offsite, encrypted | With a tested restore path |

**Categories to avoid entirely:** custom enchantments, entity clearers, mob stackers, wholesale pre-tuned config packs, anything unmaintained for longer than one Minecraft version, and anything whose configuration you have not read completely.

---

