## SECTION 28 - THE BUILD PROCEDURE: RUNNING THIS PROJECT WITH AN AGENTIC CLI

Section 27 explains how to stop context being lost. This section is the operating procedure: what to do, in what order, from the moment you decide to start building. It assumes one owner working with one agentic CLI - Kiro CLI, Claude Code, Cursor CLI, or Codex; the procedure is the same for all of them - driving a model at high reasoning effort, with shell access to the host.

Read this section before writing a single line of code.

### 28.1 What this project does not need

There is a large ecosystem of agent configuration repositories, skill collections, agent marketplaces, orchestrators, and memory plugins. Very little of it applies here, and installing it wholesale will make the build worse rather than better.

| Thing | Verdict | Reason |
|---|---|---|
| A large agent-config repository (dozens of agents, hundreds of skills) | Read it, do not install it | Every loaded skill, rule, and tool description competes for the same attention budget as the specification. A general-purpose harness tuned for web application work adds noise to a Minecraft server build. |
| An orchestrator or multi-agent framework | Not needed | Section 27.7 already divides the work along the document's natural seams. A framework adds moving parts without adding coverage. |
| A memory or knowledge-graph plugin | Not needed | The living documents in Section 27.5 are the memory, they are plain files, they survive every crash, and you can read them yourself. |
| A vector database of the specification | Not needed | The specification is already split by section number with an index. Retrieval by filename is more precise than retrieval by embedding for a document with numbered requirements. |
| Additional MCP servers | Only if a specific task needs one | Each connected server adds tool descriptions to every request. Add one when a task requires it, then remove it. |

The reason this project needs less tooling than most is that the rarest and most valuable artefact already exists. Agent configuration repositories mostly exist to compensate for the absence of a specification. This project has a specification, a requirement traceability matrix (Appendix F), and 82 acceptance criteria with defined evidence types (Section 21). That is the part almost nobody has.

There are, however, three patterns worth taking from the better agent-configuration repositories, all of which are already reflected in this document:

1. Guardrails enforced by code rather than by prose. An instruction in a Markdown file is a request. A hook that refuses to run a command is a guarantee. This is Section 28.4 below.
2. A verification role that is separate from and adversarial to the implementation role. This is Section 27.7.
3. A small root instruction file with narrowly scoped rules loaded on demand. This is Section 27.4.

**A security note on cloning agent configuration.** A cloned repository can place configuration in exactly the directories your CLI reads on startup, including hook definitions that execute shell commands. On a host where the agent has broad privileges, treat any third-party agent configuration the same way you would treat a plugin JAR from an unknown author: read it before it runs, and never accept a trust prompt for a repository you have not opened.

### 28.2 The three things this project needs that do not exist yet

None of these is a product, and all three take under an hour.

1. **Version control.** An agent with shell access and no version control is one mistyped command away from losing weeks of work. With version control, every mistake becomes a one-line recovery. This is the single highest-value item in this entire section.
2. **A command deny list.** See 28.4.
3. **A non-root user for the agent to work as.** See 28.3, item 5.

### 28.3 Step 0 - one hour of setup, done by the owner, before the agent runs at all

Do these in order. Do not skip any of them, and do not delegate them to the agent, because they are the controls that limit what the agent can damage.

1. **Create the repository and make the first commit.** A private remote. Push it. Confirm you can clone it to a second location. Until this is true, nothing else in this document is safe to start.
2. **Write the ignore file before the first commit, not after.** At minimum: the environment file, the world directories, logs, plugin data directories, JAR files, backups, and database dumps. Secrets that enter version-control history are difficult to remove and must be treated as compromised. Getting this file right on the first commit avoids the problem entirely.
3. **Place the specification.** Put this document at `docs/spec/MASTER.md` and commit it. It is now the authoritative source described in Section 27.3.
4. **Take a host snapshot.** Every VPS provider offers one. Take it now, before the agent has ever run. If the first session goes badly, you restore in minutes instead of rebuilding.
5. **Create a dedicated non-root user and give the agent that account.** Building a containerised Minecraft server does not require root. The agent needs to write in the project directory, run the container tooling, and read logs. Granting root buys nothing and converts a recoverable mistake into an unrecoverable one. This one change removes most of the catastrophic outcomes.
6. **Write the root instruction file.** Follow Section 27.4: under 200 lines, the five hard rules, the pointer to the specification index. Name it `AGENTS.md`, which the majority of CLIs now read natively. If your CLI reads a different filename, create that file containing a single line pointing at `AGENTS.md` rather than a second copy of the content. Two copies of the rules will drift apart, and the day they disagree the agent will follow the wrong one.
7. **Create the five living documents** from Section 27.5, empty but present, and commit them.

