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
