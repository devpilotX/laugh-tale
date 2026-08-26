# LaughTail SMP - Rejected

Ideas considered and rejected, with the reason. This file exists to prevent re-litigation (AGENTS.md section 8). Spec 1.3: anything that fails the "more fun without making it slower or less fair" test is written here rather than argued about again.

**Acceptance row 14c requires an entry in this file for the wagering escrow rejection.** It is R-0001 below, written on Day Zero so the criterion has something to point at from the start.

---

## R-0001 | 2026-08-26 | A wagering escrow, or any stake-holding mechanism

**The idea:** hold Berries from two players during a duel and pay the winner automatically. It is the obvious way to make organised fights feel consequential, players will ask for it, and third-party duel plugins ship it.

**Rejected because:**

1. It is gambling. Spec 3.5 prohibits gambling of any kind, and 3.5.1 lists the forbidden commands. Section 1.1 makes "no gambling of any kind" a differentiator from DonutSMP, not a detail.
2. It is a legal problem, not just a design one. Section 3 makes Mojang's Commercial Usage Guidelines the top precedence, above everything else in the document.
3. **Acceptance row 14c actively tests for its absence**: "Repo grep for escrow and stake-holding logic returns nothing". Building it would fail a launch gate by design.
4. Escrow makes wagering *safe*, which makes it popular, which makes it the server's identity. Section 25's scope discipline exists to stop exactly this.

**What we do instead:** nothing mechanical. Players can already pay each other with `/pay`, which 3.5.1 says cannot be removed. The wagering detector in 3.5.1 and 14a *alerts* on combat-correlated payments, and 14b requires that no automated punishment path exist from that alert. Detection without escrow, and alerting without auto-punishment.

**Related open question:** the bounty system proposed in 26.2 fires that same detector by design. See `docs/questions.md` **Q-21**. It must not be implemented as escrow, so if it ships at all it needs a different structure.

---

## R-0002 | 2026-08-26 | Anti-lag plugins - entity clearers, mob stackers, item mergers

**The idea:** the standard answer to lag on a small box.

**Rejected because:** Section 23 says "None. No entity clearers, no mob stackers", Appendix A lists them on the avoid list, and Section 25 gives the reason: "They fix a symptom by deleting player property." A player whose item drops vanish, or whose farm is silently stacked, has lost something they earned. Law 1 - one bad weekend undoes a month of marketing - applies with more force to deleting things than to lag.

**What we do instead:** the in-house watchdog with a four-step degradation ladder (6.6), which degrades cosmetics and conveniences and **never** degrades gameplay (Section 23). Plus measured tuning from Phase 6 rather than a pre-tuned config pack, which Appendix A also rejects.

---

## R-0003 | 2026-08-26 | Building on the owner's PC and deploying artefacts to the VPS

**The idea:** the conventional workflow - build locally, test locally, ship a jar.

**Rejected because:** Section 30 decides this explicitly and calls it final: "Do not build on the owner's PC." The reason is that a 2 vCPU ARM host with a specific Paper build, a specific JDK and a specific container runtime cannot be faithfully reproduced on a Windows PC, and every difference becomes a bug that only appears in production. This session's host inventory strengthens the point - the host is **aarch64** and the PC is not, so a locally built native artefact would not even run.

**Consequence, recorded honestly:** acceptance criterion `29-2` requires a local Docker Compose environment, and 29.8's deploy step 1 requires a plugin to load cleanly "on a fresh local server". Both are void under Section 30. Marked `VOID (superseded)` in `docs/acceptance.md` rather than deleted, per `32-2`. See `docs/questions.md` **Q-24**.

---

## R-0004 | 2026-08-26 | Pelican API keys as the access path

**The idea:** drive the Panel through its Application and Client APIs, which is the tidy automation route.

**Rejected because:** 33.1 and 32.3 rows 1 and 2 strike them out as NOT REQUIRED and say "Do not request it". Root SSH covers everything the APIs would have done, plus Wings configuration, firewall, node settings and database dumps, which the APIs cannot reach. Fewer credentials is less to leak.

**Consequence:** criteria `29-14` and `29-15` are written in terms of API keys and need restating in SSH terms so their intent - a reproducible runtime - is still tested. See `docs/questions.md` **Q-25**. Not silently dropped.

---

## R-0005 | 2026-08-26 | Pasting the specification into the chat

**The idea:** give the agent the whole document so it "knows everything".

**Rejected because:** 33.4 is explicit - roughly 300,000 characters consumes an enormous share of the context window before any work starts, and recall of individual details measurably degrades as the window fills. The failure mode is an agent that has been shown everything and remembers the wrong parts, which is the exact outcome the owner is trying to avoid.

**What we do instead:** the specification lives on disk, split into 43 files, indexed by `docs/spec/INDEX.md` with a quick-route table. Sections load on demand. This session read the entire document by delegating it to nine parallel agents, each given only its assigned files, and `MASTER.md` was never loaded into any single context.