### 28.4 Step 1 - the command deny list

This matters more for this project than any repository you could clone, because the agent has shell access to the machine that will eventually hold player balances and world data.

Every major CLI supports a pre-execution hook that inspects a command and refuses it. Block these outright:

| Pattern | Reason |
|---|---|
| Recursive force deletion | The single most common catastrophic command. |
| Hard reset, checkout of all files, clean with force | Silently destroys uncommitted work, which on an agent-driven project is most of the current session. |
| Force push | Destroys remote history, including the recovery point. |
| `DROP TABLE`, `DROP DATABASE`, `TRUNCATE` | The economy database is the one file in this project that cannot be regenerated. |
| Any write, move, or delete touching a live world directory | Section 22 already forbids copying a running world. This makes the rule enforceable rather than advisory. |
| Permission changes granting world-write | Turns a private key into a public one. |
| Piping a downloaded script directly into a shell | Executes unreviewed remote code with the agent's privileges. |
| Container system prune | Removes volumes, which on this stack means the database. |
| Redirecting output onto the environment file | Overwrites every secret with one line. |

Require confirmation, rather than blocking, for: restarting or stopping the server, running the migration script, editing the environment file, and any command that reaches the internet other than dependency downloads from known sources.

Two implementation details that decide whether the list actually works:

* **Normalise before matching.** Shell quoting can hide a command from a naive pattern match while executing identically. Strip quotes and collapse whitespace into a canonical form before comparing.
* **Fail closed.** If the hook errors, it must deny. A guard that silently permits everything when it crashes is worse than no guard, because you will believe you are protected.

**Do not run a fully autonomous, permission-skipping mode against the production host.** Use it, if at all, on a throwaway container. The combination of unattended execution, broad privileges, and a live host is the specific configuration in which a single bad decision becomes unrecoverable.

### 28.5 Step 2 - session one is calibration, not construction

The first session writes no game code. Its tasks:

1. Split `docs/spec/MASTER.md` into the numbered files described in Section 27.3 and build the index.
2. Create the five living documents with their initial content.
3. Read Appendix F and report any requirement it cannot map to a specification section.
4. Report any contradiction found between sections.

This session does three useful things at once. It forces one complete read of the specification. It produces the split that every later session depends on. And it shows you whether this agent, on this model, at this effort level, follows written instructions - while it is still working on Markdown files and cannot break anything.

Review the output yourself. If the split is sloppy or the contradiction report is empty when you know contradictions exist, fix the instruction file before continuing. Then commit.

### 28.6 Step 3 - the per-session loop, one phase at a time

Work through the phases in Section 20 in order. For each phase:

1. **Start a new session.** Not a continuation.
2. **Load the minimum.** The instruction file, `docs/progress.md`, and only the two or three specification files this phase touches. Do not paste the whole document. Loading 190 kilobytes of specification to implement one configuration file measurably reduces the model's ability to recall the part that matters.
3. **State the boundary explicitly.** Name the phase, name its exit gate from Section 20, and state that the next phase is out of scope for this session. An agent that drifts into the next phase produces work that was never gated.
4. **Let it implement.**
5. **Require evidence.** The agent runs the acceptance rows from Section 21 that belong to this phase and writes the results into `docs/acceptance.md` with the evidence type that row demands: the actual number, the actual log line, the actual command output. A row is not passed because the agent believes it works.
6. **Take the handoff.** The agent writes the six-point handoff from Section 27.6 into `docs/progress.md` before stopping.
7. **Commit, push, and tag the phase.**
8. **End the session.** Start the next phase fresh.

