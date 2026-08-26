# LaughTail SMP - Progress

**Status: pinned Paper 1.21.11 and all eight manifest plugins are running and verified on the dev box (aarch64). Blocked on OA-25 for `laughtail-dev` to exist as its own Panel server. See "Session 2" below - it supersedes the session 1 statement that nothing on the server has been changed.**

| | |
| --- | --- |
| Session | 1 (Day Zero) |
| Date | 2026-08-26 |
| Written by | Kiro, on the owner's PC |
| Spec version | MASTER.md v6.0 FINAL, 3,994 lines |
| Server code written | None. Zero server configuration was changed |
| Next gate | Owner reads this file, `docs/owner-actions.md` and `docs/questions.md`, then approves or asks for a rewrite |

---

## Session 2 - 2026-08-26 - the dev server actually runs pinned Paper on aarch64

**Read this first. It supersedes the "no server configuration has been changed" claim in section 1 below, which was true only for session 1.**

The owner granted full VPS access and told me to proceed. The stock server was stopped through the Panel, pinned Paper 1.21.11 build 132 replaced the running jar, the eight manifest plugins were installed against publisher checksums, and the server was started and verified. The session dropped mid-way through writing `server/server.properties`; this section is the state after finishing that work.

### What is now true on `laughtail-dev`

| Thing | State | Evidence |
| --- | --- | --- |
| Paper | **1.21.11-132 running**, Temurin 25.0.4, aarch64, `Done (83.5s)` | `start-server-and-verify.sh` |
| Plugins | **All 8 manifest plugins enabled**, 0 ERROR, 0 SEVERE | Deviation **D5 gate: PASSED**. Recorded against every manifest entry |
| Native path | Paper reports aarch64 libdeflate **and** OpenSSL in use | So the native path is exercised, not merely absent - which is what R2 was actually worried about |
| `server.properties` | **73 keys deployed from the repository**, both secrets preserved host-side | D-0014. `owner=999:987 mode=644` |
| Drift | **Zero**, by key and value | `check-properties-drift.sh` exit 0 |
| Access | Whitelist and ops hold **one entry, the owner's real account** | D-0017 |
| Row 5 (TCP half) | **PASS from outside the host** - RCON closed, no unexpected port answered | `scripts/check-external-ports.ps1` |
| Old world | **Untouched.** `world/level.dat` mtime identical before and after boot | D-0013 |
| Rollback | `server.jar.prebuild` present, 61,859,678 bytes, sha256 recorded | Reverting is one `cp` |

### The four things worth knowing that were not knowable before

**1. Paper strips every comment from `server.properties` at boot.** 6,155 bytes down to 1,868; ~60 comment lines down to 2. Values all survived. This kills the obvious design for `scripts/drift.sh`: a byte or `diff` comparison would report drift after every single start, and a check that always fails is a check everyone ignores. Drift is now defined on **meaning** - same keys, same values, comments discarded, secrets compared as "still non-empty", `motd` compared after decoding escapes on both sides. See **D-0015**.

**2. The container publishes only 25565.** Not a firewall matter - `docker inspect` shows `PortBindings` containing `25565/tcp` and `25565/udp` and nothing else. Geyser is listening on 19132 and voice chat on 24454 *inside* the container, and neither is reachable from anywhere no matter what ufw or the security group say. **OA-06 therefore needs a third layer that progress.md previously described as two:** the Pelican allocation must publish the UDP ports before Phase 7 can test row 6.

**3. ufw does not govern published Docker ports at all.** Docker inserts its rules in `DOCKER-USER` and `DOCKER`, traversed before ufw's chains. `DOCKER-USER` here is empty. Reading `ufw status` to answer "is RCON exposed" would have produced a confident, wrong answer. The external probe is the only honest test, which is why row 5's evidence comes from off the box.

**4. A bare `[ -f ]` inside the volume silently returns false.** The `ubuntu` user cannot traverse `/var/lib/pelican/volumes`, so an unprivileged file test is not just wrong, it is wrong *quietly* and the script takes the other branch. This made the installer report that it had saved `server.jar.prebuild` when it had never looked. Every file test in these scripts now runs under `sudo -n`. Related: a glob like `"$D/plugins"/*.jar` is expanded by the calling shell and so fails the same way.

### Acceptance movement

| Row | Was | Now | Note |
| --- | --- | --- | --- |
| **5** Port exposure | Not started | **TCP half PASS** | RCON unreachable, proven externally. UDP half belongs to row 6 |
| **6** UDP voice port | Not started | Still not started, **and now better understood** | Needs the Panel allocation, not just OA-06's firewall rules |
| **D5** aarch64 gate | Proposed | **PASSED for all 9 components** | Recorded in `server/manifest.yml` per component |

### What I did NOT do

* **Did not create `laughtail-dev`.** It still does not exist. Everything above happened on the pre-existing stock server, which is the only server in the Panel. **OA-25** is still the blocker: Pelican has no `p:server:make`, so there is no CLI path to create one. Pre-flight items 9 and 10 remain failed.
* **Did not touch production.** It does not exist yet either.
* **Did not open any firewall port** - that is OA-06, and it now needs the allocation change described above.
* **Did not take the `pre-build` host snapshot (OA-03).** Mitigated, not solved: there is a volume tar backup at `/home/ubuntu/laughtail-backups/` and `server.jar.prebuild`, so the *server* is recoverable. A broken Panel, corrupted Docker or a locked-out SSH is **not** covered. This is the largest outstanding risk and it is unchanged.

### Handoff - where I stopped

The dev server is **running**. That is a deliberate choice, not an oversight: the owner can now join and confirm the whitelist, the rename to IgnisClaw, and the MOTD from a real client, which is evidence no script can produce. It also burns CPU credits on a burstable instance (**R1**), so if the owner is not going to test it soon, stopping it is the better state - `scripts/remote/stop-server.sh` does that cleanly and refuses if anyone is online.

**Next, in order:**

1. Owner answers **OA-26** (rotate the two secrets that reached a transcript, or defer).
2. Owner answers **Q-41** and **OA-05** - the memory ceiling and the burstable instance. Both must be settled *before* Phase 6, because a cap measured on a configuration that is about to change is not a measurement.
3. Appendix C Paper configuration as repository source of truth: `paper-global.yml`, `paper-world-defaults.yml`, `spigot.yml`, `bukkit.yml`. This also enables the bundled spark profiler, which is currently off.
4. `db/migrations/` and the migration runner - Phase 0.5, needs no new server.
5. The pre-commit secret hook and `scripts/deploy.sh` - Phase 0.2.

### Session 2, second half - what changed after the reconnect

**Pre-flight items 9 and 10 now PASS.** The existing server was renamed to `laughtail-dev` rather than a second server being created, because a second 2,816 MiB allocation cannot coexist with this one on a 3,825 MB box. **OA-25 drops from blocking to optional** - the Application API key is still the better long-term route for the three servers still to be created, but Phase 0 is no longer stalled behind it. See **D-0021**.

