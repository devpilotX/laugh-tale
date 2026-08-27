# LaughTail SMP

A paid-access, whitelist-gated, competitive survival Minecraft server. Currency is **Berries**. Rank is earned by PvP and nothing else. Seasons are monthly with exactly one Champion. Every player is equal: one price, one set of features, nothing for sale but access.

Spec 29.10 asks this file to state the problem, the constraints, the three hardest decisions, and the measured numbers with the method that produced them. That is what follows.

## The constraints

| Constraint | Value |
| --- | --- |
| Host | AWS EC2 `t4g.medium`, ap-south-1 (Mumbai). **2 vCPU, 3.8 GB usable RAM, arm64** |
| Realistic player cap | 20-24 concurrent, to be set from measurement, not assertion |
| Performance target | MSPT under 25 ms in normal play, under 40 ms in events. A product requirement, not an aspiration |
| Panel | Pelican, already installed, Wings active |
| Build location | Directly on the VPS. There is no local build stage |
| Hard rule | The two Paper servers never run at the same time - combined allocation exceeds the box |
| Legal | Mojang's EULA and Commercial Usage Guidelines outrank every other consideration |

## The three hardest decisions

**1. Rank comes from PvP only, and nothing else contributes.** Acceptance row 30 states it as a test: two hours of mining, farming and building must change rating by *exactly zero*. This is harder than it sounds, because every anti-farm protection - diminishing returns on repeat kills, same-IP detection, combat tagging, staff exclusion - has to work without punishing honest players. It is also the decision that defines the product: there is no grinding path to the top.

**2. One currency, with the arbitrage audit as a build gate.** The economy has a single currency, dynamic prices in a bounded band, and a script that walks every item and every recipe chain looking for positive-yield cycles. It runs in CI and nightly, and **the build fails on any positive cycle**. Most servers discover their money printer from players; this one refuses to compile with one.

**3. Building on the VPS rather than locally.** Conventional practice is to build and test locally, then ship. Section 30 rejects that as final, and the host inventory proves the point: the host is aarch64 and the build PC is not, so a locally built native artefact would not even run. The cost is that every change touches a live-ish machine; the mitigations are a host snapshot before host-level changes, a drift detector, a deploy script as the only path files take to the VPS, and a destructive-command hook.

## Measured numbers, and the method

Measured 2026-08-26 by `scripts/vps-inventory.ps1` and `scripts/vps-inventory2.ps1` - two read-only SSH sessions. Nothing was installed, started, stopped or written. Both scripts are in the repository so any number here can be re-derived.

| Measurement | Value | Method |
| --- | --- | --- |
| Instance type and region | `t4g.medium`, ap-south-1c | EC2 IMDSv2 metadata |
| Architecture | arm64 / aarch64 | `dpkg --print-architecture`, `uname -m` |
| Memory | 3,825 MB total, 1,458 MB available with only the stock server up | `free -m` |
| Disk | 19 GB root, 9.5 GB free; current world 749 MB | `df -h`, `du -sh` on the Pelican volume |
| Swap reachable by the JVM | Yes - container `MemorySwap` 3,785 MB exceeds `Memory` 3,248 MB | `docker inspect` |
| Existing container CPU share | `CpuQuota` 190000 / `CpuPeriod` 100000 = 1.9 of 2 cores | `docker inspect` |
| Existing heap | `-Xms768M -Xmx2304M` against a 3,097 MiB allocation = 25.6% headroom | `docker top`, `docker inspect` |
| Firewall | ufw active, default deny in; **no UDP rules at all** | `ufw status verbose` |
| SSH posture | key-only; `passwordauthentication no` | `sshd -T` |

Two of these change the plan materially. The instance is **burstable**, so sustained CPU work exhausts credits and throttles below the 20 TPS requirement - which also makes a measured player cap non-reproducible. And the instance is **ARM64**, so every plugin needs a load-proof on this architecture before it is pinned into the manifest. Neither was knowable from the specification, which was written before anyone looked at the machine.

## Repository layout

