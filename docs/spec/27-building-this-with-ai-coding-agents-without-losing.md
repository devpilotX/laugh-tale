## SECTION 27 - BUILDING THIS WITH AI CODING AGENTS WITHOUT LOSING CONTEXT

This document will be built largely by AI coding agents. That is a reasonable plan, and this section exists because the owner asked the right question: how do you build something this large with agents **without any single requirement quietly disappearing**?

Section 28 is the day-to-day operating procedure. This section is the architecture that makes that procedure work.

### 27.1 The honest framing, before anything else

There is a widespread belief that a sufficiently good agent configuration - the right collection of agents, skills, hooks, and memory files - makes an agent "never miss context." That belief is wrong, and building on it is dangerous for a project of this size.

The measured reality is the opposite. As the number of tokens in a context window grows, a model's ability to accurately recall any specific item **within** that context **decreases**. This is well documented and is usually called context rot. More context is not more reliability. Past a certain point it is measurably less. Loading this entire 180-kilobyte document into every session does not protect requirement 43 of 210 - it actively buries it.

So no configuration file, repository, or framework can promise that nothing is missed. What can promise it is much less glamorous, and this project already has all three parts:

| Guarantee | Where it lives | What it does |
|---|---|---|
| **A written specification** | This document, split per Section 27.3 | Survives every session ending, every crash, every model change. Text on disk does not forget. |
| **A requirement traceability matrix** | Appendix F | Maps each requirement to the section that implements it, so "did we do all of them" is a checkable question rather than a feeling. |
| **Evidence-backed acceptance criteria** | Section 21, plus per-section criteria throughout | 82 rows, each demanding a specific evidence type. An agent cannot pass a row by believing it works. |

That is the answer to "I do not want to miss anything." Not a better prompt. A specification, a matrix, and tests with evidence.

### 27.2 Reference material worth reading

Read these for patterns. Do not install any of them wholesale - see Section 28.1 for why, and for the security caution about cloning agent configuration.

| Resource | What it is | Why it is relevant here |
|---|---|---|
| `affaan-m/ECC` (published originally as `everything-claude-code`) | The full agent-harness configuration set open-sourced by the winner of the Anthropic and Forum Ventures hackathon, September 2025. MIT licensed. Roughly 38 agents, 156 skills, and over 1,200 security tests. | The best single example of what a mature agent harness looks like. Read the hook and sub-agent patterns. |
| `humanlayer/advanced-context-engineering-for-coding-agents`, file `ace-fca.md` | A focused write-up on getting agents to work in large, complex, established codebases. | **The most on-point read for this project's actual risk.** Large specifications and large codebases are where agents fail, and this addresses exactly that. |
| Anthropic, "Effective context engineering for AI agents" | The engineering rationale: context rot, compaction, structured note-taking, sub-agent architectures returning compact summaries. | The source of the "smallest set of high-signal tokens" principle that Sections 27.3 and 27.4 apply. |
| Claude Code documentation, features overview | Instruction-file guidance, scoped rules, sub-agents with isolated context, hooks. | Contains the single most important operational sentence: a written instruction is a request, whereas a hook is a guarantee. |
| `hesreallyhim/awesome-claude-code` | A large curated index of skills, hooks, commands, and orchestrators. | Use as a catalogue when a specific need arises. Do not adopt it as a starting point. |

### 27.3 Split this document before building - the 180-kilobyte problem

This document is the authoritative specification, and it is far too large to load into a working session. Split it once, in the first session, keeping the section numbering intact so that every cross-reference in this document still resolves.

