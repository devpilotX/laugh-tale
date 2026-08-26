# Measured baselines

Law 5 and spec 6.8: measurement precedes tuning, and a number with no baseline is not a measurement. Deviation **D2** requires an empty-server baseline captured and committed before any feature work, so that every later cost can be attributed to something specific.

Every figure here is reproducible with `scripts/remote/spark-baseline.sh`, which is committed. Nothing in this file is estimated.

---

## B1 - empty server, no players, world already generated

| Field | Value |
| --- | --- |
| Captured | 2026-08-26 03:45 UTC |
| Host | AWS `t4g.medium`, arm64, 2 vCPU, 3,825 MB, ap-south-1c |
| Server | `laughtail-dev`, Paper 1.21.11-132, Temurin 25.0.4 |
| Plugins | All 8 manifest plugins loaded |
| Heap | `-Xms2048M -Xmx2048M`, allocation 2,816 MiB, swap disabled |
| `view-distance` / `simulation-distance` | 6 / 4 |
| Players online | 0 of 24 |

### Tick performance

```
TPS from last 1m, 5m, 15m:  20.0, 20.0, 20.0
Server tick times (avg/min/max):
  last 5s   0.2 / 0.1 / 5.0 ms
  last 10s  0.1 / 0.1 / 5.0 ms
  last 1m   0.2 / 0.1 / 12.7 ms
```

**What this means.** An idle tick costs **0.2 ms of the 25 ms budget - 0.8%**. Effectively the entire tick budget is still unspent, so anything measured later that exceeds 25 ms is the cost of features and players, not of the platform. That is the whole point of taking this reading now.

The 12.7 ms one-minute maximum is a **spike, not a load**: it is a single tick, almost certainly chunk I/O or a G1 pause, against an average of 0.2 ms. It matters only as a reminder that row 19's "MSPT under 25 ms" is untestable until a statistic and a sample window are defined - see `docs/questions.md` **Q-16**. On this data, an average would pass at 0.2 ms and a strict maximum would already be at 51% of budget with nobody playing.

### Resources

| Measure | Value | Note |
| --- | --- | --- |
| Container CPU | 2.2 - 3.2% | Of 1.9 allocated cores |
| Container memory | 2.467 GiB of 3.025 GiB ceiling (81.5%) | High because `AlwaysPreTouch` with `Xms=Xmx` commits the 2 GiB heap at boot. Predictable by design (D-0020) |
| Host memory used | 3,178 MB of 3,825 MB | |
| Host memory available | 647 MB | Was 1,844 MB of page cache before the heap was fixed at 2 GiB |
| Host load average | 0.15 / 0.20 / 0.19 | |
| Boot time to `Done` | 54 s warm, 83.5 s when generating the world | |

**The number to watch is 647 MB available**, not the CPU. CPU is almost entirely idle; memory is not. Page cache fell from 1,844 MB to ~674 MB when the heap became fixed, and chunk I/O is served from that cache. Phase 2 pregeneration and Phase 6 load testing will both press on it. This is the practical face of **Q-41**.

### How it was measured, including what did not work

Paper's own `/tps` and `/mspt` over RCON on the container's loopback address.

* The bundled spark profiler answers `The spark profiler is currently disabled` to every subcommand, so it was not used. Enabling it is a Paper config change and is deferred to the Appendix C configuration task.
* Console injection was tried first, to avoid touching the RCON credential at all, and **does not work**: PID 1 in the container is `tini`, which does not forward stdin, and writing to the JVM's own `/proc/<pid>/fd/0` fails because Wings holds that pipe. Recorded so it is not attempted a third time.
* The RCON client is ~40 lines of `python3`, which the host already has - never-break rule 13 forbids installing packages on the game box mid-build. The password is read inside the process, never printed, never passed in `argv` where `ps` would expose it, and never written to disk (D-0019).

### Not yet baselined

Deliberately listed so the gaps are visible rather than assumed:

* **Per-player cost.** Needs real or bot clients; Phase 6.
* **Pregenerated-world I/O.** This world is spawn-sized only. Phase 2 changes it materially.
* **Anything under CPU-credit throttling.** This instance is burstable (**R1**, **OA-05**), and every figure above was taken with a healthy credit balance. A throttled reading would look completely different, which is precisely why OA-05 must be settled before Phase 6.


---

## B2 - the same server, with the database container added

Captured 2026-08-26 04:11 UTC, immediately after `V1__init.sql` was applied. Same host, same server, same heap. The only change is that spec 5.2's `db` container is now running.