The reason for one phase per session is measurable rather than stylistic. Recall accuracy degrades as a context window fills. A session running for many hours has worse access to your specification than a session started five minutes ago, and it increasingly reasons from its own earlier conclusions rather than from the document. Ending sessions deliberately is not lost progress; the handoff file is the progress.

### 28.7 Step 4 - the four stop conditions

The agent must stop and ask, rather than decide, when any of these occur. Each one is a mechanism by which requirements silently disappear.

1. **The specification is ambiguous or silent.** Record the question in the open-questions file and stop. A guess made here becomes a fact that nobody ever revisits.
2. **The specification appears wrong.** Stop. The specification is never edited to match the code. If it is genuinely wrong, the owner changes it deliberately and the change is logged in `decisions.md`. An agent that edits the specification to match what it built has destroyed the only record of what was wanted.
3. **An acceptance row cannot be made to pass.** Report the failure. Do not weaken the row, do not mark it partially passed, and do not defer it silently.
4. **The context window is running low mid-task.** Write the handoff first, then stop. A handoff written before compaction is worth more than any amount of work finished after it.

### 28.8 Where to spend the deep reasoning

Running at maximum effort for everything is expensive and not actually optimal; the model's own guidance is that the default level is right for most work, and excessive deliberation on simple tasks degrades output. Spend the deep setting where the problem is genuinely hard, and use the default for mechanical work.

**Worth the maximum setting:**

* The economy value model and the arbitrage guard (Section 8). This is where a mistake costs real money and the failure mode is a currency collapse.
* The rating mathematics (Appendix B), including the repeat-kill decay and the soft reset.
* The season reset, which must be a single transaction that either completes or rolls back.
* The purchase-to-whitelist fulfilment path, where a failure means a paying customer cannot log in.
* The wagering detector (Section 3.5.1), because a false positive punishes an innocent paying customer.
* The migration runbook (Section 22), where the cost of an error is downtime and possible data loss.

**Default effort is fine:** configuration files, command registration, permission node wiring, placeholder setup, documentation, and the web layer.

### 28.9 The adversarial verification pass

At the end of each phase, open a separate session whose only instruction is: you did not write this code; attempt to prove these acceptance rows fail. Give it the acceptance rows and the code, and explicitly not the implementation session's reasoning.

This is not ceremony. An agent that both implements a feature and certifies it will certify it, because it is evaluating its own reasoning rather than the artefact. The verification role must have no stake in the answer.

### 28.10 Secrets discipline

This project will accumulate a database password, a console password, a payment provider key and secret, a chat bot token, and a voting token. Rules:

* Build against the example environment file with placeholder values. Real secrets go in last, by the owner, by hand.
* Add a pre-commit secret scan. This is a five-minute setup that prevents an entire class of incident.
* No secret is ever pasted into a chat session, a log line, an issue, or a commit message.
* Any secret that reaches version control history is rotated, not deleted.

### 28.11 Acceptance criteria for this section

| # | Criterion | Evidence |
|---|---|---|
| 28-1 | The repository exists, has a remote, and the ignore file predates the first commit | Log of the first commit; ignore file present in it |
| 28-2 | A host snapshot exists from before the first agent session | Provider snapshot list with timestamp |
| 28-3 | The agent account is not root | Output of the identity command from an agent session |
| 28-4 | The deny list blocks every pattern in 28.4 | A test transcript per pattern showing refusal |
| 28-5 | The deny list denies when the hook itself errors | Deliberate hook failure with a denied command |
| 28-6 | Session one produced the specification split and a contradiction report | The split files and the report |
| 28-7 | Every completed phase has a tag, a handoff entry, and acceptance evidence | Tag list cross-referenced against the progress and acceptance files |
| 28-8 | No phase is marked complete without the evidence its acceptance rows demand | Review of the acceptance file for claims without evidence |
| 28-9 | An adversarial verification pass exists for each completed phase | The verification session output per phase |
| 28-10 | No secret appears anywhere in version control history | Secret scan across full history |

> **The one sentence that matters in this section:** the specification, the traceability matrix, and the evidence-backed acceptance rows are what guarantee nothing is missed. Version control and the deny list are what guarantee nothing is destroyed. Everything else is optional.
