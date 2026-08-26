# LaughTail SMP - Decisions

**Append-only.** Never silently reverse an entry (AGENTS.md section 3). Every deviation from the specification is recorded here with what the specification said, what I did instead, why, and what I verified afterwards (spec 0.2). Acceptance row 77 and criterion `32-5` are satisfied by this file.

---

## D-0001 | 2026-08-26 | `.gitignore` carve-out for schema migrations

**The specification says:** 33.3 step 2, the minimum `.gitignore` must exclude `*.sql`.

**Also says:** 33.3 step 4 requires a `db/migrations/` directory; Appendix D says "migrations from the first commit"; `22-2` tests the restored schema version against what the migration tool expects.

**What I did:** included the spec's minimum list verbatim, then added `!db/migrations/` and `!db/migrations/**/*.sql` as a commented carve-out.

**Why:** schema migrations are source code, contain no secrets, and are worthless outside version control. Database *dumps* - the thing `*.sql` is protecting against - remain excluded via `*.dump`, `backups/` and the absence of any dump path in the repository.

**Verified:** `.gitignore` written before any other file entered the repository, as 33.3 step 2 requires. Not yet verified against a real `git status`, because git is not installed - `docs/owner-actions.md` OA-01. **This is the one open verification on this decision.**

**Recorded as** `docs/questions.md` **Q-03** for owner confirmation.

---

## D-0002 | 2026-08-26 | Access model built to support both one-time and recurring, with no price hardcoded

**The specification says:** 24.1 leaves the price and its recurrence open and calls it "the single most consequential unanswered question". 32.4 lists it as owner-only.

**What I did:** took 24.1's own stated default - key access on a boolean plus a **nullable** expiry timestamp. Null expiry means permanent access.