**Never-break rule 4 was being violated, and the number that said otherwise was measured against the wrong denominator.** Session 1's "25.6% headroom, satisfied but only just" used the 3,097 MiB container limit, which is the allocation *plus Pelican's own 10% overhead*. Against the real 2,816 MiB allocation, `-Xmx2304M` left 18.2% - failing both of rule 4's tests. Now `-Xms2048M -Xmx2048M`, leaving exactly 768 MiB = 27.3%. Verified with `docker top` on the running container, because a Panel edit without a restart proves nothing. See **D-0020**.

**Deviation D7 done.** `swap` 512 → 0, so `MemorySwap` equals `Memory` and the JVM cannot swap. It will OOM cleanly instead of stalling for seconds.

**A loaded gun found and unloaded.** The egg's variables read `MINECRAFT_VERSION=26.2` and `BUILD_NUMBER=latest`, and its install script downloads from `fill.papermc.io` using them. Nothing was wrong today - that script runs on install and reinstall, not boot - but one click of "Reinstall" would have overwritten the pinned jar and left a 1.21.11 world under a 26.2 server. Now pinned to 1.21.11 / 132, matching the manifest. See **D-0022**.

**Deviation D2 done.** Baseline in `docs/baselines.md`: TPS 20.0 flat, MSPT avg 0.2 ms - 0.8% of the 25 ms budget - so the whole budget is still unspent and later overruns are attributable to features. The figure that needs watching is not CPU (2.2%) but **647 MB host memory available**, down from 1,844 MB of page cache, because fixing the heap at 2 GiB took that cache and chunk I/O is served from it.

**New risk, and it is the sharpest one yet - Q-41.** The container ceiling is 3,248 MB and host services need ~700 MB, against 3,825 MB total. The limit is therefore set above what the machine can honour; it fits in practice only because the JVM does not use all it is allowed. More importantly, spec 22.3's "~2.5 GB heap for 24 players" inside a 2,816 MiB allocation leaves 11% outside, which **never-break rule 4 forbids outright**. The specification's own sizing and its own never-break rule cannot both hold on this box. That makes **R3 a conclusion rather than a worry**: either the instance grows, or the Panel moves off the game box, or the cap is below 24. All three are owner decisions with money attached.


## 1. What this session actually did

| # | Task | Evidence |
| --- | --- | --- |
| 1 | Read `AGENTS.md` | Its rules are applied throughout this document; the environment table in it is corrected in section 3 below |
| 2 | Wrote `.gitignore` **first**, before any other file entered the repository (spec 33.3 step 2) | `.gitignore`, 63 lines, contains the spec's minimum list verbatim |
| 3 | Created the tree from spec 33.3 step 4 | `docs/spec/`, `docs/private/`, `server/`, `scripts/`, `db/migrations/` |
| 4 | Placed the master spec at `docs/spec/MASTER.md` (spec 33.3 step 5) | 3,994 lines, moved from the root, not copied |
| 5 | Split it into one file per section and appendix (spec 33.4 step 2) | 43 files: `_preamble.md`, `00-` to `33-`, `A-` to `G-`, `_end-of-document.md` |
| 6 | Verified the split is lossless (spec 33.4 step 4) | `scripts/verify-split.ps1` output: part line counts sum to **3,994 = 3,994**; all **42** `##` headings appear **exactly once**; reconcatenated parts are **byte-for-byte identical** to `MASTER.md` (0 differing lines) |
| 7 | Generated `docs/spec/INDEX.md` (spec 33.4 step 3) | 332 lines. **280** headings mapped (43 top-level, 237 subsections), each with a one-line summary. Zero gaps. All 43 part files referenced. Includes a quick-route table so sections are loaded on demand, which is what 27.1 asked for |
| 8 | Read the whole specification, in parallel, without loading it into one context | Nine agents each read an assigned group of section files and wrote findings to `docs/spec/.findings/G1.md` to `G9.md`. `MASTER.md` itself was never loaded |
| 9 | Inventoried the real host, read-only | `scripts/vps-inventory.ps1` and `scripts/vps-inventory2.ps1`. Nothing was installed, started, stopped or written. Results in section 3 |
| 10 | Wrote this plan, `docs/owner-actions.md`, `docs/questions.md`, `docs/decisions.md`, `docs/rejected.md`, `docs/acceptance.md` | This file and its siblings |
| 11 | Installed git and made the three Day Zero commits | Root commit `3087a56` contains **`.gitignore` and nothing else**, confirmed by `git show --name-only` on the root commit. Then `1b1be77` (AGENTS.md, README, the 43 split files, INDEX.md, scripts) and `5115674` (the six living documents). Working tree clean |
| 12 | Wrote the hardcoded-value check from Appendix E, ran it, and it **failed on my own scripts** | `scripts/check-hardcoded.ps1` found 14 violations of acceptance row 2 in the Day Zero scripts - the VPS address, the key path, and `C:\Laugh-Tale` hardcoded 12 times. All fixed: connection details moved to a git-ignored `scripts/host.env.ps1` with a committed template, and every script now derives its paths. Re-run: **0 hits**. Split and doc verification both still pass. Recorded as decisions **D-0009** and **D-0010** |

**Three verification scripts must stay green, and are, as of this session:**

```
scripts/verify-split.ps1     3,994 = 3,994 lines; 42 headings once each; 0 differing lines
scripts/verify-docs.ps1      24 OA, 39 Q, 8 D, 5 R defined; 0 unresolved references
scripts/check-hardcoded.ps1  91 tracked files, 12 deployable scanned, 0 hits
```

**Not done, and why.** The repository has **no remote**. Git was not installed on this PC at the start of the session - verified absent from `PATH` and from all three standard install locations - so I installed it under your "full permission" instruction and made the commits locally. A GitHub repository and a push credential are still needed; see `docs/owner-actions.md` **OA-02**. Until then the build exists on one machine, which Law 6 is specifically against.

Also not done: the `pre-build` VPS snapshot (**OA-03**). No change has been made to the host, so nothing is currently at risk - but Phase 0 cannot start without it.

---

## 2. How to read the build order

The order below is Section 20's ten phases, unchanged in number and unchanged in intent. Section 33 (Day Zero) sits before Phase 0 because the specification puts it there. Section 22 (migration) is **not** a phase; it is an event triggered by player growth. Section 26 (roadmap) is everything after launch.

Four principles govern the order, all taken from the spec rather than invented:

1. **Anything that can destroy data or trust comes first.** Backups and a completed restore drill are in Phase 0, before a single gameplay feature (Section 20 preamble).
2. **The ledger precedes the shop.** Berries, transactions and the arbitrage audit (Phase 3) exist before shop tiers can gate anything (Phase 5). Section 20 already orders it this way; it is the single most important ordering decision in the document.
3. **Measurement precedes tuning.** The player cap and every watchdog threshold are outputs of Phase 6, not inputs to it (Law 5, 6.8).
4. **Cosmetics are last.** Phase 7. Nothing decorative is built before the thing it decorates works.

