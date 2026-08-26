## SECTION 22 - THE MIGRATION RUNBOOK

The owner's plan: build now on a small box, and migrate to a bigger, cheaper VPS once there are players. **This is a good plan.** This section makes it a thirty-minute job instead of a weekend of panic.

### 22.1 The portability contract, restated

Everything in 5.1 exists for this section. Re-read it. If every rule there is honoured, migration is: copy a directory, bring up the stack, change DNS. If any rule is broken, migration is an outage.

### 22.2 How to choose the next host - in priority order

Most people buy on RAM. **That is the wrong metric and it is the most expensive mistake in server hosting.** Minecraft's main thread is largely single-threaded, so the game is bounded by how fast one core runs, not by how many gigabytes are idle.

| Priority | Criterion | Why it comes here |
|---|---|---|
| **1** | **Network latency to your players** | The owner's players are largely in India. A server in Singapore or Mumbai will feel dramatically better than a cheaper one in Germany, no matter how good the specs are. In PvP, latency **is** fairness. Ping decides who wins a fight, and no amount of RAM compensates for 200 ms |
| **2** | **Dedicated vCPU and single-core clock speed** | Shared or burstable vCPUs are the number one cause of unexplained lag spikes. Ask explicitly whether cores are dedicated. After purchase, **measure CPU steal time** - a persistently non-zero steal percentage means the host is overselling and your neighbours are stealing your ticks. Steal time is invisible from inside the game and will drive you mad if you do not know to look for it |
| **3** | **NVMe storage** | Chunk loading and saving is disk-bound. NVMe over SATA SSD is a visible difference when players spread out |
| **4** | **Bandwidth allowance and egress pricing** | Minecraft plus voice plus a live map consumes real bandwidth. Metered egress can quietly cost more than the server itself |
| **5** | **RAM** | Genuinely last. 8 GB on fast dedicated cores beats 32 GB on oversold shared cores, every time. Note from 6.4 that an oversized heap actively **hurts** through longer garbage-collection pauses |
| 6 | DDoS protection **with UDP support** | Required for Bedrock and voice (13.3) |
| 7 | Snapshot and backup features | Convenience, not a substitute for your own backups |
| 8 | Honest support | You will need it once, at the worst possible moment |

### 22.3 Sizing guide

| Concurrent players | vCPU | RAM | Heap | Notes |
|---|---|---|---|---|
| Up to 24 | 2 dedicated | 4 GB | ~2.5 GB | Current box. Adequate for launch |
| 40 to 60 | 4 dedicated | 8 GB | ~6 GB | The realistic first migration target |
| 60 to 100 | 6 to 8 dedicated | 16 GB | ~10 GB | Consider splitting the arena to a second instance behind a proxy |
| 100 plus | 8 plus dedicated | 32 GB | ~12 GB | Multi-instance behind a proxy is now mandatory, not optional. **A single Paper instance does not scale linearly no matter what you buy** |

Note the ceiling in that last row honestly: past roughly 100-150 concurrent players, the answer is never a bigger box. It is more boxes behind a proxy, or a regionalising fork. Plan for that architecture before you need it.

### 22.4 Notes on specific providers

Evaluate at the time of purchase, but these patterns hold:

* **Budget VPS providers with dedicated vCPU plans** are usually the best value for this workload, and are a straightforward step up from the current box.
* **Very cheap European providers** offer extraordinary specs per rupee. The catch for this project is **latency to India**, which no amount of specs fixes. Only consider them if the playerbase is actually European.
* **The cheapest oversold providers** show up as high steal time and unexplained stutter. Their price is real and so is the reason for it.
* **The current cloud provider** is fine for building and is convenient, but its **egress charges** are the strongest argument for moving once player traffic and voice traffic grow. Note that some cloud providers will waive egress fees specifically for a full migration away - if you are moving off, it is worth asking, because that is a discount that exists precisely for this situation.
* **Managed Minecraft hosts** are worth considering only if you want to stop being the sysadmin. They cost more and give less control, and this entire document assumes you keep control.

