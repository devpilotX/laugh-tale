## SECTION 29 - PELICAN, AND THE REPOSITORY AS THE ONLY SOURCE OF TRUTH

This section was added after the owner confirmed three things:

1. (Superseded by Section 30.) This section originally assumed the server was built on a local machine first. The owner has since decided to build directly on the VPS, and Section 30 is now authoritative on where the build happens.
2. The VPS already runs **Pelican Panel**, with a stock Minecraft server already live and uncustomised.
3. The entire result - configuration, custom plugins, datapacks, documentation - is published to GitHub as the owner's own project, and GitHub is the recovery path if the local copy is ever lost.

Those three facts change decisions in Section 5 and Section 22. **Where this section disagrees with an earlier section, this section wins.**

### 29.1 Verdict on the local-first plan

**SUPERSEDED BY SECTION 30. Build directly on the VPS.** Section 30 explains why that is the right call for this project, and Section 30.2 gives the two-server rule that makes it safe. This subsection and Section 29.2 are retained only as a record of the earlier reasoning. Sections 29.3 through 29.14 remain fully in force.

Why it is right:

- No live players, so every mistake costs nothing. A corrupted world, a bad migration, a plugin that deletes inventories - all free.
- The loop is faster. Restart in seconds, no upload step, no panel round trip.
- You can destroy and regenerate the world as many times as needed while the economy and world border numbers are still being tuned.
- The paid whitelist gate from Section 3 means there is no launch deadline and no audience waiting. Nothing forces you onto the VPS early.
- It matches the build order in Section 28: one phase per session, verified before the next begins.

**The four things local development cannot give you.** Be honest about these or the VPS will surprise you:

| Cannot be tested locally | Why | Where it must be tested |
| --- | --- | --- |
| Real tick performance | Your machine has more cores, faster storage, and no noisy neighbours | VPS only |
| CPU steal time | Steal only exists on shared virtualised hardware | VPS only |
| Real network behaviour | Latency, jitter, packet loss, and UDP handling for voice chat | VPS only |
| A genuine 20-plus player load | Local bots compete with the server for the same cores, so the result is meaningless | VPS only |

**Rule.** Functional acceptance criteria may pass locally. **Every performance criterion in Section 21 counts only when measured on the VPS.** Do not tick a performance row on local hardware, and do not let anyone quote a local MSPT figure as evidence.

### 29.2 Make local resemble the VPS, or the numbers will lie

The most common local-first failure is that everything feels smooth on a developer machine and then stutters on two shared cores. Prevent it by constraining the local container to roughly the target shape from the start:

```yaml
services:
  mc:
    image: itzg/minecraft-server
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 3g
```

This will not reproduce steal time or slower storage, but it does catch the large class of problems where a feature is quietly dependent on having spare cores. If a mechanic only holds tick rate with four cores, you want to know that in week two, not on launch night.

Also keep the local server on the same Java version, the same Paper build, and the same plugin versions as the VPS. Record all three in the manifest required by Section 5. A version difference between local and production turns every debugging session into guesswork.

### 29.3 What Pelican changes

Pelican Panel is a maintained MIT-licensed fork of Pterodactyl, and it is a reasonable choice. It uses the same egg format, so templates from the Pterodactyl and Pelican egg collections both work. Its vocabulary matters, because the build agent will need it:

| Term | What it actually is |
| --- | --- |
| **Panel** | The Laravel web UI plus its SQL database. Users, servers, nodes, scheduled tasks. |
| **Wings** | The Go daemon installed on each host. It talks to Docker and starts, stops and supervises the game server containers. It also serves SFTP. |
| **Node** | One Wings installation, as seen by the Panel. Panel and Wings can live on different machines. |
| **Allocation** | A reserved IP and port pair. Every server needs at least one. |
| **Egg** | The template defining what gets installed and the start command. |
| **Mount** | A host directory exposed into the container. Note: mounts are **not** visible in the Panel file manager and **not** reachable over SFTP, although the server itself can read them. |

**The architectural conflict, and its resolution.** Section 5 assumed a plain Docker Compose stack. Pelican also owns Docker. **Do not run both orchestrators against the same game server** - two systems creating, naming and stopping the same containers is how you lose a world directory. Resolve it by splitting cleanly by environment:

| Environment | Runtime | Deployment mechanism |
| --- | --- | --- |
| Local | Docker Compose, or a plain Java process | Edit files directly in the working tree |
| VPS | Pelican egg, container managed by Wings | Push the server tree in, per 29.8 |

