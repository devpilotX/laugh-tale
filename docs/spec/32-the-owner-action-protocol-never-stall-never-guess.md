## SECTION 32 - THE OWNER-ACTION PROTOCOL: NEVER STALL, NEVER GUESS

The owner's instruction, in his words: *"whatever he need, you just give me the step. Like you need to do this, you need to do this. And I do it and then continue."*

This section makes that a mechanism rather than a hope.

### 32.1 The rule

Some actions no agent can perform: creating an account, paying for something, accepting a licence, proving ownership of a domain, generating a credential, or deciding a price. When the agent reaches one of these it must stop cleanly and ask, in the fixed format below.

It must **never**:

* invent a credential, key, token, ID, or URL, or use a placeholder that looks real
* comment out, weaken, or skip an acceptance test because it lacks access to something
* proceed on an assumption and record it as a note to resolve later
* silently pick a default for a commercial, legal, or game-balance decision
* mark a task complete when its verification step could not be run

A blocked task is a normal, healthy outcome. A guessed task is a defect that will surface weeks later, and on this project it will surface in the economy or the ranking, where it is most expensive.

### 32.2 The blocked-state format

Append to `docs/owner-actions.md`, then stop the session:

```
BLOCKED - <short title>
What I need: one sentence.
Why: the section and acceptance row that depend on it.
Steps for the owner:
  1. <exact page, screen, or menu, named precisely>
  2. <exact field and value>
  3. <where to put the result>
What I will do when it arrives: one sentence.
What I am doing meanwhile: a named task that does not depend on it, or "nothing, waiting".
```

One blocked item per entry. Never batch two unrelated asks into one entry, because the owner will action the first and the second will be lost.

### 32.3 Front-load everything: the complete owner-action inventory

Every access and credential this project will ever ask for. Completing this list **before the first line of code** means the agent never blocks on access, only on decisions.

| # | What the owner provides | Why | Where |
| --- | --- | --- | --- |
| 1 | ~~Pelican **Application** API key~~ | **NOT REQUIRED.** Superseded by row 4 per Section 33.1. Do not request it | - |
| 2 | ~~Pelican **Client** API key~~ | **NOT REQUIRED.** Superseded by row 4 per Section 33.1. Do not request it | - |
| 3 | SFTP credentials for both servers | **Optional but recommended.** Not needed for access, since root SSH covers it, but SFTP sets file ownership correctly by default and avoids the trap in Section 33.1 | Panel, per server, Settings |
| 4 | **Root SSH access to the host** | **The primary and only required access path.** Covers everything rows 1 to 3 would have done, plus Wings config, firewall, node settings, and database dumps. Requires the snapshot and hook guardrails in Sections 33.2 and 33.6 | VPS provider console |
| 4a | A verified `pre-build` VPS snapshot | The only real rollback for host-level mistakes. **Mandatory before the first change** | VPS provider console |
| 5 | GitHub account and a repository named `laughtail-smp` | Source of truth and recovery path | github.com |
| 6 | GitHub deploy key or fine-grained token | Automated push from the build machine | GitHub, Settings, Developer settings |
| 7 | 2FA enabled on all five accounts above | Section 31.9 | Each provider |
| 8 | Domain and DNS access | Website, store, and map subdomains | Registrar |
| 9 | Website hosting, separate from the game VPS | Section 5 keeps the game box doing one job | Any static or small host |
| 10 | Store account with a product created and priced | Section 3 and Section 18 | Store provider |
| 11 | Payment method that settles in INR | The owner's players pay in INR | Store provider |
| 12 | Support and appeals email address | Section 14 and Section 31.13 | Any mail provider |
| 13 | Discord server, bot token, and channel IDs | Section 18 announcements and countdowns | Discord developer portal |
| 14 | UDP **24454** opened for voice chat | Section 13. A TCP port checker cannot verify this | VPS firewall and provider panel |
| 15 | Bedrock port **19132/UDP** opened, if Bedrock is in scope | Section 4 | Same |
| 16 | Offsite backup destination and credentials | Section 22. A backup on the same box is not a backup | Object storage provider |
| 17 | Uptime monitor account | Section 21 evidence | Any monitoring provider |
| 18 | Resource pack hosting URL, if a pack is used | Section 11 | Static host or CDN |
| 19 | Minecraft EULA acceptance | Required to boot at all | `eula.txt` on both servers |
| 20 | Whitelist seed list: the first players | Paid, whitelist-gated launch | `docs/private/` |
| 21 | Confirmation of the access price | Section 24 and Mojang's uniform-price rule | Owner decision |
| 22 | Licence choice for the public repository | Section 29.12 | `LICENSE` file |
| 23 | Decision: repository public or private at launch | Section 29.11 | GitHub settings |
| 24 | Cosmetics plugin licence decision | Section 29.12 flags a GPL interaction that affects whether the repo can be public | Owner decision |

