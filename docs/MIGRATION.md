# Migrating LaughTail to a bigger VPS

Written 2026-08-27. This is a runbook: follow it top to bottom and the server moves with nothing lost.

**Read this paragraph before anything else.** The single most dangerous thing you can do during a
migration is have both servers running at once. Two servers writing to two copies of the same world
means whichever one you keep, somebody's afternoon is gone — and there is no way to merge them
afterwards. The old server stays **stopped** from the moment the final backup is taken until you have
decided the new one is good. Every step below is ordered around that.

---

## Why this is not frightening

The design has been pointed at this from the beginning, and three properties do most of the work:

**Everything that matters is in two places, and both are portable.** All state is either in the MariaDB
database or in the world folder. Nothing lives in a config file that was hand-edited on the box,
nothing lives in a plugin's private memory, and nothing depends on the machine's identity. `docs/` in
this repository is the source of truth for configuration, and `scripts/deploy.ps1` is the only path
files take to a server.

**The deploy is one command and it is idempotent.** Standing up the software on a new box is the same
31-stage script that has been run dozens of times against the old one. It is not a special migration
procedure written once and never tested.

**The restore drill is proven, not assumed.** `scripts/remote/restore-drill.sh` restores a real backup
into a scratch schema and a scratch directory and checks it: table counts, an identical schema
checksum, that database constraints still refuse bad data in the restored copy, that `level.dat` is a
valid gzip that decompresses, and that every region file came back. It passed on 2026-08-27 with 0
failures, 67 of 67 region files.

> A migration is a restore you chose the timing of. If the restore drill passes, the migration is
> paperwork.

---

## What actually has to move

| What | Where it lives now | How it moves |
| --- | --- | --- |
| **Database** — players, Berries, the full ledger, ratings, seasons, champions, homes, friends, orders, Paths, Houses, the Chronicle, punishments, the audit trail | MariaDB in the `laughtail-db` container | `mariadb-dump`, restored on the new box |
| **World** — the main world and all its dimensions, including the nether, end, resource and arena | Pelican volume, `laughtail/dimensions/` | tar of the volume |
| **Server config** — `server.properties`, Paper tuning, permissions ladder, plugin config | This repository, `server/` | The deploy script writes it |
| **Plugins** — Paper jar plus every pinned plugin | Manifest with pinned versions and checksums | The deploy script fetches and verifies |
| **The core plugin** | Built from `plugin/` on the host | The deploy script builds it |
| **Secrets** — database password, RCON password, Panel key | `docs/private/`, never committed | Copied by hand. See the warning below |

Everything in the first four rows is reproducible from this repository. Only the first two rows are
irreplaceable, and only the last row needs a human.

**Nothing is stored anywhere else.** No player data is in a YAML file, no balances are in a plugin's
own storage, no permissions exist only in LuckPerms' memory — the ladder is applied from
`server/permissions.yml` and verified node by node afterwards.

---

## Before you start

**1. Close OA-02 first.** As of this writing there are 75 commits and no git remote. If this PC dies
mid-migration the entire project is gone, and the migration needs the repository. Push to a private
repository before touching anything:

```
git remote add origin git@github.com:<you>/laughtail-smp.git
git push -u origin main
```

**2. Decide the new box size deliberately.** The current box is a `t4g.medium`: 2 vCPU, 3.8 GB, and
about 550 MB free at rest. That is the constraint behind several decisions in this project.

| New size | What it buys | Honest assessment |
| --- | --- | --- |
| `t4g.large` (2 vCPU, 8 GB) | Heap can roughly double; comfortable at 24 players | The obvious step. Still burstable CPU |
| `m7g.large` (2 vCPU, 8 GB) | Same memory, **non-burstable** CPU | Better for a PvP server. Sustained CPU work no longer exhausts credits and throttles below 20 TPS |
| `m7g.xlarge` (4 vCPU, 16 GB) | Headroom for 50+ players and a second world | Only worth it once a load test says the smaller one is not enough |