This costs nothing, **because the repository does not contain a runtime. It contains a server tree.** Enforce that with one hard rule:

> **No file in the repository may contain an absolute host path, a container name, or a Pelican server UUID.** Every path is relative to the server root. This is the Section 5 portability contract, and Pelican is its first real test.

Four Pelican operational facts that will otherwise cost you a bad evening:

- **Back up the Panel APP_KEY off the server, today.** It encrypts stored credentials. If it is lost, that data is unrecoverable even with a full database backup.
- **Enable the Panel scheduler cron and the queue worker.** If they are not running, scheduled tasks and panel-side backups silently never fire, with no error anywhere.
- **If the Panel uses TLS, Wings must too**, and putting the Panel behind a proxying CDN commonly breaks the Panel-to-Wings handshake. Keep the Wings endpoint unproxied.
- **Treat the currently live stock server as disposable.** It has no customisation and no players. Do not attempt to preserve or upgrade it. Create a fresh server from the egg at migration time and delete the old one once the new one is verified.

### 29.4 The memory arithmetic that breaks Minecraft under Pelican

**This is the single most likely way the VPS bites you, and it has nothing to do with your code.**

The default Minecraft eggs set the Java maximum heap to the full container allocation. Java then needs a substantial amount of memory *outside* the heap: metaspace, code cache, garbage collector structures, thread stacks, direct byte buffers, and the JVM itself. When the heap grows toward its configured maximum, total container usage exceeds the hard limit, and the server freezes or is killed. This is a repeatedly reported failure against the official eggs at a 4 GB allocation, and the symptom - a server that runs fine for hours and then locks up - is easy to misdiagnose as a plugin bug.

Budget it explicitly. On the current 2 core / 4 GB box:

| Consumer | Approximate cost |
| --- | --- |
| OS plus Docker engine | 350 to 450 MB |
| Wings daemon | around 100 MB |
| Panel stack, if on the same box (PHP, web server, database, cache) | 500 to 800 MB |
| Remaining for the game server container | what is left, and it is less than you think |

Resulting settings:

| Layout | Container allocation | Maximum heap |
| --- | --- | --- |
| Panel and Wings both on the game box | 3.0 GB | 2.0 to 2.2 GB |
| Wings only, Panel elsewhere | 3.4 GB | 2.5 GB |

**Rules.**

- **The maximum heap must never equal the container allocation.** Leave at least 25 percent of the allocation, and never less than 768 MB, outside the heap.
- Set the initial heap equal to the maximum heap. A growing heap on a memory-constrained box causes avoidable garbage collection churn.
- Keep the Aikar flags already specified in Section 5, but override the egg's default heap value rather than accepting it.
- **Prove it before launch:** run at full expected player load for three continuous hours and confirm container memory plateaus and stays below the allocation. A container that climbs steadily has not passed.

Note also the standing Pelican recommendation to keep game server files on a partition separate from the root filesystem, so a filling disk cannot make the host unbootable.

### 29.5 Where the Panel should live

| Option | Trade-off |
| --- | --- |
| Panel and Wings on the game box (current) | Simplest. Costs 500 to 800 MB and some CPU on the box whose tick budget is already tight. |
| Panel on a separate small box, Wings on the game box | Gives the game server most of the RAM back. Costs a few dollars a month and a second machine to maintain. This is a normal Pelican deployment, not a workaround. |
| No panel, Compose only | Cheapest in resources. Loses the console, SFTP, scheduled restarts, resource graphs, and safe file access without SSH. |

**Recommendation:** keep the current layout through the build phase and do not change infrastructure on a guess. At the first real load test on the VPS, measure MSPT at 20 to 24 players. **If MSPT sits within 20 percent of the 40 ms warning line, move the Panel to its own box** and leave only Wings on the game host. Record the measurement and the decision in `docs/decisions.md` either way.

Do not remove Pelican merely to reclaim RAM. For a solo owner, the console, the start and stop control, and SFTP are worth real money in avoided mistakes.

### 29.6 The one-way flow rule

**Files flow local to git to VPS. Never the other direction. Never edit files on the VPS.**

This rule is the entire reason your GitHub recovery plan works, and Pelican makes it unusually easy to break: the Panel has a browser file editor, a console, and SFTP on port 2022. Changing one YAML value in the browser at two in the morning is a single click.

What breaks when the rule is broken:

- The next deploy silently reverts the fix, and the bug comes back with no explanation.
- Or the deploy conflicts, and you cannot tell which side is correct.
- Either way the repository stops describing the running server, and at that moment it stops being a backup of anything.