### 22.5 The evaluation protocol - never migrate on a promise

1. Buy **one month** of the candidate host. One month, not a year, no matter how good the annual discount looks.
2. Deploy the full stack from the repository. If this takes more than 30 minutes, the portability contract is broken - **fix the repository, not the host.**
3. Restore a real backup into it.
4. Measure: CPU steal time, single-core benchmark, disk throughput, and latency from several real player locations.
5. Run the full bot load test (6.8) on the new box. Compare MSPT against the current box at identical player counts.
6. **Only then** decide. If the numbers are not clearly better, you have lost one month's fee and learned something cheap.

### 22.6 The migration procedure

**SUPERSEDED BY SECTION 22.11.** This subsection was written before the Pelican Panel was in the picture and describes a manual full-stack relocation. It is kept only as the conceptual outline, because the ordering logic is still correct. **For the actual procedure, follow 22.11 (node transfer) or 22.12 (full relocation). Where this subsection and 22.11 disagree, 22.11 wins.**

Publish the window at least 48 hours in advance. Never migrate during a season ending, a War Event, or the Finale.

**Preparation, days before:**

1. New host provisioned, firewall configured, Docker installed.
2. Repository cloned; the environment file recreated with **freshly rotated secrets** - never reuse the old ones.
3. Full stack brought up and smoke-tested with a throwaway world.
4. Lower the DNS time-to-live to 60 seconds. Do this **days ahead**, or the low value will not have propagated when you need it.

**Migration day:**

5. Announce, then enable maintenance mode.
6. Stop the game server cleanly. **Never copy a live world directory** - a half-written region file is a corrupted world.
7. Take a fresh full backup and verify its checksum.
8. Transfer the state directory. Verify checksums on arrival.
9. Bring up the new stack. Watch the logs to a clean start.
10. **Verify before switching DNS:** world loaded, database connected, player data intact, a test login works, homes and balances correct, the voice UDP port responds, and the plugin set has no errors.
11. Switch DNS. Keep the old server **stopped but not deleted** for at least 72 hours.
12. Restore the DNS time-to-live to normal after propagation.

**After:**

13. Monitor MSPT for 24 hours and compare against the recorded baseline.
14. Confirm backups are running on the new host, then **run a restore drill there** before deleting the old server.
15. Rotate every remaining credential.
16. Only now destroy the old server.
17. Update the migration document with what actually happened, including anything that surprised you. The next migration will be easier only if you write this down.

### 22.7 Migration acceptance criteria

These are the general criteria. **Section 22.15 adds the Pelican-specific rows, and both sets must pass before the old server is deleted.**

* [ ] The whole procedure completes inside the announced window.
* [ ] Zero player data lost - balances, homes, claims, cosmetics, stats, season standings, Champion records.
* [ ] Voice works on the new host, verified over the real internet with a UDP-aware check.
* [ ] Bedrock connectivity works on the new host.
* [ ] MSPT is equal to or better than the old baseline at the same player count.
* [ ] A restore drill has succeeded on the new host.
* [ ] Every secret has been rotated.
* [ ] The migration document is updated.

### 22.8 What a Pelican backup contains, and what it does not

This is the single most dangerous misconception about migrating this server. **A Pelican backup is not a backup of your service.** It is a `tar.gz` of one server's data directory and nothing else.

| Inside a Pelican server backup | **Not** inside it |
| --- | --- |
| The world folders | **The game database** - Berries, ranks, season history, homes, claims, punishments |
| `plugins/` including every jar and config | **The Panel** and the Panel's own database |
| `server.properties`, `paper-global.yml`, `bukkit.yml`, `spigot.yml` | **The Panel's `APP_KEY`** |
| `datapacks/` | Wings configuration and the node token |
| The server jar | Firewall rules, DNS, cron jobs, systemd units |
| `eula.txt`, `ops.json`, `whitelist.json` | The Pelican egg definition |
| Player data files in `world/playerdata/` | Backup destination credentials |

