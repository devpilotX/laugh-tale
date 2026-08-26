## SECTION 5 - INFRASTRUCTURE AND THE PORTABILITY CONTRACT

The owner's requirement: *"very portable, like in future if I want to migrate this server to any other VPS, then we can easily do that."* Portability is therefore a **hard architectural requirement**, not a nice-to-have. This section is the contract that makes migration boring.

### 5.1 The portability contract - eight rules, no exceptions

1. **Everything runs in Docker Compose.** One `docker-compose.yml` describes the entire server. No manually installed packages on the host that the server depends on. If it is not in the compose file, it does not exist.
2. **All state lives in named bind mounts under one directory**, `/srv/laughtail/`. Nothing important lives anywhere else on the host. Migration is then: rsync one directory, start compose.
3. **Zero hardcoded IP addresses or absolute host paths** in any config, plugin config, script, or database row. Players connect to a domain. Services find each other by compose service name. Grep for the current public IP before every release; any hit is a bug.
4. **All secrets in one `.env` file**, which is gitignored and separately backed up. No password, token, or key is ever committed, ever hardcoded, ever pasted into a plugin config that lives in git.
5. **All configuration in git.** The world data and database are not in git; every config file that shapes behaviour is. A rebuild from a bare VPS plus the git repo plus the latest backup plus `.env` must produce an identical server.
6. **The database runs in a container with its own volume**, not as a host service. Same portability rules apply.
7. **Nothing depends on a provider-specific feature.** No AWS-only load balancer, no provider-managed database, no proprietary snapshot mechanism as the *only* backup, no provider-specific metadata endpoint. Provider features may be used as a convenience, never as a dependency.
8. **The migration script exists from day one and is tested monthly**, not written in a panic on migration day (Section 22).

### 5.2 The stack

| Service | Purpose | Notes |
|---|---|---|
| `mc` | Paper server | Pinned version. Aikar-style JVM flags. Restart policy `unless-stopped`. |
| `db` | MariaDB | One database per plugin domain, or one database with clear table prefixes. Own volume. Not exposed to the internet. |
| `backup` | Scheduled backups | Snapshots world + database + configs, encrypted, offsite. |
| `monitor` | Metrics and alerting | Lightweight. Exports TPS/MSPT/memory/player count. |

Deliberately **not** on the game VPS: the website, the live map renderer, the leaderboard web app, the Discord bot. All of those live elsewhere (Section 18). The game box does one job.

### 5.3 Ports - the complete list

Getting this list wrong is the number one cause of a broken migration. Document it, and re-open every one of these on the new host.

| Port | Protocol | Purpose | Exposed publicly? |
|---|---|---|---|
| 25565 | TCP | Minecraft Java | Yes |
| 19132 | UDP | Bedrock via Geyser | Yes, if crossplay is on |
| **24454** | **UDP** | **Voice chat (Section 13)** | **Yes, if voice is on** |
| 3306 | TCP | MariaDB | **No.** Container network only. |
| 22 | TCP | SSH | Yes, key-only, no password auth, non-default port preferred |
| RCON | TCP | Remote console | **No.** Never exposed to the internet, under any circumstances. |

**The voice port is a UDP port and is the one everybody forgets.** Note two things: a normal TCP port checker cannot verify a UDP port is open, so use the voice plugin's own test command or a UDP-aware tool; and many DDoS-protection proxies do not forward UDP on cheap or free plans. Verify UDP support *before* committing to a DDoS provider, or voice chat will silently break the day you enable protection.

### 5.4 Backups - the only part of infrastructure that is not negotiable

* **Schedule:** database dump every hour. Full world snapshot every 6 hours. Config repo pushed on every change.
* **Retention:** 24 hourly, 14 daily, 8 weekly. Adjust for disk, never below 7 daily.
* **Offsite:** at least one copy on a different provider than the game host. A backup sitting on the same disk as the server is not a backup.
* **Encrypted at rest**, key stored outside the server.
* **Consistency:** dump the database with a proper hot-dump, and flush world saves before snapshotting. A torn backup is worse than no backup because it gives false confidence.
* **The restore drill is mandatory.** Once a month, restore the latest backup into a throwaway container and join it. **A backup you have never restored is a rumour.** Log each drill in `docs/restore-drills.md` with the date and how long it took.

### 5.5 Security baseline

* SSH keys only; password authentication disabled; root login disabled.
* Firewall default-deny inbound; only the table in 5.3 open.
* Database bound to the container network, never `0.0.0.0`.
* Separate database users per service, each with the minimum rights. The web leaderboard uses a **read-only** user (Section 18).
* Automatic security updates for the host OS; scheduled, announced restarts for the game.
* Unattended access to the console is Owner-only. Staff never get shell.
* Rotate every secret at migration time. Assume anything that lived on the old box is compromised the moment you decommission it.

### 5.6 Repository layout

```
laughtail/
  docker-compose.yml
  .env.example            # committed, with placeholder values
  .env                    # NEVER committed
  server/
    server.properties
    paper-global.yml
    paper-world-defaults.yml
    spigot.yml
    bukkit.yml
    plugins/<Plugin>/config.yml   # one directory per plugin, all committed
    datapacks/laughtail/          # advancements, recipes, loot tables
  db/
    migrations/V1__init.sql       # forward-only, numbered, never edited after release
  scripts/
    migrate.sh
    healthcheck.sh
    backup.sh
    restore-drill.sh
    economy_audit.py
    loadtest.js
  docs/
    00-overview.md
    01-runbook.md
    02-permissions.md
    03-economy.md
    04-commands.md
    05-rules.md
    06-migration.md
    07-performance.md
    decisions.md
    rejected.md
    restore-drills.md
```

### 5.7 Acceptance criteria

* [ ] `docker compose down && docker compose up -d` restores a fully working server with no manual steps.
* [ ] A grep of the entire repo for the current public IP returns nothing.
* [ ] A fresh VPS, given only the git repo, the latest backup, and `.env`, produces a working identical server in under 30 minutes.
* [ ] Restore drill completed and logged.
* [ ] `nmap` from outside shows only the intended ports; RCON and MySQL are invisible.

---