**The one permitted exception.** During a live incident you may edit on the server to stop the damage. **The change must be copied back into git in the same session, before you stop working.** If it is not in git by the end of the session, it did not happen and it will be lost.

**Drift detection.** Add `scripts/drift.sh`. It hashes every git-tracked configuration file on the VPS, compares against the committed version, prints any file that differs, and exits non-zero if any do. Run it as the first step of every deploy and as part of the daily health check. It must check only tracked files - the world, player data and the database differ constantly by design, and that is not drift.

### 29.7 What goes in git, and what must never

| Goes in git | Never in git |
| --- | --- |
| Server configuration: `server.properties`, `paper-global.yml`, `paper-world-defaults.yml`, `spigot.yml`, `bukkit.yml` | `.env` and every real secret |
| Every `plugins/<Plugin>/config.yml` and permission definition | `world/`, `world_nether/`, `world_the_end/`, `resource_world/` |
| `datapacks/laughtail/` in full | Player data, statistics, advancements |
| Custom plugin source code, build files, tests | Any `.jar` - server jar and plugin binaries alike |
| `db/migrations/`, `scripts/`, `docs/` including the specification | Logs, caches, `libraries/`, `versions/` |
| `docker-compose.yml` for local use, `.env.example`, `.gitignore` | Backup archives |
| `AGENTS.md`, `README.md`, `LICENSE` | The Panel database and the Panel APP_KEY |
| The exported Pelican egg JSON, so the runtime is reproducible | Plugin data directories holding player state (`.db`, `.mv.db`, `data/`) |

**The asymmetry that matters.** Before launch, local is the source of truth for everything. After launch this splits permanently:

- **Git is the source of truth for code and configuration.**
- **The VPS is the source of truth for player data.**

Neither can reconstruct the other. So:

> **GitHub protects you from losing your work. Backups protect you from losing your players' work. They are different problems and they need different mechanisms.** Publishing to GitHub does not reduce the Section 22 backup and restore-drill requirements by one line.

### 29.8 The deploy procedure

Once the VPS is live, every change reaches it this way and no other way.

| Step | Action | Gate |
| --- | --- | --- |
| 0 | Run `scripts/drift.sh` | Stop if it reports drift. Reconcile first. |
| 1 | Build and test locally: compile, unit tests, plugin loads clean on a fresh local server | Any failure stops the deploy |
| 2 | Commit, push, and tag the release | The tag is what you roll back to |
| 3 | Announce the restart in-game and on the site | Whitelist server, so a short notice is enough |
| 4 | Stop the server from the Panel, cleanly | Never kill the container to stop it |
| 5 | Take a backup: world, database, plugin data - and confirm it restores | An unverified backup is not a backup |
| 6 | Push the server tree over SFTP on port 2022 using the deploy script | Script only. No manual file manager edits. |
| 7 | Start, watch the console to fully loaded, confirm the plugin list matches the manifest | Unexpected or missing plugin means roll back |
| 8 | Run the functional smoke subset of Section 21 | Any failure means roll back |
| 9 | Record the deploy, the git tag and the result in `docs/progress.md` | Undocumented deploys make the next incident unsolvable |

**Rollback path:** stop the server, restore the pre-deploy backup, redeploy the previous tag. **If you cannot state the rollback path out loud before step 4, do not deploy.**

**Rule.** The deploy script is the only mechanism by which files reach the VPS. Not the file manager, not an ad-hoc SFTP client, not a console command.

### 29.9 Three migrations, and why the first is a rehearsal

You will migrate at least three times:

1. **Local to VPS** - planned, no players, nothing at risk.
2. **VPS to a larger VPS** - later, with real players, real balances, and time pressure.
3. **Any future provider or panel change** - whenever it comes.

All three use the Section 22 runbook. The important consequence: **migration one is a free, zero-risk rehearsal of migration two.** Treat it that way. Time each step. Write down every manual action, including the ones that felt too obvious to record. Note everything you had to look up. **The deliverable of migration one is not a working server - it is a runbook accurate enough that migration two is boring.**

Two decisions to settle before migration one:

- **Fix the production world seed now and never change it.** Regenerating the world later destroys every player build.
- **Chunk pregeneration:** pregenerating locally and transferring region files saves VPS CPU, but those files are large. Measure the transfer against simply pregenerating on the VPS overnight before assuming local is faster.

### 29.10 The portfolio standard: what "human written" has to mean

