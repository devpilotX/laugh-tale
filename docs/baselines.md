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