Restoring a Pelican backup onto a fresh box gives you a folder of files with nothing to run them. **If the game database is not restored alongside it, every Berry balance, every rank, every season record, and every claim is gone** even though the world loads perfectly and looks fine. That failure mode is especially cruel because the server appears to work.

Use Pelican backups for what they are good at: a fast rollback of one server's files on the same infrastructure. Do not mistake them for a migration tool.

### 22.9 The three irreplaceable things

Everything about this server falls into one of two buckets. Knowing which is which is what makes migration a routine job.

| Irreplaceable - must be copied | Regenerated from the repository |
| --- | --- |
| **1. The world folders** (overworld, nether, end, resource world) | Every configuration file |
| **2. The game database dump** (economy ledger, ranks, seasons, homes, claims, punishments, cosmetic unlocks) | Every plugin, from the manifest with version and checksum |
| **3. The Panel's `APP_KEY`**, only if the Panel itself is moving | The custom LaughTail plugins, built from source |
| | The datapack |
| | `server.properties` and all Paper tuning |
| | Permission groups, shop tiers, rank ladder, price tables |
| | The scripts and the acceptance harness |

On the `APP_KEY`: Pelican encrypts sensitive values in its own database using that key, which lives in `/var/www/pelican/.env`. **Lose it and the encrypted data is irrecoverable even with a perfect database backup.** Copy it before you touch anything, and store it where the repository never will - it is a secret, and Section 29.11 forbids it from version control.

This split is the entire reason Sections 29 and 30 insist the repository is the only source of truth. It reduces migration from *move a server* to *move three things and redeploy the rest*.

### 22.10 Two shapes of migration - choose the easy one

| | **Option A: move the game server only** | **Option B: move everything, Panel included** |
| --- | --- | --- |
| What moves | The Minecraft server, to a new Pelican node | Panel, Wings, database, and server |
| New box runs | Wings only | Panel, Wings, MariaDB, Redis |
| Mechanism | **Pelican's built-in server transfer** | Manual rebuild and restore |
| `APP_KEY` risk | None. The Panel never moves | Real. Must be preserved exactly |
| Rollback | Trivial - the old node still holds the server | Harder |
| Downtime | 30 to 90 minutes | Half a day |
| Recommended | **Yes** | Only later, deliberately, as its own project |

**Take Option A.** Install Wings on the new VPS, register it as a second node on the Panel you already have, and use the Panel's transfer feature to move `laughtail` from the old node to the new one. Both boxes stay online throughout, and rollback is simply not deleting the old server.

Moving the Panel is a separate, optional job with no player-facing benefit. Do it on a quiet weekend months later, or never. A Panel on a small box is perfectly happy managing a node on a large one.

### 22.11 The node-transfer runbook (the recommended path)

Publish the window at least 48 hours ahead. **Never migrate during a season ending, a War Event, or the Finale.** Section 31.1 fixes the season instant, so this is easy to schedule around.

**Phase 1 - days before, zero risk, no downtime**

1. Provision the new VPS. Same OS family as the current one to avoid surprises.
2. Harden it: non-root user, key-only SSH, automatic security updates.
3. Open the firewall. **Every one of these, or something will silently fail:**

```
ufw allow 22/tcp        # SSH
ufw allow 2022/tcp      # Pelican SFTP
ufw allow 25565/tcp     # Minecraft Java
ufw allow 24454/udp     # Simple Voice Chat
ufw allow 19132/udp     # Bedrock via Geyser, if in scope
ufw enable
```

   Port 8080 stays closed to the internet; the Panel reaches Wings over it internally. Note that a TCP port checker **cannot** verify 24454 or 19132 - you need a UDP-aware check, and Section 13.3 says so for a reason.