This requirement is worth taking seriously, because as a *quality gate* it makes the codebase genuinely better. But it is two separate requirements, and they need separating.

**Requirement A: the code carries no machine residue and meets a real professional standard.**

- No generated attribution anywhere: no "generated with" notices, no co-author trailers, no tool names in comments or commit messages.
- No comment that restates the code. Comments explain **why**, never what.
- No speculative abstraction: no interface with a single implementation, no configuration option nothing reads, no factory for one object.
- No dead code, no commented-out blocks, no unused imports, no leftover debug logging.
- One style, enforced by a formatter and a linter in CI, so style stops being a matter of opinion.
- **Commits are one logical change each**, with an imperative subject under 72 characters and a body explaining why. Never a commit titled "implement section 8". If a session produced a four-thousand-line commit, split it with an interactive rebase before pushing.
- The README, the architecture notes and the decision records are written **in your own words**. They are the part a reader actually reads.

**Requirement B: you can explain every line.** This is the one that decides whether the project is worth anything to you.

- Nothing merges to `main` until you have read every line of it.
- For each file, you must be able to answer: what does this do, why does it exist, what breaks if it is deleted, and why this approach rather than the obvious alternative.
- **Anything you cannot answer gets rewritten by you, or deleted. There is no third option.**
- Budget roughly a third of your time for review. If a session generates more than you can review in that session, the session was too large - the same rule as Section 28.6, for the same reason. Having plenty of credit does not raise this limit, because the limit is your review capacity and the context window, not the budget.

**One thing worth saying plainly.** Building a project with AI assistance and then presenting it as your project is ordinary practice, and nobody expects you to have typed every character. What does not work is claiming a process you did not follow if someone asks directly - an employer, a university, or a competition with disclosure rules. Answer that honestly if it is ever asked. It costs you nothing, because the thing that impresses a competent reviewer here was never typing speed.

**And you are undervaluing what you actually authored.** The specification is yours: rating driven purely by PvP, monthly resets, absolute equality with no purchasable advantage, exactly one champion per season, the refusal to build a wagering escrow, the paid whitelist as the anti-cheat strategy, the portability contract. Those are product and architecture decisions, and they are precisely what a senior reviewer looks for. **Commit the specification and the decision records alongside the code.** A well-argued `docs/decisions.md` and `docs/rejected.md` will do more for you than any quantity of source, because almost no portfolio project has them - and `rejected.md` in particular demonstrates the judgement that hiring managers claim to want and rarely see evidence of.

What the README must contain: the problem, the constraints you designed against, the three hardest decisions and why you chose as you did, the measured performance numbers with the method used to obtain them, and what you would do differently next time.

### 29.11 What must not be published

A public repository publishes your own countermeasures. Treat the following as sensitive:

- The wagering detector signatures, windows and thresholds from Section 3.5.1.
- The shop arbitrage guard and the economy value model constants from Section 8.
- Anti-cheat configuration and tolerance values.
- Rate limits, and the exact backup and restore schedule.
- Staff command lists with their permission nodes.
- Anything documenting what is **not** monitored.

**Rule: never publish a threshold that tells someone exactly how to stay underneath it.**

The practical approach: **keep the repository private until launch.** After launch, publish the code and configuration, exclude a `docs/private/` directory, and keep trust-and-safety detail in a separate private repository. You lose nothing for portfolio purposes - a reviewer cares about the architecture and the decision records, not your detector constants.

And per Section 28.10: **a secret that reaches a public commit is compromised permanently.** A later commit does not remove it from history. Rotate it.

### 29.12 Licensing for a public repository

- **Add a LICENSE file when the repository is created, not later.** Without one, nobody may legally reuse the work, and an unlicensed "project" reads as unconsidered.
- **Check the licence of anything you build against.** Some plugins in the candidate list are GPL-3.0. If you publish plugin source that links against GPL-3.0 code, the safe reading is that your plugin must also be GPL-3.0. Three clean ways out: license your own plugin GPL-3.0, use a soft dependency and reflection so you do not link against it, or choose a differently licensed plugin. **Decide before writing the code and record it in `docs/decisions.md`** - discovering this after the plugin is written is an expensive rewrite.
- **Never commit third-party jars.** Reference them in the Section 5 manifest with versions and checksums.
- **Never commit the Minecraft server jar or any paid plugin binary.** Paid resources almost always prohibit redistribution, and a public repository is redistribution.

### 29.13 Access model: what the API can do, and what still needs SSH