Each phase below states four things, because 33.5 says a plan judged on traceability must cite numbers and not intentions:

* **Delivers** - the phase's own words from Section 20, expanded.
* **Implements** - the specification sections and appendices it builds.
* **Satisfies** - acceptance criteria by number. Bare numbers such as `40` are rows of the Section 21 master table. Hyphenated IDs such as `29-7` are that section's own criteria table.
* **Depends on** - what must already be true, and which owner actions block it.

**A note on acceptance criteria numbering.** The Section 21 master table has 81 rows: 1-78 plus 14a, 14b, 14c. Separately, eighteen sections define their own criteria tables. Nine of those use explicit IDs (`22-1`..`22-15`, `27-1`..`27-9`, `28-1`..`28-10`, `29-1`..`29-17`, `30-1`..`30-6`, `31-1`..`31-18`, `32-1`..`32-6`, `33-1`..`33-9`, and `8-1`..`8-5`/`9-1`..`9-7`). The rest - 3.9, 5.7, 6.9, 11.6, 12.6, 13.5, 14.10, 17.5, 18.7 and 22.7 - are **unnumbered checkbox lists**. I have given those positional IDs in `docs/acceptance.md` and flagged them; see `docs/questions.md` **Q-02**. Sections 7, 10, 15, 16 and 19 define no criteria of their own and rely entirely on the Section 21 table.

---

## 3. The host, as measured this session

This corrects three things the `AGENTS.md` environment table gets slightly wrong, and surfaces four risks the specification could not have known about because it never saw the machine.