**Stay on arm64 (Graviton).** Not for the price — because every plugin in the manifest has been
load-proven on aarch64 on this box. Moving to x86 invalidates that evidence and means re-testing every
plugin. If you do move to x86, treat it as a separate project.

**CPU matters more than you would think here.** The current instance is *burstable*, which means
sustained load exhausts CPU credits and the server then throttles below the 20 TPS requirement. That
also makes a measured player cap unreproducible. If you are paying for a bigger box anyway, paying for
a non-burstable one buys more than extra RAM would.

**3. Take a snapshot of the old box** (OA-03). Not the same thing as a backup: a snapshot means you can
put the old server back exactly as it was if the new one disappoints. It is the difference between a
migration you can abandon and one you cannot.

---

## The migration

Times are for a ~750 MB world on a reasonable connection. Total is roughly 45 minutes, of which about
20 is downtime.

### Step 1 — Warn players (a few days ahead)

Announce a maintenance window. If a season is close to ending, **finish it first.** Migrating mid-season
is fine technically, but a season that ends during a migration is a season players will not trust.

### Step 2 — Provision the new box (30 min, old server still running)

Create the instance, then install Docker, Pelican Panel and Wings exactly as on the old host. Nothing
below touches the old server, so take your time.

```
# On the new host
sudo apt update && sudo apt install -y docker.io
# then Pelican Panel + Wings, per their install guide
```

Create a server in the Panel named `laughtail-dev` with the same egg. **Note its new volume UUID** —
several scripts reference it.

**Open the ports properly this time (OA-06).** The old box never had these, which is why Bedrock and
voice chat were unreachable:

| Port | Protocol | For |
| --- | --- | --- |
| 25565 | TCP **and UDP** | Minecraft Java |
| 19132 | **UDP** | Bedrock via Geyser |
| 24454 | **UDP** | Voice chat |
| 22 | TCP | SSH |
| 8443 | TCP | Panel |

Three layers, all of which must allow it: the Pelican **allocation** must publish the port, then
**ufw**, then the **AWS security group**. Missing any one leaves the port dead with no error anywhere —
which is exactly how it was missed the first time.

### Step 3 — Stop the old server and take the final backup (5 min, downtime begins)

```
powershell -File scripts\remote.ps1 -ScriptFile scripts\remote\stop-server-with-warning.sh -Confirmed -Reason "migration"
powershell -File scripts\remote.ps1 -ScriptFile scripts\remote\backup-run.sh -Confirmed -Reason "final pre-migration backup"
```

The stop script warns players in game, waits, flushes the world to disk and then stops. **Do not skip
the warning version** — a `kill` mid-save is how a world corrupts.

**From this moment the old server does not start again** until you have decided the new one is bad.
Write that down somewhere you will see it.

### Step 4 — Verify the backup before you rely on it (5 min)

```
powershell -File scripts\remote.ps1 -ScriptFile scripts\remote\restore-drill.sh -Confirmed -Reason "verify the migration backup"
```

**Do not skip this and do not proceed if it reports any failures.** This is the step that turns
"I have a backup" into "I have a backup that restores". It has caught its own bugs twice.

### Step 5 — Copy the data across (10 min for ~750 MB)

Host to host directly, rather than via your PC — it is faster and there is one fewer copy to get wrong.

```
# On the OLD host
sudo tar -czf /tmp/laughtail-world.tar.gz -C /var/lib/pelican/volumes/<OLD-UUID> .
sudo docker exec laughtail-db sh -c 'mariadb-dump -u laughtail -p"$(cat /run/lt-secrets/app_password)" --single-transaction --routines --triggers laughtail' > /tmp/laughtail-db.sql

# Check they are plausible BEFORE trusting them
ls -lh /tmp/laughtail-world.tar.gz /tmp/laughtail-db.sql
grep -c 'CREATE TABLE' /tmp/laughtail-db.sql    # expect 30 or more

# Copy to the new host
scp -i <key> /tmp/laughtail-world.tar.gz /tmp/laughtail-db.sql ubuntu@<NEW-IP>:/tmp/
```