**SUPERSEDED BY SECTION 33.1.** The owner has chosen to grant root SSH access to the host and to create **no Pelican API keys at all**. Root SSH is a strict superset of both key types, so nothing here becomes impossible. **Do not ask the owner for API keys.** This subsection is retained because the distinction below is still worth understanding, and because it becomes relevant again if API access is ever added for automation. Read Section 33.1 for the access model actually in force, including the file-ownership trap that root access introduces.

The key created in the panel admin area is **not sufficient on its own**, and the reason is structural rather than a permissions mistake. Pelican exposes two separate APIs with different key types, and file operations are not in the administrative one.

| | **Application API** | **Client API** |
| --- | --- | --- |
| Key created at | Admin area, API Keys | Your account settings, API credentials |
| Base path | `/api/application` | `/api/client` |
| Purpose | Administrative CRUD on panel objects | Operating a server you own |
| Covers | Servers (create, update, delete, transfer), nodes, allocations, users, eggs, database hosts, server databases, mounts, roles | Power state, console, **all file operations** (list, read, write, upload, download, copy, rename, compress, decompress, pull remote file, permissions), backups, schedules, startup variables, network |
| Does **not** cover | Any file operation, power control, or console access | Anything administrative: creating servers, nodes, or users |

**Conclusion: the migration needs both keys.** The admin key provisions the server; the client key puts files into it and starts it. Neither can do the other's job, and this separation is long-standing behaviour in this codebase family, not a bug to work around.

**The third access path: SFTP.** Wings serves SFTP on port **2022**, authenticated live through the Panel, with the username format `<panel-username>.<8-character-server-id>`. For pushing an entire directory tree this is the practical tool - far better than issuing hundreds of file-write API calls. Two caveats: host mounts are not visible over SFTP, and some paths may be refused because they sit on the egg's denylist.

**Which mechanism each migration stage uses:**

| Stage | Mechanism |
| --- | --- |
| Create the production server: node, allocation, egg, memory, disk, CPU limits | Application API |
| Create the server database, if using a panel-managed one | Application API |
| Set startup variables, including the heap value from 29.4 | Client API |
| Upload the built server tree | SFTP on 2022, or Client API upload or pull plus decompress |
| Start, stream the console, confirm the plugin list | Client API |
| Take a backup and verify it restores | Client API |
| Delete the old server, after the new one passes | Application API |

**None of that requires host SSH.** The migration itself is fully automatable from the two keys plus SFTP.

#### Scope the admin key down

Setting every permission to Read and Write, as the panel's "Set All Permissions" shortcut invites, hands any holder of that key full control of the panel. Given that this key will be used by an automated build agent, apply least privilege:

| Permission | Set to | Reason |
| --- | --- | --- |
| Server | Read and Write | Create the new server, delete the old one |
| Allocation | Read and Write | Assign the game port |
| Egg | Read | Select an egg; never modify one from a script |
| Node | Read | Read capacity only |
| Server Database | Read and Write **only** if using a panel-managed database, otherwise None | Least privilege |
| Database Host | None | Deploys never reconfigure database hosts |
| User | **None** | A key that can write users can create an administrator |
| Role | **None** | Same reason |
| Mount | None | Mounts require host access regardless |
| Plugin | None | No deploy script needs to touch panel plugins |

Also on that same screen:

- **Use the Whitelisted IPv4 Addresses field.** It is the strongest control available on the key creation page. Restrict the key to the machine that runs deploys. Residential addresses change, so expect to update it.
- **Write a real Description.** Unlabelled keys cannot be audited or safely revoked later.
- The key is displayed once. Store it in a password manager, never in the repository, never in a committed environment file. Sections 28.10 and 29.7 apply without exception.
- **Client API keys currently have no scopes at all** - they are all or nothing. Treat the client key as the more dangerous of the two despite its name, and rotate it after migration.

#### What genuinely requires SSH

SSH is not needed for the migration. It is needed for the host, and several items below are direct requirements of this specification:

| Task | Why the API cannot do it | Reference |
| --- | --- | --- |
| Open UDP 24454 for voice chat in the host firewall | The host firewall sits outside the panel | Voice section |
| Measure CPU steal time | Not observable from inside a container | Section 21 |
| Back up the Panel APP_KEY | Lives in the Panel environment file on the host | 29.3 |
| Enable the scheduler cron and the queue worker | systemd and crontab | 29.3 |
| Change Wings configuration: allowed mounts, SFTP port, overallocation | `/etc/pelican/config.yml` plus a service restart | - |
| Move the Panel to its own machine | Full reinstall | 29.5 |
| Put server files on a separate partition | Host storage layout | 29.3 |
| Patch the OS, Docker engine, and Wings | Host package management | Section 22 |
| Recover when the Panel itself is down | The API is unavailable exactly when it is needed most | Section 22 |