| Fact | Measured value | Consequence |
| --- | --- | --- |
| Instance | **t4g.medium**, `i-0d5663cfa8038b494`, **ap-south-1c** (Mumbai) | Mumbai is the right region for Indian players (22.2). But **t4g is a burstable T-series instance**, which the spec never considers. See risk R1 |
| Architecture | **arm64 / aarch64** (AWS Graviton) | Every plugin must be proven to run on ARM64 before it is pinned. See risk R2 |
| CPU | 2 vCPU. Idle load average 0.20, but 9-12% user time with only the stock server up | Consistent with 2 vCPU / 4 GB as stated |
| RAM | **3,825 MB total. 2,367 MB already in use. 1,458 MB available** | The spec's target 2.5 GB game heap plus the Panel does not fit comfortably. See risk R3 |
| Swap | `/swapfile` 2 GB **plus** `zram0` 957 MB. Container `MemorySwap` (3,785 MB) exceeds `Memory` (3,248 MB), so the JVM **can** swap | Swap on a 20 TPS server converts a memory spike into a multi-second freeze. See risk R4 |
| Disk | 19 GB root, **9.5 GB free**. Current world is only 749 MB | Pregenerating five worlds at borders 6,000 / 2,000 / 3,000 / 3,000 will not fit. See risk R5 |
| Access | `ubuntu` with **passwordless sudo**, key-only SSH, `PasswordAuthentication no`, `PermitRootLogin without-password` | `AGENTS.md` says "Root SSH"; the reality is `ubuntu` + `sudo -n`, which is functionally equivalent and slightly safer. Pre-flight 33.6 item 3 (key auth, passwords disabled) **already passes** |
| Panel | Pelican Panel present at `/var/www/pelican`, `nginx` active on 80/443/8443, `pelican-queue` **active**, Wings **active and enabled** | Pre-flight prerequisite met. Note `mariadb` and `redis-server` are both **inactive**, so the Panel is not using them - most likely SQLite plus a file cache |
| Servers in the Panel | **One**. Volume `4fd2f0a9-...`, container **Up 2 days**, image `yolks:java_25` | `laughtail-dev` and `laughtail` **do not exist yet**. Pre-flight 33.6 item 9 **fails**, and item 11 ("the existing stock server is stopped") **fails - it is running** |
| Existing server heap | Allocation 3,097 MiB, `-Xms768M -Xmx2304M`. Headroom 793 MiB = **25.6%** | Never-break rule 4 is satisfied, but only just. Note this one container is allocated 3.0 GiB of a 3.7 GiB box |
| Existing server CPU | `CpuQuota=190000 / CpuPeriod=100000` = **1.9 of 2 cores** | Leaves 0.1 core for Wings, nginx, the Panel and the queue worker. This is the failure mode Section 22.13 warns about; it shows up as backup failures and heartbeat loss, not as game lag |
| `server.properties` | `online-mode=true` ✔, `difficulty=hard` ✔, but `white-list=false` ✘, `max-players=20`, `view-distance=8` (spec says 6), `simulation-distance=6` (spec says 4), `enable-rcon=true` | Divergences to fix in Phase 0/1, not now |
| Plugins present | Chunky 1.5.3, FastAsyncWorldEdit 2.15.4, `Geyser-ViaProxy.jar`, bStats, spark | No manifest, no pinned versions, no checksums - never-break rule 9 is currently unmet. `Geyser-ViaProxy.jar` in a `plugins/` folder is suspicious; ViaProxy is normally a standalone proxy. Floodgate is absent |
| Firewall (ufw) | active, default deny in. Allowed: 22, 80, 443, 8443, 25565/**tcp**. Denied: 8080, **2022** | **UDP 24454 (voice) and 19132 (Bedrock) are not open. 25565/udp is not open either. Port 2022 is denied, which blocks the SFTP deploy path that 33.1 and 30.2 want to use** |
| Host git | 2.43.0 present on the VPS | Ironically the host has git and the build PC does not |
| Auto updates | `/etc/apt/apt.conf.d/20auto-upgrades` not found | Spec 5.5 wants automatic security updates; never-break rule 13 forbids upgrading mid-build. Both need reconciling |

### The four host risks, in priority order

**R1 - The instance is burstable, and this threatens the product's core promise.** A `t4g.medium` earns CPU credits at a fixed rate and has a baseline of 20% of 2 vCPU. Sustained full-CPU work - Chunky pregeneration, the Phase 6 bot load test, a war event, the Finale - will exhaust the credit balance. After that the instance is either throttled to baseline (Standard mode) or billed for surplus (Unlimited mode). A throttled instance cannot hold 20 TPS, and worse, **a load test run on a burstable instance produces a player cap that is not reproducible**, which makes Phase 6's entire output untrustworthy. Note also that acceptance row 22-10 measures *steal time*, which is the wrong signal here: T-instance throttling does not appear as steal. This needs an owner decision before Phase 2, not Phase 6. See `docs/owner-actions.md` **OA-05**.

**R2 - ARM64 changes plugin selection.** Pure-Java plugins are fine, and Paper, Geyser, Floodgate, spark and Chunky all run on aarch64. The risk is any plugin shipping native libraries - some anti-cheats and some voice components bundle per-architecture natives. Appendix A picks plugins by *category*, so the manifest is not yet fixed; the fix is cheap if the constraint is known now and expensive if discovered in Phase 7. I propose an explicit ARM64 load-test gate in Phase 0. See deviation **D5**.

**R3 - Memory is already tight before the real server exists.** 1,458 MB available with only the stock server running. The spec's own sizing (22.3: "Up to 24 players, 4 GB, heap ~2.5 GB") leaves roughly 1.5 GB for the OS, Docker, Wings, the Panel and the queue worker - and 22.13 budgets 4 GB for the Panel tier *alone* on a bigger box. The two-servers-never-together rule exists precisely because of this. It also means the Phase 0 restore drill cannot use a live scratch stack on this box.

**R4 - The JVM can swap.** Fix by setting the container's swap limit equal to its memory limit so the JVM fails cleanly instead of stalling. Cheap, reversible, and consistent with Law 8 (fail loud, not slow).

**R5 - The disk will not hold the pregenerated worlds.** 9.5 GB free. Overworld alone at a 6,000-block border is on the order of several GB of region files, before Nether, End, Resource and Arena, before hourly database and six-hourly world backup staging. Grow the EBS volume before Phase 2. See **OA-04**.

---

## 4. The proposed build order

### Overview

| Phase | Delivers | Gate (Section 20's words) |
| --- | --- | --- |
| **Day Zero** (S33) | Snapshot, repo, split spec, index, this plan, pre-flight | The owner has read and approved the plan (33.6 item 15) |
| **0** | Foundation: stack, schema, backups, restore drill, monitoring, firewall | Server starts from a clean checkout with one command, and a restore drill has succeeded |
| **1** | Access, permissions, the paywall | An unpaid account cannot connect. A paid one can. An Admin is denied every node in 17.3 |
| **2** | The world | The resource world regenerates cleanly and cannot touch the main world |
| **3** | Economy | Zero positive-yield cycles, and an atomic-match crash test passes |
| **4** | Combat, rank, seasons | Two hours of mining moves RP by zero; the reset is idempotent; exactly one Champion |
| **5** | Shop gating, homes, quality of life | A Tier 1 player cannot buy a Tier 8 item by any means, including a modified client |
| **6** | Load testing and tuning | MSPT under 25 ms at the chosen cap, and the watchdog degrades and recovers |
| **7** | Voice, cosmetics, events | Voice works between two real clients; cosmetics under 2 ms; an event inside budget |
| **8** | Web, launch preparation | Every Section 21 test passes, and the 5.6 documentation set is complete |
| **9** | Soft launch | One complete season, no data loss, no economy exploit, no unexplained downtime |
| *Migration* (S22) | Move to a bigger box when players justify it | 22-1 to 22-15 and the 22.7 checklist all pass |
| *Post-launch* (S26) | Tiers 1-4 | Not scheduled until Phase 9's gate closes |

### Day Zero - Section 33

**Delivers.** A verified `pre-build` snapshot. The repository with `.gitignore` as its first commit. The specification split and indexed. The six living documents. This plan, approved. All fifteen pre-flight items in 33.6 true.

**Implements.** 33.1-33.7. 27.3 (the split), 27.4 (`AGENTS.md`), 27.5 (the living documents). 28.3 (session-zero setup). 32.2-32.5 (the owner-action protocol and the sixth living document). 29.7 (what belongs in the repository), 29.11 (visibility), 29.12 (licence).

**Satisfies.** `33-1` to `33-9`. `32-1`, `32-3`, `32-4`, `32-5`. `27-1` (the split and index exist and are lossless). `28-1`, `28-2`, `28-3`.

**Depends on.** Owner only: **OA-02** GitHub repository and deploy key, **OA-03** the `pre-build` snapshot, **OA-14** licence choice, **OA-15** repository visibility. **OA-01** (git) is resolved.

**State: 9 of 10 tasks done. Blocked on OA-02 and OA-03.** Pre-flight status right now - items 3, 5, 6, 7, 8 and 12 pass (measured or evidenced), items 1, 2, 9, 10, 11, 13, 15 fail or are unverified, items 4 and 14 are owner-side. **8 of 15.**

---

### Phase 0 - Foundation

**Delivers.** The Docker Compose stack with all four services. Repository structure. The environment file and its example. Git initialised with secrets ignored. Paper installed and starting cleanly. A database with schema migrations. Backups running and **one restore drill completed**. Monitoring and alerting live. The firewall configured and ports verified externally, **including UDP**.

**Implements.** 5.1-5.7 (the portability contract). 6.1-6.4 and 6.7 (baseline tuning, the measurement toolchain). 29.1-29.14 in full (the repository as the only source of truth, drift detection, the deploy path, the exported egg). 30.1-30.6 (build on the VPS). 31.8 (daily restart hour), 31.14. Appendix C: environment file, Compose file, `server.properties`, Paper and Spigot tuning, JVM flags. Appendix D: the migration framework plus `players` and `access_grants`. Appendix E: health check, backup, restore drill, secret rotation, hardcoded-value check, prohibited-mechanic check. 22.8 (what a Pelican backup does *not* contain).

**Satisfies.** Rows **1, 2, 3, 4, 5, 6**. The 5.7 checklist. The 6.9 checklist, baseline portion only. `29-1` to `29-17`. `30-1` to `30-6`. `28-4` to `28-7` and `28-10`. Establishes row **25** (no main-thread database calls) as a rule, proven in Phase 6. Opens row **77** (the decision log), which stays open to Phase 9.

**Depends on.** Day Zero complete and approved. **OA-03** snapshot, **OA-04** disk, **OA-05** instance type, **OA-06** firewall and security-group ports, **OA-07** permission to stop the stock server, **OA-08** offsite backup destination, **OA-09** uptime monitor.

**Proposed internal order.** This is where most of the sequencing risk lives, so it is spelled out:

| Step | Work | Why here |
| --- | --- | --- |
| 0.1 | Host remediation: snapshot, grow the disk, settle the instance type, open UDP 24454 / 19132 / 25565 in **both** ufw and the AWS security group, allow 2022 from the owner's IP only, set container swap = memory, stop the stock server | Five pre-flight items currently fail. **Proposed deviation D1** |
| 0.2 | Repository machinery: the destructive-command deny hook, the pre-commit secret scan, `scripts/drift.sh`, `scripts/deploy.sh`, `.env.example`, the plugin manifest with pinned versions and checksums | 33.6 item 13 and never-break rule 9. A hook is a guarantee; prose is a request |
| 0.3 | Create `laughtail-dev` in the Panel with its own allocation, heap at least 25% below it, and `CpuQuota` that leaves headroom for Wings and the Panel | Pre-flight items 9 and 10. Fixes the 1.9-of-2-cores problem measured above |
| 0.4 | Pin Paper and the JDK. **Prove every manifest plugin loads on aarch64** | **Proposed deviation D5** |
| 0.5 | Database service and `db/migrations/`, including the `champions` unique constraint that row 36 requires be enforced in the schema | Row 36's evidence is "schema plus failed-insert test", so the constraint is a Phase 0 artefact even though seasons are Phase 4 |
| 0.6 | Backups, then **one completed restore drill**, then `docs/restore-drills.md` | The Section 20 gate. Note the drill cannot run as a live parallel stack on 4 GB - it must be sequential |
| 0.7 | Health check, monitoring, alerting to a private channel | Row 75 begins here |
| 0.8 | Firewall verified **externally**, UDP with a UDP-aware method | Rows 5 and 6. A TCP checker cannot prove 24454 |
| 0.9 | Capture an empty-server MSPT and memory baseline and commit it | **Proposed deviation D2.** Without a baseline, no later delta is attributable |
| 0.10 | Prove cold start from a clean checkout, and time a rebuild | Rows 1 and 3 |

---

### Phase 1 - Access, permissions, and the paywall

**Delivers.** Whitelist enforcement. Store integration end to end, including a test purchase **and a test refund**. The permission ladder with the full never-grant list verified. The rules acceptance gate. Punishment tooling and the published ladder. Anti-cheat installed in **alert-only** mode. Packet-level protection.

**Implements.** 3.1-3.9 (legal and commercial, which 0.4 makes absolute). 14.1-14.10 (rules, enforcement, anti-cheat, appeals). 17.1-17.5 (the Owner/Admin split and the never-grant list). 18.3 (the store pipeline). 19.12-19.14 (staff commands). 31.9 (account security), 31.13 (data deletion and privacy). 24.1's nullable-expiry design so one-time and recurring pricing both remain open at zero cost. Appendix C: `rules.yml`, `punishments.yml`, `messages.yml` with every string externalised per 24.7, and the permissions export. Appendix D: `players`, `access_grants`, `punishments`, `reports`, `staff_audit`.

**Satisfies.** Rows **7, 8, 9, 10, 11, 12, 14, 14c, 17, 49, 50, 52, 53, 54, 56, 57**. Row **16** payment-path half. Row **18** in-game half. Row **13** opened, closed in Phase 8. Row **51** begins its clock. Row **55** permission half. The 3.9 checklist (8 items), the 14.10 criteria, the 17.5 checklist (4 items).

**Depends on.** Phase 0's database and backups, because a paid grant that is not durable is a refund request. **OA-10** store account with a product priced, **OA-11** an INR-settling payment method, **OA-12** the access price decision (24.1), **OA-13** owner-approved Terms, Privacy and Refund text, **OA-16** Discord server, bot token and channel IDs, **OA-17** support and appeals email, **OA-18** the whitelist seed list.

**Blocking conflict to resolve first.** Row 14 requires a repository grep for the word `key` to return nothing, while the spec itself mandates `APP_KEY` handling text throughout Sections 22 and 29. As written this row can never pass. See `docs/questions.md` **Q-05**.

---

### Phase 2 - The world

**Delivers.** All five worlds created, borders set, pregenerated with Chunky. Spawn built and protected. Claims configured with the **block-not-player** rule verified. The resource world with its reset script, **tested against a copy first**. Difficulty and gamerules set.

**Implements.** 7.1-7.5. 31.12 (resource-world regeneration). The world rows of Section 23 (borders 6,000 / 2,000 / 3,000 / 3,000, fire tick off, mob griefing off, keep-inventory off, hard difficulty). Appendix C: the claims configuration. Appendix D: `claims`. Appendix E: resource-world regeneration.

**Satisfies.** Rows **45, 46, 47**.

**Depends on.** Phase 0 backups existing *before* several GB of world is generated. **OA-04 (disk) is a hard blocker** - pregeneration will fill the current volume. **OA-05 (instance type) should be settled first**, because pregeneration is the first sustained-100%-CPU workload and will burn the CPU credit balance (**proposed deviation D6**).

**Known unknowns.** Section 7 gives no numbers for claim accrual rate, starting allowance, minimum claim size, abandoned-claim threshold, or the trust-level matrix. Section 20 also says "five worlds" while 22.9 and 22.11 both verify "four". Both recorded in `docs/questions.md`.

---

### Phase 3 - Economy

**Delivers.** Berries. The shop with the derived price table. The arbitrage audit script, in CI **and** nightly. The auction house. The order book with atomic matching. The safe trade GUI. All money sinks. The weekly report.

**Implements.** 8.1-8.6. 10.3 (selling is never gated). 31.5 (daily sell caps and repricing), 31.10 (market-abuse thresholds, which stay in `docs/private/` per never-break rule 10). Appendix B's base-value formula. Appendix C: `prices.yml`, `economy.yml`. Appendix D: `balances`, `transactions`, `auction_listings`, `orders`, `order_matches`, `shop_tier_state`. Appendix E: economy audit, weekly economy report.

**Satisfies.** Rows **26, 27, 28, 29, 41**. The `8-1` to `8-5` criteria. Builds the timestamped transaction ledger that rows **14a** and **14b** read in Phase 4.

**Depends on.** Phase 0's transactional database - the order book cannot be atomic without one. A complete recipe graph, and a CI runner, before the audit can gate the build.

**Blocking gap.** The economy is **not implementable as written**. `target_berries_per_hour`, the minimum buy/sell spread, price elasticity, the recovery rate, daily sell caps, the balance-growth alert multiple, the anti-snipe window, auction listing slot count and the transfer-tax threshold all have no value anywhere in the specification. Row 27 tests "the minimum spread" and no minimum spread is ever stated. This is the single largest specification gap found, and it is on the critical path. See `docs/questions.md` **Q-10**.

---

### Phase 4 - Combat, rank, and seasons

**Delivers.** Combat tagging. Elo rating with every anti-farm protection. The rank ladder. Stats tracking. The season reset job, **tested for idempotency and for mid-run failure**. The countdown campaign. The season archive. The Champion system, including the datapack advancement, tested on a fake season.

**Implements.** 9.1-9.9 and Appendix B in full. 31.1 (the season instant), 31.2 (never end a season without a Champion), 31.3 (the combat-log penalty). Appendix C: `ranks.yml`, `seasons.yml`. Appendix D: `combat_ratings`, `combat_events`, `stats`, `seasons`, `season_archive`, `champions`. Appendix E: the season reset script.

**Satisfies.** Rows **14a, 14b, 15, 30, 31, 32, 33, 34, 35, 36, 38, 55**. Row **37** Java half. Row **39** monument half. The `9-1` to `9-7` criteria.

**Depends on.** Phase 3's ledger, because the wagering detector correlates a Berry payment with a combat death inside 60 seconds. Phase 0's schema, because row 36 demands a database constraint rather than application logic. Phase 2's worlds. **A Champion cannot be produced without the Finale, which is Phase 7** - so Phase 4 delivers the Champion *mechanism* and a fake-season test, and the first real Champion is Phase 9.

**Blocking contradictions.** Appendix B's Elo constants are internally inconsistent with Section 9 in three places: `MAX_GAIN = 40` is unreachable because `raw = 24 * (1 - E) < 24`; the death floor is "the bottom of the ladder" in 9.2 but `max(tier_floor(CR_victim), ...)` in Appendix B, which removes demotion entirely; and decay is "1% per week above the tier floor" in 9.2 but `CR * (1 - DECAY_RATE)` in Appendix B, a twentyfold difference at CR 2000. Ranking is Section 28.8's own example of where maximum care is warranted. See `docs/questions.md` **Q-11** to **Q-13**.

---

### Phase 5 - Shop gating, homes, and quality of life

**Delivers.** The eight shop tiers with server-side enforcement. Homes to 20 with rename and home-to-home. All teleports with every guard. The quality-of-life set. The settings GUI.

**Implements.** 10.1-10.4. 15.1-15.6. 16.1-16.3. 19.1-19.11 (every player command). 31.6 (new-player grace). Appendix C: `shop-tiers.yml`. Appendix D: `homes`, `preferences`.

**Satisfies.** Rows **40, 41, 42, 43, 44**.

**Depends on.** Phase 3, because home slots are bought with Berries. Phase 4, because a shop tier is derived from rank. Phase 1, because enforcement is a permission check. Law 9 governs the whole phase: the GUI is a picture of the truth, and row 40 must hold against a modified client.

**Known unknowns.** No base home count, no home-slot price curve, no teleport warmup or cooldown in seconds, no combat-tag duration, no vault page count. `/warp` exists as a player command but no `/setwarp` exists at any tier.

---

### Phase 6 - Load testing and tuning

**Delivers.** The bot load test at 10, 20, 30 and 40. The event scenario. Spark profiles captured and analysed. Config tuned. **The player cap set from the measured number.** The watchdog built and its degradation ladder verified.

**Implements.** 6.1-6.9. 31.7 (the HUD and bossbar budget). Appendix C: `watchdog.yml`, which cannot be written earlier because its thresholds are outputs of this phase. Appendix E: the load-test script.

**Satisfies.** Rows **19, 20** (budget measured; the real event is Phase 7), **21, 22, 23, 24, 25, 48**. The 6.9 checklist.

**Depends on.** Phases 1-5, because measuring a partial server measures nothing. Bot clients driven from **off** the game box, or the test consumes the CPU it is measuring. **OA-05 is a hard blocker**: on a burstable instance the measured cap is not reproducible, so Phase 6's central output would be worthless (**R1**).

**Structural problem.** Row 19 requires "MSPT under 25 ms" with no statistic, no sample window and no definition of "normal play". A pass/fail gate with no percentile and no duration is not testable. Also: 6.1 calls sustained MSPT over 40 ms a hard failure in normal play, while the 6.6 watchdog only alerts above 48 ms - so the server can sit in a documented hard-fail state silently. See `docs/questions.md` **Q-16** and **Q-17**.

---

### Phase 7 - Voice, cosmetics, and events

**Delivers.** Discord voice channels. Proximity voice with the UDP port verified **over the real internet**. The Bedrock path decided and documented. Cosmetics with the particle budget. War events with full state snapshots. The Finale format.

**Implements.** 11.1-11.6. 12.1-12.6. 13.1-13.5. 4.3-4.5 (crossplay and client support). 31.4 (arena item rules), 31.11 (voice). Decisions 24.3 (voice route) and 24.6 (Bedrock scope). Appendix C: `cosmetics.yml`, the voice configuration, `war.yml`. Appendix D: `cosmetics_owned`, `war_events`, `war_participants`. Appendix E: arena regeneration.

**Satisfies.** Rows **20** (with a real event), **37** (Bedrock via Geyser), **58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70**. The 11.6, 12.6 and 13.5 criteria.

**Depends on.** Phase 6's watchdog thresholds, because 12.4 disables cosmetics during events and the watchdog is what does it. Phase 4's rank, because cosmetics unlock by rank. **UDP 24454 open in ufw *and* the AWS security group *and* mapped by the Pelican container** - three layers, and row 6 requires proving it with a UDP-aware method. Geyser and Floodgate proven on aarch64 (**R2**).

**Highest host risk in the build.** The dragon Finale loads the End on top of the survival and arena worlds with live PvP for up to 32 players, on 2 vCPU. 12.4 already concedes that holograms and scheduled tasks must be disabled during events, which is evidence there is no steady-state headroom. Row 60's 2 ms cosmetic budget is 8% of a 25 ms tick spent on decoration.

---

### Phase 8 - Web, launch preparation

**Delivers.** The website on separate hosting. The store live. Legal pages. Leaderboards through the read-only database user. Hall of Fame. Live map with markers off. Status page. Discord fully wired.

**Implements.** 18.1-18.7. 5.6 (the complete documentation set). 29.10-29.12 (README, licence, visibility). 26.1 (the launch checklist).

**Satisfies.** Rows **16, 18, 39** (web halves), **71, 72, 73, 74, 75, 76, 77, 78**. Re-audits rows **13** and **14** now that cosmetics and shop tiers exist (**proposed deviation D4**). The 18.7 checklist (9 items).

**Depends on.** **OA-19** domain and DNS access, **OA-20** website hosting separate from the game VPS (18.1 calls this non-negotiable), **OA-21** a status-page provider, **OA-22** resource-pack hosting if a pack ships. Phases 3 and 4 for data. A read-only database user, and a transport from the off-box website to the game database that the specification never names.

**Gate conflict.** Section 20's Phase 8 gate is "every acceptance test in Section 21 passes", but row 51 requires "one full week of normal play" and rows 34 and 36 in their live form require a real season - all of which only Phase 9 produces. The gate as written is unreachable. See deviation **D3**.

---

### Phase 9 - Soft launch

**Delivers.** A small group of paying players. MSPT watched continuously. **Fix, do not add.** One full season, including one real reset and one real Champion, before opening more widely.

**Implements.** Section 20 Phase 9. 26.1. Sections 14 and 31 in anger rather than in test.

**Satisfies.** Row **51**. Rows **34** and **36** in live form. Continuous re-verification of row **19**.

**Depends on.** Everything. **OA-18** the soft-launch roster, **OA-12** the price actually live.

**Discipline note.** Section 26.2 titles Tier 1 "first month after launch" and lists clans, quests, a battle pass and bounties. The first month after launch *is* the soft-launch season, and Phase 9 says "fix, do not add". These cannot both be followed. My recommendation is that Tier 1 starts when Phase 9's gate closes, not when the calendar month turns. Owner's call - see `docs/questions.md` **Q-20**.

---

### Not phases

**Migration - Section 22.** Event-driven, triggered by player growth, not scheduled. Satisfies `22-1` to `22-15`, the 22.7 checklist, and rows **3** and **78**. It carries the most dangerous single instruction in the specification: 22.7 says "every secret has been rotated" while 22.12 says preserve the identical `APP_KEY` and refuse any tool that offers to regenerate it. Getting that wrong makes encrypted Panel data permanently unrecoverable. Recorded as `docs/questions.md` **Q-01**, the highest-severity item in this build.

**Post-launch - Section 26.** Tiers 1 to 4. Tier 3 is explicitly after migration. Not planned further until Phase 9 closes. Note 26.2's bounty system fires the row 14a wagering detector by design, so it cannot ship without an owner ruling.

---

## 5. Deviations I propose from Section 20

Each of these needs a yes or no. None changes a phase number, and none reorders the phases.

| # | Deviation | Why | Cost of not doing it |
| --- | --- | --- | --- |
| **D1** | Add a host-remediation step 0.1 at the front of Phase 0 | Five 33.6 pre-flight items currently fail, including "the stock server is stopped" (it is running) and "`laughtail-dev` exists" (it does not) | Phase 0 work lands on a box whose disk, CPU allocation and firewall are wrong |
| **D2** | Capture an empty-server MSPT and memory baseline at step 0.9 and commit it | Law 5. Every later measurement is a delta against something | Phase 6 cannot attribute cost to any specific feature |
| **D3** | Split the Section 21 gate: a **pre-soft-launch** set (all rows except 51 and the live forms of 34 and 36) and a **pre-public-launch** set (all 81) | Phase 8's gate as written requires evidence only Phase 9 can produce | The launch gate is unreachable and gets waived informally, which is how gates die |
| **D4** | Re-run rows 13 and 14 as a Phase 8 audit, in addition to Phase 1 | Neither the no-advantage audit nor the no-gambling grep can be closed before cosmetics (Phase 7) and shop tiers (Phase 5) exist | A green tick in Phase 1 that is no longer true at launch |
| **D5** | Add an aarch64 load-proof gate to Phase 0.4: no plugin is pinned into the manifest until it is observed loading on this host | The host is Graviton. The specification never knew this | A native-library failure discovered in Phase 7, after the manifest is baked into deployment |
| **D6** | Settle the instance-type question before Phase 2, not Phase 6 | Chunky pregeneration is the first sustained-100%-CPU workload and will exhaust the CPU credit balance | Pregeneration takes far longer than budgeted and every subsequent measurement is contaminated |
| **D7** | Set the game container's swap limit equal to its memory limit | The JVM can currently swap. Law 8 prefers a loud failure to a slow one | A memory spike becomes a multi-second freeze instead of a clean OOM |
| **D8** | Keep `docs/private/` for detector thresholds, and treat 3.5.1's published-threshold text as superseded by never-break rule 10 | 3.5.1 asks for detector detail in a committed file; rule 10 forbids publishing thresholds | Publishing the wagering and anti-cheat thresholds teaches evasion |

---

## 6. Critical path

```
OA-01 git ─── DONE ─┐
OA-03 snapshot ─────┼─> Day Zero commits ─> Phase 0.2 tooling ─┐
OA-02 GitHub ───────┘   (local: DONE, remote: blocked)         │
                                                           v
OA-04 disk ────┬─> Phase 0.1 host remediation ─> Phase 0.3..0.10 ─> Phase 1 ─> Phase 2
OA-05 instance ┤                                                       ^
OA-06 ports ───┘                                                       │
OA-10..13 store, price, legal ──────────────────────────────────────────┘

Phase 2 ─> Phase 3 (economy) ─> Phase 4 (rank) ─> Phase 5 (gating) ─> Phase 6 (measure) ─> Phase 7 ─> Phase 8 ─> Phase 9
             ^                                                            ^
             │                                                            │
       Q-10 economy numbers                                        OA-05 must be settled
       (hard blocker, no values in spec)                           or the cap is meaningless
```

The three things that will actually stall this build, in order:

1. **Q-10** - the economy has no numbers. Phase 3 cannot start without them, and Phases 5 and 6 sit behind Phase 3.
2. **OA-05** - the burstable instance. It invalidates Phase 6 and slows Phase 2.
3. **OA-03** - no `pre-build` snapshot means Phase 0 cannot touch the host at all. 33.2 calls it the single most important step on Day Zero, and it is the only rollback that covers a broken Panel, corrupted Docker or a locked-out SSH.

---

## 7. Handoff

**Where I stopped.** Plan written and committed. No server code, and no server configuration changed. Two read-only SSH sessions were opened and closed. The only thing installed anywhere was git, on this PC.

**What the owner should do next.** Read this file, then `docs/owner-actions.md` (24 items, each with exact steps), then `docs/questions.md` (the contradictions and gaps, severity-ordered). Then either approve the order or tell me what to change. Spec 33.5 is explicit that a thin plan should be rejected rather than corrected later.

**What I will do on approval, in order.** Push to GitHub once OA-02 arrives, then - after OA-03, OA-04, OA-05 and OA-06 - Phase 0.1 host remediation, then 0.2 repository machinery. I will not touch the host before the snapshot exists.

**Surprises worth remembering.** The build PC has no git but the VPS does. The host is ARM64 and burstable, neither of which the specification anticipated. One Pelican server exists and is running, and it is allocated 1.9 of the box's 2 cores. The specification's own `.gitignore` excludes `*.sql` while the same subsection mandates `db/migrations/`; the carve-out I applied is recorded as decision D-0001.

---

## Session 2, third block - Phase 0 foundation

**Phase 0.5 done - the database exists.** Spec 5.2's `db` container: `mariadb:11.4.5` pinned by digest, 320 MiB cap, loopback only, 180 MiB actual use. `V1__init.sql` applied in 379 ms creating bookkeeping, `players`, `access_grants`, `seasons`, `champions`. **Acceptance row 36's schema half PASSES** - `PRIMARY KEY (season_number)` plus a failed-insert test returning `ERROR 1062`. The migration runner was made to apply, to be idempotent, and to *refuse* - all three observed rather than assumed. See **D-0023**, **D-0024**.

**Phase 0.6 done, and this was the actual Section 20 gate for the phase.** `backup-run.sh` does save-off / save-all flush / tar / save-on with the flush restoration in a trap, plus `mariadb-dump --single-transaction`. `restore-drill.sh` **PASSED with 0 failures**: 5/5 tables, identical V1 checksum, 3/3 foreign keys, `level.dat` decompressing cleanly, 12/12 region files, and - the check most people skip - **the row 36 constraint survives the round trip**. A backup that restores rows but loses a constraint restores a silently broken server. Logged in `docs/restore-drills.md`. Backups are now on cron: hourly database at :17, six-hourly full at :23, with logrotate, a `bash -n` check, a cron.d mode check, and the scheduled command executed once as root to prove it runs.

**Appendix C partly done - Paper config under repository control** as a managed subset of keys rather than whole files, because Paper renames keys between versions and rewrites these files at boot. Six managed keys, spark now enabled, and the autosave collision that 6.4 explicitly forbids found and fixed. Zero drift after boot. See **D-0025**.

**The guard became narrower, not weaker.** `DROP DATABASE` was an absolute denial, which refused the restore drill itself - and refusing to *test* a backup in the name of data safety is a net loss of safety. It now judges the target name: `laughtail` and `players` are still refused, only `_drill` and `_scratch` names pass. **75 guard tests, 0 failures**, both directions proven.

### One bug class kept recurring - worth internalising

**`sudo` never applies to the shell's own redirection.** Three separate instances this session:

* `sudo -n wc -l < file` - the redirect runs as `ubuntu`, which cannot read the volume, so the count came back empty and a test reported a **false pass**.
* `sudo -n gzip -t < file` - same fault, rescued only by an `|| true` fallback that hid it.
* A bare `[ -f ]` inside the volume returns **false** rather than erroring, so the installer took the wrong branch and reported saving a rollback jar it had never looked at.

Related: `"$D/plugins"/*.jar` is expanded by the calling shell and fails the same way. And under `pipefail`, `cmd | head` returns 141 (SIGPIPE) and aborts the script under `set -e`.

### State against the ten phases

| Phase | State |
| --- | --- |
| Day Zero | Done apart from owner items - OA-02 GitHub, OA-03 snapshot, 2FA, plan approval |
| **0 Foundation** | **Mostly done.** 0.2 tooling, 0.3 dev server, 0.4 pinned + arm64 proof, 0.5 database, 0.6 backups **and a passed restore drill**, 0.9 baseline. Remaining: 0.1 host remediation (OA-03/04/05/06), 0.7 alerting (OA-16), 0.8 UDP verification (OA-06 **and** a Panel allocation change), 0.10 cold-start proof |
| 1-9 | Not started. No paywall, economy, rank, seasons, shop gating, load test, voice, cosmetics or website |

**Acceptance: 3 of 81 rows carry evidence** - row 5 TCP half, row 36 schema half, plus the tooling-satisfied 29.x criteria. That is the honest number.

### Next, in order

1. **0.10 cold start** - prove the server comes up from a clean checkout with one command and time a rebuild (rows 1 and 3). Everything needed now exists.
2. `paper-world-defaults.yml` and `bukkit.yml` into the managed registry, if Phase 6 justifies the entity-range changes currently deferred under Law 5.
3. **Phase 1 is blocked on owner input** - OA-10 store, OA-12 price, OA-13 legal text, OA-16 Discord. But its schema is already in place, so LuckPerms permission work and the rules-gate table can start early.
4. **Q-41 must be answered before Phase 6.** Host memory available is now **473 MB** and has fallen with each required component. Spec 22.3's ~2.5 GB heap for 24 players cannot coexist with never-break rule 4 on this box. That is arithmetic, not opinion.


---

## Session 2, fourth block - the core plugin, Minecraft 26.2, and Phase 2

### The single most important thing to know

**The server moved from Minecraft 1.21.11 to 26.2** (D-0028), because the version pin was the cause of an unplayable server rather than a conservative choice. The owner connects with 26.2; ViaVersion translated every packet; GrimAC predicts movement *from* packets and set the player back. Matching the server to the client generation removed the translation entirely.

**There is no anti-cheat.** GrimAC was tested twice and rejected twice, on different evidence each time - first the translation problem on 1.21.11, then on 26.2 where it loads and its packet layer dies (`NMS_ITEM_STACK_CLASS is null`). Acceptance **row 50 is unclaimable and has never been claimed**. On a server whose product is PvP fairness this is the top pre-launch blocker. **OA-27.**

### What now exists that did not

| Thing | State |
| --- | --- |
| **LaughTail core plugin** | Built from source on the host in a throwaway maven container. 0.1.0, 7 source files. Player registration on UUID, the rules gate with version stored (row 17), Section 7.2 gamerule enforcement, `/laughtail status`, `/laughtail reload` |
| **Minecraft 26.2** | Paper 26.2-119, API `26.2.build.119-stable`, plugin compiled for **Java 25** |
| **Five worlds** | `laughtail` 6000, `_nether` 2000, `_the_end` 3000, `_resource` 3000, `_arena` 512 (flat). Multiverse-Core 5.8.1-pre.3 |
| **Section 7.2 rules** | keep_inventory false, fire spread false, mob griefing false, natural regen true - on all five, enforced on `WorldLoadEvent` |
| **Owner account** | Now in the `owner` LuckPerms group with `laughtail.rules.bypass`. It had been left in `default` |

### Things that will bite the next person

**`sudo` never applies to the shell's own redirection or globs.** Seven instances this session. `sudo wc -l < file`, `sudo gzip -t < file`, bare `[ -f ]` inside the volume, `"$D/plugins"/*.jar`, `ls -1d "$D"/laughtail*`. The bare `[ -f ]` form is the dangerous one: it returns **false** for a file that exists and the script takes the wrong branch silently.

**`grep -c` exits 1 on zero matches.** Under `pipefail` plus `set -e` that kills the script on a *clean* log. Three instances.

**26.2 renamed the gamerules.** `doFireTick` is now `minecraft:fire_spread_radius_around_player`; `naturalRegeneration` is `minecraft:natural_health_regeneration`. Console commands using the old names return "Incorrect argument for command". Bukkit's `GameRule` constants still map correctly - which is why enforcing rules through the plugin is right by construction, not by luck.

**Minecraft 26.x requires Java 25.** `class file has wrong version 69.0, should be 65.0`. A release-21 compile reports *every symbol as missing* rather than naming the version. maven-shade-plugin needed 3.6.2 for the same reason.

**Never print a file containing a secret, redacted or not.** D-0026: a placeholder token quoted in a comment got substituted with the real password, and a `sed` that masked only `password:` lines let it through. Print facts *about* the file instead. The credential was rotated and verified dead.

### Where Phase 2 actually stands

Done: five worlds, borders, gamerules. **Not** done, each for a stated reason:

* **Claims (7.3)** - the specification gives no accrual rate, starting allowance, minimum claim size or reclamation threshold. Rows 45 and 46 blocked on a **spec gap**, not on effort.
* **Pregeneration (6.5)** - hours of sustained CPU on a **burstable** instance (OA-05) and several GB on a disk with ~6.5 GB free (OA-04).
* **Resource-world reset (7.4)** - needs the script that "names the world explicitly and refuses to run against the main world". The world now exists, so this is buildable next.
* **Spawn (7.5)** - a build, not a config.

### Next, in order, for whoever picks this up

1. **V2 migration**: `combat_ratings`, `combat_events`, `stats`, `punishments`, `staff_audit`. Pure schema, no blockers.
2. **Resource-world reset script** (7.4) with the explicit-name refusal, plus a backup immediately before.
3. **Combat tagging and stats** in the plugin. Note the Elo constants themselves are blocked: **Q-11 to Q-13** record three internal contradictions in Appendix B.
4. **Do not run Phase 6** until **Q-41** (memory) and **OA-05** (burstable) are answered. Host memory available is ~560 MB with nobody online.

### Owner actions that block whole phases

**OA-02** no git remote - 42 commits exist on one PC. **OA-03** no host snapshot. **OA-10/12/13** store, price, legal text - Phase 1's paywall cannot start. **OA-16** Discord webhook - monitoring detects but cannot alert. **OA-27** anti-cheat. **Q-10** the economy has no numbers anywhere in the specification, which blocks Phase 3 and everything behind it.
