# LaughTail SMP - Agent Operating Instructions

This file is read automatically at the start of every session. It is short on purpose. It tells you where the truth lives and what you must never do. It is not the specification.

## 1. What this project is

A paid, whitelist-only Minecraft Java SMP server called **LaughTail SMP**. Currency is **Berries**. Rank is earned by PvP only. Seasons are monthly with exactly one Champion. Total equality between players: no donor tiers, no pay-to-win, no gambling, no cheating.

The owner is not a programmer. Explain decisions in plain language. Never assume they will notice a silent failure.

## 2. The specification is the source of truth

The full specification lives in `docs/spec/`. Start at `docs/spec/INDEX.md`, which maps every section to a file.

**Load only the sections you need for the current task.** Do not read the whole specification into context. It is very large, and recall degrades as context fills. The index exists so you can be selective.

If this file and the specification disagree, **the specification wins** - except for the never-break rules in section 5 below, which always win.

## 3. Read these three files before touching anything

In this order, every session, without exception:

1. `docs/progress.md` - what is done, what is in flight, what is next
2. `docs/decisions.md` - decisions already made, with reasons. Never silently reverse one
3. `docs/owner-actions.md` - what is blocked waiting on the owner

If `docs/progress.md` says a task was in flight, verify the actual state of the code and the server before continuing. Do not trust the note alone.

## 4. The environment

| Fact | Value |
| --- | --- |
| Build location | **Directly on the VPS.** There is no local build stage |
| Panel | Pelican, already installed and running |
| Access | **Root SSH to the host.** No Pelican API keys are in use |
| Dev server | `laughtail-dev` - all build work happens here |
| Production server | `laughtail` - players only. Created empty, stays stopped until launch |
| Box | 2 vCPU, 4 GB RAM. This is small. Every decision must respect it |
| Concurrency | **The two servers must never run at the same time.** Combined allocation exceeds the box |

Kiro runs on the owner's PC, not on the VPS. Do not install agent tooling on the game box; it competes for CPU with the server you are measuring.

### The ownership trap

Pelican server files live in `/var/lib/pelican/volumes/<server-uuid>/`. Files created there by root will have the wrong owner and the container may fail to read or write them, **silently**.

After any direct file operation in a volume, fix ownership to match the other files already in that directory, then verify from the Panel file manager or the server console that the file is readable. Prefer SFTP on port 2022 for routine file work, because it gets ownership right automatically.

## 5. Never-break rules

These are absolute. If a rule blocks the task, stop and write to `docs/owner-actions.md`.

1. **Never touch the production server** until the change has passed acceptance on `laughtail-dev`.
2. **Never run both Paper servers at once.** Stop one before starting the other.
3. **Never reset or delete the main world.** Only the resource world resets, monthly.
4. **Never set `-Xmx` equal to the container allocation.** Leave at least 25 per cent or 768 MB outside the heap. Equal values freeze the server rather than crashing it, which is harder to diagnose.
5. **Never commit a secret.** No `.env`, no Panel `APP_KEY`, no database password, no API key, no token. `.gitignore` must be correct before the first commit.
6. **Never regenerate the Panel `APP_KEY`.** Encrypted panel data becomes permanently unrecoverable, even with database backups.
7. **Never run `/reload`.** Use `/laughtail reload`.
8. **Never `rm -rf` outside the repository and the dev server volume.** State the full path and wait for confirmation on anything irreversible.
9. **Never install a plugin that is not in the manifest** with a pinned version and a checksum.
10. **Never publish detector thresholds** for anti-cheat, wagering, or market manipulation. Publishing them teaches evasion.
11. **Never mark a task complete without evidence.** A log line, a command output, a screenshot, or a passing test. Intent is not evidence.
12. **Never guess an owner decision.** Write it to `docs/owner-actions.md` and move to other work.
13. **Never upgrade host OS packages or Docker mid-build** without a fresh VPS snapshot first.
14. **Never leave the server in a broken state at the end of a session.** If out of time, revert to the last known-good state and record it.

These are rules, not preferences. Where the tooling can enforce one with a hook, add the hook - prose is a request, a hook is a guarantee.

## 6. The build loop

For every task:

1. Read the relevant specification section from `docs/spec/`.
2. State the acceptance criteria you are targeting, by number.
3. Implement.
4. Test on `laughtail-dev`.
5. Capture the evidence.
6. Update `docs/progress.md` and `docs/acceptance.md`.
7. Commit with a message naming the specification section.
8. Move on.

One task per commit. Small commits. A commit that touches six unrelated things cannot be reverted safely.

## 7. When to stop and ask

Stop, write to `docs/owner-actions.md`, and tell the owner in plain language when:

* You need a credential, an account, a domain, a port opened, or a payment.
* A decision is the owner's to make - price, policy, naming, anything player-facing.
* The same acceptance test fails twice in the same way. Do not keep guessing.
* You are about to do something irreversible.
* The specification is ambiguous or two sections contradict each other. Record the contradiction; do not pick silently.

**Do not stall silently and do not guess.** Use the fixed format in specification section 32.2, one item per entry, so the owner can act on it without asking follow-up questions. Then continue with unblocked work rather than waiting.

## 8. Where things are written

| File | Purpose |
| --- | --- |
| `docs/progress.md` | Running state. Updated every session |
| `docs/decisions.md` | Decisions and their reasons. Append-only |
| `docs/rejected.md` | Ideas considered and rejected, with why. Prevents re-litigation |
| `docs/owner-actions.md` | Blocked items for the owner. Append-only |
| `docs/questions.md` | Open questions that are not blocking |
| `docs/acceptance.md` | Every acceptance criterion and its evidence |
| `docs/private/` | Never committed. Secrets and thresholds live here |

## 9. Context discipline

Context is a budget, not a container. Recall degrades as it fills.

* Load specification sections on demand, never wholesale.
* Before running low on context, write a handoff into `docs/progress.md`: what you did, what you verified, what is next, and anything surprising.
* End every session with code, documents, and evidence all committed. Never end mid-edit.
* If you resume and the notes disagree with reality, trust reality and correct the notes.

## 10. Standing bias

When two options are open and the specification does not decide:

* Prefer the boring, well-supported plugin over the clever custom one.
* Prefer fewer features working perfectly over more features working sometimes. Consistency beats features.
* Prefer the option that is easier to migrate to a bigger VPS later.
* Prefer the option that fits in 2 vCPU and 4 GB today.
* Prefer reversible over irreversible.

When genuinely unsure, ask. One clear question costs less than one wrong build.