4. Install Docker, then install Wings following the current Pelican documentation.
5. In the Panel: **Admin, Nodes, Create Node.** Point it at the new VPS, set its memory and disk to the real capacity minus a reserve for the OS and Wings, then copy the generated configuration to `/etc/pelican/config.yml` on the new box and start Wings.
6. Confirm the node shows a **green heartbeat** in the Panel. If it does not, stop here and fix it. Everything downstream depends on this.
7. Create at least one allocation on the new node for the game port.
8. **Measure the box before trusting it.** Per Section 22.5: `mpstat 1 10` for CPU steal time, a single-core benchmark, disk throughput, and latency from several real player locations. A non-zero steady steal percentage means the host is overselling and you should stop the migration and ask for a refund.
9. Lower the DNS time-to-live to 60 seconds. **Do this days ahead** or the low value will not have propagated when you need it.
10. Take a full backup of the game database and **verify you can restore it** onto the new box into a throwaway schema. An unverified backup is a rumour.

**Phase 2 - migration day**

11. Announce, then enable maintenance mode.
12. **Stop the server cleanly from the Panel console.** Never transfer a running server; a half-written region file is a corrupted world. Confirm the container is actually down.
13. Dump the game database and checksum it:

```
mysqldump --single-transaction --routines --triggers \
  -u root -p laughtail > laughtail-$(date +%F).sql
sha256sum laughtail-$(date +%F).sql
```

14. Copy the dump to the new box and verify the checksum matches on arrival. A dump that changed in transit is worse than no dump, because you will not notice.
15. Restore it into the new database, then confirm the schema version matches what Flyway expects. A schema mismatch after a restore is the most common post-migration failure.
16. **Now run the transfer.** In the Panel: the server, **Manage, Transfer**, choose the new node and its allocation. Pelican archives the volume on the old node, streams it to the new one, and repoints the server record. Watch it to completion; do not close the tab.
17. If the transfer fails partway, the server record stays on the old node. **Start it there and you are back in production.** That is the rollback, and it is why this path was chosen.
18. Once transferred, update the server's memory, disk, and CPU limit for the new box. Remember Pelican's CPU limit is a percentage: `200` means two cores, `800` means eight.
19. Update the startup variables and `-Xmx` per Section 22.13. **Do not simply scale the heap with the RAM.**
20. Start the server and watch the log to a clean start with zero plugin errors.

**Phase 3 - verify before you switch DNS**

Do not point players at the new box until every one of these passes:

21. World loaded, correct seed, correct borders on all four worlds.
22. Database connected, and `/balance` plus `/baltop` return the same values as before the move.
23. `/home`, `/claim info`, `/stats`, `/rank`, and `/season` all return correct pre-migration data for at least three real accounts.
24. Cosmetic unlocks intact, and the current Champion record is present in the archive.
25. A test login works from outside your own network.
26. Voice connects and audio passes, verified with a real second client, not a port check.
27. Bedrock connects, if in scope.
28. No plugin reports an error or a missing dependency at startup.
29. `scripts/healthcheck.sh` passes and `scripts/drift.sh` reports zero drift against the repository.
30. MSPT under a synthetic load is equal to or better than the recorded old baseline at the same player count. **This is the whole reason you moved. Verify it before celebrating.**

**Phase 4 - cut over**

31. Switch DNS to the new IP.
32. Keep the old server **stopped but not deleted for at least 72 hours.** Storage is cheap; a bad week without a rollback is not.
33. Restore the DNS time-to-live to its normal value once propagation completes.
34. Disable maintenance mode and announce.

**Phase 5 - after**

35. Monitor MSPT and tick health for 24 hours against the baseline.
36. Confirm backups are running **on the new host**, then run a full restore drill there.
37. Rotate every credential: panel API keys, SFTP passwords, database passwords, and any token that touched the old box. Rotation is more reliable than revocation.
38. Only now delete the old server and decommission the old VPS.
39. Write down what actually happened in `docs/06-migration.md`, including anything that surprised you. **The next migration is only easier if this step is done.**