```
docs/
  spec/
    MASTER.md              <- this document, unmodified, authoritative
    INDEX.md               <- one line per file: number, title, what it covers
    00-how-to-use.md
    01-product.md
    02-design-laws.md
    03-legal-commercial.md
    04-platform-versions.md
    05-infrastructure-portability.md
    06-performance.md
    07-world-gameplay.md
    08-economy.md
    09-rank-seasons.md
    10-shop.md
    11-cosmetics.md
    12-war-events.md
    13-voice.md
    14-rules-enforcement.md
    15-homes-teleports.md
    16-settings-menu.md
    17-permissions.md
    18-web-store.md
    19-commands.md
    20-build-phases.md
    21-acceptance.md
    22-migration.md
    23-defaults.md
    24-open-questions.md
    25-scope-discipline.md
    26-roadmap.md
    27-agent-build.md
    28-build-procedure.md
    appendix-a-plugins.md
    appendix-b-ranking-maths.md
    appendix-c-config-files.md
    appendix-d-database.md
    appendix-e-scripts.md
    appendix-f-traceability.md
    appendix-g-additions.md
```

Rules for the split:

* **`MASTER.md` remains authoritative.** If a split file and `MASTER.md` ever disagree, `MASTER.md` wins and the split file is regenerated. Never edit a split file and assume the master followed.
* Load only the two or three files a task actually needs. Implementing the shop means `10-shop.md`, `09-rank-seasons.md`, and `08-economy.md` - not the whole specification.
* `INDEX.md` exists so an agent can find the right file without reading all of them.

### 27.4 The root instruction file

One file at the repository root, read by the agent on every session start. Name it `AGENTS.md`; most CLIs now read that filename natively, and where yours reads a different name, point that file at this one rather than duplicating the content.

**Keep it under 200 lines.** Every line in it is a permanent tax on attention, paid on every single request for the life of the project. It is not a place to be thorough. It contains only what is true for every task:

1. What this project is, in two sentences.
2. Where the specification lives, and the instruction to read `docs/spec/INDEX.md` and load only what is needed.
3. The five hard rules, verbatim (below).
4. How to run, build, and test the stack - the exact commands.
5. Where the living documents are, and the requirement to update them.
6. The stop conditions from Section 28.7.
7. Nothing else.

**The five hard rules, to be quoted verbatim in the instruction file:**

1. **Access is the only thing ever sold.** No feature, cosmetic, currency, slot, or convenience may be purchasable, ever.
2. **No paying player may have any capability another paying player lacks.** Staff tooling is the only exception.
3. **No gambling and no wagering.** Never build a stake-holding mechanism of any kind. See 3.5 and 3.5.1.
4. **Never disable online mode.** Not for testing, not temporarily, not with a flag.
5. **Never claim a performance result without a measurement.** Numbers come from the profiler, not from reasoning.

Anything more specific than these belongs in a scoped rule file that loads only for the relevant paths, or in the specification section itself.

### 27.5 The five living documents

These are the project's memory. They are plain Markdown, they are committed, and they survive every session ending, model change, and crash. An agent that does not update them has not finished its task.

| File | Contents | Written when |
|---|---|---|
| `docs/progress.md` | The current state: what is done, what is in progress, what is next. Newest entry at the top. | Every session, at the end. Mandatory. |
| `docs/decisions.md` | Every decision that deviated from the specification or resolved an ambiguity, with the reasoning and the date. | Whenever a judgement call is made. |
| `docs/rejected.md` | Everything deliberately **not** built, and why. | Whenever an idea is refused. |
| `docs/acceptance.md` | Each acceptance row, its status, and the actual evidence. | As rows are tested. |
| `docs/questions.md` | Open questions the specification does not answer. | Whenever the agent would otherwise have to guess. |

> **`rejected.md` is the one most people skip, and on this project it matters most.** This design contains a long list of deliberate refusals: no donor tiers, no wagering escrow, no paid crates, no plain player teleport command, no anti-lag plugins, no top-N season rewards. A future agent with no memory of the conversations that produced those refusals will look at the codebase, see an obvious gap, and helpfully fill it. It will re-add donor ranks because "servers usually have them." `rejected.md` is the only thing standing between this project and the slow reintroduction of everything that was deliberately removed. Every entry needs the reason, not just the decision - a refusal without a reason gets overturned by the next confident argument.

### 27.6 The session handoff protocol

An agent must write a handoff into `docs/progress.md` before its session ends, and before any context compaction. Six points, always:

