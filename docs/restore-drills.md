# Restore drills

Section 20's Phase 0 gate is not "backups are running". It is "**a restore drill has succeeded**". An untested backup is a belief, and the usual way people discover theirs is broken is the day they need it.

This file is the log. One entry per drill, newest first. Every entry must name what was restored, what was checked, and what failed - a drill with nothing recorded did not happen.

Reproduce with `scripts/remote/backup-run.sh` then `scripts/remote/restore-drill.sh`.

---

## Drill 1 - 2026-08-26 04:35 UTC - PASSED, 0 failures

**Restored from:** `world-20260826T043146Z.tar.gz` (213 MB, 238 entries) and `db-20260826T043146Z.sql.gz` (2,629 bytes, 5 tables).

**Nothing live was touched.** The database dump contains `CREATE DATABASE laughtail` and `USE laughtail`, so restoring it as-is would have **overwritten the live schema**. Those two statements are stripped and the remainder loaded into a separate `laughtail_drill` schema, dropped afterwards. The world was extracted to `/home/ubuntu/laughtail-scratch/`, never into the Pelican volume.

### Database half

| Check | Result |
| --- | --- |
| Tables restored | **5, matching live 5** |
| Migration history | `V1` present, checksum `4d3a4fb7…3bcb7ec` **identical to live** |
| Foreign keys | **3 restored, 3 live** |
| **Row 36 constraint** | **Survived** - the restored schema still rejected a second champion for the same season |

The constraint check is the one that matters most and it is the one people skip. A backup that restores rows but loses a `PRIMARY KEY` restores a **silently broken** server: it would look fine, accept two champions, and violate acceptance row 36 without any error. Verifying data came back is not the same as verifying the guarantees came back.

### World half

| Check | Result |
| --- | --- |
| `laughtail/level.dat` | present, 1,534 bytes, magic `1f8b` (gzip), **decompresses cleanly** so it is not truncated |
| Region files | **12 restored, 12 live** |
| Region header | `r.0.0.mca` chunk location table populated (422 non-zero nibbles), not a zero-filled stub |
| Config and access files | `server.properties`, `ops.json`, `whitelist.json`, `config/paper-global.yml`, `spigot.yml` all present and non-empty |
| Restored values still correct | `white-list=true`, `online-mode=true`, `level-name=laughtail` |

**The backup contains secrets.** The restored `server.properties` carries a live `rcon.password`. That is unavoidable - it is a faithful copy - and it is why these archives stay on the host and must never be copied to the repository or anywhere public. It is also an argument for closing **OA-08** with an *encrypted* offsite destination rather than a plain bucket.

### What this drill does NOT prove

Stated plainly, because a drill that oversells itself is worse than none:

* **It does not prove a full disaster recovery.** No server was started from the restored files. Restoring onto a stopped server and booting it is a heavier drill that needs a second allocation, which this 3.8 GB box cannot host alongside the live one (rule 2, Q-41). The world files are proven readable and complete; that they *boot* is inferred, not shown.
* **It does not cover loss of the instance.** **OA-08 is still open**: these archives sit on the same EBS volume as the thing they protect. They survive a bad deploy, a corrupted world or a dropped table. They do not survive the volume going away. Neither does the missing `pre-build` host snapshot (**OA-03**) help, because that does not exist either.
* **It does not cover the owner's pre-existing world.** `world/`, `world_nether/` and `world_the_end/` are excluded from routine backups on purpose - they are immutable (D-0013, mtime proven unchanged) and already captured in `prebuild-volume-20260826-022637.tar.gz`. Re-taring 749 MB on every run would fill a 19 GB disk.

### Two bugs the drill itself exposed

1. **The guard refused the whole drill**, because `DROP DATABASE` was an absolute denial. Refusing to *test* a backup in the name of data safety is a net loss of safety, so the rule now judges the **target name**: real schemas and tables are still refused, and only names ending `_drill` or `_scratch` are permitted. Proven both ways by `guard.tests.ps1` GROUP 14 - 75 tests, 0 failures.
2. **The guard then refused it again**, because the scratch schema was named via `$DRILL_DB`. The guard reads script text statically and cannot know what a shell variable expands to, so it failed closed - correctly. The name is now literal. **General rule: never hide a destructive target behind a variable, or static checking cannot protect you.**

### Frequency

Not yet scheduled. 5.4 wants hourly database and six-hourly world backups; nothing is on a timer yet because a timer that fires unattended should not be the first time a script runs in anger. Scheduling is the next backup task, together with alerting on failure - a silent backup failure is indistinguishable from success, which is the worst property a backup can have.