> **Rule: keep SSH access. Use the API for deploys and SSH for the host.** These are not competing options. Configure SSH with key authentication only, password authentication disabled, root login disabled, and the non-root user required by 28.3.

#### The delete order

Nothing on the currently live stock server is worth keeping, and deleting it is correct. **But the order matters, because deleting a server deletes its volume, and 4 GB will not run the old and new servers simultaneously.**

1. Export the egg JSON and commit it, per 29.7.
2. Record the allocation, port, and server identifier.
3. Stop the old server. **Do not delete it yet.**
4. Create the new server, upload the built tree, start it, and run the functional smoke subset of Section 21.
5. Only once it passes, delete the old server.
6. Rotate the panel password and SFTP credentials afterwards. Credential revocation on server deletion has historically been unreliable in this codebase family, so rotate rather than assume.

#### The clean-slate rule

What crosses from local to production, and what must not:

| Migrates from local | Must start empty on the VPS |
| --- | --- |
| Server and plugin configuration | The world, or a freshly pregenerated world on the fixed seed |
| Datapacks | Player data, statistics, advancements |
| Custom plugin jars built from committed source | The economy database and the full ledger |
| Permission definitions | Ranks, ratings, and season history |
| Database migration files | The whitelist |

The reason is not tidiness. A local test world carries administrator-granted items, invented balances, and test kills. **The Section 8 economy audit and the Section 9 rating system both assume a clean ledger from day one.** Carrying test data forward silently invalidates every economy acceptance number in Section 21, and there is no way to separate it out afterwards.

#### Give the agent the right reference

The authoritative endpoint list for the installed panel version is served by the panel itself at `/docs/api` - sign in to the panel first, then open it. Point the build agent there rather than at any third-party API reference, because it matches the exact version running. If panel access is wired into the agent through an MCP server rather than direct HTTP calls, review that server's source before granting it a key, per 28.1.

### 29.14 Acceptance criteria

| ID | Criterion | Evidence |
| --- | --- | --- |
| 29-1 | No file in the repository contains an absolute host path, container name, or Pelican server UUID | Grep across the tree, output empty |
| 29-2 | The local container is constrained to the VPS core and memory shape | Compose file plus a screenshot of the running limits |
| 29-3 | Panel APP_KEY is backed up off the server | Owner confirmation, location recorded in the runbook |
| 29-4 | Panel scheduler cron and queue worker are both running | Service status output |
| 29-5 | Maximum heap is at least 25 percent below the container allocation, minimum 768 MB of headroom | Start command plus allocation screenshot |
| 29-6 | Container memory plateaus below the allocation across a three-hour full-load run | Memory graph over the full window |
| 29-7 | `scripts/drift.sh` exists, runs clean, and is invoked by the deploy script and the daily health check | Script plus two consecutive clean runs |
| 29-8 | A deploy has been performed end to end using only the deploy script, with a verified pre-deploy backup | Deploy log entry in `docs/progress.md` with git tag |
| 29-9 | A rollback has been rehearsed at least once on the VPS before launch | Restore drill record per Section 22 |
| 29-10 | Migration one produced a timed, step-by-step runbook | `docs/06-migration.md` with recorded timings |
| 29-11 | `.gitignore` excludes every item in the right-hand column of 29.7, and no excluded item appears in history | `git log` search for each pattern, all empty |
| 29-12 | LICENSE present, and any GPL linkage decision recorded | LICENSE file plus the `docs/decisions.md` entry |
| 29-13 | Every file in `main` has been read by the owner, and nothing unexplainable remains | Owner sign-off recorded per phase in `docs/progress.md` |
| 29-14 | Both an Application API key and a Client API key exist, each scoped as narrowly as the panel allows, and neither appears anywhere in the repository | Panel key list plus a git history search for both key prefixes |
| 29-15 | The Application API key is IP-restricted and carries a description, with User, Role, Mount, Plugin and Database Host all set to None | Panel key list screenshot |
| 29-16 | The old server was deleted only after the new one passed the smoke subset, and panel and SFTP credentials were rotated afterwards | Deploy log entry in `docs/progress.md` |
| 29-17 | Production world, player data, and economy database all started empty or freshly generated | First-day economy audit showing a zero-balance ledger |

---