1. **What I did.** Files changed and why.
2. **What works, with evidence.** The acceptance rows that now pass, and the evidence for each.
3. **What is half-finished.** Precisely where it stopped, and what state the code is in.
4. **What I decided.** Anything logged to `decisions.md` or `rejected.md` this session.
5. **What I could not answer.** Anything added to `questions.md`.
6. **What the next session should do first.** One concrete instruction.

This takes two minutes and it is the difference between a project that survives forty sessions and one that quietly forgets something in session twelve. A handoff written before compaction is worth more than any amount of work completed after it.

### 27.7 Dividing the work into sub-agents

Sub-agents matter here for one specific reason: each gets its own fresh context window, so a sub-agent reading five plugin configuration files does not consume the main session's budget - it returns a short summary instead. Divide along this document's natural seams, so each role loads a small, coherent slice of the specification.

| Role | Owns | Loads |
|---|---|---|
| **Infrastructure** | Container stack, backups, the portability contract, migration | Sections 5 and 22 |
| **Economy** | Currency, value model, shop, auction house, sinks, arbitrage guard | Sections 8 and 10 |
| **Combat and seasons** | Rating maths, ranks, resets, war events, the finale | Sections 9 and 12, Appendix B |
| **Player systems** | Homes, teleports, claims, quality of life, the settings menu | Sections 7, 15, and 16 |
| **Trust and safety** | Rules, enforcement, anti-cheat, the wagering detector, permissions | Sections 3.5, 3.5.1, 14, and 17 |
| **Presentation** | Cosmetics, voice chat, website, store, scoreboard, chat formatting | Sections 11, 13, and 18 |
| **Verification** | Running acceptance rows and reporting results | Sections 6 and 21 |

> **Keep Verification separate, and keep it adversarial.** Its instruction is: you did not write this code; attempt to prove these acceptance rows fail. It reports failures and does not fix them. An agent that both implements a feature and certifies it will certify it - not from dishonesty, but because it is re-evaluating its own reasoning rather than examining the artefact. The verification role must have no stake in the answer.

### 27.8 Six rules the agent must never break

1. **The specification is the source of truth.** Not the code, not the previous session's summary, not the agent's recollection.
2. **Never edit the specification to match the code.** If the specification is wrong, the owner changes it deliberately and the change is logged. An agent that edits the specification to match what it built has destroyed the only record of what was wanted.
3. **Never mark an acceptance row passed without the evidence that row demands.** "It should work" is not evidence. A number, a log line, or command output is.
4. **Never let an open question be compacted away.** It goes into `questions.md` the moment it appears.
5. **Write the handoff before context runs low,** not after the warning.
6. **Re-read the relevant specification file before implementing,** even if it was read earlier in the same session. Especially if it was read earlier in the same session - that is exactly when recall has degraded and the agent is working from its own summary instead of the document.

### 27.9 Acceptance criteria for this section

| # | Criterion | Evidence |
|---|---|---|
| 27-1 | The specification is split per 27.3 with numbering preserved, and `INDEX.md` exists | Directory listing plus the index |
| 27-2 | `MASTER.md` is present, unmodified, and marked authoritative | File hash compared against the delivered document |
| 27-3 | The root instruction file exists and is under 200 lines | Line count |
| 27-4 | The instruction file contains the five hard rules verbatim | Diff against 27.4 |
| 27-5 | All five living documents exist and are committed | Directory listing |
| 27-6 | Every completed session has a six-point handoff entry | Review of `progress.md` |
| 27-7 | `rejected.md` contains, at minimum: donor tiers, wagering escrow, paid crates, plain player teleport, anti-lag plugins, top-N season rewards - each with its reason | Review of `rejected.md` |
| 27-8 | Every requirement in Appendix F maps to an implementing section and an acceptance row | Completed matrix |
| 27-9 | The Verification role has produced at least one report of a failing row it did not then fix | The report |

> **The single most important sentence in this section:** the specification, the traceability matrix, and the evidence-backed acceptance rows are what guarantee nothing is missed - not the size of the context window, and not the sophistication of the harness.
---

