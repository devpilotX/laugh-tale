## APPENDIX C - CONFIGURATION FILES TO CREATE

| File | Purpose |
|---|---|
| Environment file | Every secret. Gitignored, with a committed example containing no real values |
| Compose file | The four services (5.2) |
| Server properties | Baseline in 6.4 |
| Paper and server tuning configs | Baseline in 6.4 |
| JVM flags file | Heap and garbage collection (6.4) |
| ranks.yml | Tier names, thresholds, prefixes, cosmetic unlocks |
| shop-tiers.yml | The eight tiers and their contents (10.2) |
| prices.yml | Derived from the base value formula, with assumptions documented |
| economy.yml | Taxes, fees, sinks, dynamic band, floor |
| seasons.yml | Length, reset time, reset factor, warning schedule, Champion rewards |
| war.yml | Prep window, lives, caps, arena settings, finale format |
| cosmetics.yml | The ladder, particle budgets, viewer limits |
| voice config | Port, bind address, codec settings, permissions |
| watchdog.yml | MSPT thresholds and the degradation ladder (6.6) |
| claims config | Accrual rate, minimum size, trust levels, reclamation threshold |
| rules.yml | Rules text and version, the source for all three publication points |
| punishments.yml | The published ladder (14.4) |
| messages.yml | **Every user-facing string.** One file, so translation is possible later (24.7) |
| permissions export | The full node tree, including the never-grant list, in version control |

---