| Measure | B1 (no database) | B2 (with database) | Change |
| --- | --- | --- | --- |
| Host memory used | 3,175 MB | 3,306 MB | **+131 MB** |
| Host memory available | 650 MB | **519 MB** | **−131 MB** |
| Page cache | 695 MB | 592 MB | −103 MB |
| `laughtail-db` memory | - | 180.4 MiB of a 320 MiB cap | new |
| `laughtail-db` CPU | - | 0.03% | negligible |
| Game container | 2.468 GiB / 3.025 GiB | unchanged | - |

**CPU is a non-issue; memory is the whole story.** The database costs 0.03% CPU and 180 MiB. Nothing here is failing, and the container's own 320 MiB cap means it cannot grow into the game server's space.

**But the trend is the finding.** Available memory has now gone 1,844 MB → 650 MB → 519 MB across this session, in two deliberate steps: fixing the heap at 2 GiB, then adding the database. Both were correct decisions - the first fixed a never-break rule 4 violation, the second is required by spec 5.2 - and together they have consumed most of the slack this box had.

What still has to fit into what remains: Chunky pregeneration (Phase 2), backup compression running alongside the tick loop (5.2 puts `backup` and `monitor` on the same box), and 20-plus real players. **This is the third data point for Q-41 and all three point the same way.** The honest position is that this box is now close to full with none of the game's actual features built, and that is a sizing conclusion rather than a tuning one.

### Query performance, for what it is worth

`V1__init.sql` applied in **379 ms** for five tables with foreign keys - nothing to tune. Recorded only so that a future migration taking materially longer is visibly different rather than merely feeling slow.


---

## B3 - idle steady state with everything Phase 0 requires running

Eight consecutive monitor samples, 2026-08-26 05:02-05:10 UTC. Game server up, database up, permission ladder applied, backups and monitoring scheduled. **Zero players.**

| Measure | Range across 8 samples |
| --- | --- |
| TPS (1m) | 19.7 - **20.0** |
| MSPT average (1m) | **0.1 - 0.2 ms** once settled |
| MSPT maximum (1m) | 1.2 - 756.8 ms (see below) |
| Host memory available | **277 - 370 MB** |
| Host swap in use | 140 - 158 MB, flat |
| Disk | 60% used, 7.5 GB available |

### Tick performance is not the problem

MSPT settled to **0.1-0.2 ms average**, matching B1 exactly. The earlier readings of ~6 ms were traced to the deploy's own work being measured seven minutes after boot - `investigate-tick-cost.sh` sampled six times at ten-second intervals and watched it return to 0.2 ms. **No regression.** The baseline did its job: it made a transient look suspicious enough to check, and the check settled it.

### Memory is the problem, and it is now measured rather than predicted

Available memory oscillates in a **277-370 MB** band and does not trend downward - swap use is flat, so this is steady state, not a leak. The server is healthy. But that band is the entire remaining headroom of the machine **with nobody playing**, before Chunky pregeneration, before backup compression running beside the tick loop, and before a single paying player connects.

This is **Q-41** with evidence attached rather than arithmetic. Three components have consumed the slack in this session, each of them *required*:

| Change | Available memory after |
| --- | --- |
| Start of session (heap `-Xmx2304M`, growing on demand) | 1,844 MB of page cache |
| Heap fixed at 2,048 MiB to satisfy never-break rule 4 | ~650 MB |
| Database container added, as spec 5.2 requires | ~519 MB |
| Permission ladder, monitoring, backups scheduled | **277-370 MB** |

None of these is optional and none can be given back. The conclusion has not changed, it has hardened: spec 22.3's ~2.5 GB heap for 24 players cannot coexist with never-break rule 4 on a 3,825 MB box that also runs the Pelican Panel.

### The 756 ms tick, and what it exposed about thresholds

One sample recorded a 756.8 ms maximum against a 1.6 ms average in the same minute. Judged on the average that is a perfectly healthy server; in reality it contained a **three-quarter-second freeze** that every player online would have felt.

The monitor's original thresholds only examined the average, so it passed silently. A maximum-based alert was added at 250 ms - five vanilla ticks' work in one tick. It fired on the spike and cleared once the spike aged out of the window.

This is exactly the gap `docs/questions.md` **Q-16** records: row 19 says "MSPT under 25 ms" and names **no statistic and no sample window**, so the same server passes or fails depending on which number you read. On this data an average-based reading passes at 0.2 ms while a maximum-based reading fails at 756 ms.

### A calibration lesson worth keeping

The memory alert was first set at "under 400 MB". Eight samples showed the idle floor is ~277 MB, so it fired **every single time**. An alert that always fires is noise, and it trains people to ignore the channel - the same failure as a drift detector that reports drift on every boot.

Thresholds now sit **below** the measured floor (220 MB warn, 120 MB severe) so they catch a *departure* from steady state. The steady state itself is not a per-sample alert; it is an owner decision, and it belongs in Q-41 where it can be acted on once instead of shouted about every five minutes.
