# Rebuilding LaughTail from GitHub alone

The goal this answers: *"If I delete the server and later buy a bigger VPS, can I recreate it in
minutes from GitHub?"*

**Yes for the server. No for your players' data — and that distinction is the whole point of this
document.**

---

## Read this part first

There are two different things people mean by "the server", and GitHub holds exactly one of them.

| | In GitHub? | If the VPS is destroyed |
| --- | --- | --- |
| **The server itself** — plugin source, configuration, permissions, migrations, deploy scripts, docs | **Yes, all of it** | Rebuilt in about 45 minutes, identical |
| **The world** — your builds, the terrain, chests, everything placed | **No** | **Gone forever unless a backup exists off the box** |
| **Player data** — Berries, ranks, homes, stats, Paths, the ledger | **No** | **Gone forever unless a backup exists off the box** |

So GitHub guarantees you can rebuild an **identical, empty** LaughTail. It does not preserve a single
Berry.

**Right now the backups live on the same VPS as the server.** That is fine for the failure it was
designed for — a bad deploy, a corrupted world, a mistaken command. It is no protection at all against
losing the machine, because the backups go with it.

**This is the one thing to fix before relying on any of the above.** It is recorded as OA-33.

---

## What is deliberately not in GitHub, and why

Only four things, and none of them block a rebuild:

| Excluded | Why | To rebuild |
| --- | --- | --- |
| `scripts/host.env.ps1` | Holds the server address and SSH key path | Copy `host.env.example.ps1`, fill in three values |
| `docs/private/` | Never-break rule 10: detector thresholds must not be published | Generate a fresh IP salt. Nothing else is needed |
| `logs/` | Local run history, no value elsewhere | Nothing |
| `.cache/` | Downloaded jars, re-fetched by checksum | Nothing |

**The database password is not in either place, and does not need to be.** `db-up.sh` generates one on
first run and stores it inside the container as a file secret. A fresh box gets a fresh password with no
action from you — which is why there is no credential to carry, copy, or lose.

---

## The rebuild, on a bare VPS

Roughly 45 minutes, most of it waiting for downloads.

### 1. Provision the box (20 min)

Ubuntu on **arm64**, then Docker, Pelican Panel and Wings. Stay on arm64: every plugin in
`server/manifest.yml` has been load-proven on aarch64, and moving to x86 throws that evidence away.

Create a Pelican server named `laughtail-dev` and note its **volume UUID**.

Open the ports — three layers must all allow each one, and missing any leaves it dead with no error:

| Port | Protocol | For |
| --- | --- | --- |
| 25565 | TCP **and UDP** | Minecraft Java |
| 19132 | **UDP** | Bedrock via Geyser |
| 24454 | **UDP** | Voice chat |
| 22 | TCP | SSH |
| 8443 | TCP | Panel |

### 2. Clone and configure (2 min)

```
git clone https://github.com/devpilotX/laugh-tale.git
cd laugh-tale
copy scripts\host.env.example.ps1 scripts\host.env.ps1
```

Fill in three values:

```
$LT_SSH_KEY  = 'C:\path\to\your-key.pem'
$LT_SSH_DEST = 'ubuntu@<NEW-IP>'
$LT_VOLUME   = '<NEW-VOLUME-UUID>'
```

### 3. Recreate the private config (1 min)

Only the IP salt matters. It is used to hash player addresses so same-connection alt farming can be
detected without storing anyone's IP. A **fresh random value is correct** — it does not need to match the
old one, because nothing is compared across rebuilds.

```
mkdir docs\private
# docs/private/private.yml
ip_salt: "<paste 32+ random characters here>"
```

The plugin runs without this file and says so loudly in the log, so a missing salt is visible rather
than silent. What you lose without it is same-IP alt detection.

### 4. Deploy (3 min)

```
powershell -File scripts\deploy.ps1
```

That one command verifies artefact checksums, refuses if any secret or hardcoded value has crept in,
runs the destructive-command guard tests, checks the row 25 thread guards, brings up the database, applies
all seven migrations, installs Paper and every pinned plugin, writes every configuration file, builds the
core plugin from source on the host, applies the permission ladder and verifies it node by node, starts
the server, and runs both drift checks.

### 5. Confirm it is genuinely the same server (5 min)

The boot log must show all three self-tests. If any is missing, stop and find out why:

* `Row 25 verified: a main-thread database call was refused`
* `ORDER BOOK SELF-TEST PASS: value conserved through a real match`
* `ARBITRAGE AUDIT PASS: 1585 recipes examined, 0 positive-yield cycles`

Then the suites, all of which should report zero failures:

```
test-shop.sh   test-orders.sh   test-roleplay.sh   test-friends.sh
test-economy.sh   test-moderation.sh   test-access.sh   db-test-append-only.sh
```

At this point you have an identical, **empty** server. Season 1 opens by itself within a minute.

### 6. Restore your data — only if you kept a backup off the box

This is the step GitHub cannot help with. Follow `docs/MIGRATION.md` from step 5 onward: extract the
world tarball into the volume, **fix file ownership** (root-owned files are unreadable by the container
and it fails silently), and load the database dump — with `--triggers`, because the audit table's
append-only protection *is* a trigger.

Then verify by comparing figures rather than trusting the process: player count, `SUM(berries)`
**exactly**, transaction count, and the active season.

---

## Making this guarantee real

Two things, in order of importance.

### Get backups off the box (OA-33)

Until this is done, the honest position is: *GitHub protects the server, nothing protects the world.*

Cheapest option, roughly a few cents a month: an S3 bucket with versioning on, and one line added to
`backup-run.sh`:

```
aws s3 cp "$OUT" "s3://<bucket>/laughtail/" --storage-class STANDARD_IA
```

**Versioning matters more than the bucket does.** Without it, a corrupted world backed up on schedule
overwrites the last good copy, and the backup becomes the thing that destroys the data.

Then set a reminder to run `restore-drill.sh` monthly. That drill has caught its own bugs twice — the
first time, three separate faults meant it had silently stopped testing anything while still appearing
to pass. A backup nobody has restored is a hope, not a backup.

### Keep the repository honest

The rebuild only stays fast while the repository stays the single source of truth. Two habits protect
that:

* **Never change the live server by hand.** `scripts/deploy.ps1` is the only path files should take, and
  the drift checks exist to catch it when that is ignored.
* **Push after every session.** A commit on one PC is worth exactly as much as no commit at all if that
  PC is what fails.

---

## In short

* **Server: fully recoverable from GitHub.** Clone, three values, one command, 45 minutes.
* **No credential to carry.** The database password regenerates itself; the IP salt is freshly random.
* **World and player data: not in GitHub, and should not be.** Git is not for a 271 MB world.
* **The gap that matters is off-box backups.** Fix that and the guarantee is complete. Leave it and
  losing the VPS means starting over with an empty world — a working server, but nobody's history in it.