### 22.12 The full-relocation runbook (only if the Panel moves too)

Only do this deliberately, as its own project, on a quiet day. It has **no player-facing benefit**. Everything in 22.11 still applies; these steps are additional.

**Before touching anything:**

1. **Copy `/var/www/pelican/.env` off the box and store it securely.** Read the `APP_KEY` line and confirm you have it. Pelican encrypts sensitive database values with this key. Lose it and that data is unrecoverable even from a perfect database backup. It is a secret: Section 29.11 forbids it from the repository, and Section 32.3 lists it as an owner-held item.
2. Dump the Panel's own database, separately from the game database:

```
mysqldump --single-transaction --routines --triggers \
  -u root -p panel > panel-$(date +%F).sql
sha256sum panel-$(date +%F).sql
```

3. Export the LaughTail egg from **Admin, Eggs, Export**. Commit the JSON to the repository. Section 29.7 already requires this, and this is the moment it pays for itself.

**On the new box:**

4. Install the Panel's dependencies: PHP 8.3 with the required extensions, MariaDB 10.11 or newer, Redis 7 or newer, Composer 2, Node 20, and a web server.
5. Install the Panel to `/var/www/pelican`.
6. Restore the Panel database dump.
7. Restore `.env` with the **identical `APP_KEY`**. Update only the database host, Redis host, and `APP_URL`. **Do not regenerate the key.** If a tool offers to, refuse.
8. Clear cached configuration, then run the migration command - on a restored database it should be a no-op. If it wants to create tables, your restore did not work and you must stop.
9. Install the scheduler cron, exactly this line:

```
* * * * * php /var/www/pelican/artisan schedule:run >> /dev/null 2>&1
```

10. Enable and start the queue worker service. **Without the cron and the queue worker, scheduled restarts and backups silently never run** - and nothing warns you.
11. Set up SSL. **If the Panel is served over HTTPS, Wings must also use SSL** or the Panel cannot talk to it. Mismatched SSL is the most common post-relocation failure.
12. Update every node's FQDN if the Panel's address changed, and restart Wings on each.
13. **Do not put the Wings endpoint behind a proxying CDN.** A proxy that returns an HTML error page produces the confusing error `could not unmarshal response: invalid character '<' looking for beginning of value`, which looks like a Wings bug and is not.
14. Re-issue both API keys per Section 29.13, and update anything that used them.
15. Verify the Panel can start, stop, and read files on every server on every node before declaring this finished.

### 22.13 Sizing the new box - do not give Minecraft 50 GB

The most tempting mistake on a large box is to hand the whole machine to the game. **Do not.** A larger heap makes garbage-collection pauses longer, and a long pause is a visible lag spike. Section 6.4 says this already; it matters most exactly when you finally have RAM to spare.

| Resource | Give the game | Why |
| --- | --- | --- |
| Heap (`-Xmx`) | **8 to 12 GB, never more** | Past roughly 12 GB, G1 pause times grow faster than the benefit. Aikar's flags are tuned for this range |
| Container allocation | Heap plus at least 25 per cent, or 768 MB minimum | Section 29.4. Java needs memory outside the heap, and an allocation equal to `-Xmx` **freezes** the server rather than crashing it |
| Pelican CPU limit | `400` to `600` on an 8-core box | The value is a percentage: `100` is one core. Leave headroom for Wings, the Panel, and backups |
| Concurrent players | Still **100 to 150 maximum** on one Paper instance | Hardware does not fix this. The main thread is largely single-threaded |

**A sensible split for 8 cores and 50 GB:**