**`--triggers` is not optional.** The audit table's append-only protection *is* a trigger. Dump without
it and the new server has an audit trail that can be quietly edited — the guarantee would be gone and
nothing would look wrong.

`--single-transaction` gives a consistent snapshot without locking. The server is already stopped so it
hardly matters, but it costs nothing and matters greatly if you ever dump a running server.

### Step 6 — Point the repository at the new host (2 min)

```
# scripts/host.env.ps1 - git-ignored, which is why it is allowed to hold the address
$LT_SSH_KEY  = 'C:\VPS\...\your-key.pem'
$LT_SSH_DEST = 'ubuntu@<NEW-IP>'
$LT_VOLUME   = '<NEW-VOLUME-UUID>'
```

`scripts/host.env.example.ps1` is the committed template if you need the exact shape. Every state-changing
command goes through `scripts/remote.ps1`, which reads this file � so this is the only place the address
belongs, and it is why acceptance row 2 (no hardcoded values) passes.

**No script hardcodes the volume any more**, so there is nothing else to change. This was true when this
runbook was first drafted and has since been fixed at the source: scripts either receive the volume from
`host.env.ps1` or discover it, and `reset-seasons.sh` refuses outright if more than one server volume
exists without being told which to use � because picking one arbitrarily is how a script wipes the wrong
server. Worth re-checking anyway, since it costs nothing:

```
findstr /S /C:"4fd2f0a9" scripts\*.ps1 scripts\remote\*.sh
```

The only expected hit is `host.env.ps1`, which is git-ignored and is where the address belongs.

### Step 7 — Restore the data (5 min)

```
# On the NEW host
sudo tar -xzf /tmp/laughtail-world.tar.gz -C /var/lib/pelican/volumes/<NEW-UUID>/
```

**Then fix ownership, and do not skip this.** Files created by root in a Pelican volume are unreadable
by the container, and it fails **silently** — the server starts, the world appears empty or read-only,
and nothing in the log says why. Match the ownership of the files already there:

```
sudo chown -R $(stat -c '%u:%g' /var/lib/pelican/volumes/<NEW-UUID>) /var/lib/pelican/volumes/<NEW-UUID>
```

Bring up the database container, then load the dump:

```
powershell -File scripts\remote.ps1 -ScriptFile scripts\remote\db-up.sh -Reason "migration"
# on the new host
sudo docker exec -i laughtail-db sh -c 'mariadb -u laughtail -p"$(cat /run/lt-secrets/app_password)" laughtail' < /tmp/laughtail-db.sql
```

**Copy the secrets by hand.** `docs/private/` is not in git, deliberately. The database password and the
RCON password must match what the dump and the configs expect. Copy the files; do not retype them, and
do not print them.

### Step 8 — Deploy (3 min)

```
powershell -File scripts\deploy.ps1
```

This is the same script that has run against the old box dozens of times. It verifies checksums, checks
for hardcoded values and secrets, runs the destructive-command guard tests, checks the row 25 thread
guards, applies migrations, installs Paper and every pinned plugin, writes all configuration, builds
the core plugin, applies the permission ladder and verifies it node by node, starts the server, and
runs both drift checks.

**Expect the migration runner to report "already applied" for all six migrations.** If it tries to
*apply* one, the dump did not load — stop and work out why before going further.

### Step 9 — Verify, in this order (10 min)

Cheapest and most diagnostic first:

```
powershell -File scripts\remote.ps1 -ScriptFile scripts\remote\health-check.sh -Reason "post-migration"
```

Then confirm the boot log shows all three self-tests passing:

