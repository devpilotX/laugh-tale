## SECTION 1 - THE PRODUCT, IN ONE PAGE

### 1.1 What LaughTail SMP is

A **paid-access, whitelist-gated, competitive survival multiplayer server**. Inspired by DonutSMP in shape - survival world, real economy, serious PvP, deep stats - and deliberately better than it in every place DonutSMP is weak.

| | DonutSMP | LaughTail SMP |
|---|---|---|
| Access | Free, public, anyone | **Paid, uniform price, whitelist-gated** |
| Griefing | Allowed, semi-anarchy | **Banned and prevented** |
| Economy | Dual currency, hyperinflated, known shop arbitrage exploit | **Single currency, sinks, arbitrage-proofed** |
| Ranks | Donor tiers sold for money, more homes for more money | **Earned by PvP only. Nothing sold. Everyone equal.** |
| Gambling / crates | Paid crates and keys | **None. No gambling of any kind.** |
| Seasons | Loose | **Monthly reset, exactly one Champion per season** |
| Cheating | Reactive | **Anti-cheat plus a paid gate that makes ban evasion expensive** |

### 1.2 The five pillars

1. **Survival that respects your time.** Your base is safe. Your chests are safe. Your work is not erased while you sleep.
2. **PvP that decides everything.** Rank comes from combat and nothing else. No grinding your way to the top.
3. **An economy that does not collapse.** One currency, real sinks, dynamic prices, no infinite money loops.
4. **Absolute fairness.** Same price, same access, same features, same odds. Nobody can buy an edge because there is no edge for sale.
5. **Smoothness as a feature.** 20 TPS is a product requirement, not an aspiration. Every feature has a tick budget and is cut if it exceeds it.

### 1.3 The one-sentence test

Before you build anything, ask: **"Does this make the server more fun without making it slower or less fair?"** If the answer is no on either count, do not build it. Write it in `docs/rejected.md` with the reason.

### 1.4 Scale reality (agreed with the owner, not up for debate)

* Current host: **2 vCPU / 4 GB RAM**. Realistic healthy cap: **20-24 concurrent players**.
* 60 players fighting in one arena will **not** hold 20 TPS on this box. The owner knows and accepts this.
* The plan is: **build complete and correct now at small scale, grow the playerbase, then migrate to a bigger and cheaper VPS** (Section 22). Every architectural decision in this document is made so that migration is a boring 30-minute job and not a rebuild.

---