| Purpose | RAM | Notes |
| --- | --- | --- |
| Production server | 12 GB allocation, 9 GB heap | Comfortable for 60 to 100 players |
| `laughtail-dev` | 4 GB allocation, 3 GB heap | Now it can run **at the same time** as production. This is the real luxury the bigger box buys |
| Arena or event instance | 8 GB allocation, 6 GB heap | Optional. Behind a proxy, this is how you get past the single-instance ceiling |
| Panel, MariaDB, Redis | 4 GB | |
| Website, map renderer, Discord bot | 4 GB | Section 5 wanted these off the game box; now they can come home |
| **Unallocated, left for the OS** | **12 GB or more** | Not waste. The OS page cache holds hot chunk data, and this genuinely improves chunk load times. **Do not allocate it.** |

The honest summary: that upgrade does not buy a bigger single server. It buys **more servers running at once**, real headroom, and the ability to keep dev permanently online instead of trading it against production. Both of those are worth more than a bigger heap.

When you cross this threshold, revisit Section 30.2. The two-servers-never-together rule exists only because a 4 GB box forces it. On the new box, run both, and delete that constraint from the runbook.

### 22.14 Realistic timings

| Step | Rehearsed | First time |
| --- | --- | --- |
| VPS provisioning, hardening, firewall | 20 to 30 min | 45 to 60 min |
| Docker and Wings install | 15 min | 30 to 45 min |
| Node creation and green heartbeat | 10 min | 20 to 40 min, most of the pain is SSL and FQDN |
| Measuring the box properly | 20 min | 20 min. **Never skip it** |
| Database dump, transfer, restore, verify | 10 to 20 min | 30 min |
| Pelican server transfer | 10 to 40 min | Same. Bounded by world size and network speed |
| Startup config, heap, CPU limit | 10 min | 20 min |
| The 10-point verification in Phase 3 | 30 min | 60 min |
| DNS cutover and propagation | 5 min plus TTL | Same |

**Player-facing downtime: 30 to 90 minutes.** Total wall clock including verification: **3 to 4 hours rehearsed, a full day the first time.**

Budget the full day. Announce a two-hour window and finish early - the reverse ruins trust, and on a paid server it produces refund requests.

The reason this is hours rather than a weekend is Section 30.5: dev to production at launch **is** the rehearsal. By the time you move to the big box you will have run the same procedure at least once with nothing at stake. Do not skip that rehearsal to save an afternoon.

### 22.15 Pelican migration acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 22-1 | The game database was dumped, checksummed, transferred, and the checksum re-verified on arrival | Two matching checksums recorded |
| 22-2 | The restored schema version matches what the migration tool expects | Migration tool status output |
| 22-3 | The `APP_KEY` was preserved unchanged, if the Panel moved | Before-and-after comparison, recorded in `docs/private/` |
| 22-4 | The egg JSON in the repository matches the egg on the new node | Exported JSON diffed against the committed copy |
| 22-5 | Balances, homes, claims, stats, cosmetics, and season history match pre-migration values for at least three real accounts | Before-and-after capture |
| 22-6 | The current Champion record survived the move | Season archive query |
| 22-7 | Voice audio passes on the new host, verified with a real second client, not a port check | Recorded test |
| 22-8 | `-Xmx` is at least 25 per cent below the container allocation, and no more than 12 GB | Startup flags plus panel allocation |
| 22-9 | MSPT at equal player count is equal to or better than the recorded old baseline | Two spark reports side by side |
| 22-10 | CPU steal time on the new host is effectively zero under load | `mpstat` output |
| 22-11 | The Panel cron and queue worker are running, proven by a scheduled restart firing | Scheduler log |
| 22-12 | Backups run on the new host **and** a full restore drill has succeeded there | Drill record in `docs/restore-drills.md` |
| 22-13 | Every credential that touched the old box has been rotated | Rotation checklist |
| 22-14 | The old server was kept stopped, not deleted, for at least 72 hours after cutover | Panel timestamps |
| 22-15 | `docs/06-migration.md` records what actually happened, including surprises | Committed document |

---

