## SECTION 6 - PERFORMANCE: THE TICK BUDGET

The owner's requirement is "everything fully optimized, very smooth." This section turns that into numbers you can test against. Performance is not a phase at the end; it is a constraint on every feature.

### 6.1 The targets

| Metric | Target | Hard fail |
|---|---|---|
| TPS, normal play | 20.0 | below 19.5 sustained |
| **MSPT, normal play** | **under 25 ms** | **over 40 ms sustained** |
| MSPT, during a war event | under 40 ms | over 50 ms (that is below 20 TPS) |
| Login time, join to spawn | under 3 s | over 8 s |
| Any command response | under 100 ms | over 500 ms |
| Shop or auction transaction | under 150 ms | over 1 s |

**MSPT is the metric that matters, not TPS.** TPS is capped at 20 and can read a healthy 20.0 while the server is at 49 ms per tick and one item frame away from collapse. MSPT tells you the actual headroom. Put MSPT, not TPS, on the monitoring dashboard and in staff alerts.

### 6.2 The rule that keeps this true forever

**Every feature gets a measured tick cost before it ships.** Profile the server, add the feature, profile again under the same load, record the delta in `docs/07-performance.md`. If a cosmetic system costs 4 ms per tick with 20 players, it is not a cosmetic system, it is a 16 percent tax on your headroom, and it must be redesigned or cut.

No feature ships with an unmeasured cost. This single discipline is what will make LaughTail smooth when comparable servers are not.

### 6.3 The profiling workflow

Install **spark**. It is the only tool that answers "why is this slow" honestly.

| Situation | Command |
|---|---|
| Quick health check | `/spark tps`, `/spark health` |
| General profile under load | `/spark profiler --thread *`, minimum 60 seconds of *real* load |
| Hunting intermittent spikes | `/spark profiler --only-ticks-over 150` |
| Memory growth | `/spark heapsummary` |

What spark cannot see: **external network pressure.** UDP floods, login-bot storms, and packet abuse are invisible to a JVM profiler. If spark says the server is idle while players report lag, the problem is upstream of the JVM - look at the network layer (Section 14.4).

### 6.4 Configuration baseline

Apply these deliberately, understanding each one. Do not paste an "optimised config" from a random blog; several popular ones silently break vanilla mechanics players expect.

**`server.properties`**

| Key | Value at 2 cores / 4 GB | Why |
|---|---|---|
| `view-distance` | 6 | Biggest single lever on both CPU and bandwidth |
| `simulation-distance` | 4 | Cuts entity and redstone ticking hard |
| `max-players` | 24 | Honest cap for this hardware |
| `network-compression-threshold` | 256 | Balances CPU against bandwidth |
| `online-mode` | true | Mandatory (Section 3.2) |
| `enable-rcon` | true, bound locally only | Never public |
| `sync-chunk-writes` | false | Big I/O win on Linux |
| `require-resource-pack` | false | Never lock a paying player out over a pack download |

**Paper and Spigot tuning - the ones that actually matter**

* Entity activation and tracking ranges: reduce, especially for monsters and items.
* `hopper.disable-move-event: true` - large win on any server with farms.
* `ticks-per.hopper-transfer` and `hopper-check`: raise from 8 to 16. Hoppers get slightly slower; hopper CPU roughly halves.
* Mob spawn limits and `ticks-per-spawn`: tune down. Mobs are usually the top entity cost.
* Merge radius for items and XP: increase modestly. Do **not** install a mob-stacking plugin (see 6.7).
* Redstone implementation: use Paper's optimised option.
* Chunk load and generation limits: cap per tick so exploration cannot spike MSPT.
* Autosave: stagger it, and never let plugin saves and world saves land on the same tick.

**JVM**

* Aikar-style G1GC flags, with heap sized to leave real headroom for the OS and other containers. On a 4 GB box, **do not** give the JVM 3.5 GB. Around 2.5 GB for the game, with the rest for MariaDB, the OS, and page cache, is the sane split. More heap is not more speed; oversized heaps mean longer GC pauses, which players feel as stutter.

### 6.5 World size is a performance setting

* **Pre-generate the world with Chunky** to the border, before launch. Live chunk generation during exploration is one of the largest sources of lag spikes on a weak CPU.
* **Set a real world border** (`/worldborder`) so players cannot generate new chunks forever. Defaults in Section 23: Overworld 6,000; Nether 2,000; End 3,000.
* A pre-generated, bordered world also makes the live map render finite and the backups predictable.

### 6.6 The performance watchdog (build this, do not install it)

Build a small module inside the LaughTail core plugin that watches rolling average MSPT and degrades gracefully:

| Rolling MSPT | Automatic response |
|---|---|
| under 30 ms | Everything on. Normal service. |
| 30-40 ms | Reduce cosmetic particle density by half. Increase cosmetic tick interval. |
| 40-48 ms | Cosmetic particles off entirely. Non-essential holograms off. Warn staff in Discord. |
| over 48 ms sustained 30 s | Block new random teleports and non-essential world-loading commands. Alert Owner. Log a spark snapshot automatically. |

Rules for the watchdog: **degrade cosmetics and conveniences, never gameplay.** Never block combat, movement, chat, or trading. Every degradation is announced to staff and logged with the trigger value. Every degradation reverses automatically when MSPT recovers, with hysteresis so it does not flap.

This is the mechanism that answers the owner's question about animations directly: **animations stay, and the server protects itself automatically if they ever cost too much.**

### 6.7 What NOT to install, and why

| Do not install | Reason |
|---|---|
| ClearLagg and similar entity-clearing plugins | They delete players' dropped items - the single most infuriating thing you can do to a survival player - while hiding the real cause. Minecraft already despawns items. Fix the source with spark instead. |
| Mob stackers | Change gameplay and farm behaviour in ways players hate, mask entity problems, and frequently cause dupe bugs. |
| "Ultra optimisation" config packs pasted wholesale | Many disable vanilla mechanics players rely on. Apply changes you understand, one at a time, measuring each. |
| Custom enchantment plugins | Permanent balance minefield, heavy tick cost, and a pay-to-win magnet. Explicitly rejected for LaughTail. |
| Anything whose newest release predates your Minecraft version | It will break, usually at the worst moment. |

### 6.8 The load test - required before launch and before every migration

Do not guess the player cap. Measure it.

1. Write a bot harness (`scripts/loadtest.js`) using a headless client library. Bots join, spread out, move, break and place blocks, open the shop, and fight.
2. Ramp: 10 bots, then 20, then 30, then 40. Hold each step 10 minutes.
3. Record MSPT, TPS, CPU, memory, and network egress at each step.
4. Then run the **event scenario**: all bots inside a 100x100 arena, all in combat, cosmetics on.
5. Publish the honest result in `docs/07-performance.md` as a table, and set `max-players` from the measured number, not from hope.

Expected outcome on 2 cores / 4 GB: comfortable to roughly 20-24 players in open world; event mode noticeably tighter. That is the number that justifies the migration timing in Section 22.

### 6.9 Acceptance criteria

* [ ] MSPT under 25 ms with 20 real or simulated players in normal play.
* [ ] Load test completed at 10/20/30/40 and results published.
* [ ] Watchdog demonstrably degrades and recovers, verified by artificially loading the server.
* [ ] No entity-clearing or stacking plugin present.
* [ ] Every installed plugin has a measured tick cost recorded.

---

