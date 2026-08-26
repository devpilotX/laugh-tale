## SECTION 30 - THE BUILD ENVIRONMENT DECISION: BUILD ON THE VPS

**This section supersedes Sections 29.1 and 29.2 where they disagree.** Those sections recommended building locally first. The owner has decided to build directly on the VPS, and on re-examination that is the correct decision for this project. Sections 29.3 through 29.14 remain fully in force.

### 30.1 The decision, and why it is right here

Build directly on the VPS. Do not build on the owner's PC. This is final. Do not reopen it in a later session.

The reasoning, recorded so no future session has to rediscover it:

* **The target environment already exists.** Pelican Panel and Wings are installed and working on the VPS, and a stock Paper server is already live on it. Building locally would mean constructing a second copy of an environment that is already running, then maintaining both of them forever.
* **The owner's PC cannot validate a single Section 21 performance criterion.** It cannot reproduce CPU steal time, the container memory limit, the real network path, or genuine concurrent player load. Every performance number produced locally would have to be measured again on the VPS before it could be trusted. A measurement that must be repeated is not a test, it is a rehearsal.
* **One environment cannot drift from itself.** Section 29.6 exists because two environments diverge. Removing the second environment removes the failure mode entirely.
* **Law 1.** Fewer moving parts. Simplicity is a feature on this project, not a compromise.

What is lost, stated plainly rather than glossed over:

* A slower edit-and-test loop. Section 30.3 recovers most of it.
* No free safety net: a destructive command reaches the only copy that exists. Section 30.2 is the answer to that, and it is not optional.

### 30.2 Two servers on one panel: the rule that makes this safe

Create **two** servers in Pelican, not one.

| Server | Identifier | Purpose | When it runs |
| --- | --- | --- | --- |
| Development | `laughtail-dev` | Every build, test, experiment, and restart loop | Throughout the build. Stopped after launch except during deploy rehearsals |
| Production | `laughtail` | The server players connect to | Stopped until launch. Running afterwards |

The rules, all of them hard:

1. **All agent work happens on dev.** The agent may never write to production by any route except running `scripts/deploy.sh`.
2. **Only one of the two runs at a time.** This box is 2 vCPU and 4 GB. It cannot host two Paper servers at once, and it does not need to.
3. **Production is created empty and stays empty until launch.** World, player data, economy ledger, ranks, season history, and whitelist all start from nothing. This restates the clean-slate rule in Section 29.13 and it is not negotiable: Section 8's economy audit and Section 9's rating both assume a ledger with no prior history.
4. **The existing stock server is disposable.** Stop it, do not delete it, until dev has booted and passed a smoke test. Then delete it and reclaim its allocation and its port.

Memory, extending the arithmetic in Section 29.4:

| Server | Container allocation | `-Xmx` | Reasoning |
| --- | --- | --- | --- |
| `laughtail-dev` | 1.5 GB | 1.0 GB | Enough to boot, run integration tests, and hold two to four test clients |
| `laughtail` | 3.0 GB | 2.0 to 2.2 GB | Per Section 29.4, with the Panel co-located on the same box |

The combined 4.5 GB exceeds the box, and that is acceptable **only** because the two never run together. Set the node memory limit to physical RAM minus the reserve for the OS, the Panel, and Wings, then enable memory overallocation on the node and enforce the never-both-running rule by procedure. If overallocation is uncomfortable, drop dev to 1.0 GB with `-Xmx 768m`; it will still boot and still run every test.

`-Xmx` must never equal the container allocation. Leave at least 25 per cent, or 768 MB, outside the heap. Section 29.4 explains what happens when this is ignored, and it is a freeze, not a crash.

### 30.3 Keeping the loop fast without a local server

* **Run the Kiro CLI on the owner's PC, not on the VPS.** The agent edits the git working copy locally, then ships changes to dev with `scripts/deploy.sh` over SFTP on port 2022. Two reasons: an agentic CLI running on a 2-vCPU box competes for CPU with the very server it is measuring, and the agent's working state should not live on the machine that later becomes production.
* **Compile and unit-test locally.** Java compilation and MockBukkit tests need neither a Minecraft server nor the VPS. Only integration tests need dev. Most of the loop time lives here, and it stays local and fast.
* **Keep dev warm.** Do not restart for every change. Use `/laughtail reload` for configuration-only changes, and never `/reload`.
* **Read logs through the Pelican console** rather than over SSH wherever the console is sufficient.
* **One deploy per task, not one per edit.** Batch a task's changes, deploy once, test once.

### 30.4 What must never be done directly on the VPS

Every one of these breaks portability, which the owner named as a hard requirement.

1. **Never edit a configuration file through the panel file manager or SFTP as the primary action.** Edit it in the repository, commit, then deploy. If a file is edited on the server to test a hypothesis, it must be copied back into the repository and committed in the same session, or reverted before that session ends.
2. **Never install a plugin by uploading a jar by hand** without recording it in the repository manifest with version, source URL, and checksum.
3. **Never run a one-off state-changing command** without adding it to a script in `scripts/`.
4. **Never let data exist only on the VPS**, other than the live world and the live database, both of which backups already cover.
5. **Every session ends with `scripts/drift.sh` reporting zero drift** between the repository and dev. A session that ends with drift is not a finished session.

### 30.5 Migration becomes three rehearsed moves

| Move | From and to | When | What it proves |
| --- | --- | --- | --- |
| 1 | dev to production, same box | Launch | First real use of `deploy.sh`, on a box where a mistake costs nothing |
| 2 | production to a larger VPS | When demand passes 20 to 24 concurrent players | Move 1 already proved the procedure end to end |
| 3 | Any later move | Later | Identical procedure, no new risk introduced |

Because every move runs the same script against the same repository, the owner's requirement to migrate without deleting anything is satisfied by construction. Nothing is deleted. A new server is built from the repository and the data volume is restored into it. The old server is stopped, kept until the new one passes its smoke test, and only then removed.

### 30.6 Acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 30-1 | Two servers exist in Pelican, dev and production, and production is empty | Panel view plus an empty world directory listing |
| 30-2 | Production has never been written to except by `deploy.sh` | Deploy log cross-checked against file timestamps |
| 30-3 | The two servers have never run simultaneously | Panel activity log |
| 30-4 | `scripts/drift.sh` reports zero drift at the end of every session | Script output committed to `docs/progress.md` |
| 30-5 | Every deployed plugin appears in the repository manifest with version and checksum | Manifest diffed against the running server |
| 30-6 | A full deploy from a clean checkout onto an empty dev server succeeds unattended | Timed run recorded in `docs/06-migration.md` |

---