```
AGENTS.md              Operating rules. Read automatically every session. Short on purpose
README.md              This file
.gitignore             Written before the first commit. Never-break rule 5
docs/
  spec/
    MASTER.md          The specification, v6.0 FINAL, 2,950 lines. The archive
    INDEX.md           The working entry point. 280 headings mapped to 43 files
    00-...33-, A-...G- One file per section and appendix. Load on demand
  progress.md          Running state and the proposed build order
  decisions.md         Decisions and their reasons. Append-only
  rejected.md          Ideas rejected, with why. Prevents re-litigation
  owner-actions.md     Blocked items for the owner. Append-only
  questions.md         Contradictions and ambiguities found in the specification
  acceptance.md        Every acceptance criterion and its evidence
  private/             Never committed. Secrets and detector thresholds
server/                Server configuration, deployed to the VPS from here
scripts/               Every state-changing command lives in a script, never ad hoc
db/migrations/         Schema migrations, version-controlled from the first commit
```

## Recreating this server from scratch

`docs/REBUILD.md` is the runbook: clone, fill in three values, run one command, and a bare VPS becomes an
identical server in about 45 minutes. There is no credential to carry across - the database password
regenerates itself and the IP salt is freshly random.

**It rebuilds the server, not the data.** The world and every player balance live in backups, not in git,
and a 271 MB world does not belong in a repository. `docs/MIGRATION.md` covers moving live data to a new
box; OA-33 covers getting those backups off the machine they are protecting, which is the one gap that
currently matters.

## Where to start

Read `AGENTS.md`, then `docs/progress.md`, then `docs/decisions.md`, then `docs/owner-actions.md` - in that order, every session. Then load only the specification sections the current task needs, using `docs/spec/INDEX.md`. Do not load `MASTER.md`; spec 33.4 explains why.

## Status

**Playable and running. Not yet open to paying players.** Last updated 2026-08-27.

The server runs Paper 26.2 on the VPS with a clean boot, and `docs/progress.md` carries the running
handoff. What exists:

| Area | State |
| --- | --- |
| **Core plugin** | 27 source files, no dependency beyond Paper. Written from scratch |
| **Database** | 7 migrations, 33 tables, forward-only runner that refuses a tampered checksum |
| **Economy** | Single currency, transactional ledger, 777-item shop, dynamic prices, order-book bazaar |
| **Ranking** | Ten PvP tiers, monthly seasons, one Champion enforced by a database constraint |
| **Roleplay** | Six Paths, four Houses, a five-chapter Chronicle. Status only, never power |
| **Ops** | One-command deploy, hourly backups, restore drill that passes, monitoring |
| **Acceptance** | 81 criteria: 9 pass with evidence, 8 partial, 7 built but untested, 57 not started |

### Three things are re-proven on every single boot

Because a check that has to be remembered stops being run:

* **No blocking database call on the main thread.** The plugin deliberately attempts one and confirms
  it is refused.
* **The bazaar cannot create or destroy value.** A real order match runs inside a transaction and is
  rolled back, asserting Berries and items are conserved.
* **The shop cannot be turned into a money printer.** All 1,585 recipes are checked for a profitable
  cycle, pessimistically. If one is found the shop **closes itself** rather than trading.

That last one is not theoretical: it found 220 profitable recipes the first time the full catalogue was
priced, and the server now lowers offending prices automatically.

### What stands between this and opening

* **No anti-cheat.** Tested twice, failed twice - Minecraft 26.2 is too new for any anti-cheat to
  support. On a server whose entire value is a fair PvP ladder this is the launch blocker, and it is a
  decision rather than an engineering task (`docs/owner-actions.md`, OA-32).
* **No land claims**, so griefing is currently unprevented.
* **No load test**, so the 24-player cap is an assertion rather than a measurement.
* **No website or legal pages**, which a paid server needs before it can charge.

`docs/a-to-z.md` is the honest full inventory, including everything missing.

### A note on reading this repository

The commit messages are unusually long on purpose. Each explains *why* a change was made and, where a
bug was found, what the failure mode was - several of them record bugs that were invisible because the
test meant to catch them had silently stopped working. `docs/decisions.md` holds the same reasoning for
the decisions that shaped the design, and `docs/rejected.md` records what was deliberately not built.