### 32.4 The decisions only the owner can make

These cannot be delegated, but every one has a recommended default so **nothing ever waits on a decision**. The agent proceeds on the default, records it in `docs/decisions.md`, and flags it for confirmation at the next checkpoint.

| Decision | Recommended default | Section |
| --- | --- | --- |
| The five open questions | As written there | Section 24 |
| Access price | Owner's call; must be one uniform price | Section 3, Section 24 |
| Season end hour | 00:00 IST on the 1st | Section 31.1 |
| Combat-log flat penalty | 25 RP on top of the normal loss | Section 31.3 |
| Daily per-item sell cap | Set at 3x the modelled manual rate | Section 31.5 |
| New-player grace length | 30 minutes of playtime | Section 31.6 |
| Daily restart hour | 05:00 IST | Section 31.8 |
| Repository visibility | Private until launch, then decide | Section 29.11 |

### 32.5 Never lose context

This extends Section 27. The owner's requirement is absolute: no context is lost between sessions.

* `docs/owner-actions.md` becomes a **sixth living document**, alongside the five in Section 27.5. It is append-only and nothing is ever deleted from it, only marked resolved with a date.
* **Write the handoff before running low on context, not after.** An agent that notices it is near its limit has already lost the ability to write a good summary. Write the six-point handoff from Section 27.6 at the end of every task, not every session.
* **Every session begins by reading `docs/progress.md`, `docs/decisions.md`, and `docs/owner-actions.md` in that order**, before touching any code.
* **Every session ends with three things committed:** the code, the updated living documents, and `scripts/drift.sh` output showing zero drift.
* If a session ends unexpectedly, the next session's first job is to reconcile the repository against dev and write down what it found, before doing anything new.
* Never rely on a previous session's writes having survived. **Verify state before editing it.** File byte counts and section heading lists are cheap to check and this document's own history proves the check is necessary.

### 32.6 Model and effort policy

The owner has chosen Opus 5 at maximum effort, and that choice is honoured. Two notes that cost nothing and protect quality:

* Section 28.8 identifies the areas where maximum effort genuinely earns its cost: the rating mathematics, the season reset job, the economy model, the permission split, the migration procedure, and the acceptance harness. Those are the frontier problems in this build.
* For mechanical work such as generating configuration, writing repetitive tests, or formatting documentation, maximum effort adds cost without adding quality and can produce overthought output on structured tasks. Dropping to default effort on that work is not a compromise on quality; it is avoiding a known failure mode.
* This is guidance, not a constraint. If the owner wants maximum effort everywhere, that is a legitimate choice and the build proceeds exactly as specified.

### 32.7 Acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 32-1 | `docs/owner-actions.md` exists, is append-only, and every entry uses the fixed format | File review |
| 32-2 | No acceptance test is skipped, weakened, or commented out for lack of access | Diff review across the whole build |
| 32-3 | No fabricated credential, token, ID, or URL appears anywhere in the repository | Secret scan plus grep for placeholder patterns |
| 32-4 | Every item in the Section 32.3 inventory is either provided or has an open blocked entry | Checklist against the table |
| 32-5 | Every default taken under Section 32.4 is recorded in `docs/decisions.md` with a date | File review |
| 32-6 | Every session ends with code, living documents, and zero-drift output all committed | Git log |

---