- `Row 25 verified: a main-thread database call was refused`
- `ORDER BOOK SELF-TEST PASS: value conserved through a real match`
- `ARBITRAGE AUDIT PASS: 1585 recipes examined, 0 positive-yield cycles`

Then the full suite:

```
scripts\remote\test-shop.sh        scripts\remote\test-orders.sh
scripts\remote\test-roleplay.sh    scripts\remote\test-friends.sh
scripts\remote\test-economy.sh     scripts\remote\test-moderation.sh
scripts\remote\test-access.sh      scripts\remote\db-test-append-only.sh
```

Then check the data actually arrived, rather than assuming:

| Check | Expected |
| --- | --- |
| `SELECT COUNT(*) FROM players` | Same as before the move |
| `SELECT SUM(berries) FROM balances` | **Identical.** Not close — identical |
| `SELECT COUNT(*) FROM transactions` | Same. The ledger must sum to the balances |
| `SELECT season_number, state FROM seasons` | Same season, still active |
| `SELECT COUNT(*) FROM staff_audit` | Same, and still refusing UPDATE |
| `/laughtail rating` | INVARIANTS: all pass |

Finally, in game: join, open `/menu`, walk into your base, check a home teleport, check `/balance`, and
confirm your rank and Path progress are intact.

### Step 10 — Cut over (5 min)

Only now. Update DNS if you use a hostname, tell players, and watch the first fifteen minutes with
`monitor.sh` running.

**Keep the old box stopped but not destroyed for at least a week.** Storage is cheap; a bad migration
you cannot reverse is not.

---

## If it goes wrong

**The deploy fails partway.** Every stage is idempotent — fix the cause and re-run. Nothing is
half-applied.

**The world is empty or read-only.** Almost certainly the ownership step. Re-run the `chown` and
restart.

**Migrations try to apply instead of reporting "already applied".** The dump did not load. Do not let
the server create empty tables over your data — stop, drop the schema, and reload the dump.

**Balances are wrong.** Stop the server immediately and do not let anyone trade. The ledger is
authoritative: `transactions` sums to what `balances` should be, so the correct figures are recoverable.
Trading on wrong balances is what makes it unrecoverable.

**It is simply worse than before.** Start the old box. That is why it is still there.

---

## After a bigger box: what to revisit

Several decisions were made *because* the box was small. On a larger one they deserve another look:

**Raise the heap, keeping never-break rule 4.** Never set `-Xmx` equal to the container allocation —
leave at least 25% or 768 MB outside it. Equal values freeze the server rather than crashing it, which
is far harder to diagnose. On 8 GB, something like a 5 GB heap against a 7 GB allocation.

**Then actually load-test, and settle Q-41.** The player cap has never been measured; 24 is currently an
assertion. Measure MSPT under real load and set the cap from the measurement.

**Reconsider what memory forced you to skip.** The database container is capped at 320 MB and uses 180.
The Chronicle is server-wide partly because per-player quest state did not fit. Both were correct at
3.8 GB and both could be revisited at 8 or 16.

**Anti-cheat is still not a memory problem (OA-32).** A bigger box does not fix it. It fails because
Minecraft 26.2 is too new for any anti-cheat to support, and that remains a decision rather than a
resource.

---

## The short version

1. Push to a git remote first. Do not migrate a project that exists on one PC.
2. Snapshot the old box.
3. Provision the new box and open the UDP ports properly this time.
4. Stop the old server **with the warning script**, back up, and **run the restore drill**.
5. Copy the world tarball and the database dump — **with `--triggers`**.
6. Point `host.env.ps1` at the new host and fix every hardcoded volume UUID.
7. Extract, **fix ownership**, load the dump, copy the secrets by hand.
8. `scripts\deploy.ps1`.
9. Verify: health check, three boot self-tests, eight test suites, then compare row counts and the
   Berry total exactly.
10. Cut over. Keep the old box stopped for a week.

The two steps people skip are the restore drill and the ownership fix, and they are the two that cost a
whole afternoon when skipped.