**Why:** one nullable column keeps both commercial models open at zero build cost, so no work waits on the decision (spec 32.4's whole purpose). Converting a subscription business to one-time later is much harder than the reverse, so this ordering is also the cheaper mistake.

**Verified:** nothing built yet. Design only.

**Confirmation requested:** `docs/owner-actions.md` **OA-12**.

---

## D-0003 | 2026-08-26 | Repository private until launch

**The specification says:** 29.11 and 32.4 - repository visibility is an owner decision; recommended default is private until launch, then decide.

**What I did:** proceeding on private.

**Why:** never-break rule 5 - a secret committed to a public repository is a permanent incident rather than a fixable mistake. Never-break rule 10 forbids publishing detector thresholds. Private is the reversible option; public is not.

**Verified:** no repository exists yet - OA-02.

---

## D-0004 | 2026-08-26 | The split follows document structure, not 27.3's prescribed filenames

**The specification says:** 27.3 prescribes a set of split filenames. 33.4 step 2 says "split it into one file per section: `00-...md` through `33-...md`, plus one per appendix".

**The conflict:** 27.3's list names no file for sections 29, 30 or 33, and calls the migration file `22-migration.md` while `29-10` and `30-6` call it `docs/06-migration.md`. Criterion `27-1` tests the split against 27.3's list, so it cannot pass as written.

**What I did:** split by actual document structure into 43 files - `_preamble.md`, `00-` through `33-`, appendices `A-` through `G-`, and `_end-of-document.md` - covering every section including 29, 30 and 33.

**Why:** 33.4 is the later, more specific and self-consistent instruction, and it is the one the owner's own first prompt cites. A split that omits three sections defeats the purpose.

**Verified:** `scripts/verify-split.ps1` - part line counts sum to 3,994, equal to `MASTER.md`; all 42 `##` headings appear exactly once; reconcatenating the parts in document order is byte-for-byte identical to `MASTER.md`, zero differing lines. `docs/spec/INDEX.md` maps all 280 headings with no gaps and references all 43 files.

**Recorded as** `docs/questions.md` **Q-30**.

---

## D-0005 | 2026-08-26 | Section 24's seven open questions proceed on their stated defaults

**The specification says:** 24.1 to 24.7 each carry a recommendation and a working default; 32.4 says nothing should wait on a decision that has one.

**What I did:** taking every default as written.

| Question | Default taken |
| --- | --- |
| 24.1 price and recurrence | See D-0002 |
| 24.2 shop tier at reset | `drop_one`, behind one config key so all three behaviours are one line apart |
| 24.3 voice route | Browser-based presented as primary for universality; client mod offered as the quality upgrade |
| 24.4 lifesteal hearts | Built, switched **OFF** at launch |
| 24.5 clans and guilds | Not at launch; roadmap Tier 1 |
| 24.6 Bedrock | Enabled, explicitly labelled best-effort, known limits published |
| 24.7 languages | Every user-facing string in a language file from day one, English only populated |

**Why:** 24.3's default is the one that most deserves comment - leading with browser voice means no paying player is ever excluded from a flagship feature, which is Law 3 applied to a technical choice rather than a commercial one.

**Verified:** design only.

**Confirmation requested:** the table at the end of `docs/owner-actions.md`.

---

## D-0006 | 2026-08-26 | The eight 32.4 owner-only decisions proceed on their recommended defaults

Season end hour 00:00 IST on the 1st (31.1). Combat-log penalty 25 RP on top of the normal loss (31.3) - **with the caveat in `docs/questions.md` Q-14** that 31.3 requires the penalty be strictly worse than dying and the normal death loss is never stated, so I have read 32.4's "on top of" literally and made it additive rather than flat. Daily per-item sell cap at 3x the modelled manual rate (31.5). New-player grace 30 minutes of playtime (31.6). Daily restart 05:00 IST (31.8). Repository visibility per D-0003. Access price per D-0002.

**Why recorded:** `32-5` requires every default taken under 32.4 to be dated here.

**Verified:** design only. Pre-flight 33.6 item 12 is satisfied by this entry - the eight decisions are "explicitly left at their defaults".

---

## D-0007 | 2026-08-26 | Detector thresholds live only in `docs/private/`

**The specification says:** 3.5.1 describes the wagering detector and asks for its detail in a committed file. Never-break rule 10 and 31.10 forbid publishing detector thresholds because publishing them teaches evasion.

**What I did:** all thresholds - wagering, anti-cheat, market manipulation - will live in `docs/private/`, which is git-ignored. Only the *existence* of detection is published, which is what deterrence needs.

**Why:** rule 10 is a never-break rule and outranks a section instruction. A published threshold is an instruction manual for staying just under it.

**Verified:** `docs/private/` exists and is excluded by `.gitignore`. Proposed as deviation **D8** in `docs/progress.md`; recorded as `docs/questions.md` **Q-29**.

---

## D-0008 | 2026-08-26 | Read-only host inspection performed before writing the plan

**The specification says:** nothing either way. 33.5 says the first session produces a plan, not code. Law 5 says measure, never guess.

**What I did:** opened two read-only SSH sessions to the host and collected an inventory: instance type, architecture, CPU, memory, disk, swap, container limits, heap flags, `server.properties`, installed plugins, ufw rules, listening sockets, sshd configuration, and Pelican service state. Nothing was installed, started, stopped, written or changed. Scripts retained as `scripts/vps-inventory.ps1` and `scripts/vps-inventory2.ps1` so the measurement is repeatable.

**Why:** the plan asserts dependencies and risks. Asserting them from the specification alone would have missed all five findings in `docs/questions.md` section B - including that the host is a burstable ARM instance, which changes both the plugin manifest and the credibility of Phase 6's player-cap measurement.

**Verified:** the full output is quoted in `docs/progress.md` section 3. Two sessions, both read-only, both closed.


---

## D-0009 | 2026-08-26 | Host connection details are configuration, never source

**The specification says:** acceptance row 2 - "Grep for IP addresses and absolute host paths across the repo returns nothing". Spec 5.1 requires the stack rebuild anywhere without editing code.

**What happened:** the host inventory scripts I wrote earlier in this session hardcoded the VPS address and an absolute path to the SSH key, and every Day Zero script hardcoded `C:\Laugh-Tale`. I wrote `scripts/check-hardcoded.ps1` to enforce row 2 and it failed with **14 hits, all in my own scripts.**

**What I did:**

* Connection details moved to `scripts/host.env.ps1`, which is git-ignored. `scripts/host.env.example.ps1` is committed as the template with placeholders.
* Every script now derives the repository root from `$PSScriptRoot` rather than naming it.
* `git.exe` is resolved from `PATH` with fallbacks, not by absolute path.

**Why it is recorded rather than quietly fixed:** the check found the violation in the same session that created it, which is the only reason it did not become permanent. That is the argument for having the check in CI from the first commit rather than from Phase 0, and it is why Appendix E lists it.

**Verified:** `scripts/check-hardcoded.ps1` now reports **0 hits** across 12 deployable files. `scripts/verify-split.ps1` and `scripts/verify-docs.ps1` both still pass after the refactor, so nothing was broken in the process. `scripts/vps-inventory2.ps1` was re-run against the live host and returned identical values through the new configuration path.

---

## D-0010 | 2026-08-26 | The row 2 grep is scoped to deployable artefacts, not to the specification

**The problem:** row 2 says "across the repo". Taken literally it includes `docs/spec/`, which is the verbatim specification - and editing that would break the lossless-split guarantee that `33-4` and `27-1` depend on. It would also flag `169.254.169.254`, the AWS metadata endpoint, which is a fixed constant and not host-specific.

**What I did:** `scripts/check-hardcoded.ps1` scans tracked files under `scripts/`, `server/`, `db/`, plus any compose, Dockerfile or `.env.example` - the things that actually get deployed. It allow-lists `169.254.169.254`, `127.0.0.1`, `0.0.0.0` and `255.255.255.255`. It scans `docs/*.md`, `README.md` and `AGENTS.md` for **secrets** (private key headers, AWS key ids, GitHub and Slack token shapes) but permits a host address in owner-facing prose, because telling the owner which machine to click on is the point of that prose.

**Why:** 5.1's intent is portability of the deployable artefact. A specification that quotes an example IP is not a portability defect; a deploy script that hardcodes one is.

**Verified:** 91 tracked files, 12 deployable scanned, 8 documentation files scanned for secrets, 0 hits. Recorded here because narrowing the scope of a launch-gate test is exactly the kind of change that must not happen silently - `32-2` forbids weakening a test, and this is a scoping decision the owner can overrule.


---

## D-0011 | 2026-08-26 | Pin Minecraft 1.21.11 and Paper build 132, not the newest stable

**The specification says:** 4.2 - "run the **latest stable release that all critical plugins support.** Never run a snapshot in production. Never update on launch day of a new version - **wait for anti-cheat and the economy plugins to confirm support.** Pin the exact version in the compose file; never use a floating `latest` tag."

**What the newest stable actually is.** Queried the PaperMC v3 API directly (`scripts/paper-versions.ps1`; the v2 API now returns 410 Gone):

| Version | Newest STABLE build | SHA-256 |
| --- | --- | --- |
| 26.2 | 119 | `a8c9140c3075bd7c04973e9cdc491b21bfe6bad472b674ef932a4ae0fec19629` |
| 26.1.2 | 74 | `1d70b1dab9cf4a6de615209a536f3a45a2186240253c428213ce2188ab95e5f7` |
| 1.21.11 | 132 | `5ffef465eeeb5f2a3c23a24419d97c51afd7dbb4923ff42df9a3f58bba1ccfba` |

**What the critical plugins support** (`scripts/plugin-support.ps1`, against each plugin's own repository):

| Component | Latest release | Supports 26.2 |
| --- | --- | --- |
| ViaVersion | 5.11.0 | yes |
| ViaBackwards | 5.11.0 | yes |
| Floodgate | 2.2.6-b67 | yes |
| LuckPerms | 5.5.71-bukkit | yes |
| Chunky | 1.5.3 | yes |
| spark | current | yes |
| Simple Voice Chat | bukkit-2.6.21 | yes |
| **GrimAC (anti-cheat)** | **2.3.73** | **no - stable ceiling is 1.21.11** |

**The decision:** pin **Minecraft 1.21.11, Paper build 132**.

**Why.** GrimAC is the gating component and 4.2 names anti-cheat explicitly as the thing to wait for. Confirmed with a second, narrower query (`scripts/check-gating-plugins.ps1`): the highest Minecraft version supported by **any GrimAC release** is 1.21.11. A non-release GrimAC build does reach 26.2 - but Section 23 forbids snapshots in production, Section 23 makes packet protection "a launch blocker", and rows 50 and 51 make anti-cheat behaviour a launch gate. Running a beta anti-cheat as the sole cheat defence on a **paid** server trades a real protection for a version number nobody can see.

Also verified before committing to 1.21.11: Geyser **2.11.2 build 1232** (`Geyser-Spigot.jar`, sha256 `5a56d231221fbf7ad6d701f2a39581fff9b7835df28f1a6345a1b8cf34455b92`) states support for 1.21.11, so 4.4 crossplay is not sacrificed by the older pin (`scripts/check-geyser-for.ps1`).

**Cost of this decision, stated honestly.** We launch one Minecraft line behind current. Players on 26.x clients still connect through ViaVersion, which 4.3 already requires for the Indian playerbase. The upgrade path is a single re-pin once GrimAC ships a stable 26.x release, and 4.2's instruction to wait is exactly this situation.

**Revisit when:** GrimAC publishes a stable release supporting 26.x. Then re-run `scripts/plugin-support.ps1` and re-pin.

**Verified:** all three scripts are in the repository and every number above is re-derivable. This decision was reached before any jar was downloaded or installed.


---

## D-0012 | 2026-08-26 | Requesting a Pelican Application API key, against 33.1

**The specification says:** 33.1, and 32.3 rows 1 and 2, strike out both Pelican API keys as "**NOT REQUIRED**... Do not request it", on the stated grounds that root SSH is "the primary and **only required** access path" which "covers everything rows 1 to 3 would have done".

**What I measured:** that premise is false. `php artisan list` on the Panel returns the complete `p:` namespace. It contains `p:node:make` and `p:user:make` but **no `p:server:make`** - Pelican has no CLI path to create a server, only `p:server:bulk-power`. The node also has exactly one allocation, already bound to the stock server, and allocations are creatable only through the Panel UI or the Application API.

**Therefore:** `laughtail-dev` cannot be created over SSH. Pre-flight 33.6 items 9 and 10 and the whole of Section 20 Phase 0 sit behind it.

**What I did:** raised `docs/owner-actions.md` **OA-25** offering two routes - the owner clicks, or the owner issues a narrowly-scoped Application API key. I recommended the key, and I did **not** proceed on either without an answer.

**Why the key is the better route, beyond unblocking:** this project creates a server at least four times - `laughtail-dev` now, `laughtail` at launch, a scratch server for the Phase 0 restore drill, and a replacement after the Section 22 migration. Via the API each is a scripted, committed, reviewable action. Via the UI each is a sequence of clicks that cannot be committed, cannot be diffed, and cannot be replayed on a new box in under thirty minutes - which acceptance row 3 requires. Section 29's whole argument is that the repository reproduces the runtime.

**What I refused to do:** create the server by writing to `/var/www/pelican/database/database.sqlite`. It is technically possible and it is exactly the class of change that breaks a Panel silently, which is the trap 33.1 itself warns about.

**Verified:** the `p:` namespace listing and the allocation, node, server, egg and user counts are in this session's transcript and re-derivable with `scripts/remote/panel-capability.sh`.


---

## D-0013 | 2026-08-26 | `level-name=laughtail`, and the owner's existing world is never opened

**The problem:** the volume already held a `world/` directory. `scripts/remote/check-world-version.sh` read its `level.dat` and found **DataVersion 4903, written by Minecraft 26.2**. We are pinning **1.21.11** (D-0011), and Minecraft cannot open a world from a newer version - it either refuses or corrupts. Deleting it was never an option: never-break rule 3.

**Decision:** set `level-name=laughtail`. Paper then generates fresh `laughtail`, `laughtail_nether` and `laughtail_the_end` directories and never reads `world/` at all. The old world stays on disk, untouched, as its own rollback.

**Why not downgrade or convert:** there is no supported downgrade path. Any conversion tool would be operating on the owner's only copy of a world we did not create.

**Verified:** first boot created all three `laughtail*` directories, and `world/level.dat` has mtime **1787711549 before and after** the boot - byte-identical, never opened. Evidence in `scripts/remote/start-server-and-verify.sh` output.

**Cost:** the old world occupies 749 MB that will not be reclaimed until the owner says it may be. Recorded against **OA-04** (disk) rather than silently deleted.

---

## D-0014 | 2026-08-26 | `server.properties` lives in git with secrets as `__PRESERVE__`, resolved host-side

**The problem:** Section 29 requires the repository to be the only source of truth for configuration, but the live `server.properties` contains an RCON password and a management-server secret. Never-break rule 5 forbids either entering git.

**Decision:** the repository holds the full file with every secret written as the literal `__PRESERVE__`. `scripts/remote/deploy-server-properties.sh` - generated from that one file by `scripts/gen-deploy-server-properties.ps1` - reads each placeheld value **from the live file on the host** and substitutes it there. No credential is transmitted, printed or stored. The script reports only a character count.

**Why not a `.env` file or Panel variables:** both would split the truth across two places, and the Panel's copy cannot be diffed or reviewed. One file, one source, secrets resolved at the last possible moment.

**Four properties the deploy script enforces, each of which was a real failure mode, not a hypothetical:**

1. **Refuses to run while the container is up.** Paper rewrites `server.properties` at shutdown, so editing a running server silently discards the edit.
2. **Aborts if the template lacks any key the live file has.** Paper regenerates a default for a missing key - for a secret that is a silent credential rotation. This check caught **twelve** keys the first draft had omitted, including `management-server-secret`.
3. **Aborts if a `__PRESERVE__` placeholder survives into the output.** It did, twice, during development - once from a mis-escaped `sed`, once because the check matched the template's own explanatory prose. Both times it installed nothing.
4. **Refuses to generate at all if a real secret is sitting in the template**, so the placeholder cannot be filled in by accident and committed.

**Verified:** deployed with `rcon.password` (32 chars) and `management-server-secret` (40 chars) both carried across, file `owner=999:987 mode=644`, and all 73 keys read back from disk.

---

## D-0015 | 2026-08-26 | Configuration drift is defined on meaning, not on bytes

**What I measured:** Paper rewrites `server.properties` on boot. The deployed file went from **6,155 bytes with ~60 comment lines to 1,868 bytes with 2**, and the keys were reordered. Every value survived.

**Therefore:** a drift detector that compares bytes, or runs `diff`, reports drift after **every single start**. A check that always fails is a check everybody learns to ignore, which is worse than no check.

**Decision:** `scripts/remote/check-properties-drift.sh` compares **key and value**, sorted, with comments discarded. Two further equivalences are handled explicitly rather than by loosening the comparison:

* The two secrets are compared as **"still non-empty"**, never by value. A secret that has become empty is a real failure and is reported as one.
* `motd` is compared **after decoding** `\uXXXX` escapes and `\\` on **both** sides. The repository writes escapes because that is the portable way to put section signs in a `.properties` file; Paper writes literal UTF-8. Same string, two spellings.

**A trap worth recording:** the first attempt decoded only the repository side, then tried Python's `unicode_escape` codec, which decodes via latin-1 and turns a literal UTF-8 `§` into two mojibake characters. It reported drift that did not exist. Both sides must be decoded, with the same rules.

**Verified:** `template keys: 73   live keys: 73`, `NO DRIFT`, both secrets non-empty, motd identical after decoding. Exit code 0.

---

## D-0016 | 2026-08-26 | The 1.21.9 management server is explicitly disabled, and its secret is preserved

**What I found:** Minecraft 1.21.9 added a management API, and the live file already had eight `management-server-*` keys including a 40-character secret. The first draft of the template omitted all of them.

**Why that mattered:** this is a **second remote-control surface** for the server, so acceptance row 5 - "RCON unreachable, only the intended ports open" - governs it exactly as it governs RCON. Omitting the keys would have had Paper regenerate the secret at boot: a silent credential rotation.

**Decision:** all eight keys are stated explicitly. `management-server-enabled=false`, `management-server-host=localhost`, `management-server-port=0`, and the secret carried across by `__PRESERVE__`. Disabled, bound to loopback, and pointed at port 0 - three independent reasons nothing can listen, so no single mistake opens it.

**Verified:** read back from disk after boot as `management-server-enabled=false`, `management-server-port=0`. The external probe found no port answering beyond the five intended ones.

---

## D-0017 | 2026-08-26 | The dev whitelist holds the owner only, and two offline-mode op grants were removed

**The urgent part:** deploying `white-list=true` and `enforce-whitelist=true` against a `whitelist.json` of `[]` locks out **everybody, including the owner**. That window existed and is now closed.

**What Mojang says about the three op entries** (`scripts/remote/verify-owner-identity.sh`):

| UUID | Version | Name in file | Mojang |
| --- | --- | --- | --- |
| `5139b372-eba4-3bf7-b8a7-0da708433c5e` | 3 | dipanshu03j | **unknown** |
| `263645f0-7a1b-4d45-a0c9-16d9b0d345d0` | 4 | dipanshu03j | **confirmed, currently named IgnisClaw** |
| `7d6a728a-8c62-31b4-89e5-2555c96ba89c` | 3 | IgnisClaw | **unknown** |

A version 4 UUID is issued by Mojang; a version 3 UUID is invented by an offline-mode server from the player's name.

**Decision:** `ops.json` and `whitelist.json` contain exactly one entry, the owner's real account, with the name corrected to **IgnisClaw** - `usercache.json` and Mojang agree the account was renamed from dipanshu03j, and Minecraft matches on UUID so the rename is harmless either way.

**Why the two version 3 entries were removed rather than left alone:** under `online-mode=true` they can never authenticate, so they grant nothing today - but they are standing **level 4** grants that would activate for whoever holds those names if online-mode were ever turned off. Dead configuration that becomes a privilege escalation under one config change is not harmless.

**`bypassesPlayerLimit` is `false`.** Law 1: the owner does not get a reserved slot that a paying player cannot have.

**Scope, stated so it is not mistaken for a precedent:** this is `laughtail-dev`. Acceptance row 12 - "whitelist matches paid transactions exactly, zero unexplained entries" - is a **production** test. The production whitelist is written only by the paid grant pipeline built in Phase 1. The owner is on the dev whitelist because nothing can be tested otherwise.

**Verified:** both files validated as one-element JSON arrays before installation, installed `owner=999:987 mode=644`, and both removed UUIDs confirmed absent from `ops.json`. Originals saved to `_quarantine/*.prebuild`.

---

## D-0018 | 2026-08-26 | `allow-flight=false` until GrimAC is proven to catch flight

**The tension:** 7.2 allows elytra, and the vanilla flight check has a history of false-kicking elytra users on a laggy tick - which a 2 vCPU burstable box will produce. The usual answer is `allow-flight=true`, letting a real anti-cheat do the movement checks properly.

**Decision:** leave it `false` for now. GrimAC is installed but **not yet proven** - acceptance row 50 requires a caught test flight with a logged violation, and that is Phase 1 work. Until that evidence exists, the crude vanilla check is the only flight protection there is, and turning it off would leave a gap that nothing covers while looking like a tuning improvement.

**Revisit in Phase 1**, immediately after row 50 passes. Note this is a `server.properties` key only; 15.6's permanent ban on `/fly` as a *feature* is a permission node and is unaffected either way.

---

## D-0019 | 2026-08-26 | The read-only scripts never print a whole config file again

**What went wrong:** the first version of `scripts/remote/read-access-state.sh` ended with `cat "$D/server.properties"`. It printed the live RCON password and the management-server secret into an agent transcript. Never-break rule 5 exists precisely to stop that.

**Decision:** no script in this repository dumps `server.properties` wholesale. Key **names** are read by `read-properties-keys.sh`; **values** are read only by explicit name, and the two secret-bearing keys are excluded by construction. Any output that might contain them is passed through a redacting `sed` first. The reason is written into the script itself as a comment so the next person does not re-add the convenience.

**Residual risk, stated plainly:** the two secrets did appear in one earlier session's transcript. They are unchanged on the host and remain functional. Rotating them is cheap - RCON is not reachable externally and the management server is disabled - but it is the owner's call, so it is raised as an owner action rather than done silently.


---

## D-0020 | 2026-08-26 | Never-break rule 4 was being measured against the wrong number, and was failing

**What session 1 recorded:** "Allocation 3,097 MiB, `-Xms768M -Xmx2304M`. Headroom 793 MiB = **25.6%**. Never-break rule 4 is satisfied, but only just."

**That was wrong.** 3,097 MiB is the **container limit**, which Pelican computes as the allocation **plus its own 10% overhead**. The allocation the Panel actually enforces is **2,816 MiB**, read from `Server::find(1)->memory`. Against that number:

```
2816 - 2304 = 512 MiB outside the heap = 18.2%
```

Rule 4 requires **25% or 768 MB**. It was failing both tests, and the reassuring 25.6% came from treating Pelican's overhead allowance as headroom we were entitled to spend. It is not: it is the room the JVM's non-heap memory - metaspace, code cache, thread stacks, direct byte buffers, GC structures - has to live in.

**Fixed:** `-Xms2048M -Xmx2048M`. That leaves exactly **768 MiB = 27.3%** outside the heap, passing both tests.

**Why `Xms` equals `Xmx`:** the startup line already carries `-Dusing.aikars.flags` and `-XX:+AlwaysPreTouch`. Aikar's flags require `Xms=Xmx`, and pre-touching a fixed heap makes the footprint **predictable at boot** rather than growing later into a box with no room to grow. On 3.8 GB, a surprise is worse than a cost.

**Verified in the running container, not in the Panel record** - the distinction matters because Wings only applies memory changes when it recreates the container:

* `docker top` shows `-Xms2048M -Xmx2048M`
* allocation 2816, xmx 2048, outside 768 MiB (27%) - **RULE 4 PASS**
* boot clean, `Done (54s)`, all eight plugins enabled, 0 ERROR

**The cost, stated because it is real:** committing the heap up front pushed container use to 2.487 GiB of its 3.025 GiB ceiling at idle, and host page cache from 1,844 MB down to 740 MB with 625 MB available. Predictable, but tight. See **Q-41**, which works through whether the 2,816 MiB allocation is itself too large for this box.

---

## D-0021 | 2026-08-26 | The existing server is renamed to `laughtail-dev` rather than a second server being created

**The blocker:** pre-flight 33.6 items 9 and 10 require a server named `laughtail-dev` with its own allocation and a heap 25% below it. D-0012 established that Pelican has **no `p:server:make`**, so a server cannot be created over SSH, and OA-25 has been waiting on the owner since.

**What I did instead:** renamed the one existing server. It already has the only allocation on the node (`0.0.0.0:25565`), it already runs the pinned Paper with our config, and its heap now satisfies rule 4. Renaming satisfies items 9 and 10 today, with a single scalar field change.

**Why this is better than creating a second server, not merely easier:** a second server needs a second allocation and its own memory. This box has 3,825 MB total and this one server is allocated 2,816 MiB. Two such servers cannot coexist - which is exactly why never-break rule 2 exists. Creating a second one would produce a Panel record that can never safely start, and pre-flight item 11 already requires the other server to stay stopped. One server, correctly named, is the honest configuration.

**How it was changed:** through the application's own Eloquent models via `artisan tinker`, never raw SQL against `database.sqlite`. The models handle casts, timestamps and encrypted attributes correctly; hand-editing a Panel database is the class of change that breaks a Panel silently, and it is the trap 33.1 warns about. Every previous value was printed before being overwritten, so reverting is copy and paste.

**Consequence for OA-25:** **downgraded from blocking to optional.** The Application API key is still the better long-term route - the production server, the restore-drill scratch server and the post-migration replacement all still need creating, and Section 29 wants each to be a scripted, reviewable action rather than a sequence of clicks. But Phase 0 is no longer stalled behind it.

**Production is unaffected.** `laughtail` still does not exist, and never-break rule 1 is intact.

---

## D-0022 | 2026-08-26 | The egg variables are pinned so a Reinstall reproduces the manifest instead of destroying it

**What I found:** the Paper egg's install script downloads from `fill.papermc.io` using two server variables, and they read `MINECRAFT_VERSION=26.2` and `BUILD_NUMBER=latest`.

**Why that was a loaded gun:** the install script runs on install and reinstall, **not** on boot - so nothing was broken today. But one click of "Reinstall" in the Panel would have fetched the newest 26.2 build, overwritten the pinned `server.jar`, and left a 1.21.11 world and config under a 26.2 server. `latest` is precisely the floating tag spec 4.2 forbids, sitting in the one place nobody was looking.

**Fixed:** `MINECRAFT_VERSION=1.21.11`, `BUILD_NUMBER=132` - the same values `server/manifest.yml` pins and whose checksum `verify-manifest.ps1` confirms. A reinstall now rebuilds exactly what the manifest describes, which is what Section 29 means by the repository reproducing the runtime.

**Note for the migration (Section 22):** the egg has an `update_url` pointing at the upstream `egg-paper.yaml`. Updating the egg from upstream would reset these variables to their defaults. Anyone who does that must re-pin them.

**Verified:** read back as `BUILD_NUMBER = 132`, `MINECRAFT_VERSION = 1.21.11`, `SERVER_JARFILE = server.jar`.


---

## D-0023 | 2026-08-26 | MariaDB runs as a container, and a factual correction to session 1

**The correction first.** Session 1 recorded that "`mariadb` and `redis-server` are both **inactive**, so the Panel is not using them". That reading was wrong. `scripts/remote/db-assess.sh` shows **no MariaDB or MySQL packages installed at all**, no server or client binary on `PATH`, and `systemctl is-enabled` returning **`not-found`** rather than `disabled`. They were never installed. `systemctl is-active` reports `inactive` for a unit that does not exist, which is what produced the misreading.

**Why that changed the plan for the better.** "Start the existing service" was never an option. The real choice was between installing MariaDB on the host and running spec 5.2's `db` container. The container wins on three counts:

1. **No `apt` on the game box.** 33.2 item 4 requires a fresh snapshot before "installing or upgrading anything at host level", and **OA-03 means no snapshot exists**. A host package install would have been the one irreversible step in this session.
2. **The footprint is capped, not hoped for.** `--memory 320m` with `--memory-swap` equal to it, so it cannot swap - the same reasoning as deviation D7 for the game container. Measured use: **180.4 MiB**.
3. **It is what the specification actually says.** 5.2 lists `db` as a container alongside `mc`.

**Pinned to `mariadb:11.4.5`** with the pulled digest `sha256:49117dcc...938f7e4b` recorded in `server/manifest.yml`. A tag can be repointed by the publisher; a digest cannot. Confirmed `arch=arm64`.

**Not exposed.** Published on `127.0.0.1:3306` only. 5.2 requires container-network only and row 5 requires MySQL invisible from outside; `check-external-ports.ps1` already probes 3306 and expects closed.

**Data lives outside the Pelican volume**, at `/home/ubuntu/laughtail-db/`. Two reasons: it keeps the 33.1 ownership trap away from the database, and world backups and database backups have completely different consistency requirements (5.4) so they should not share a directory.

**Credentials** are generated on the host with `openssl rand`, stored `0600` root-only, and passed as `MARIADB_*_FILE` secrets rather than `-e` values - an environment variable is visible in `docker inspect` for the life of the container. Neither password has been printed or committed.

**Tuning, deliberately small:** `innodb_buffer_pool_size 64M` against the 128M default, `performance_schema` off, `max_connections 40`, UTC, `innodb_flush_log_at_trx_commit 1`. The dataset will be a few MB for years - 24 players and a transaction ledger - so a buffer pool larger than the whole dataset would only take page cache away from Paper's chunk I/O, and `sync-chunk-writes` is false precisely because that cache matters. Durability is kept at the default because a Berry transaction that is acknowledged must survive a power cut.

**The cost, measured:** host available memory fell from 650 MB to **519 MB**. That is the third data point for **Q-41** and it moves in the wrong direction.

---

## D-0024 | 2026-08-26 | Schema conventions, and why the migration runner refuses more than it applies

**Written as `db/migrations/V1__init.sql`, forward-only.** Applied in 379 ms; five tables, all InnoDB and `utf8mb4`.

**V1 is deliberately not all 23 Appendix D tables.** It creates the bookkeeping, the two tables Phase 0 and Phase 1 need (`players`, `access_grants`), and the `seasons`/`champions` pair. Each later phase adds its own migration. The economy tables specifically should not be guessed at now: **Q-10** records that the economy has no numbers anywhere in the specification, and schema written against undecided mechanics gets rewritten - which forward-only migrations make expensive.

**`champions` is the exception and is here on purpose.** Acceptance row 36 asks for "exactly one Champion per season" with evidence "**schema** plus failed-insert test". That wording demands a database constraint, so `PRIMARY KEY (season_number)` is a Phase 0 artefact even though seasons are Phase 4. Application-level checking would satisfy the sentence and miss the point: a race, a bug or a manual console command could still produce two champions.

**Conventions, each with a reason rather than a habit:**

| Choice | Instead of | Why |
| --- | --- | --- |
| `CHAR(36)` ascii_bin UUIDs | `BINARY(16)` | Tens of players, not millions, so the space saving is irrelevant while the debugging cost is real - every manual query and support conversation would need hex conversion. `ascii_bin` gives exact, case-sensitive matching |
| `DATETIME(3)`, UTC by convention | `TIMESTAMP` | `TIMESTAMP` is a 32-bit offset that dies in 2038, and MariaDB converts it using the *session* time zone, so one row reads differently from two connections. 31.1 puts the season reset on a clock, so an ambiguous instant is a real bug |
| `BIGINT` money | `DECIMAL` or a float | Berries are integers. A float balance cannot be summed reliably and would undermine the Phase 3 arbitrage audit |
| `first_ip_hash CHAR(64)` | storing the IP | Row 32 needs same-IP kill *comparison*, not readability. A hash satisfies the requirement and limits what a database leak discloses |
| `rules_version_accepted` | a boolean | Row 17 requires the accepted **version** be stored, so changing the rules can re-gate everyone |
| `expires_at` nullable | `NOT NULL` | D-0002 and 24.1: the owner has not chosen one-time versus recurring pricing. NULL means never expires, so both models work with no later schema change |
| `UNIQUE` on `transaction_ref` | no constraint | Payment webhooks are delivered more than once. This is what makes the handler safe to retry - the same payment cannot grant access twice |

**The runner enforces forward-only rather than requesting it.** Every applied migration's SHA-256 is recorded, and if the file's hash later differs, the run **aborts and applies nothing**. Appendix D says never modify a live schema by hand; the corollary is never modify an applied migration, because the database cannot be re-derived from it afterwards. Without a checksum, an edited V1 is indistinguishable from an untouched one.

**All three behaviours were observed, not assumed:**

* **Applies:** V1 in 379 ms, five tables, `ERROR 1062` on the duplicate champion.
* **Idempotent:** second run reported "already applied, checksum matches", "nothing to apply", `applied_at` unchanged.
* **Refuses:** with the recorded checksum corrupted to `deadbeef...`, the runner printed both hashes and exited **3**, applying nothing. Then restored and re-verified. A guard that has never been observed refusing anything is an assumption, so it was made to refuse once, reversibly.

**One bug worth recording, because it is a whole class.** The first version of the SQL helper piped output through `grep`, which makes the pipeline's exit status *grep's*. A `CREATE TABLE` produces no output, grep found nothing, exited 1, and `set -e` aborted the run on a statement that had actually succeeded. Output is now captured and filtered with `sed` so the real exit status survives - which the row 36 test depends on, since it must distinguish success from a constraint violation.


---

## D-0025 | 2026-08-26 | Paper config is managed as a documented subset of keys, not as whole files

**The obvious reading of Section 29** - keep `paper-global.yml`, `paper-world-defaults.yml`, `spigot.yml` and `bukkit.yml` in the repository and deploy them - is wrong here, for three measured reasons:

1. **Paper adds, renames and moves keys between versions.** A repository copy would go stale silently, and on upgrade the stale file would *win* over Paper's new baseline, re-introducing old defaults. Some of these keys already moved between the version that generated this volume (26.2) and the pinned 1.21.11.
2. **Paper rewrites these files at boot and on config migration**, so a byte-for-byte model produces permanent false drift - the same effect measured for `server.properties` in D-0015.
3. **A subset is auditable and a whole file is not.** Six deliberate keys with reasons can be reviewed; four hundred keys copied from a default file hide which ones were actually decisions.

**So `server/paper-tuning.yml` is a registry**: file, key path, value, and *why*. Everything not listed is Paper's business.

**The applier refuses to create a key that does not already exist.** This is the important safety property. Paper ignores an unknown key without any error, so a typo'd or renamed path would look successfully applied and do nothing at all. The applier aborts and tells you to re-derive paths with `paper-config-paths.sh`.

**What was actually changed, and why each one:**

| File | Key | From | To | Reason |
| --- | --- | --- | --- | --- |
| paper-global | `spark.enabled` | false | **true** | 6.7 names spark as the measurement toolchain. Bundled with Paper but off by default |
| paper-global | `player-auto-save.rate` | -1 | **5000** | 6.4 stagger requirement - see below |
| paper-global | `player-auto-save.max-per-tick` | -1 | **5** | spreads player writes instead of doing them in one tick |
| spigot | `ticks-per.hopper-transfer` | 8 | **16** | 6.4 states these exact numbers |
| spigot | `ticks-per.hopper-check` | 8 | **16** | 6.4 states these exact numbers |

**The autosave collision was a real defect, not tidying.** 6.4 says "never let plugin saves and world saves land on the same tick". Chunk autosave runs at 6000 ticks, and `player-auto-save.rate` was `-1`, which *inherits* `bukkit.yml`'s `ticks-per.autosave` - also 6000. So both fired on the same tick every five minutes. 5000 against 6000 coincides every 30,000 ticks (25 minutes) instead.

**Section 6.4 turned out to be partly obsolete, and that is worth recording** rather than blindly "fixing" things that are already right. Verified already true in Paper 1.21.11 by reading the live files: `hopper.disable-move-event` true, `misc.redstone-implementation` `ALTERNATE_CURRENT` (6.4's "Paper's optimised option"), `misc.update-pathfinding-on-block-update` false, `per-player-mob-spawns` true, `merge-radius` already 4.0/6.0 versus Spigot's 2.5/3.0. That spec text was written against an older Paper.

**What I deliberately did NOT change, and why.** 6.4 also advises reducing entity activation and tracking ranges and tuning mob spawn limits down. Measured idle MSPT is **0.2 ms against a 25 ms budget**. There is no CPU shortage to fix, and reducing activation ranges trades visible gameplay fidelity - mobs freeze while a player can still see them - for CPU that is not scarce. Law 5 and 6.8 both put measurement before tuning, so those values are listed in `server/paper-tuning.yml` as Phase 6 candidates with their current values, to be set from the load test rather than from a blog post. The one honest counter-argument is memory rather than CPU, and that belongs to Q-41 and the load test too.

**Verified:** applier set 5 keys and reported the 6th already correct; server booted clean in 57 s with all eight plugins and zero ERROR; `check-paper-drift.sh` reports `drift=0` **after** the boot, so Paper preserved the values rather than rewriting them.

**A spark limitation, recorded so it is not rediscovered.** With `spark.enabled` true, `spark health` now replies "Generating server health report..." where it previously said "The spark profiler is currently disabled" - so the command is registered and running. But the report itself is delivered asynchronously to the command sender, and an RCON sender is transient, so the report never arrives over RCON. Two client strategies were tried - draining all packets, then holding the connection open for 20 s - and neither retrieves it. This is a spark/RCON interaction, not a configuration fault. **The working channel for spark reports is the Panel console**, which the owner has. `/tps` and `/mspt` remain the scriptable path and are what the D2 baseline uses.


---

## D-0026 | 2026-08-26 | I printed a database password into a transcript, and what changed as a result

**What happened.** `plugin/src/main/resources/config.yml` carried the placeholder token in its *header comment* - the comment explained "the placeholder below is the literal string `__PRESERVE__`". The deploy script replaced **every** occurrence of that token in the file, so the real database password was substituted into the comment as well as into the `password:` key. The output was then displayed through a `sed` that redacted only lines matching `^\s*password:`. The copy in the comment sailed straight past it and was printed in full.

**This is the second secret exposure in this project** (D-0019 was the first, a whole-file `cat`). Two different causes, one shared shape: **a redaction filter that has to be right about every line will eventually be wrong about one.**

**What I did about it, immediately:**

1. **Rotated the credential.** `scripts/remote/rotate-db-app-password.sh` generated a new 32-character value on the host, applied it with `ALTER USER`, verified the **new** password authenticates, and verified the **old** password is now **rejected** - a rotation that leaves the old credential working is not a rotation. The exposed value is dead. Nothing external depended on it: the `laughtail` user is reachable only from the `pelican_nw` Docker network and is used only by this plugin.
2. **Anchored the substitution.** It now replaces the password only where it appears as the value of the `password:` key, exactly once, and **aborts** if the count is not exactly one afterwards. A token mentioned in prose is now inert.
3. **Stopped printing the file at all.** The deploy verifies by *property* - line count, host, schema, user, rules version, password *length* - and never displays content. This is the substantive change: verifying properties is safer than displaying content and trusting a filter.
4. **Removed the token from the comment**, because the cheapest defence is not to repeat it in prose.

**The general rule I should have been following, now written down:** never print a file that contains a secret, redacted or otherwise. Print facts *about* it. A redaction is a denylist, and denylists fail quietly in the one case nobody thought of.

**Residual risk, stated plainly:** the old password appeared in one agent transcript and is now invalid everywhere. It was never committed to git. The root password was not exposed. No player data, payment data or panel credential was involved.

---

## D-0027 | 2026-08-26 | The LaughTail core plugin exists, built on the host in a container

**Built from source in this repository** rather than downloaded - never-break rule 9 is about pinning third-party jars; this one we own. `plugin/` holds a six-file Maven project producing `LaughTail-0.1.0.jar`, 764 KB.

**Compiled inside a throwaway `maven:3.9.9-eclipse-temurin-21` container on the VPS.** Same reasoning as D-0023 for MariaDB: never-break rule 13 and 33.2 item 4 say do not install host packages mid-build without a snapshot, and OA-03 means none exists. Nothing is installed on the host - no JDK, no Maven. The container is capped at 640 MiB because the box has roughly 300 MB spare (B3) and an unbounded Maven JVM could OOM the host and take the game server with it.

**Targets Java 21, not 25.** The server runs Temurin 25, but Paper 1.21.11 targets 21, and compiling to 21 means the jar runs on both. Targeting 25 would tie the plugin to this exact runtime for nothing.

**Scope at 0.1.0 is deliberately small and complete** rather than broad and half-working: player registration keyed on UUID, the rules gate with the accepted version stored, `/laughtail status`, and `/laughtail reload` - which is what never-break rule 7 says to use instead of vanilla `/reload`. Berries, rank, seasons and the watchdog are not here and are not pretended to be.

**Three real problems solved along the way, none of which were visible from the design:**

1. **The game container could not reach the database.** MariaDB publishes 3306 on the *host's* 127.0.0.1 so it is invisible externally (D-0023), but the game server runs in a container on `pelican_nw` - and a container's loopback is its own. Nothing in the config file would have revealed this; the plugin would simply have timed out. Fixed by attaching the database container to `pelican_nw` and addressing it at `172.18.0.3`. It is still published nowhere reachable from outside, so acceptance row 5 is unaffected. The deploy now **proves** reachability with `/dev/tcp` from inside the game container before writing any config.
2. **`No suitable driver found`** after the driver was relocated. Shading rewrites the driver *classes* but not `META-INF/services/java.sql.Driver`, which still named `org.mariadb.jdbc.Driver` - so `DriverManager` looked up a class that no longer existed and reported what sounds like a network fault but is a packaging one. Fixed twice over: `ServicesResourceTransformer` relocates the service file, **and** the code instantiates the driver directly so correctness does not depend on service discovery at all.
3. **The transport had a hidden 24 KB ceiling.** `remote.ps1` embedded the base64 payload in the ssh command line, and Windows caps a command line near 32,000 characters. The plugin build script - 49 KB of base64 carrying six source files - was the first thing large enough to hit it, and the error, "The filename or extension is too long", says nothing about size. The payload now streams over stdin, with `tr -d '\r'` on the remote side because PowerShell terminates the stream with CRLF and GNU `base64` rejects the carriage return.

**The design constraint that shaped `Database.java` is acceptance row 25:** no database call on the main thread. Every method asserts it is off the main thread and **throws** if it is not, rather than quietly costing tick time - Law 8, fail loud rather than slow. Every statement is parameterised; a player name is attacker-controlled input.

**One honest limitation:** connections are opened per operation rather than pooled. That is fine for a handful of writes per join and 24 players, and it will need revisiting before Phase 3's order book, which is write-heavy and latency-sensitive. Noted rather than glossed.

**Verified:** loads on aarch64 as the 9th plugin, `Database reachable, migration V1 present.`, zero ERROR lines, and `/laughtail status` reports version, rules version and database state over RCON.


---

## D-0028 | 2026-08-26 | The server moves from Minecraft 1.21.11 to 26.2, matching the client

**This reverses the version half of D-0011**, and the reason is that D-0011's premise was right but incomplete. It pinned 1.21.11 because that was the newest version every plugin *stated* support for. What it did not account for is that **players do not choose the server's version - their launcher does**. The owner connected with 26.2, so ViaVersion translated every packet, and GrimAC - which predicts movement *from* packets - mispredicted and set them back. The symptom reported was "I cannot even sprint".

So the pin was not merely conservative, it was the cause of an unplayable server.

**Checked before moving, not after.** `scripts/plugin-support.ps1` asked each publisher directly: ViaVersion, ViaBackwards, LuckPerms, Chunky, spark and Simple Voice Chat all state 26.2; Geyser and Floodgate track the newest release by design and their own APIs return 2.11.2-b1232 and 2.2.5-b140 as latest, which are already the pinned builds.

**Two pins changed:** Paper 1.21.11-132 → **26.2-119** (stable), and Chunky 1.4.40 → **1.5.3**. That second one is a satisfying inversion: 1.4.40 was pinned *only* because 1.5.3 did not state 1.21.11 support. Moving to 26.2 resolved the conflict rather than working around it.

**Via stays at stable 5.11.0.** Modrinth offers 5.12.0 for 26.2 but only as a SNAPSHOT, and spec 4.2 forbids a floating pin. With the server on the client's generation, Via is now inert for current players and translates only for genuinely older ones - which also means the OA-27 conflict no longer affects anybody playing on a current client.

**The casualty is GrimAC, and it was unavoidable either way.** Its latest release states 1.21.11 and has **no 26.2 build at all**, so it could not have worked with a 26.2 client under either pin. It stays quarantined, still checksum-verified in the manifest. **Acceptance row 50 remains unclaimable and has never been claimed.** This is now the single most important open item before launch: a PvP server whose product is fairness cannot open without anti-cheat. OA-27 is updated accordingly.

**Four toolchain problems the move exposed, each of which reported something other than its cause:**

1. **`paper-api:26.2-R0.1-SNAPSHOT` does not exist.** Paper changed its API coordinate scheme for the 26.x line to `26.2.build.119-stable`. That is strictly better for this project - the API is pinned to the exact server build, so the two cannot drift - but the failure read as a missing repository.
2. **`class file has wrong version 69.0, should be 65.0`.** Major version 69 is **Java 25**: Minecraft 26.x requires it. Compiling with `release 21` could not read the API at all, and javac reported *every symbol as missing* rather than naming the version. The plugin now targets 25, which the server already runs.
3. **`Unsupported class file major version 69`** from maven-shade-plugin 3.5.3, *after* a successful compile - its bundled ASM cannot read Java 25 bytecode. Fixed by moving to shade 3.6.2. This one looked like a shading bug and was a toolchain gap.
4. **`--` inside an XML comment** is illegal, which broke the POM after I wrote `release 21` with dashes in a comment. Trivial, and worth recording because the error message pointed at a character position, not at the rule.

**The world upgraded, and the owner's original world did not.** Paper performed a `WorldFolderMigration` on boot; the `laughtail` world now reports **DataVersion 4903**, which is 26.2. The pre-existing `world/` directory - which was 26.2 all along, and was the reason D-0013 pointed `level-name` elsewhere - still has an unchanged mtime. It is now *readable* by this server for the first time, but it stays untouched: D-0013 stands until the owner says otherwise.

**And a real defect this surfaced:** Paper reported `Ambiguous plugin name 'Chunky'` because both 1.5.3 and 1.4.40 sat in `plugins/`, with load order decided by chance. The cause was a **bare `[ -f ]`** in the installer - the sixth instance of that class in this project. The `ubuntu` user cannot traverse the Pelican volume, so the test returned false for a file that existed and the quarantine was silently skipped. The same script also still contained the *original* instance, which had been reporting "server.jar.prebuild already exists, leaving it" for a rollback copy it had never checked. Both now use `sudo -n test -f`.

**Verified:** Paper 26.2-119 running, API 26.2.build.119-stable, all 8 plugins loaded including Chunky 1.5.3 and LaughTail 0.1.0, boot in 45 s, **zero ERROR lines**, 31 of 31 deploy stages green.


---

## D-0029 | 2026-08-26 | Minecraft 26.2 unified world storage, and every world-path assumption had to change

**What was found.** After the move to 26.2, only two directories existed at the volume root - `laughtail` and `world` - yet Multiverse listed five worlds and the plugin had successfully applied borders to all five. Paper had announced this on boot as "World storage migration is required during startup", which is easy to read as routine.

**The actual layout:**

```
laughtail/
  level.dat
  dimensions/minecraft/overworld/region
  dimensions/minecraft/the_nether/region
  dimensions/minecraft/the_end/region
  dimensions/minecraft/laughtail_resource/region
  dimensions/minecraft/laughtail_arena/region
```

Every dimension now lives **inside one world folder**, addressed as a namespaced dimension. There is no longer a `laughtail_nether` directory. Multiverse records the old name as `legacy-world-name`.

**Why this matters more than it looks.** Every script that treats a world as a top-level directory is silently wrong, and the two that did were the two where being wrong is worst:

* `regen-resource-world.sh` looked for `$D/laughtail_resource` and refused to run. That refusal is the system working: it declined to operate on a path it could not confirm rather than deleting something adjacent to it.
* `backup-run.sh` excluded `./world_nether` and `./world_the_end`, paths that no longer exist. Harmless in effect - and it turns out **better** than before, because including `laughtail/` now captures all five worlds in one archive. Verified: 333 entries, 26 region files, up from 12.

**The dangerous consequence, and the mitigation.** Under the old layout, the resource world was a sibling of the main world. Under this one it is a sibling of `overworld`, `the_nether` and `the_end` *inside the same folder* - so a path mistake in the regeneration script is now one directory name away from deleting the permanent world rather than a whole level away. The script therefore checks the **dimension path** as well as the world name, refusing anything matching `overworld`, `the_nether` or `the_end`, and refusing anything that does not contain `laughtail_resource`.

---

## D-0030 | 2026-08-26 | The resource world regeneration takes no arguments, and proves it worked

7.4 is unusually specific: "Deleting the wrong world folder is an unrecoverable, server-killing mistake, so the script must name the world explicitly and refuse to run against the main world."

**So the script takes no parameters at all.** There is no `--world` flag to typo and no variable to expand wrongly. A script that *can* destroy the main world will eventually be pointed at it, and the destructive-command guard cannot help, because a variable is opaque to static analysis - a lesson this project already learned when the guard refused the restore drill for exactly that reason.

**Five independent refusals**, any one of which stops the run: the literal name checked against a protected list; the dimension path checked against the permanent dimensions; not the server's default world, read from `server.properties` at runtime; the target must already exist, so a typo cannot be "created"; and a backup must complete **and be listable** before anything is destroyed.

**A false pass caught before it mattered.** Multiverse 5 answers `mv regen` with "Run /mv confirm <id> to continue. This will expire in 30 seconds" and does nothing until that arrives. The first version printed that prompt as though it were a result and reported **"RESOURCE WORLD REGENERATED"** while the world was untouched - a false success on the single most destructive operation in the project.

Fixed twice over: the confirmation token is parsed and sent, **and** the directory mtime is compared before and after, so the script fails if the world did not actually change. Reporting success without evidence is the failure this whole script exists to prevent, and it managed to do it to itself on the first attempt.

**Verified end to end:** all refusals passed, the one online player was evacuated (`Teleported IgnisClaw to laughtail`), a 213 KB backup was taken and confirmed listable, token 440 was sent, Multiverse replied `World 'laughtail_resource' regenerated!`, the directory mtime advanced from 1787728685 to 1787729480, all three permanent dimensions were still present at their original sizes, and the owner's original world's `level.dat` mtime was unchanged.

**Not done, and visibly so:** 7.4 also wants escalating warnings on the 9.5 schedule. That belongs to the season clock in the plugin, which does not exist yet. Faking it with `sleep` in a shell script would be worse than leaving it undone.


---

## D-0031 | 2026-08-26 | The owner delegated the numeric decisions; P1 to P13 are now decisions

**The owner's instruction:** "whatever decision are best do it."

That is a delegation of the thirteen proposals in `docs/proposals.md`, so they stop being proposals and become decisions. Recorded here with the owner's instruction as their authority, because a value nobody can trace back to a decision gets re-litigated.

**Approved as written**, with two amendments noted below:

| # | Value | Now |
| --- | --- | --- |
| P2 | `target_berries_per_hour` = 1,200 | decided |
| P3 | minimum spread 12% | decided |
| P4 | elasticity 0.15 per 1,000 units, band ±40% | decided |
| P5 | recovery 5% of the gap per hour | decided |
| P6 | daily sell cap 3,600 per category | decided |
| P7 | balance alert at 4× median active balance | decided |
| P8 | anti-snipe window 30 s | decided |
| P9 | 6 auction slots, +2 per tier above 4 | decided |
| P10 | 5% transfer tax above 5,000 Berries | decided |
| P11 | `MAX_GAIN` = 24, keeping `raw = 24 * (1 - E)` | decided |
| P12 | death floor is the bottom of the LADDER, not the tier - demotion exists | decided |
| P13 | decay 1% per week of the distance above the tier floor, none in week one | decided |

**P1 is amended, not approved as written.** The access price stays at **₹199** as the recommended figure, but it is no longer a build input - see D-0032. With payment collected manually there is no store field to configure, so the price can change whenever the owner likes without touching anything.

**What I am NOT treating as delegated.** "Whatever decision is best" covers numbers and technical rulings. It does not cover things that are legally binding or that would spend the owner's money: the Terms, Privacy and Refund text (OA-13), buying an anti-cheat licence, growing the EBS volume, or changing the EC2 instance type. Those still stop and ask. A delegation of judgement is not a delegation of signature or of spend.

---

## D-0032 | 2026-08-26 | No payment integration. Access is granted manually against payment received

**The owner's instruction:** "realmoney stuff remove for now. this is paid server whoever pay me i just add him whitelisted. thats it."

**What this removes from the build**, and it is a lot:

* No store platform, no product configuration, no checkout (was OA-10).
* No payment provider, no INR settlement account, no webhook endpoint (was OA-11).
* No automated grant pipeline, no refund automation, no chargeback handling.
* Section 18.3's store pipeline and the payment half of rows 16 and 18 are out of scope for now.

**What it keeps, and must keep.** The `access_grants` table stays and stays mandatory, because acceptance row 12 does not care how the money arrived: "the whitelist matches paid transactions exactly, with zero unexplained entries." Manual collection makes that *easier* to satisfy and *easier* to get wrong - easier because the owner knows every payment personally, easier to get wrong because a whitelist edit with no matching grant row leaves no trace at all.

**So the flow becomes:** the owner receives payment out of band, runs one command, and the command does both halves - it writes the `access_grants` row **and** adds the whitelist entry, in that order, so a whitelisted player without a grant record cannot exist. That is the whole value of doing it in a command rather than by hand in the Panel: the audit trail is not optional.

`source` is recorded as `manual` and `transaction_ref` takes whatever reference the owner has - a UPI reference, a screenshot filename, a date and name. `amount_minor` and `currency` stay nullable because a manual process will not always have a clean figure.

**Why this is a good decision and not just a simpler one.** Mojang's Commercial Usage Guidelines are satisfied either way, but a manual whitelist removes an entire class of risk at this stage: no card data anywhere near the server, no webhook to secure, no chargeback flow to get wrong, and no PCI-adjacent surface. At 20 to 24 players the manual work is a few minutes a week. The automated pipeline is worth building when the player count makes it worth it, and 26.x's roadmap is the right place for it.

**Recorded as reversible.** `access_grants.expires_at` is still nullable (D-0002), `transaction_ref` still has its unique constraint so a webhook could later be made idempotent against it, and nothing about the schema assumes manual entry. Adding a store later needs no migration.

---

## D-0033 | 2026-08-26 | A roleplay layer is recorded as a future direction, not started

**The owner's instruction:** "when everything is done, then we are also introduce roleplay system here. real roleplay."

**Recorded and deliberately not designed.** Noted here so it is not lost, and left undesigned because designing it now would be the wrong order twice over:

* Section 25 is explicit about scope discipline, and the current build has 74 of 81 acceptance rows untouched. A new pillar before the existing ones work would guarantee neither works.
* A roleplay layer is not a feature, it is a second product. It touches identity, chat, economy, world and moderation - every system currently half-built. Whatever gets designed now against a half-built economy will be redesigned once the economy is real.

**One thing worth flagging early, because it is structural rather than cosmetic.** A serious roleplay layer and the current competitive-PvP framing pull in different directions: PvP-everywhere with `keepInventory=false` (7.2) is hostile to sustained roleplay, and rank-from-PvP-only (Law 1) gives a roleplayer no progression at all. Those are reconcilable - separate worlds, or a roleplay season format - but the reconciliation is a **product decision**, and it should be made deliberately rather than discovered when the two systems first collide.

Added to the post-launch roadmap in `docs/progress.md` rather than to any current phase.


---

## D-0034 | 2026-08-26 | A wildcard denial makes `default: op` grant nothing — every node must be granted by name

**The symptom.** The owner ran `/laughtail rating` and got "No permission", while being both server op and a member of the `owner` LuckPerms group.

**The cause, which generalises.** `plugin.yml` declared `laughtail.status` as `default: op`, and it was never granted to any group. That looked safe because the owner *is* op. But:

1. The `admin` group carries an explicit **`* = false`**, required because 17.3 forbids a wildcard for Admin.
2. `owner` **inherits** `admin`.
3. In LuckPerms an explicit wildcard denial beats an op-based default.

So every node not granted by name somewhere in the chain resolved to denied — for the Owner as well as for Admin. The wildcard denial that protects 17.3 also swallowed a harmless diagnostic command.

**The rule that follows:** *once any group in the inheritance chain denies the wildcard, `default: op` in `plugin.yml` grants nothing.* Every permission the ladder needs must be granted explicitly by name.

That is a better posture regardless. It means the permission set is legible from `server/permissions.yml` alone, rather than depending on who happens to be opped — and op status is exactly the thing 17.3 wants to stop mattering.

**Why the existing verification missed it, which is the more useful failure.** `verify-permissions.sh` tested 31 never-grant nodes (all explicitly denied, all correct) and a 12-row inheritance matrix (all nodes that *were* explicitly granted). Both passed. Neither could notice a node that was **missing entirely** — the tests only asked "are the things I listed correct", never "can the Owner actually operate the server".

**So the fix is two things, not one:**

* `laughtail.status` is now granted by name to `admin`.
* A new **operator sanity** check asserts that the `owner` group resolves **true** for the ten nodes required to run the server at all — status, reload, season, access grant and revoke, ban, history, unban, rules bypass, audit read. It was written before the fix was applied and correctly reported `laughtail.status owner=None FAIL   <-- the Owner cannot use this`, then passed after. A check that has only ever been seen passing has not been tested.

**One honest limitation of the analyser.** It reported the node as `None` (undefined) rather than `false`, because `effective()` treats only `* = true` as a grant and does not model `* = false` as a denial for undefined nodes. Both readings produce the correct verdict — unusable either way, and the sanity check fails on both — but the analyser's *explanation* is less precise than LuckPerms' actual behaviour. Worth knowing before trusting its wording on a future puzzle.


---

## D-0035 | 2026-08-26 | The DonutSMP-style feature set: built in-plugin, not assembled from plugins

The owner listed the feature set they want, in the technical terms used by servers that have it: chest-GUI menu, homes, auction house, bazaar/order book, TPA, leaderboards, RTP and an RTP queue, friends, a shard shop, pay, a stats GUI, multi-line nametags, and a Lunar Apollo client button.

### One item conflicts with a design law and needs a ruling

**"Shard Shop → custom currency shop" would be a SECOND currency.** The specification is explicit and repeated: one currency, because dual currencies hyperinflate, and it is listed among the structural failures LaughTail exists to fix. `README.md` states it as a headline: "One currency, dynamic prices in a bounded band."

A second currency is not a feature addition, it is a reversal of a founding decision. So it is **not** being built, and this is recorded rather than silently dropped.

**What can be built instead, which gets the same player experience without the currency:** a shop *section* gated on something other than money - rank tier (Section 10 already does exactly this, eight tiers), Champion status, or season achievement. That gives the "special shop with exclusive stock" feeling that a shard shop provides, while the only thing anyone earns and spends remains Berries. If the owner specifically wants a *second earned resource*, that is a real product decision and should be taken deliberately against Law 1 rather than as a side effect of copying a menu layout.

### Build in our plugin, do not install seven plugins

The obvious route is DeluxeMenus + EssentialsX + HuskHomes + AuctionHouse + PlaceholderAPI + LeaderHeads + a friends plugin + Vault. AGENTS.md's standing bias does prefer "the boring, well-supported plugin over the clever custom one", and that bias is right in general. Here it loses, for four specific reasons:

**1. A second source of truth for money would break the ledger.** Vault and EssentialsX economy keep their own balance store. D-0032 and V3 make `transactions` the source of truth and `balances` a cache, precisely so the Phase 3 arbitrage audit can see every movement. Bolting on Vault means two systems both believe they know a player's balance, and the audit can only see one of them. That is not a integration difficulty, it is a correctness failure.

**2. Acceptance row 40 cannot be satisfied by a generic shop.** "A Tier 1 player cannot buy a Tier 8 item by any means, including a modified client." That requires the purchase check to sit server-side inside the same system that knows the player's rank. A generic shop plugin gates on a permission node, which means the gate is only as good as whatever syncs that node - and a sync gap is a purchasable advantage.

**3. Memory.** `baselines.md` B3 records ~500 MB of host headroom with nobody online, and Q-41 already concludes this box cannot hold the specification's own 24-player heap alongside the Panel. Seven plugins is seven more class loaders, seven config surfaces and seven upgrade paths, on a box that is already the binding constraint. One plugin that does the job is cheaper in every direction.

**4. Never-break rule 9 costs multiply.** Every plugin needs a pinned version, a publisher checksum, and an aarch64 load proof, and every one of them can break on a Minecraft version bump - which this project has already lived through once this session, and which cost GrimAC entirely.

**The exceptions, where installing IS right:**

* **Multi-line nametags** need TAB or Apollo. Rendering text above a player's head in more than one line is a client-facing trick that is genuinely hard to reproduce and has no bearing on the ledger. Install it.
* **Lunar Apollo** is client integration by definition - a server cannot fake it. Worth doing, and worth noting it only benefits players on that client, so nothing may depend on it.
* **PlaceholderAPI** if and only if something else needs it. It is a dependency, not a feature.

### What the specification already covers, so is not new work

Most of the list is already specified, which is worth saying because it means these are not additions but the existing plan under different names:

| Owner's term | Already in the specification |
| --- | --- |
| Homes, `/sethome` | Section 15: up to 20, rename, home-to-home, slots bought with Berries |
| Auction | Section 8: auction house with listing slots (P9) |
| Quick Buy / Orders / Sell | Section 8: the order book with **atomic matching** |
| Teleport / TPA | Section 15: teleports with warmup, cooldown and combat guards |
| Leaderboards | Section 18: through a read-only database user |
| Stats window | Section 9.8: the full stat list, already in V2 |
| Pay | Built - `/pay` with the P10 tax |
| Shop | Section 10: eight rank-gated tiers |

**Genuinely new, and reasonable:** the chest-GUI menu as the front door to all of it, RTP with a queue, and friends. None conflicts with anything; all three are UI and convenience rather than economy, which is why they are safe to add.

### Order of work

The GUI is last, not first. A menu is a *view*, and building the view before the things it shows produces a menu full of buttons that do nothing - which looks like progress and is not. So: homes, then TPA and RTP, then the shop, then the order book and auction, then the GUI that fronts all of them, then nametags and Apollo.
