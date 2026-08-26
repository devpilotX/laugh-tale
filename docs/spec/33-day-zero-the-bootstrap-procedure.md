## SECTION 33 - DAY ZERO: THE BOOTSTRAP PROCEDURE

This section is the answer to a single question: **the specification exists, so what do I actually type first?** It supersedes nothing in the design; it is purely the starting procedure.

### 33.1 The access decision: root SSH instead of Pelican API keys

**The owner has chosen to give the agent root SSH access to the host, and to create no Pelican API keys. This is accepted.** Root SSH is a strict superset of what both API keys could do, so nothing in this document becomes impossible. Sections 29.13 and rows 1 to 3 of the inventory in 32.3 are **superseded** for this reason: the two keys are no longer required, and the agent should not ask for them.

What is gained: no key management, no scope gaps, no stalling on a missing permission. The agent can restart Wings, read logs, run database dumps, inspect Docker, and edit any file. This is what the owner wanted and it removes an entire class of blockage.

What is lost must be stated honestly, because it is real:

| With scoped API keys | With root SSH |
| --- | --- |
| The blast radius is bounded by the key's scope | **The blast radius is the entire machine** |
| A leaked key can be revoked and re-issued | A mistake can destroy the Panel, Wings, Docker, and both servers |
| The Panel records who did what through the API | Host-level actions leave only shell history |
| Deleting a server requires the Application key | `rm -rf` on a volume needs nothing |

The mitigation is **not** a smaller credential. The mitigation is a snapshot plus enforced guardrails, which is 33.2 and 33.6. Do not skip either because the access is convenient.

One further consequence, which will bite silently if it is not respected: **Pelican server files are owned by the container user, not root.** They live in `/var/lib/pelican/volumes/<server-uuid>/`. A file written there over SSH as root can be unreadable or unwritable by the server, and Paper will fail in a way that looks like a plugin bug. After any direct file operation in a volume, match ownership to the surrounding files and verify from the Panel file manager or the server console. For routine file work, prefer SFTP on port 2022, which gets ownership right without being told.

### 33.2 Before anything else: take a VPS snapshot

**This is the single most important step on Day Zero, and it is the real answer to not firing in the air.**

GitHub protects the code. Pelican backups protect one server's files. **Neither protects the machine.** If the agent breaks the Panel, corrupts Docker, or misconfigures the firewall and locks SSH out, the only fast recovery is a host snapshot.

1. Take a full VPS snapshot from the hosting provider's control panel. Name it with the date and the word `pre-build`.
2. Confirm the provider shows it as complete, not pending.
3. Know where the restore button is **before** you need it. Find it now.
4. Take a fresh snapshot before each of these: installing or upgrading anything at host level, changing firewall rules, the first production deploy, and any migration.

Snapshots are cheap. A rebuilt Panel is not. If the provider charges for snapshots, this is the best money in the entire project.

### 33.3 The repository skeleton

Do this once, in this order. **The `.gitignore` must exist and be correct before the first commit**, because a secret committed once lives in history forever even after deletion.

1. Create the project directory on the owner's PC, where Kiro runs. Not on the VPS.
2. Write `.gitignore` first. At minimum it must exclude:

```
.env
*.env
docs/private/
*.key
*.pem
id_rsa*
*.sql
*.jar
backups/
logs/
world*/
*.log
```

3. `git init`, then commit **only** `.gitignore` as the first commit. Now the guard exists before anything else can be added.
4. Create the tree:

```
AGENTS.md
README.md
LICENSE
.gitignore
docs/
  spec/
    MASTER.md
    INDEX.md
  progress.md
  decisions.md
  rejected.md
  owner-actions.md
  questions.md
  acceptance.md
  private/          (git-ignored)
server/
scripts/
db/migrations/
```

5. Place the master specification file at `docs/spec/MASTER.md`.
6. Place `AGENTS.md` in the repository root. It is separate from the specification and much shorter, and it is read automatically at the start of every session.
7. Create the six living documents as empty files with a heading each, so the agent has somewhere to write from the first minute.
8. Commit. This is the baseline.

### 33.4 What not to do with the specification file

**Do not paste the specification into a chat message.** It is close to three hundred thousand characters. Pasting it consumes an enormous share of the context window before any work begins, and recall of any individual detail gets measurably worse as the window fills. The result is the exact failure the owner is trying to avoid: an agent that has been shown everything and remembers the wrong parts.

The specification belongs **on disk**, split, and indexed. Task zero for the agent is therefore:

1. Read `docs/spec/MASTER.md`.
2. Split it into one file per section: `00-...md` through `33-...md`, plus one per appendix.
3. Generate `docs/spec/INDEX.md` mapping every section and subsection number to its file, with a one-line summary of each.
4. Verify the split is lossless: total line count of the parts equals the master, and every `##` heading appears exactly once.
5. Commit.

After that, `MASTER.md` is the archive and `INDEX.md` is the working entry point. Sections get loaded on demand, which is what Section 27 asked for and what keeps recall sharp across a long build.

### 33.5 The first session must produce a plan, not code

This is the verification gate the owner asked for. The first instruction is deliberately narrow:

> Read `AGENTS.md`. Then read `docs/spec/MASTER.md` and split it as described in section 33.4. Then produce, in `docs/progress.md`, a proposed build order: every phase, what it delivers, which specification sections it implements, which acceptance criteria it satisfies, and what it depends on. List separately everything you need from me and everything in the specification you found ambiguous or contradictory. **Write no server code and change no server configuration in this session.** Stop when the plan is written and wait for my approval.

What comes back is the real test of readiness. Judge it on four things:

| Check | What good looks like |
| --- | --- |
| Order | Foundations before features. Database and economy ledger before shops. Never cosmetics first |
| Traceability | Every phase cites section numbers and acceptance criteria, not vague intentions |
| Honesty | It reports contradictions and ambiguities it found. A plan with zero questions about a document this size has not been read properly |
| Owner items | The blocked list is specific and actionable, not a vague request for access |

If the plan is thin, vague, or silent about gaps, **do not approve it.** Ask for a rewrite. This is the cheapest correction available; every later one costs real work.

Only after approval does the first build task begin - and the first build task should be small and verifiable, such as bringing up `laughtail-dev` from the repository and proving `scripts/drift.sh` reports zero drift.

### 33.6 Pre-flight checklist

Every line must be true before the first build task starts. This is fifteen minutes of work that prevents most of the ways this goes wrong.

| # | Check |
| --- | --- |
| 1 | A `pre-build` VPS snapshot exists and shows complete |
| 2 | The restore procedure for that snapshot has been located |
| 3 | SSH works with a key, and password authentication is disabled |
| 4 | Two-factor authentication is enabled on the Panel, GitHub, the registrar, the host account, and the email behind all of them |
| 5 | `.gitignore` is committed and is the first commit in history |
| 6 | `AGENTS.md` is in the repository root |
| 7 | The specification is at `docs/spec/MASTER.md` and committed |
| 8 | The six living documents exist |
| 9 | `laughtail-dev` exists in the Panel, with its own allocation, and starts and stops cleanly |
| 10 | `laughtail-dev` heap is at least 25 per cent below its allocation |
| 11 | The existing stock server is **stopped**, and not yet deleted |
| 12 | The eight decisions in 32.4 are either confirmed or explicitly left at their defaults |
| 13 | A destructive-command guard exists as a hook, not merely as a sentence in `AGENTS.md` |
| 14 | The owner knows how to read the Panel console and where the log files are |
| 15 | The first session's output was a plan, and the owner has read and approved it |

On item 13: enforcement matters more than instruction. A rule written in prose is a request; a hook that refuses the command is a guarantee. At minimum, block `rm -rf` outside the repository and the dev volume, block anything touching `.env` or the Panel `APP_KEY`, and block destructive git operations on shared history. Normalise quotes before matching, because a naively written guard is trivially bypassed by quoting inside the command.

### 33.7 Day Zero acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 33-1 | A verified `pre-build` VPS snapshot exists before any change is made | Provider console entry with timestamp |
| 33-2 | The first commit in repository history contains `.gitignore` and nothing that must stay secret | `git log` of the first commit |
| 33-3 | `AGENTS.md` is in the root, is under 200 lines, and is loaded at session start | File plus a session transcript showing it was read |
| 33-4 | The specification is split losslessly, and `INDEX.md` maps every section | Line-count comparison and a heading-uniqueness check |
| 33-5 | The first session produced a build plan and changed no server state | `docs/progress.md` plus a clean `scripts/drift.sh` run |
| 33-6 | The owner explicitly approved the build order before the first build task | Recorded approval in `docs/decisions.md` |
| 33-7 | A destructive-command guard is active as a hook and has been tested by attempting a blocked command | Hook config plus the refusal output |
| 33-8 | Every item in the 33.6 checklist is ticked | Completed checklist committed |
| 33-9 | The stock server is stopped but not deleted until the production server passes acceptance | Panel state |

---

