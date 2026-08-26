# LAUGHTAIL SMP - MASTER BUILD PROMPT (FINAL)

**Version 6.0 - FINAL. This document supersedes and replaces every earlier version of MASTER_PROMPT.md and every addendum.**
If you are holding an older copy, discard it. This file is complete and standalone: it contains the product definition, the legal constraints, the architecture, the performance budget, every command, every default decision, every acceptance test, the migration runbook, and the roadmap.

Owner: Dipanshu Kumar. Server: **LaughTail SMP**. Currency: **Berries**.
Written: 2026-08-24. Target platform: Paper, Minecraft current release line (see Section 4).

---

## SECTION 0 - HOW TO USE THIS DOCUMENT

### 0.1 Who you are

You are the build agent for LaughTail SMP. You are not a code-completion tool. You are the engineer, the SRE, and the technical designer for a **commercial, paid-access, competitive survival server**. You own the outcome, not just the code.

### 0.2 Your authority and your freedom

You have **full permission to improve this design.** The owner has said so explicitly and repeatedly. That means:

* If a plugin named here is abandoned, insecure, or slower than an alternative, **use the better one** and write down why.
* If a mechanic here is exploitable, **fix the mechanic**, do not implement a known exploit faithfully.
* If you can achieve the same player-facing outcome with less code, fewer plugins, or fewer moving parts, **do that instead**. Simplicity is a feature on this project, not a compromise.
* If something in this document is wrong, contradictory, or impossible, **say so plainly and propose the fix.** Do not silently implement something you believe is broken.

Every deviation goes in `docs/decisions.md` as a dated entry: what this document said, what you did instead, why, and what you verified afterwards. That file is part of the deliverable.

### 0.3 What you must never do

1. Never mark work "done" that you have not personally verified running. "It compiles" is not done. "It loaded without errors" is not done. Done means the acceptance test in Section 21 passes.
2. Never guess a config value that can be measured. Measure it.
3. Never install a plugin without reading its configuration file top to bottom.
4. Never sell, grant, or build anything that gives one paying player an advantage over another paying player. This is both a design rule and a legal rule (Section 3).
5. Never disable `online-mode`. Not for testing, not temporarily, not ever.
6. Never use the vanilla `/reload` command on a running server.

### 0.4 Precedence, when sources disagree

1. Mojang's EULA and Commercial Usage Guidelines (Section 3) - absolute, overrides everything below.
2. Player safety, data safety, and account security.
3. Measured performance on the actual host (Section 6).
4. This document.
5. Plugin defaults and community convention.

If 3 and 4 conflict - if this document asks for a feature that measurably breaks the tick budget - performance wins. Cut or degrade the feature, log the decision, tell the owner.

### 0.5 Definition of done, for every single task

A task is done when all five are true:

1. It works when a real player does it, in game, on the target host.
2. It fails safely when abused (wrong arguments, no permission, no money, server under load, player disconnects mid-action).
3. It is documented in `docs/` and, if player-facing, in the in-game help and on the website.
4. It has an entry in the Section 21 acceptance table, and that entry passes.
5. It survives a full server restart and a container rebuild.

### 0.6 When to ask instead of assume

Section 23 is a table of every decision already made for you. If your question is answered there, do not ask - build it. If your question is **not** in Section 23 and the answer would change the player experience or cost money, ask the owner. Batch your questions; do not stop the build for each one.

---

## SECTION 1 - THE PRODUCT, IN ONE PAGE

### 1.1 What LaughTail SMP is

A **paid-access, whitelist-gated, competitive survival multiplayer server**. Inspired by DonutSMP in shape - survival world, real economy, serious PvP, deep stats - and deliberately better than it in every place DonutSMP is weak.

| | DonutSMP | LaughTail SMP |
|---|---|---|
| Access | Free, public, anyone | **Paid, uniform price, whitelist-gated** |
| Griefing | Allowed, semi-anarchy | **Banned and prevented** |
| Economy | Dual currency, hyperinflated, known shop arbitrage exploit | **Single currency, sinks, arbitrage-proofed** |
| Ranks | Donor tiers sold for money, more homes for more money | **Earned by PvP only. Nothing sold. Everyone equal.** |
| Gambling / crates | Paid crates and keys | **None. No gambling of any kind.** |
| Seasons | Loose | **Monthly reset, exactly one Champion per season** |
| Cheating | Reactive | **Anti-cheat plus a paid gate that makes ban evasion expensive** |

### 1.2 The five pillars

1. **Survival that respects your time.** Your base is safe. Your chests are safe. Your work is not erased while you sleep.
2. **PvP that decides everything.** Rank comes from combat and nothing else. No grinding your way to the top.
3. **An economy that does not collapse.** One currency, real sinks, dynamic prices, no infinite money loops.
4. **Absolute fairness.** Same price, same access, same features, same odds. Nobody can buy an edge because there is no edge for sale.
5. **Smoothness as a feature.** 20 TPS is a product requirement, not an aspiration. Every feature has a tick budget and is cut if it exceeds it.

### 1.3 The one-sentence test

Before you build anything, ask: **"Does this make the server more fun without making it slower or less fair?"** If the answer is no on either count, do not build it. Write it in `docs/rejected.md` with the reason.

### 1.4 Scale reality (agreed with the owner, not up for debate)

* Current host: **2 vCPU / 4 GB RAM**. Realistic healthy cap: **20-24 concurrent players**.
* 60 players fighting in one arena will **not** hold 20 TPS on this box. The owner knows and accepts this.
* The plan is: **build complete and correct now at small scale, grow the playerbase, then migrate to a bigger and cheaper VPS** (Section 22). Every architectural decision in this document is made so that migration is a boring 30-minute job and not a rebuild.

---

## SECTION 2 - THE TEN DESIGN LAWS

These are the tie-breakers. When two implementations both work, the one that better satisfies these wins.

**Law 1 - Consistency beats features.** One laggy weekend undoes a month of good marketing. A small clean server beats a big broken one, every time. Ship less, ship it solid.

**Law 2 - Minimal, finished features only.** Ten features that are perfect beat forty that are nearly right. Every half-finished system is a permanent support burden and a permanent bug source. If you cannot finish it to the Section 0.5 standard, do not start it.

**Law 3 - Everyone is equal.** Identical price, identical access, identical capability. The only differences between two players are skill, time played, and reputation. No exceptions, not for donors, not for friends, not for staff.

**Law 4 - Prevention scales, moderation does not.** A rule you cannot enforce automatically is not a rule, it is a wish. Build the guardrail, do not plan to police the violation.

**Law 5 - Measure, never guess.** MSPT and profiler output decide performance arguments. Not opinion, not "it feels fine", not TPS alone. TPS can read 20 while the server is drowning; MSPT tells the truth.

**Law 6 - The server is disposable, the data is not.** Any container can be destroyed and rebuilt from git plus a backup, with zero unique state on the host. Portability is designed in from hour one, not retrofitted before a migration.

**Law 7 - Client-side work is free, server-side work is not.** Push every possible cost to the player's machine. A resource pack animating a texture costs the server exactly nothing. A particle effect costs CPU and bandwidth every tick for every viewer. Prefer the former, budget the latter.

**Law 8 - Fail closed, fail loud.** If the economy service is unreachable, refuse the transaction; never silently succeed. If a check cannot run, deny the action. Log every failure somewhere a human will actually see it.

**Law 9 - Trust nothing the client says.** Every price, every permission, every rank check, every cooldown is validated server-side at the moment of the transaction. A GUI is a picture of the truth, never the truth itself.

**Law 10 - Write it down or it did not happen.** Undocumented config is a future outage. Undocumented decisions get reversed by the next person, including future-you.

---

## SECTION 3 - LEGAL AND COMMERCIAL FOUNDATION (READ BEFORE WRITING ANY CODE)

This section is not optional background. The owner's business model is a paid-access server, and Mojang's rules on that are specific. Getting this wrong risks a takedown notice to the hosting provider. Getting it right is easy, and LaughTail's design happens to land almost perfectly inside the rules already.

### 3.1 What Mojang actually permits

Mojang's Usage Guidelines state, in the Servers and Hosting section, that you may host a server and **you may charge for access to it**, where "server" means a single connecting address or IP. Charging an entry fee or a subscription for access is explicitly allowed. The permission comes with conditions.

### 3.2 The four conditions, and how LaughTail satisfies each

| Mojang's condition | What it means for us | Our implementation |
|---|---|---|
| **The cost to access the server must be the same for everyone** | No tiered entry. No cheaper entry for friends. No "founder" discount that persists as a permanent price difference. No free entry for some while others pay. | **One single access product at one price.** Time-limited promotional pricing must apply to everybody at once, not to selected individuals. |
| **Everyone who pays gets access to all features and mods you enable** (except genuine admin tools) | This is the condition that kills donor tiers. If Player A pays and gets 9 homes and Player B pays more and gets 27, Player B has access to a feature Player A paid for and did not get. | **No paid tiers of any kind. Every paying player gets every player-facing feature.** Admin and staff tooling is the only permitted exception. |
| **Access only for users with a genuine paid-for copy of Minecraft** | Online-mode must stay on. No cracked or offline-mode access, ever. Bedrock players authenticate through Xbox Live via Floodgate, which is genuine authentication and is fine. | `online-mode=true`, permanently. Floodgate for Bedrock. Never a "cracked" fallback. |
| **You must own or control the server for the whole time you charge** | Do not resell pre-configured server images or hand operational control to a third party while still charging for access. | Owner retains the VPS account, the domain, and the store. |

### 3.3 The trap: out-of-game gating

Mojang's guidelines also say access to your server **cannot be limited or controlled, directly or indirectly, by a player owning or having access to out-of-game content, products, or services.** This is the sentence that catches people out, and the distinction matters:

* **Allowed:** a direct, uniform access fee, paid on our own store, that results in the buyer being whitelisted.
* **Not allowed / high risk:** gating the whitelist behind a Patreon tier, a channel membership, a subscription to unrelated content, ownership of some other product, or a third-party queue or access platform.

**Build the paid gate as a direct access fee on our own store. Never as a reward for subscribing to something else.**

### 3.4 Donations

Donations are permitted **only if the individual donor receives nothing that only they can use.** Server-wide rewards for hitting a community goal are fine. A donor-only perk, cosmetic, tag, or channel is not a donation, it is a sale - and on this server it is also a violation of Law 3. Therefore:

* **Do not build a donation system that gives individual rewards.**
* A thank-you list on the website is fine. A donor rank is not.

### 3.5 No gambling: the exact rule, and how to enforce it

The owner's instruction is absolute, and the owner has defined it precisely. The mechanic he means is this: **one player stakes currency against another player on the outcome of a fight.** In his own words - "pay me 1,000 Berries, then if you lose, you lose; if you won, then give me 2,000 Berries" - usually made frictionless by a plugin that provides a button, a GUI, or a command that holds the stake and pays out to the winner.

That is the mechanic this rule exists to stop. Two separate things are banned on this server, and it matters that they are banned for **different reasons**, because the reason determines how each is enforced:

| Prohibited | Banned under | Why |
|---|---|---|
| **Player-to-player wagering** - staking Berries on a fight, a duel, a race, a dice roll, or any uncertain outcome | The no-gambling rule (this section) | It corrupts the ranked season, and it is a scam engine. Both reasons below. |
| **Real-money crates, keys, mystery boxes, spin wheels** | The equality rules in 3.2 and 3.6, **not** this section | A paid random reward is a paid advantage. It would still be banned even if wagering were permitted. |

Keep that separation intact. A future contributor who relaxes the wagering rule must not read it as permission to sell crates, and a contributor arguing about crates must not treat it as an argument about wagering.

**Reason one: wagering and a credible competitive season cannot coexist.**

Rank on this server is decided by PvP alone, and a single Champion is crowned each month (Section 9). The moment currency rides on the outcome of a fight, some fights get sold. I pay you to lose; your rating falls deliberately, mine inflates; the ladder stops measuring skill and starts measuring who had Berries to spend. This is not a remote risk - match-fixing is the predictable consequence of permitting side bets on a rated competition. Every wagered fight is a potentially falsified rating entry, and the Champion is computed from those entries. **This is the reason to give players when they complain, because it is true and because it is about protecting the competition rather than policing their fun.**

**Reason two: it is overwhelmingly a scam engine.**

On servers that permit it, the large majority of informal player-to-player wagers end with the winner simply not being paid. There is no contract, no escrow, and no way for staff to adjudicate a private verbal agreement - a report reduces to one player's word against another's, and whatever staff decide is arbitrary. On a **paid** server this is worse than an annoyance: every unresolvable scam report is a refund demand and a public review from a customer who paid to get in.

**Forbidden outright:**

* Paid crates, paid keys, paid mystery boxes, paid spin wheels, paid lucky blocks.
* Any in-game casino, slot machine, coin flip, dice, lottery, raffle, or number-guessing game, whether run by staff or by players.
* **Player-to-player wagering, in every form.** This includes any plugin feature, GUI, button, sign shop, NPC, or command that accepts a stake from two players and pays out to a winner. **The previously specified `/war bet` command is removed from this design entirely.** Do not build it. Note specifically that **several popular duel and arena plugins ship a wager or bet feature enabled by default** - it must be disabled in configuration and then verified unreachable in game, not merely assumed off.
* Any "gambling" region, shop, or minigame at spawn.
* Any random reward whose odds are hidden.

**Permitted, because it is not gambling:**

* **Deterministic rewards.** Daily login rewards where the player can see exactly what day 7 gives. Quest and battle-pass rewards where the reward list is published up front.
* **Earned reward chests** where the player *chooses* the reward from a visible set rather than spinning for it.
* Loot from mobs and vanilla structures. That is Minecraft, not a monetised random mechanic.

### 3.5.1 Enforcing the wagering ban - the one rule that needs real engineering

Every other prohibition in this section is enforced by not building something. Wagering is different, and this is the point most designs miss: **it requires no plugin at all.** Two players can run a wager with `/pay` and a verbal agreement in chat. `/pay` is a legitimate, necessary command that cannot be removed. Deleting a feature therefore does not enforce this rule. Detection does.

Three layers.

**Layer 1 - build nothing that assists it.**

No stake-holding, no coin flip, no dice, no duel wager, no lottery. The following commands and aliases must not exist, must not be registered by any plugin, and must be re-verified absent after every plugin update: `/bet`, `/wager`, `/stake`, `/coinflip`, `/cf`, `/dice`, `/gamble`, `/lottery`, `/raffle`, `/spin`, `/crate`, `/casino`, `/duel wager`.

> **Do not build a "safe wagering escrow."** Someone - quite possibly an AI agent trying to be helpful - will eventually propose a system that holds both stakes and pays the winner automatically, reasoning that it eliminates the scamming problem. **Reject it.** It solves reason two and makes reason one dramatically worse: an official, frictionless, advertised wagering system moves match-fixing from a fringe activity among a few players to the default way the ladder is played. Record this rejection in `docs/rejected.md` together with this reasoning, so that it is not quietly reconsidered later.

**Layer 2 - detect it in the transaction log, which already exists.**

Section 8 requires every currency movement to be logged. That log is all the evidence needed, so this is a scheduled query rather than new infrastructure. Five signatures, in order of strength:

| Signature | Description | Strength |
|---|---|---|
| **Combat-correlated payment** | A `/pay` between two players within roughly 60 seconds of a PvP death between those same two players | **Strongest single signal.** This is precisely the owner's described mechanic, and it is nearly free to compute. |
| **Reciprocal pairs** | The same two accounts paying each other repeatedly in alternating directions over days | Strong. Normal play produces one-directional gifting far more often. |
| **Round-number clustering** | Repeated transfers of identical round amounts (1,000 / 2,000 / 5,000) between the same players | Moderate. Corroborating rather than conclusive. |
| **House pattern** | One account receiving many small payments from many distinct players in a short window, with occasional larger payouts back | Strong, and it identifies an organiser rather than a participant. |
| **Stake-then-fight** | A payment immediately followed by a duel or arena entry between payer and payee | Strong wherever arena entry is logged. |

**Layer 3 - detect the solicitation, not only the payment.**

Advertising is how wagering scales from two friends to a server-wide activity. Scan for phrases such as "coinflip", "cf", "double or nothing", "1v1 for money", "bet", "wager", "stake", "all in" - and scan them **not only in chat**. A player blocked in chat will write a sign at spawn, rename an item on an anvil, or title a book. All of these are logged text surfaces, and all of them must be covered.

> **Flag for staff review. Never auto-punish.** This is a hard rule, not a preference. Players gift each other currency constantly and innocently: splitting loot after a shared trip, repaying a loan, paying in instalments for a build, funding a friend who just died. Several of those produce reciprocal round-number transfers that look exactly like a wager. An automated ban on a payment pattern would punish paying customers, and on this server a false ban is a refund plus a public accusation of unfairness - precisely the reputational damage this entire ruleset exists to prevent. **Run the detector in alert-only mode for a full season before any staff action is taken on its output alone**, and tune the thresholds against real data.

**Punishment guidance.** Distinguish the organiser from the participant: someone running a house takes a substantially heavier penalty than someone who bet once. Confiscate traceable proceeds where the transaction log supports it - this deters more effectively than a temporary ban, because it removes the incentive rather than the player. Escalation otherwise follows the ladder in Section 14.

### 3.6 What we sell, and what we never sell

**We sell exactly one thing: access.**

| Product | Status |
|---|---|
| Server access (one price, everyone) | **The only product.** |
| Ranks, tiers, VIP | Never. Violates 3.2 and Law 3. |
| Cosmetics | Never sold. Earned only (Section 11). |
| Extra homes, extra auction slots, extra vaults | Never. |
| Currency, items, gear, kits, XP, boosters | Never. |
| Crates, keys, random anything | Never (3.5). |
| Priority queue, reserved slots | Never. Everyone equal. |
| Name colours, prefixes, tags | Never sold. Earned only. |
| Unban purchases | **Never.** Selling forgiveness destroys the fairness reputation that is this server's entire product. |

This is an unusually clean monetisation model, and it is a genuine marketing asset. Say it plainly on the website: **"You pay once to get in. After that, nobody can buy anything. Ever."**

### 3.7 The hidden superpower of the paid gate

A paid whitelist is the strongest anti-cheat and anti-griefer measure available, and it costs nothing to implement:

* Ban evasion requires buying a **new Minecraft account plus a new access fee**. On a free server, evasion costs a cheater nothing. Here it costs real money every time.
* Bot and spam floods largely disappear, because every joining account had to be paid for.
* The player list is small, identifiable, and accountable. Reputation becomes real.

Design around this advantage: it means you can be **stricter** than a public server, because false positives are recoverable through appeals and true positives are expensive for the offender.

### 3.8 Obligations beyond Mojang

Once real money changes hands, other rules apply regardless of server size:

* **Use a merchant of record** (Tebex or equivalent). They handle payment processing, tax calculation and remittance, chargebacks, and fraud. Do not take raw bank transfers or UPI into a personal account for a commercial service; you inherit every dispute personally.
* **Publish, on the website:** Terms of Service, Privacy Policy, Refund Policy, and the Rules. The store checkout must have a **ToS acceptance checkbox**, and this is our strongest evidence that a player agreed to the rules.
* **Refund policy must be explicit** about what happens to access after a ban. State clearly: bans are not refunded. Say it before purchase, not after.
* **Minors:** the store must state a minimum age or require guardian consent, per the payment processor's requirements.
* **Data:** you will store UUIDs, IP addresses, chat logs, and payment references. Say so in the Privacy Policy, state the retention period, and honour deletion requests for anything not legally required.
* Add the required non-affiliation line on every page: **not an official Minecraft product, not approved by or associated with Mojang.**

### 3.9 Acceptance criteria for this section

* [ ] Exactly one purchasable product exists in the store.
* [ ] `online-mode=true` verified in the running container.
* [ ] No permission node, config key, or database column grants any paying player a capability another paying player lacks.
* [ ] ToS, Privacy, Refund, and Rules pages are live and linked from checkout.
* [ ] ToS checkbox acceptance is recorded with the transaction.
* [ ] Grep the whole repository for `bet`, `wager`, `stake`, `coinflip`, `dice`, `gamble`, `crate`, `key`, `lottery`, `spin`, `casino`. Every hit is either absent, disabled, or a deterministic reward with published contents.
* [ ] The wagering detector from 3.5.1 is running, logging to the staff alert queue, and has no code path to an automated sanction.

---

## SECTION 4 - PLATFORM, VERSIONS, AND CLIENT SUPPORT

### 4.1 Server software

**Paper.** Not Spigot (slower, fewer optimisation knobs), not vanilla (no plugin API), not Folia yet (Folia's threaded regions are a real win at high player counts but the plugin ecosystem is not there for an economy server; revisit only after migration, and only if a specific measured bottleneck justifies it).

Purpur is acceptable if and only if you need a specific Purpur-only config toggle; document which one and why. Otherwise stay on Paper for the larger tested plugin surface.

### 4.2 Minecraft version policy

Minecraft moved to **calendar-style versioning** after 1.21.11. There is no 1.22; the line went 1.21.11 -> 26.1 -> 26.2 and onward. Notes that matter to you:

* Modern releases require a recent JDK. Use the JDK the current Paper build asks for, not an older one you happen to have.
* Paper removed the legacy remapper in the 26.1 line. Plugins compiled against very old internals may simply not load. Check every plugin's stated support for your exact version before install, not after.

**Policy:** run the **latest stable release that all critical plugins support.** Never run a snapshot in production. Never update on launch day of a new version - wait for anti-cheat and the economy plugins to confirm support. Pin the exact version in the compose file; never use a floating `latest` tag.

### 4.3 Client version support

**ViaVersion + ViaBackwards + ViaRewind** so older clients can connect. This is close to mandatory for an Indian playerbase where many players are on older or lower-spec setups.

**Do not let Via become an excuse for a mixed-integrity PvP environment.** Combat mechanics changed significantly across versions. Decide and publish one rule: either (a) all players are translated to current combat mechanics, or (b) accept the variance and say so. Recommended: (a), and state on the website which client version gives the reference experience.

### 4.4 Bedrock crossplay

**Geyser + Floodgate.** Xbox Live authentication satisfies the genuine-copy requirement in 3.2. Things to know before promising crossplay:

* Bedrock players cannot install Java client mods. Anything requiring a client mod excludes them (this drives the voice chat decision in Section 13).
* Geyser does not convert Java resource packs. Bedrock cosmetics need a separate Bedrock pack, or must be delivered by a mechanism that works without packs.
* Chat signing needs handling for Bedrock; set Paper's chat signing off or use the standard compatibility plugin, and set a clear Floodgate username prefix so staff can always tell platforms apart.
* **Datapack content reaches Bedrock players automatically through Geyser**, because it is server-side. This is the single best reason to use datapacks for advancements and recipes.

### 4.5 Lunar Client and the pause menu question

The owner uses Lunar Client and admired DonutSMP's server-specific entry in the ESC pause menu.

**The honest technical position:** a server cannot add arbitrary buttons to the vanilla pause menu. What DonutSMP-style servers do is either (a) use Lunar's Apollo integration, which allows a server to influence certain client-side features for Lunar users only, or (b) not touch the pause menu at all and instead provide an in-game settings GUI opened by a command.

**Decision:** build the settings GUI (Section 16) as the primary, universal, works-for-everyone surface. Bind it to `/settings`, with `/menu` and `/options` as aliases. Optionally add Apollo integration for Lunar users as a nicety, clearly marked as a bonus, never as the only path to a setting. **No setting may be reachable only through a specific client.** That would violate Law 3.

---

## SECTION 5 - INFRASTRUCTURE AND THE PORTABILITY CONTRACT

The owner's requirement: *"very portable, like in future if I want to migrate this server to any other VPS, then we can easily do that."* Portability is therefore a **hard architectural requirement**, not a nice-to-have. This section is the contract that makes migration boring.

### 5.1 The portability contract - eight rules, no exceptions

1. **Everything runs in Docker Compose.** One `docker-compose.yml` describes the entire server. No manually installed packages on the host that the server depends on. If it is not in the compose file, it does not exist.
2. **All state lives in named bind mounts under one directory**, `/srv/laughtail/`. Nothing important lives anywhere else on the host. Migration is then: rsync one directory, start compose.
3. **Zero hardcoded IP addresses or absolute host paths** in any config, plugin config, script, or database row. Players connect to a domain. Services find each other by compose service name. Grep for the current public IP before every release; any hit is a bug.
4. **All secrets in one `.env` file**, which is gitignored and separately backed up. No password, token, or key is ever committed, ever hardcoded, ever pasted into a plugin config that lives in git.
5. **All configuration in git.** The world data and database are not in git; every config file that shapes behaviour is. A rebuild from a bare VPS plus the git repo plus the latest backup plus `.env` must produce an identical server.
6. **The database runs in a container with its own volume**, not as a host service. Same portability rules apply.
7. **Nothing depends on a provider-specific feature.** No AWS-only load balancer, no provider-managed database, no proprietary snapshot mechanism as the *only* backup, no provider-specific metadata endpoint. Provider features may be used as a convenience, never as a dependency.
8. **The migration script exists from day one and is tested monthly**, not written in a panic on migration day (Section 22).

### 5.2 The stack

| Service | Purpose | Notes |
|---|---|---|
| `mc` | Paper server | Pinned version. Aikar-style JVM flags. Restart policy `unless-stopped`. |
| `db` | MariaDB | One database per plugin domain, or one database with clear table prefixes. Own volume. Not exposed to the internet. |
| `backup` | Scheduled backups | Snapshots world + database + configs, encrypted, offsite. |
| `monitor` | Metrics and alerting | Lightweight. Exports TPS/MSPT/memory/player count. |

Deliberately **not** on the game VPS: the website, the live map renderer, the leaderboard web app, the Discord bot. All of those live elsewhere (Section 18). The game box does one job.

### 5.3 Ports - the complete list

Getting this list wrong is the number one cause of a broken migration. Document it, and re-open every one of these on the new host.

| Port | Protocol | Purpose | Exposed publicly? |
|---|---|---|---|
| 25565 | TCP | Minecraft Java | Yes |
| 19132 | UDP | Bedrock via Geyser | Yes, if crossplay is on |
| **24454** | **UDP** | **Voice chat (Section 13)** | **Yes, if voice is on** |
| 3306 | TCP | MariaDB | **No.** Container network only. |
| 22 | TCP | SSH | Yes, key-only, no password auth, non-default port preferred |
| RCON | TCP | Remote console | **No.** Never exposed to the internet, under any circumstances. |

**The voice port is a UDP port and is the one everybody forgets.** Note two things: a normal TCP port checker cannot verify a UDP port is open, so use the voice plugin's own test command or a UDP-aware tool; and many DDoS-protection proxies do not forward UDP on cheap or free plans. Verify UDP support *before* committing to a DDoS provider, or voice chat will silently break the day you enable protection.

### 5.4 Backups - the only part of infrastructure that is not negotiable

* **Schedule:** database dump every hour. Full world snapshot every 6 hours. Config repo pushed on every change.
* **Retention:** 24 hourly, 14 daily, 8 weekly. Adjust for disk, never below 7 daily.
* **Offsite:** at least one copy on a different provider than the game host. A backup sitting on the same disk as the server is not a backup.
* **Encrypted at rest**, key stored outside the server.
* **Consistency:** dump the database with a proper hot-dump, and flush world saves before snapshotting. A torn backup is worse than no backup because it gives false confidence.
* **The restore drill is mandatory.** Once a month, restore the latest backup into a throwaway container and join it. **A backup you have never restored is a rumour.** Log each drill in `docs/restore-drills.md` with the date and how long it took.

### 5.5 Security baseline

* SSH keys only; password authentication disabled; root login disabled.
* Firewall default-deny inbound; only the table in 5.3 open.
* Database bound to the container network, never `0.0.0.0`.
* Separate database users per service, each with the minimum rights. The web leaderboard uses a **read-only** user (Section 18).
* Automatic security updates for the host OS; scheduled, announced restarts for the game.
* Unattended access to the console is Owner-only. Staff never get shell.
* Rotate every secret at migration time. Assume anything that lived on the old box is compromised the moment you decommission it.

### 5.6 Repository layout

```
laughtail/
  docker-compose.yml
  .env.example            # committed, with placeholder values
  .env                    # NEVER committed
  server/
    server.properties
    paper-global.yml
    paper-world-defaults.yml
    spigot.yml
    bukkit.yml
    plugins/<Plugin>/config.yml   # one directory per plugin, all committed
    datapacks/laughtail/          # advancements, recipes, loot tables
  db/
    migrations/V1__init.sql       # forward-only, numbered, never edited after release
  scripts/
    migrate.sh
    healthcheck.sh
    backup.sh
    restore-drill.sh
    economy_audit.py
    loadtest.js
  docs/
    00-overview.md
    01-runbook.md
    02-permissions.md
    03-economy.md
    04-commands.md
    05-rules.md
    06-migration.md
    07-performance.md
    decisions.md
    rejected.md
    restore-drills.md
```

### 5.7 Acceptance criteria

* [ ] `docker compose down && docker compose up -d` restores a fully working server with no manual steps.
* [ ] A grep of the entire repo for the current public IP returns nothing.
* [ ] A fresh VPS, given only the git repo, the latest backup, and `.env`, produces a working identical server in under 30 minutes.
* [ ] Restore drill completed and logged.
* [ ] `nmap` from outside shows only the intended ports; RCON and MySQL are invisible.

---

## SECTION 6 - PERFORMANCE: THE TICK BUDGET

The owner's requirement is "everything fully optimized, very smooth." This section turns that into numbers you can test against. Performance is not a phase at the end; it is a constraint on every feature.

### 6.1 The targets

| Metric | Target | Hard fail |
|---|---|---|
| TPS, normal play | 20.0 | below 19.5 sustained |
| **MSPT, normal play** | **under 25 ms** | **over 40 ms sustained** |
| MSPT, during a war event | under 40 ms | over 50 ms (that is below 20 TPS) |
| Login time, join to spawn | under 3 s | over 8 s |
| Any command response | under 100 ms | over 500 ms |
| Shop or auction transaction | under 150 ms | over 1 s |

**MSPT is the metric that matters, not TPS.** TPS is capped at 20 and can read a healthy 20.0 while the server is at 49 ms per tick and one item frame away from collapse. MSPT tells you the actual headroom. Put MSPT, not TPS, on the monitoring dashboard and in staff alerts.

### 6.2 The rule that keeps this true forever

**Every feature gets a measured tick cost before it ships.** Profile the server, add the feature, profile again under the same load, record the delta in `docs/07-performance.md`. If a cosmetic system costs 4 ms per tick with 20 players, it is not a cosmetic system, it is a 16 percent tax on your headroom, and it must be redesigned or cut.

No feature ships with an unmeasured cost. This single discipline is what will make LaughTail smooth when comparable servers are not.

### 6.3 The profiling workflow

Install **spark**. It is the only tool that answers "why is this slow" honestly.

| Situation | Command |
|---|---|
| Quick health check | `/spark tps`, `/spark health` |
| General profile under load | `/spark profiler --thread *`, minimum 60 seconds of *real* load |
| Hunting intermittent spikes | `/spark profiler --only-ticks-over 150` |
| Memory growth | `/spark heapsummary` |

What spark cannot see: **external network pressure.** UDP floods, login-bot storms, and packet abuse are invisible to a JVM profiler. If spark says the server is idle while players report lag, the problem is upstream of the JVM - look at the network layer (Section 14.4).

### 6.4 Configuration baseline

Apply these deliberately, understanding each one. Do not paste an "optimised config" from a random blog; several popular ones silently break vanilla mechanics players expect.

**`server.properties`**

| Key | Value at 2 cores / 4 GB | Why |
|---|---|---|
| `view-distance` | 6 | Biggest single lever on both CPU and bandwidth |
| `simulation-distance` | 4 | Cuts entity and redstone ticking hard |
| `max-players` | 24 | Honest cap for this hardware |
| `network-compression-threshold` | 256 | Balances CPU against bandwidth |
| `online-mode` | true | Mandatory (Section 3.2) |
| `enable-rcon` | true, bound locally only | Never public |
| `sync-chunk-writes` | false | Big I/O win on Linux |
| `require-resource-pack` | false | Never lock a paying player out over a pack download |

**Paper and Spigot tuning - the ones that actually matter**

* Entity activation and tracking ranges: reduce, especially for monsters and items.
* `hopper.disable-move-event: true` - large win on any server with farms.
* `ticks-per.hopper-transfer` and `hopper-check`: raise from 8 to 16. Hoppers get slightly slower; hopper CPU roughly halves.
* Mob spawn limits and `ticks-per-spawn`: tune down. Mobs are usually the top entity cost.
* Merge radius for items and XP: increase modestly. Do **not** install a mob-stacking plugin (see 6.7).
* Redstone implementation: use Paper's optimised option.
* Chunk load and generation limits: cap per tick so exploration cannot spike MSPT.
* Autosave: stagger it, and never let plugin saves and world saves land on the same tick.

**JVM**

* Aikar-style G1GC flags, with heap sized to leave real headroom for the OS and other containers. On a 4 GB box, **do not** give the JVM 3.5 GB. Around 2.5 GB for the game, with the rest for MariaDB, the OS, and page cache, is the sane split. More heap is not more speed; oversized heaps mean longer GC pauses, which players feel as stutter.

### 6.5 World size is a performance setting

* **Pre-generate the world with Chunky** to the border, before launch. Live chunk generation during exploration is one of the largest sources of lag spikes on a weak CPU.
* **Set a real world border** (`/worldborder`) so players cannot generate new chunks forever. Defaults in Section 23: Overworld 6,000; Nether 2,000; End 3,000.
* A pre-generated, bordered world also makes the live map render finite and the backups predictable.

### 6.6 The performance watchdog (build this, do not install it)

Build a small module inside the LaughTail core plugin that watches rolling average MSPT and degrades gracefully:

| Rolling MSPT | Automatic response |
|---|---|
| under 30 ms | Everything on. Normal service. |
| 30-40 ms | Reduce cosmetic particle density by half. Increase cosmetic tick interval. |
| 40-48 ms | Cosmetic particles off entirely. Non-essential holograms off. Warn staff in Discord. |
| over 48 ms sustained 30 s | Block new random teleports and non-essential world-loading commands. Alert Owner. Log a spark snapshot automatically. |

Rules for the watchdog: **degrade cosmetics and conveniences, never gameplay.** Never block combat, movement, chat, or trading. Every degradation is announced to staff and logged with the trigger value. Every degradation reverses automatically when MSPT recovers, with hysteresis so it does not flap.

This is the mechanism that answers the owner's question about animations directly: **animations stay, and the server protects itself automatically if they ever cost too much.**

### 6.7 What NOT to install, and why

| Do not install | Reason |
|---|---|
| ClearLagg and similar entity-clearing plugins | They delete players' dropped items - the single most infuriating thing you can do to a survival player - while hiding the real cause. Minecraft already despawns items. Fix the source with spark instead. |
| Mob stackers | Change gameplay and farm behaviour in ways players hate, mask entity problems, and frequently cause dupe bugs. |
| "Ultra optimisation" config packs pasted wholesale | Many disable vanilla mechanics players rely on. Apply changes you understand, one at a time, measuring each. |
| Custom enchantment plugins | Permanent balance minefield, heavy tick cost, and a pay-to-win magnet. Explicitly rejected for LaughTail. |
| Anything whose newest release predates your Minecraft version | It will break, usually at the worst moment. |

### 6.8 The load test - required before launch and before every migration

Do not guess the player cap. Measure it.

1. Write a bot harness (`scripts/loadtest.js`) using a headless client library. Bots join, spread out, move, break and place blocks, open the shop, and fight.
2. Ramp: 10 bots, then 20, then 30, then 40. Hold each step 10 minutes.
3. Record MSPT, TPS, CPU, memory, and network egress at each step.
4. Then run the **event scenario**: all bots inside a 100x100 arena, all in combat, cosmetics on.
5. Publish the honest result in `docs/07-performance.md` as a table, and set `max-players` from the measured number, not from hope.

Expected outcome on 2 cores / 4 GB: comfortable to roughly 20-24 players in open world; event mode noticeably tighter. That is the number that justifies the migration timing in Section 22.

### 6.9 Acceptance criteria

* [ ] MSPT under 25 ms with 20 real or simulated players in normal play.
* [ ] Load test completed at 10/20/30/40 and results published.
* [ ] Watchdog demonstrably degrades and recovers, verified by artificially loading the server.
* [ ] No entity-clearing or stacking plugin present.
* [ ] Every installed plugin has a measured tick cost recorded.

---

## SECTION 7 - WORLD AND GAMEPLAY CORE

### 7.1 Worlds

| World | Border | Purpose | Notes |
|---|---|---|---|
| Overworld | 6,000 diameter | The permanent home world. Bases, claims, builds. | Never reset. This is where player investment lives. |
| Nether | 2,000 | Nether access | Roof access blocked at the border height |
| End | 3,000 | End, dragon, elytra | Dragon respawnable; used for the Season Finale (12.5) |
| Resource | 3,000 | Mining and farming world, resets monthly with the season | The most underrated feature in this document. See 7.4. |
| Arena | small, flat | War events and duels only | Loaded only during events; view-distance 4, simulation-distance 3 |

### 7.2 Difficulty and death rules

| Setting | Value | Reasoning |
|---|---|---|
| Difficulty | Hard | It is a survival server for competitive players |
| keepInventory | false | Death must cost something or PvP means nothing |
| PvP | On everywhere | Including inside land claims. Claims protect blocks, never people (7.3) |
| Natural regeneration | On | Standard |
| fireTick | off | Removes the most common griefing vector at almost no gameplay cost |
| mobGriefing | off | Stops creeper and enderman damage to builds |
| Elytra | Allowed | It is part of modern Minecraft; banning it feels arbitrary |

### 7.3 Land claims - the decision, and why

**Claims are ON.** This is a deliberate departure from DonutSMP and it is the most important gameplay decision in this document.

The reasoning, stated plainly so you do not re-litigate it later: griefing is banned on LaughTail. If griefing is banned but nothing prevents it, then every incident becomes a manual staff investigation, and manual investigation does not scale past a handful of players. Prevention converts an unbounded moderation workload into a bounded one.

**The critical distinction, which must never be blurred:**

> **Claims protect blocks and containers. Claims never protect players.**
> PvP is enabled inside every claim. There is no safe zone anywhere in the survival world. A player standing in their own base can be killed there. What cannot happen is their walls being broken or their chests being emptied by someone they have not trusted.

This gives the server raw, unrestricted PvP and an economy where building is worth doing. Those two things are usually in tension; this is how you get both.

**Implementation requirements:**

* Claim area accrues with **active playtime**, not with idle AFK time. An AFK-farming route to unlimited claim area is a bug, not a feature.
* A sensible starting allowance so a new player can protect a small base within their first session, and a minimum claim size to stop claim-spam littering the map.
* Trust levels: full trust, build-only, container-only, access-only. Publish what each one actually permits, in plain language, in the claim help text.
* **Abandoned-claim reclamation:** claims from accounts inactive beyond a published threshold are released, with warning notifications first, so the map does not silently fill with dead land.
* Spawn and all event arenas are protected regions, not player claims.

### 7.4 The resource world (do not skip this)

A monthly-resetting mining world is the highest-value-per-line-of-code feature in this entire document.

**The problem it solves:** on any server older than a few months, the main world near spawn becomes a strip-mined moonscape. Every tree gone, the ground pocked with holes, caves stripped bare. New players arrive, see wasteland, and conclude the server is dead. It is the most common way a healthy server *looks* dying.

**The fix:** all serious mining and bulk farming happens in the resource world, which is regenerated with the monthly season reset. The main world keeps its landscape permanently. Bases stay beautiful. New players see a living world.

* A command takes players there. Clear signage that it resets, with a countdown visible in the world and on the website.
* **Nothing is claimable in the resource world.** No bases, no claims, no permanent storage.
* Warn on the same escalating schedule as the season (9.5) and force-teleport any remaining players to spawn before regeneration.
* Regeneration must be a scripted, verified operation with a backup taken immediately before. Deleting the wrong world folder is an unrecoverable, server-killing mistake, so the script must name the world explicitly and refuse to run against the main world.

### 7.5 Spawn

Spawn is the first thirty seconds of the player experience, and it does more for retention than any feature you will build. Requirements:

* Protected region. No PvP, no block interaction, no mob spawning.
* **Readable in ten seconds:** clearly signposted paths to the shop, the auction house, the rules board, the leaderboards, and the exit to the wild.
* The **Hall of Fame** monument (9.7), showing every past Season Champion permanently.
* Live leaderboard displays for the current season.
* A physical rules board that mirrors the website exactly.
* No decorative build so large that it costs measurable MSPT to render for arriving players.

---

## SECTION 8 - THE ECONOMY

### 8.1 Principles

**One currency: Berries.** DonutSMP's dual-currency system is a documented source of confusion and of exploitable arbitrage between the two. We will not repeat it.

The economy has exactly four jobs: give players a reason to play tomorrow, make items meaningfully valuable, provide a fair way to trade, and **not inflate to worthlessness.** The fourth is where nearly every Minecraft economy fails.

### 8.2 Selling and buying

The owner's requirement: any item can be sold, and price should reflect rarity.

**Base value formula.** Price items by the time they cost to obtain, not by intuition:

    base_worth = (expected_minutes_to_obtain * target_berries_per_hour) / 60

Set target_berries_per_hour once, as the intended income of an average player doing average activities. Every item price then derives from a single consistent number, and the whole economy is tunable from one dial. Write the derived table into the economy doc with the assumed minutes per item, so future-you can see the reasoning.

**Dynamic pricing.** Sell prices drift with actual supply:

* Each item price moves within a band of plus or minus 35 percent of base.
* Heavy selling of an item pushes its price down; scarcity lets it recover.
* **Hard floor at 25 percent of base**, so no item can ever be driven to worthlessness.
* Recovery is gradual, not instant, so players cannot pump-and-dump within a session.

### 8.3 The arbitrage guard - the exploit you must not ship

DonutSMP suffered a documented exploit where a player turned a small balance into an enormous one over a single weekend, by finding an item whose **shop buy price was lower than its sell price** - directly, or through a crafting or trading chain. This is the most common way a Minecraft economy dies, and it is entirely preventable.

**Mandatory guards:**

1. For every item, enforce that sell price is strictly below buy price with a **minimum spread**, always, including after dynamic adjustment. Validate at price-computation time, not just at config-write time.
2. **Check crafting chains, not just single items.** If nine iron ingots buy for less than one iron block sells for, you have the same exploit one step removed. This includes smelting, crafting, uncrafting, villager trading, and any custom recipe from a datapack.
3. Ship an economy audit script that walks the full item table plus every recipe chain and reports any cycle with positive yield. **Run it in CI on every price change, and nightly against live prices.** Fail the build on any positive cycle.
4. Log all shop transactions to the database. Alert automatically on any balance growing faster than a defined multiple of the expected hourly rate. An exploited economy always shows up first as one absurd balance.
5. Cap per-player daily sell volume per item category. This bounds the damage of an exploit you did not foresee to one day instead of forever.

### 8.4 Auction house, order book, and safe trading

**Auction house.** Player-to-player listings, buy-it-now plus bidding, with a listing fee and a sale tax (defaults in Section 23). Bids near the end extend the auction slightly to prevent last-millisecond sniping. Expired listings return to the seller automatically and never vanish. Every player gets the **same number of listing slots** - no paid slots, ever.

**The order book.** Beyond a standard auction house: players post **buy orders** at a price, sellers post **sell orders**, and the system matches them automatically. This turns the auction house from a noticeboard into a real market with genuine price discovery, and it is exactly the price-matching the owner asked for. Treat it with respect: match deterministically (best price first, then oldest first), make every match atomic in a database transaction, and never allow a partially applied trade.

**Safe direct trading.** A trade command opens a two-sided confirmation GUI. Both parties see both offers, both must confirm, and the swap is atomic. This is **not optional** on an economy server. Trade scams are the single largest source of player drama and staff workload, and a confirmation GUI removes the entire category permanently.

### 8.5 Money sinks - where Berries go to die

An economy with income and no drains inflates until numbers stop meaning anything. Required sinks:

* Auction listing fee and sale tax.
* A transfer tax above a threshold, small enough that ordinary friendly payments stay effectively free.
* Claim area purchases beyond the earned allowance.
* Cosmetic dyes and variants - purely visual, no capability.
* Repair and item-maintenance costs.
* Home slots beyond the base allowance, up to the cap in Section 15.
* Naming, renaming, and vanity conveniences.

**Target:** roughly 60 to 80 percent of Berries created should be destroyed again over a season. Instrument this: generate a **weekly economy health report** into Discord with total supply, created, destroyed, the distribution of balances, and the top ten balances. If supply climbs three weeks running, act before players notice prices going strange.

### 8.6 Acceptance criteria

* [ ] The economy audit reports zero positive-yield cycles across all items and recipes.
* [ ] Every buy price exceeds its sell price by at least the minimum spread, verified at both extremes of the dynamic band.
* [ ] An order-book match is atomic: kill the server mid-match in testing and confirm no item or Berry is created or destroyed.
* [ ] The trade GUI cannot be exploited by disconnecting, swapping items after confirming, or spam-clicking.
* [ ] The weekly economy report generates and posts automatically.

---

## SECTION 9 - RANK, SEASONS, AND THE ONE CHAMPION

### 9.1 The ranking rule

**Rank is earned by PvP and by nothing else.**

This is the owner's explicit and repeated instruction, and it is the identity of the server. Mining for twenty-four hours a day must not raise rank by a single point. Playtime, money, blocks broken, mobs killed are all tracked and displayed in stats, and none of them affect rank.

    Rank Points (RP) = Combat Rating (CR)

Nothing else feeds in. No activity component, no participation bonus, no weighting. One input.

### 9.2 Combat rating - Elo, with anti-farm protection

Use a standard Elo formulation so beating a strong player is worth far more than beating a weak one:

    E = 1 / (1 + 10 to the power of ((CR_victim - CR_killer) / 400))
    delta = K * (1 - E)
    K = 24
    Starting CR = 1000
    Clamp: minimum +2, maximum +40 per kill

The victim loses a symmetric amount, floored so a player cannot be driven below the bottom of the ladder.

**Anti-farm protections, all mandatory:**

| Exploit | Protection |
|---|---|
| Killing the same player repeatedly | Diminishing returns per pair: 100 percent, then 50, 25, 10, then 0 percent, resetting after 6 hours |
| Alt-account farming | Same-IP and same-payment-source kills award zero RP and raise a staff alert. The paid gate makes alts expensive, which makes this rare, but check anyway |
| Friends trading kills | Detect reciprocal kill patterns between the same pair and zero them, with a staff alert |
| Spawn camping | No RP for kills within a defined radius of spawn or of a player's own respawn point, plus a brief post-respawn invulnerability that ends the instant the player attacks |
| Logging out to avoid a loss | Combat tag: disconnecting while tagged is resolved as a death |
| Inactivity squatting | RP decays 1 percent per week above the tier floor after 7 days of inactivity, so the ladder reflects who is actually playing |

### 9.3 The rank ladder

Ten tiers, each with a name, an RP threshold, a chat prefix, and a cosmetic unlock (Section 11):

Wanderer, Settler, Raider, Fighter, Warrior, Gladiator, Champion, Warlord, Legend, Mythic.

Thresholds live in config, tunable without a code change. Set them from the measured RP distribution after the first season, not from guesswork. The top tier should be genuinely rare.

### 9.4 Monthly reset

**The season resets on the 1st of every month at 00:00 server time.**

* **Soft reset, not a wipe.** Compressing toward the mean keeps the ladder meaningful while giving everyone a real chance:

    RP_new = 1000 + (RP_old - 1000) * 0.35

* The reset job must be **idempotent**. If it runs twice, or the server restarts mid-reset, the outcome is identical. Guard with a database flag on the season row, not with a timestamp comparison.
* **Archive first, reset second.** The full final standings are written to the season archive before anything is modified. Season history is permanent and must be queryable and visible on the website forever.
* **Rewards are granted before the wipe, in the same transaction.** A reset that clears standings before granting rewards is a data-loss bug, and it will happen at midnight when nobody is awake unless you order it correctly.
* What resets: RP, CR, and the seasonal leaderboards.
* **What never resets: Berries, items, homes, claims, cosmetics, achievements, and Hall of Fame entries.** Players must never fear a reset destroying their work.

### 9.5 The countdown campaign

Escalating notifications before reset, starting three days out as the owner specified:

3 days, 2 days, 24 hours, 12 hours, 6 hours, 1 hour, 15 minutes, 5 minutes, 1 minute.

Delivery: chat announcement, title or action-bar flash at the shorter intervals, a scoreboard countdown inside the final day, a website banner, and Discord announcements at the 3-day, 24-hour, and 1-hour marks. Escalate the visual weight as it gets closer, so by the final minute it is impossible to miss. Every message states plainly **what will and will not be lost**.

### 9.6 THE SEASON CHAMPION - exactly one per season

This is a headline requirement from the owner and it deserves to be the centrepiece of the competitive design.

> **At the end of each season, exactly one player is named Champion of LaughTail. Not a top three. Not a podium. One name.**

**How the Champion is decided.** Winning on ladder points alone is anticlimactic - the last week becomes a spreadsheet exercise, and the leader just stops fighting to protect their score. Instead:

1. **The season ladder qualifies you.** The top 32 by RP at the season cutoff earn a place in the Finale.
2. **The Season Finale decides it.** One scheduled event (12.5) produces one winner.
3. **One Champion. One name. No shared titles.** If the format could produce a tie, the format is wrong - build in a decisive sudden-death tiebreak rather than sharing the title.

**What the Champion receives:**

| Reward | Detail |
|---|---|
| **A custom advancement** | Implemented as a **datapack advancement**, granted only to that player, titled with the season, for example "Champion of Season 3". It sits in their advancement tree permanently, it is announced server-wide when granted, and it can never be granted again. This is exactly the custom achievement the owner asked for, and a datapack is the right tool because it is server-side and therefore **also visible to Bedrock players through Geyser**. |
| **A permanent title** | A unique chat and tab prefix marking them as a past Champion, kept forever, through every future season. |
| **A crown cosmetic** | A visible head-slot cosmetic, Champion-only, never obtainable any other way. |
| **A place in the Hall of Fame** | Name, season number and date carved permanently into the monument at spawn, and listed forever on the website. |
| **A season-exclusive cosmetic set** | Never reissued in any later season. |

**What the Champion does NOT receive:** no Berries, no items, no gear, no stat bonus, no permission, no shop discount, no head start next season. **The prize is glory and nothing else.** This is not a limitation, it is the design. A Champion who begins the next season stronger breaks Law 3, and the reward is more valuable precisely because it cannot be converted into an advantage.

**Implementation notes:** grant the advancement, the title and the crown in a **single database transaction** together with the season archive write. Test the entire path on a fake season before the first real one ends. This code runs once a month, so a bug in it is both highly visible and permanently embarrassing.

### 9.7 The Hall of Fame

A physical monument at spawn plus a permanent website page. One entry per season: the Champion's name, the season number, the date, and their final RP. It grows by exactly one line every month. Within a year it becomes the most-looked-at build on the server, and it is the cheapest retention mechanic in existence, because it makes the competition feel like it has a history.

### 9.8 Stats tracking

Tracked, shown on the stats screen, and available on the website. Rank comes only from PvP, but everything is measured:

| Stat | Notes |
|---|---|
| Player name and rank | Current tier and RP |
| Berries balance | Current |
| Kills, deaths, ratio | Kills are the only stat that feeds rank |
| Killstreak | Current and best ever |
| Mob kills | By type |
| Blocks mined and placed | Informational only |
| Playtime | **Shown in hours until 24, then in days and hours** - as the owner specified |
| Distance travelled | By method |
| Seasons played, best finish | Historical |
| Champion titles held | The stat everyone wants |

All stats persist across seasons. Viewing another player's stats is public. Transparency is part of the fairness reputation.

### 9.9 Acceptance criteria

* [ ] Mining, farming and building for two hours changes RP by exactly zero.
* [ ] Killing the same alt five times yields RP only on the diminishing pattern, then zero.
* [ ] The reset runs twice in a row and produces an identical result.
* [ ] Rewards are granted before archival, verified by killing the server mid-reset and re-running.
* [ ] Exactly one Champion exists per season row, enforced by a database constraint and not by application logic alone.
* [ ] The Champion advancement is visible to a Bedrock client through Geyser.
* [ ] The Hall of Fame monument and web page both update automatically.

---

## SECTION 10 - THE RANK-GATED SHOP

### 10.1 The rule

**The shop is open to everyone. What you may buy depends on your rank.** A brand-new player can buy basic supplies. High-tier gear is unlocked by climbing the ladder, and because rank comes only from PvP, **the shop is unlocked by fighting**.

### 10.2 The eight tiers

| Tier | Name | Unlocked at | Contents |
|---|---|---|---|
| 1 | Basics | Everyone | Food, wood, stone, torches, basic tools, boats |
| 2 | Settled | Settler | Building blocks, iron tools, chests, minecarts |
| 3 | Combat starter | Raider | Iron armour, shields, bows, basic potions |
| 4 | Geared | Fighter | Diamond gear, low-tier enchanted books, golden apples |
| 5 | Veteran | Warrior | Netherite scrap, strong potions, ender chests |
| 6 | Elite | Gladiator | Netherite gear, high-tier enchants, shulker boxes |
| 7 | Champion | Champion | Rare blocks, beacons, elytra, top-tier consumables |
| 8 | Legendary | Legend and Mythic | Prestige and decorative rarities. **Cosmetic and status only - nothing here confers combat power.** |

### 10.3 Implementation rules

* **Show locked items greyed out, never hidden.** A visible lock labelled "Unlocks at Warrior" is a goal. A hidden item is just an absence. This one UI choice is worth real retention.
* **Enforce server-side, in the transaction layer.** The GUI is a picture of the rules; the check happens when money moves. Assume a modified client will try to buy a Tier 8 item at Tier 1 on day one, because it will.
* **Selling is never gated.** A new player must be able to sell anything they find from their first minute. Gating income would strangle new players; gating spending creates aspiration. Only buying is tiered.
* Tier definitions live in config, editable without a code change.
* A command shows the full tier ladder with the player's current position.

### 10.4 What happens to shop access at the monthly reset

This is an **open decision for the owner** (Section 24). Three options, all implemented behind one config key:

| Option | Behaviour | Effect |
|---|---|---|
| keep_peak | Keep the highest tier ever reached | Most forgiving. Risk: after a year everyone is Tier 8 and the system stops mattering |
| **drop_one (default)** | Drop exactly one tier at reset | Keeps progression meaningful without feeling punishing. **Recommended.** |
| full_reset | Back to Tier 1 every month | Most competitive and harshest. May drive off casual players |

Default to drop_one. It is trivially changeable once the owner has seen real player reaction.

---

## SECTION 11 - COSMETICS, AND THE ANIMATION QUESTION ANSWERED

The owner asked directly: should we keep animated cosmetics, or remove them if they hurt smoothness? Here is the complete answer.

### 11.1 The key technical fact

**Not all animation costs the server anything.** There are two fundamentally different kinds, and confusing them is why people believe cosmetics always cause lag.

| Type | Where the work happens | Server cost | Verdict |
|---|---|---|---|
| **Resource-pack texture animation** - a cape or elytra texture cycling through frames | Entirely on the **player's own GPU**. The server sends the item once; the client animates it forever. | **Zero. Literally none.** A resource pack hooks into Minecraft's existing rendering system; the server is not involved per frame. | **Keep. Unconditionally.** |
| **Server-side particle effects** - trails, wings, auras | The **server** computes positions and sends packets to every nearby viewer, every time it runs | Real CPU and real bandwidth, scaling with players multiplied by viewers multiplied by particle count | **Keep, but strictly budgeted and auto-degrading** |

**So the answer is: keep the animations.** The animated capes and elytra - the ones that look most impressive - are exactly the ones that are free. The particle effects do cost something, so they get a hard budget and an automatic off-switch under load (6.6). Nothing needs to be removed.

### 11.2 Honest capability limits - never oversell these

State these plainly to the owner and on the website. Promising them and failing is worse than not offering them.

1. **No server can grant a real Minecraft cape.** Capes are an account-level Mojang entitlement. No plugin, no datapack, no permission can create, grant or transfer one. What servers actually do is render a **cape-like model in the player's back slot** through a resource pack. It looks like a cape to everyone who has the pack. It is not a Mojang cape and never can be.
2. **Animated elytra textures generally require a client-side mod** from the entity-model or texture-features family. Vanilla clients will see a static texture. Design the ladder so the static version already looks good and treat animation as a bonus for those who have the mod.
3. **Geyser does not convert Java resource packs.** Bedrock players will not see pack-based cosmetics unless you build a separate Bedrock pack. **Particle-based cosmetics work everywhere including Bedrock**, because particles are game state rather than pack content. That makes particles the inclusive choice even though they cost more.
4. **Never force a resource pack.** Locking a paying player out of the server because a texture download failed is unacceptable. The pack is optional and the server must be fully playable without it.

### 11.3 The cosmetic ladder

Earned by rank. One meaningful unlock per tier, so every promotion is visible to everybody:

| Rank | Cosmetic unlock |
|---|---|
| Wanderer | None. The blank slate makes the first unlock feel like something |
| Settler | Chat prefix, custom join message |
| Raider | Particle trail, three styles |
| Fighter | Static cape model, footstep effect |
| Warrior | Particle wings, static elytra skin |
| Gladiator | **Animated cape** |
| Champion | Animated wings, kill effect |
| Warlord | Animated cape variants, death effect |
| Legend | Full animated set, name glow |
| Mythic | Season-exclusive set, **never reissued in any later season** |
| **Season Champion** | Crown plus the season-exclusive Champion set (9.6) |

### 11.4 The two unbreakable cosmetic rules

1. **Cosmetics are earned, never sold.** Not for Berries, not for money, not ever. They are the visible proof of what a player achieved. The moment they are purchasable they stop meaning anything - and on a paid-access server, selling them would also break Section 3.2.
2. **Cosmetics are kept forever.** They survive every monthly reset. A player who reaches Gladiator in Season 2 still has that animated cape in Season 20. This is what makes chasing them worthwhile, and it is the counterweight that makes a monthly reset feel acceptable rather than punishing.

### 11.5 The particle budget - hard numbers

| Constraint | Value |
|---|---|
| Particle spawn interval per cosmetic | No faster than every 4 ticks |
| Maximum particles per player per tick | Capped and configurable |
| Viewer radius | Limited, so a crowd does not multiply cost quadratically |
| Effects visible per player at once | One trail plus one wing set. Never a stack |
| During war events | Particle cosmetics **off by default** for everyone. Announce it as an anti-lag measure, not a punishment |
| Under MSPT pressure | Automatically reduced, then disabled, by the watchdog (6.6) |

Particles must be dispatched **asynchronously wherever the API permits**, and never inside a synchronous per-entity loop over all online players.

### 11.6 Acceptance criteria

* [ ] Cosmetics cost zero Berries and zero money, verified by grepping for any purchase path.
* [ ] Cosmetics survive a full season reset.
* [ ] Twenty players wearing maximum cosmetics adds under 2 ms MSPT, measured and recorded.
* [ ] The watchdog disables particles under load and re-enables them on recovery.
* [ ] The server is fully playable with the resource pack declined.
* [ ] A Bedrock player sees particle cosmetics correctly.

---

## SECTION 12 - THE COMPETITIVE LAYER: WAR EVENTS AND THE FINALE

The owner described it as: players prepare, then a large organised fight, lose two or three times and you are out, culminating in something like a dragon fight. Very competitive. Here is that, made buildable.

### 12.1 Three layers of competition

| Layer | Frequency | What it is |
|---|---|---|
| **Open-world PvP** | Always | The baseline. Any fight anywhere feeds RP |
| **War Events** | Weekly or fortnightly, scheduled | Organised elimination battles with a preparation phase |
| **Season Finale** | Once a month, end of season | Decides the single Champion (9.6) |

### 12.2 War Event format

1. **Announcement and prep window, 48 hours by default.** Players know the time. They farm, gear up, form alliances and plan. **The preparation phase is the event** for many players - it drives a burst of economy activity and coordination every single cycle. Do not shorten it.
2. **Sign-up** closes shortly before the start. Publish the roster.
3. **The fight.** All participants enter the arena world. Each player has **3 lives**. Lose all three and you are out of this event.
4. **Winner:** the last player or team standing.

**The correction that matters, and it is important:** elimination is scoped to **the event, not the season**. A player knocked out of one War Event plays in the next one, and the next. Locking someone out for weeks because they lost three fights would be the fastest possible way to lose a paying player - and on a paid server that is a refund request and a bad review. The drama of elimination stays; the punishment does not extend past the event.

### 12.3 Hard mechanical requirements

| Requirement | Why |
|---|---|
| **Disconnecting counts as losing a life** | Otherwise force-quitting is the optimal play at one life remaining |
| Deterministic seeded spawn placement | No advantage from spawn luck, and reproducible for dispute review |
| Full inventory snapshot on entry, restored on exit | Nobody loses their survival inventory to an event bug |
| Arena regenerates between events, scripted | No residual advantage from the previous fight |
| Spectator mode for eliminated players | Keeps the audience engaged, which is half the value of an event |
| Every kill, death and life loss logged with a timestamp | Disputes get settled with data, never with memory |
| Event caps: **20 to 24 now, 40 after the first migration, 60 at full scale** | Set from the measured load test, never from ambition |
| Cosmetic particles off during events | Protects the tick budget exactly when it matters most |
| **No betting or wagering of any kind** | Section 3.5. The previously specified war betting command is removed from this design |

### 12.4 If the arena costs too much

On 2 cores, sixty players in one arena is not achievable, and the owner has accepted this. Mitigations in order of preference:

1. Cap the event at the measured number. A great 20-player event beats a stuttering 60-player one.
2. Run the arena in a separate world with reduced view and simulation distance.
3. Disable all cosmetics, holograms and non-essential scheduled tasks during the event window.
4. **After migration:** move the arena to a **separate server instance behind a Velocity proxy**, so an event can never affect the survival world at all. This is the correct long-term architecture and is why Velocity appears in the Tier 3 roadmap.

### 12.5 The Season Finale

Once a month, deciding one Champion:

1. **Qualification:** top 32 by RP at the season cutoff.
2. **Bracket:** double elimination, so one unlucky fight does not end a strong player's season. Published bracket, scheduled times, spectators welcome.
3. **The final stage - the dragon.** The last remaining players face the Ender Dragon **while still able to fight each other**. Whoever lands the killing blow and survives is Champion. This is a genuinely excellent finale: dramatic, legible to spectators, with precedent in the largest Minecraft events, and the cooperate-or-betray tension in the final minutes will be the best content the server produces all month.
4. Tie-break by sudden-death duel. **There is exactly one Champion.**
5. Record everything. The Finale is the server's marketing material - the clips from it are what recruit next month's players.

### 12.6 Acceptance criteria

* [ ] Disconnecting at one life results in elimination, verified.
* [ ] An eliminated player can immediately play normal survival and can join the next event.
* [ ] Inventories are perfectly restored on event exit, including after a crash mid-event.
* [ ] MSPT stays under 40 ms at the configured event cap with combat active.
* [ ] Arena regeneration leaves no blocks, items or entities from the previous event.
* [ ] Exactly one Champion is produced, and the tie-break path has been tested.
* [ ] No betting or wagering command exists anywhere in the codebase.

---

## SECTION 13 - VOICE CHAT

New requirement from the owner: voice chat in game. This section exists because the naive answer ("install the voice plugin") quietly excludes a large fraction of the playerbase, and because the voice port is the single most commonly broken thing in a server migration.

### 13.1 The core problem

Minecraft has no native voice chat. Every solution is an add-on, and they split into two families with a real trade-off:

| Approach | Who can use it | Audio quality | Cost to players | Cost to us |
|---|---|---|---|---|
| **Mod-based proximity voice** (the Simple Voice Chat family) | Java players **who install a client mod**. Bedrock players cannot. | Best. Proper spatial audio, noise suppression, Opus codec | A one-time mod install | A server plugin plus one open UDP port |
| **Browser-based proximity voice** (the OpenAudioMc family) | **Everyone**, Java and Bedrock, with no install at all | Good, not as good | Keep a browser tab open | A server plugin plus a dependency on an external web service |
| **Discord voice** | Everyone with Discord | Excellent, but not positional | Nothing | Nothing at all |

### 13.2 The decision

**Build all three, in this order, and let players choose.** This is the only answer that respects Law 3, because a voice system available to only some paying players is an unequal feature.

1. **Discord voice channels first.** Zero cost, zero risk, works today, works for everybody, and you should have a Discord anyway. Ship this on day one by simply creating the channels.
2. **Mod-based proximity voice as the flagship experience.** This is what players actually want in a survival server - hearing footsteps and voices getting louder as someone approaches is a genuinely transformative feature for both immersion and PvP tension.
3. **A browser-based bridge so Bedrock and unmodded players are not excluded.** There are Geyser bridge extensions that put Bedrock players into the same proximity voice through a web interface with no client mod. Treat these as promising but young: several are explicitly in development, and at least one warns that its audio is **not fully encrypted** and must be run behind an HTTPS proxy. Evaluate carefully, run it behind TLS, and if it is not stable enough, fall back to option 1 for Bedrock players and say so honestly on the website rather than shipping something broken.

### 13.3 Implementation requirements

| Requirement | Detail |
|---|---|
| **UDP port** | The mod-based voice server needs its **own UDP port**, separate from the game port. The conventional default is 24454. It must be open in the host firewall, in the cloud security group, and in the container port mapping. |
| **UDP cannot be tested with a normal port checker** | UDP is connectionless, so standard TCP port-check tools will report nothing useful. Use the voice plugin's built-in test command, or a UDP-aware tool. Add this to the migration checklist explicitly. |
| **DDoS protection must forward UDP** | Many cheap or free protection layers proxy TCP only. If you enable protection without UDP support, voice chat silently dies. Verify UDP support before choosing a provider. |
| **Bandwidth is a real cost** | Voice is roughly 20 to 32 kbps per active speaker, relayed to every nearby listener - so cost scales with speakers multiplied by listeners. On a provider that charges for egress, this is a measurable line item. Measure it during the load test, and factor it into the migration decision in Section 22. |
| **Cross-mod compatibility** | If you support more than one voice mod, use a server-side bridge so players on different mods can still hear each other. Do not fragment the playerbase into two audio worlds. |
| **Permissions and moderation** | Voice must be moderatable: staff need mute, per-player and global. Voice-based harassment is subject to the same punishment ladder as chat, and the rules must say so. |
| **Opt-in, always** | Nobody is forced into voice. Push-to-talk should be the default over open-mic, both for player comfort and to reduce relayed traffic. |
| **Never a requirement** | No gameplay feature, event or reward may require voice chat. It is an enhancement, never a gate. |

### 13.4 Known limitations to publish honestly

* Java players need a client mod. This is a small hurdle but it is a real one.
* **Lunar Client users are covered** - Lunar supports importing community modpacks, and a well-maintained voice-chat pack for Lunar exists with a one-click install. Document the exact steps on the website, with screenshots, because this is the single most common support question you will get. Note that some HUD icons may not render correctly on Lunar; the functionality still works.
* Bedrock players depend on the bridge, which is newer and less proven than the core plugin.
* Voice traffic is encrypted in transit by the main plugin but the authors do not guarantee its security. Do not promise players that voice is private. Say it is encrypted, not that it is secure.

### 13.5 Acceptance criteria

* [ ] Voice works between two Java clients on the target host, over the public internet, not just on localhost.
* [ ] The UDP port is verified open with a UDP-aware method, and is documented in the port table and the migration checklist.
* [ ] A Bedrock player can either join voice through the bridge, or is clearly told on the website that Discord is their route.
* [ ] Staff can mute a player in voice, and the action is logged.
* [ ] Voice bandwidth is measured under load and recorded in the performance doc.
* [ ] Disabling voice entirely, via one config flag, leaves the server fully functional.

---

## SECTION 14 - RULES, ENFORCEMENT, AND KEEPING THE SERVER CLEAN

The owner's requirement is a **clean server**: no cheating, no gambling, no griefing, no flooding, no scamming. On a paid server this is not just a values statement - it is the product. People are paying for a place where none of that happens.

The guiding principle, repeated from Law 4: **a rule you cannot enforce automatically is not a rule, it is a wish.**

### 14.1 Anti-cheat

Cheating is the fastest way to kill a competitive PvP server, and because rank here comes only from combat, **a single undetected cheater corrupts the entire ladder and therefore the entire season.** This is the highest-stakes system in the document.

* **Install a modern simulation-based anti-cheat.** The strongest free option runs its checks on network threads rather than the main server thread, which means it does **not** cost you tick time - a genuinely important property on 2 cores. It is open source, actively maintained, and supports a wide range of client versions.
* **Know the gap:** the leading free option is strongest on **movement** checks (flight, speed, reach, timer) and weaker on **combat** heuristics such as kill aura. The standard professional answer is to pair a movement-focused anti-cheat with a combat-focused one. Start with the free movement anti-cheat, monitor false positives and cheat reports for one full season, and add a paid combat layer only if real evidence shows you need it. Do not buy anti-cheat you have not proven you need.
* **Tune before you enforce.** Run in alert-only mode first. Watch the alerts against known-good players. False positives that punish honest players will cost you more paying customers than the cheaters would have.
* **Never auto-ban on a single flag.** Auto-flag, auto-alert, and require a human decision plus recorded evidence for a permanent ban.
* **Remember the structural advantage (3.7):** here, a banned cheater must buy a new game account *and* pay the access fee again. You can afford to be strict.
* Log every violation with the player, check, certainty, and timestamp, into the database, retained for the season.

### 14.2 Anti-grief, in three layers

**Layer 1 - Prevention.** Claims (7.3), protected spawn and arena regions, fire tick off, mob griefing off, TNT and end-crystal limits near claims, and bucket restrictions near other players' claims. Note that region plugins have a performance-sensitive setting for high-frequency flags such as fluid and fire flow - enable it deliberately and measure the cost. Some destruction cannot be cleanly rolled back afterwards, which is exactly why prevention comes first.

**Layer 2 - Evidence.** Full block logging, on the database, from day one. The investigation workflow is: inspect, then look up the history, then **preview the rollback**, then apply it, with an undo available. **The preview step is mandatory** - an unpreviewed rollback on a shared build is how staff cause more damage than the griefer.

**Layer 3 - Restricted repair rights.** Rollback and restore are an **item-duplication vector** and historically the most abused staff tool on survival servers. Therefore:

> **Rollback, restore and log-purge are Owner-only.** Admins get preview only. These permission nodes appear on the never-grant list in Section 17.

### 14.3 Flooding - the owner said one word, and it is three different problems

| Problem | What it looks like | Defence |
|---|---|---|
| **World flooding** | Water and lava buckets used to destroy terrain and builds; fire spread; TNT at spawn | Region flags denying water flow, lava flow, fire spread, lava fire, TNT and creeper explosions in protected areas; fire tick off globally; bucket limits near others' claims |
| **Chat and command flooding** | Spam, caps, repeated messages, advertising, command spam | Rate limits per player, similar-message detection, caps filter, link and IP filter, escalating automatic mutes, and a first-join restriction such as requiring the player to move before chatting |
| **Packet flooding and crash exploits** | Malformed or high-volume packets, book and sign exploits, login-bot storms | Packet-level protection and rate limiting. **This is a launch blocker, not a nice-to-have** - a single crafted packet flood can hard-crash a server, and a JVM profiler cannot even see it (6.3) |

### 14.4 The published punishment ladder

Publish this exactly, in all three places (14.6). Players accept strict enforcement when it is predictable; they revolt against enforcement that looks arbitrary or personal.

| Offence | First | Second | Third |
|---|---|---|---|
| Chat spam or caps | Auto-mute 10 min | Mute 1 hour | Mute 24 h |
| Advertising another server | Mute 24 h | Ban 7 d | Permanent |
| Minor griefing | Warning plus rollback | Ban 3 d | Ban 30 d |
| **Heavy griefing or flooding** | **Ban 7 d plus full rollback** | **Ban 30 d** | **Permanent** |
| Scamming another player | Ban 7 d plus restitution where possible | Ban 30 d | Permanent |
| **Gambling, running or organising** | Warning plus confiscation of proceeds | Ban 7 d | Ban 30 d |
| **Cheating or unfair client mods** | **Ban 30 d plus full season RP reset to floor** | **Permanent** | - |
| Duplication or economy exploiting | Permanent, plus economy correction | - | - |
| Ban evasion | Permanent on all known accounts | - | - |
| Harassment, hate speech, threats | Ban 7 d minimum, staff discretion upward | Permanent | - |

Notes that must accompany the table: **bans are not refunded** (state this before purchase, per 3.8); **evidence is required before any ban** - an anti-cheat flag or a block-log entry, never a hunch; and every punishment is logged with the issuing staff member's name, permanently and reviewably.

### 14.5 Rules acceptance - the ban-proofing step

On first join, before the player can move, build or chat, they must accept the rules. Store the **acceptance timestamp and the rules version** in the database. Combined with the store's ToS checkbox (3.8), this makes "I never agreed to any rules" an argument that cannot be made. It takes ten minutes to build and saves every future appeal argument.

When the rules change materially, increment the version and re-prompt.

### 14.6 Rules in three places, never drifting apart

The rules exist in exactly three places, and they must be **identical, word for word**:

1. **The website** - the canonical source (Section 18).
2. **In game** - a rules GUI, plus the physical board at spawn.
3. **Discord** - a pinned, locked channel.

Add a verification step to the release checklist: diff all three. A player who finds a contradiction between two versions of the rules has just won every appeal argument they will ever make.

### 14.7 Reporting and appeals

* **In-game reporting**, with the block-log context around the incident **auto-attached** to the report. A report that arrives with evidence already gathered is a report a small staff team can actually action.
* A way for the reporter to check status, so reports do not feel like shouting into a void.
* **Exactly one appeal route** - a Discord form or ticket bot. Do not build a forum; nobody will use it, and it becomes an abandoned page that makes the server look dead.
* Publish the expected response time and then meet it. On a paid server, an unanswered appeal is a chargeback waiting to happen.

### 14.8 The AFK and auto-farm policy - write it down before it becomes an argument

Every survival server eventually has this fight, and having no published position is what makes it toxic. Decide and publish: whether AFK fishing or mob farms are permitted, whether auto-clickers or macros are permitted (recommendation: **no**, since rank is combat-based and macro use in combat is indistinguishable from cheating), and what the AFK kick timeout is. Since rank cannot be farmed anyway (9.1), you can afford a relaxed stance on economy AFK - but say so explicitly rather than leaving it ambiguous.

### 14.9 Plugins versus datapacks - the division of labour

The owner asked for both. Use each where it is genuinely better:

| Use a **datapack** for | Use a **plugin** for |
|---|---|
| Custom recipes | Permissions and ranks |
| Custom advancements, including the Champion achievement (9.6) | Currency and the economy |
| Loot tables and predicates | Punishments and moderation |
| Gamerule and world behaviour tweaks | Anti-cheat |
| Anything that should reach **Bedrock players through Geyser** with no download | Anything that runs every tick |

**Rule of thumb:** if a datapack and a plugin can both do the job, the plugin wins - it is easier to secure, easier to reload, and easier to profile. Never put permissions, currency, punishment or tick-heavy logic in a datapack.

### 14.10 Acceptance criteria

* [ ] A non-trusted player cannot break a block or open a container inside a claim - but **can** kill the owner there.
* [ ] Fire and lava do not spread across a protected region boundary.
* [ ] 200 chat messages per second from one account results in an automatic mute, with MSPT unaffected.
* [ ] A packet-abuse test suite does not crash or degrade the server.
* [ ] A full grief incident is rolled back inside five minutes using the documented workflow.
* [ ] An attempted rollback-based duplication fails and raises an alert.
* [ ] A new player cannot move, build or chat before accepting the rules, and the acceptance is recorded with a version.
* [ ] A report reaches Discord with block-log evidence attached automatically.
* [ ] The punishment ladder is identical, word for word, in all three locations.
* [ ] Anti-cheat catches a test flight and a test reach cheat, and logs both with evidence.

---

## SECTION 15 - HOMES, TELEPORTS, AND QUALITY OF LIFE

### 15.1 Homes

The owner's requirement: **up to 20 homes, renameable, and the ability to teleport from one home directly to another.**

| Rule | Detail |
|---|---|
| Base allowance | Every player starts with the same number of homes. **The same number for everyone** - Law 3. No rank and no payment increases it. |
| Growth to the cap | Additional slots up to **20** are bought with **Berries**, at an escalating in-game cost. This makes home slots a money sink (8.5) rather than a privilege. |
| Hard cap | 20. Enforced in code, not just in config. |
| Rename | Full rename support, with sensible name validation - length limits, no colour codes in the stored key, no duplicate names per player. |
| **Home to home** | Teleporting directly from one home to another is supported. This is explicitly requested; do not treat it as an edge case. |
| Listing | A clear list command and a clickable GUI, showing name, world and coordinates. |
| Deletion safety | Deleting a home asks for confirmation. Players will misclick, and an accidentally deleted home in a 6,000-block world is a genuinely lost base. |

**Data integrity requirement:** homes live in the **database**, not in a flat file. They must survive a container rebuild and a VPS migration untouched. Homes are one of the two things players would rage-quit over losing; the other is their balance.

### 15.2 Teleport commands for everyone

All of these are available to every player at the same allowance:

| Command family | Behaviour |
|---|---|
| Teleport request | Ask to teleport to a player. Timeout, accept, deny, and cancel. |
| Teleport-here request | Ask a player to come to you. |
| **Auto-accept toggle** | Auto-accept requests from friends or party members only, or from nobody. Never a blanket auto-accept from everyone - that is a trap on a PvP server, and someone will exploit it within a week. |
| Random teleport | Randomly teleport within the current world, with a per-world cooldown. **Must be safe:** never into lava, void, water, a wall, or another player's claim. Pre-generate candidate locations asynchronously; a synchronous safe-location search is a classic tick spike. |
| To the surface | Teleport to the highest safe block above your position, with a cooldown. Purely quality of life, and much loved. |
| Back to spawn | Return to spawn. |
| Back | Return to your previous location - **but never after a PvP death** (see 15.4). |

### 15.3 Why there is no plain teleport command for players

> **Deliberate exclusion.** Players never get a direct, unconsented teleport to another player. On a PvP server with a combat-based ranking system, instant travel to any player's exact coordinates is an assassination tool and a base-finding tool. Every teleport between players must be **consented** through a request, or must be staff-only. This is not an oversight and must not be "fixed" later by a well-meaning contributor.

### 15.4 Teleport guards - all mandatory

| Guard | Reason |
|---|---|
| Warmup delay before teleporting, cancelled by movement or damage | Stops teleport-as-escape from a losing fight. This single rule preserves the integrity of open-world PvP |
| Blocked entirely while combat-tagged | Same reason, absolute |
| Cooldown after arriving | Prevents teleport-spam harassment |
| **Back is disabled after a PvP death** | Otherwise a killed player instantly returns to the fight, or to their dropped items. This removes the entire meaning of dying |
| Blocked into another player's claim without trust | Prevents claim-bypass raiding |
| Blocked into the arena world outside an event | Prevents pre-positioning |
| All teleports rate-limited server-wide | A chunk-loading teleport is one of the most expensive things a player can do; unrestricted teleporting is a load-generation exploit |

### 15.5 Other quality-of-life features

Keep this list short. Every one of these is a feature to maintain, and Law 2 says minimal and finished beats broad and half-working.

| Feature | Notes |
|---|---|
| Personal vaults | A small number of extra storage pages, identical count for every player |
| Ender chest access | Standard convenience |
| Crafting, anvil and grindstone access | Standard convenience |
| Item repair | **Costs Berries**, and is a sink. Never free and never unlimited |
| Nickname | Colour allowed, **impersonation of another player or of staff is not**. Enforce a similarity check against existing names |
| Hat | Wear a block on your head. Free, harmless, popular |
| Night vision toggle | Cosmetic convenience only. **Never combat-relevant** - it must be disabled while combat-tagged, or it is a real advantage in dark fights |
| Deterministic reward chest | See 3.5. A **published, visible** reward list. No randomised paid boxes, ever |
| AFK marker | Automatic, plus a manual toggle |
| Kits | Only a starter kit and, at most, a modest daily kit, identical for everyone |

### 15.6 Explicitly excluded, and why

| Excluded | Reason |
|---|---|
| Flight | Trivialises survival, exploration, and PvP escape |
| Heal, feed, god mode | Direct combat advantage |
| Player-accessible gamemode changes | Creative mode on a survival economy server is an infinite item duplicator |
| Player-accessible item spawning | Same |
| Free unlimited repair | Removes a needed money sink |
| Direct teleport to a player | 15.3 |
| Back after a PvP death | 15.4 |

These are excluded for **everyone**, at every rank, forever. There is no tier at which a player can buy their way into any of them. That is the entire point of Law 3.

---

## SECTION 16 - THE IN-GAME SETTINGS MENU

### 16.1 What the owner asked for, and the honest technical answer

The owner described the Minecraft pause menu - the escape-key screen with Back to Game, Advancements, Statistics, Multiplayer, Options, and on Lunar Client an extra Lunar Options entry - and wants a LaughTail entry there.

**The honest answer, which was given before and is repeated here because it constrains the design:** a Minecraft server **cannot add arbitrary buttons to the vanilla pause menu.** That menu is client-side. Options are either compiled into the client, or added by a client mod. The Lunar Options button exists because Lunar is a modified client. No plugin, on any server, can put a button there for a vanilla player.

What the server *can* do is provide the same thing through a surface every client can reach.

### 16.2 The design: one command, three aliases, one GUI

Build a **settings GUI** opened by a settings command, with **menu and options as aliases**, because those are the words players will instinctively try.

This GUI is the LaughTail control panel and it should feel like a real settings screen, not a plugin menu: clear categories, obvious toggles, current values visible at a glance, and no dead ends.

| Category | Contents |
|---|---|
| **Profile** | Your rank, RP, position on the ladder, season standing, Champion titles held |
| **Cosmetics** | Equip, unequip, dye, preview. Locked entries visible and labelled with their unlock rank |
| **Homes** | List, teleport, rename, delete, buy a slot |
| **Notifications** | Toggle join and leave messages, death messages, event announcements, season-countdown pings |
| **Chat** | Global chat on or off, private message toggle, ignore list |
| **Teleports** | Auto-accept mode, request notifications |
| **Voice** | Voice on or off, push-to-talk or open-mic, volume, per-player mute (Section 13) |
| **Display** | Scoreboard on or off, action-bar info, hologram visibility, **particle density** - which doubles as a player-side performance control |
| **Stats** | Full personal statistics (9.8) |
| **Server** | Rules, how the ranking works, the season countdown, the Hall of Fame, and links to the website and Discord |

### 16.3 Rules for the menu

* **Every setting is reachable from this one GUI.** No setting may be available only through a chat command, and none may be available only through one particular client.
* **All preferences persist in the database**, per player, surviving restarts and migrations.
* **Sensible defaults for new players.** A brand-new player should never need to open this menu to have a good first session.
* **If the owner uses Lunar Client**, integrating with its server-side API is a legitimate **bonus** - it can offer things like server-controlled waypoints and cooldown displays for Lunar users. But it is strictly additive. **No feature, and no setting, may be reachable only through Lunar.** Anything else silently splits the playerbase into first and second class, which breaks Law 3.
* Keep the GUI cheap: build the inventory once per open, never on a repeating task, and never hold a per-player scheduled task open for a menu that is closed.

---

## SECTION 17 - PERMISSIONS: THE OWNER AND ADMIN SPLIT

### 17.1 The staff ladder

Default, Helper, Mod, SrMod, Admin, Owner, Console.

The owner's instruction is explicit: **the Owner has every power. The Admin has meaningfully less - they can manage the server and nothing else.** "Nothing else" is interpreted, correctly, as: an Admin can run the server day to day, but cannot touch the things that could destroy the server, corrupt the economy, or hide their own actions.

### 17.2 What each tier gets

| Tier | Scope |
|---|---|
| **Helper** | Answer questions, inspect block logs read-only, mute and kick short durations, claim and view reports, teleport to coordinates |
| **Mod** | Everything above, plus temporary bans, teleport to players, close reports, voice mute, inventory inspection |
| **SrMod** | Everything above, plus longer bans, ban appeals review, punishment history review, ability to overturn a junior's punishment |
| **Admin** | Everything above, plus **server management**: start and stop events, manage the arena, reload LaughTail config, manage claims administratively, grant and revoke cosmetics, adjust shop tiers, world management, **preview** rollbacks, permanent bans |
| **Owner** | Everything. Including the never-grant list below |
| **Console** | Automation only. Scheduled tasks, the reset job, backups. No human uses console as their identity |

### 17.3 The never-grant-to-Admin list

These permissions belong to the Owner and to Console alone. This list exists because every one of these is either a **server-destruction risk**, an **economy-corruption risk**, or an **audit-evasion risk**.

| Never granted to Admin | Why |
|---|---|
| Wildcard permission of any kind | Silently grants everything, including everything on this list, and everything added in future |
| Permission-plugin administration | Whoever can edit permissions can grant themselves everything. This is the single most important line in this table |
| Operator status, granting or removing | Bypasses the entire permission system |
| Stop, restart, or reload the server | An unscheduled restart mid-event is a server-wide incident |
| Plugin management at runtime | Loading or unloading plugins live is both a stability risk and an audit hole |
| Unlimited money, resetting balances, editing prices | Direct economy corruption. One command could end the season's economy |
| **Rollback, restore, or purge block logs** | An item-duplication vector, and purge specifically destroys the evidence trail. **Purge is the most dangerous permission on the server** |
| Backup, restore, or database access | Contains every player's data; restore can roll back the whole world |
| Season management, manual reset or manual Champion assignment | The integrity of the competition depends on this being untouchable by staff |
| World editing on live worlds | One mistyped selection can delete a region of the map |
| Whitelist add and remove | The whitelist **is** the paywall (Section 3). Manual grants bypass payment, which is both revenue loss and a fairness breach |
| Audit-log access and secret access | Staff must not be able to read or edit the record of what staff did |
| Shell access to the host | Bypasses everything above at once |

### 17.4 Staff conduct rules that must be enforced technically

* **Staff play on separate accounts from their staff accounts.** A staff member competing on the ladder with access to staff tools is an unresolvable fairness problem, and on a paid server it is a refund-generating scandal. Enforce it: the staff account cannot earn RP.
* **All staff actions are logged, permanently, to the database**, including who, what, when, and to whom - and staff cannot delete these logs.
* **Two-person rule for permanent bans** where possible: one issues, one reviews.
* **Rotate every credential when a staff member leaves.** Every one, immediately, without exception or discussion.
* Publish the staff list on the website, so players know exactly who has authority and impersonators are easy to spot.

### 17.5 Acceptance criteria

* [ ] An Admin-level test account is denied every single node in 17.3, verified one by one and recorded.
* [ ] Permission inheritance is verified by a test matrix, not by assumption.
* [ ] A staff account earns zero RP from a kill.
* [ ] Every staff action appears in the audit log, and a staff account cannot delete from it.

---

## SECTION 18 - WEB PRESENCE AND THE STORE

### 18.1 The rule that comes before everything else in this section

> **Never host the website on the game VPS.**

On 2 cores this is not a preference, it is a hard rule. A web server competes for exactly the CPU the game needs, and worse, a public website is the natural target for a traffic flood. If the site and the game share a machine, then **anyone who floods the website has also lagged the game.** Separate them and that attack is impossible.

Use free or near-free static hosting on a separate platform. This is both faster and safer than anything self-hosted, and it costs nothing.

### 18.2 What the site must contain

| Page | Purpose |
|---|---|
| **Home** | What LaughTail is, in one screen. Live player count and server status |
| **Store** | The **only** thing sold is access (3.6). One price, for everyone |
| **Rules** | The canonical rules and the punishment ladder, matching in-game and Discord exactly (14.6) |
| **Terms of Service, Privacy Policy, Refund Policy** | Non-negotiable. Required by payment processors, and your protection in a dispute (3.8) |
| **How to join** | Payment, then whitelist, then connect. With the voice-chat setup guide (13.4) and the resource-pack note |
| **Leaderboards** | Live top RP, top balance, top killstreak, current season standing |
| **Hall of Fame** | Every Season Champion, forever (9.7) |
| **Season history** | Archived final standings for every past season |
| **Live map** | Optional, with the constraints in 18.5 |
| **Status page** | Uptime and current state, hosted externally |
| **Staff list** | Who has authority (17.4) |

Include the non-affiliation statement: LaughTail is not an official Minecraft product and is not approved by or associated with Mojang or Microsoft.

### 18.3 The store to whitelist pipeline - the most important integration in the project

This is the mechanism that makes the paid server actually work, so it must be built with more care than any cosmetic feature.

**The flow:** payment succeeds, then the player's account is added to the whitelist automatically, then they receive a confirmation with connection instructions.

**Requirements:**

| Requirement | Detail |
|---|---|
| **Use an established Minecraft monetisation platform** | Do not hand-roll payment handling. An established platform gives you tax handling, fraud screening, chargeback tooling, and a supported path from a completed purchase to an in-game command |
| **Idempotent grants** | A duplicated webhook must not create two entries or two charges. Key every grant on the transaction ID |
| **Verify the username properly** | Resolve to the account UUID, not the display name. Names change; UUIDs do not. A whitelist keyed on names will break the first time a customer renames |
| **Handle the offline case** | If the server is down when payment completes, the grant must queue and apply on the next start. **Never lose a paid grant** |
| **Handle refunds and chargebacks** | An automatic whitelist removal path, with the policy published in advance |
| **Never expose RCON to the internet** | If the platform integration needs a channel to the server, use its supported method behind the firewall (5.3) |
| **Log every grant and revoke** | With timestamp, transaction reference, and resulting UUID. This log is your answer to every access dispute |
| **Test the entire path end to end before launch**, including a refund | The first real customer must not be the first test |

### 18.4 Leaderboards and stats on the web

* Read from the game database through a **dedicated read-only database user**. The website must be structurally incapable of writing to game data, so that a web compromise cannot become an economy compromise.
* **Cache aggressively**, at least 60 seconds. An uncached leaderboard is a way for the public internet to make the game server do database work on demand.
* Precompute rankings on a schedule, not on page load.

### 18.5 The live map, and its one real risk

A live web map is excellent marketing and is genuinely popular. It has one non-obvious problem:

> **A live map showing player positions is a real-time intelligence feed for raiders and for PvP hunting.**

Rules:

* **Player markers off by default.** Show the world, not the people.
* **Player markers must be forcibly disabled during War Events and the Season Finale.** Otherwise the map becomes a wallhack that spectators can relay to competitors, and the integrity of the Finale - and therefore of the Champion title - is compromised.
* Render on a schedule, at low priority, and **never during an event window**. Map rendering is disk and CPU heavy.
* If it costs measurable MSPT after tuning, turn it off. It is marketing, and Law 1 says consistency wins.

### 18.6 Discord

Discord is where the community actually lives; the website is where it is advertised.

* Two-way chat relay between in-game and one channel, with rate limiting on both directions.
* Automatic announcements: season countdown, reset complete, **the new Champion**, War Event schedules, and downtime notices.
* Automated staff alerts: anti-cheat flags, economy anomalies, the MSPT watchdog (6.6), and backup failures. **Alerts go to a private staff channel, never to a public one** - a public alert feed tells cheaters exactly which checks fire and which do not.
* Voice channels, live from day one (13.2).
* Appeals and reports via a form or ticket bot (14.7).
* Account linking, so a Discord identity maps to a Minecraft UUID. This is also how you handle support for a player who cannot log in.

### 18.7 Acceptance criteria

* [ ] The website is not served from the game host, verified by DNS and by IP.
* [ ] A test purchase results in an automatic whitelist grant within one minute.
* [ ] A duplicated payment webhook produces exactly one grant.
* [ ] A purchase made while the server is offline is applied on next start.
* [ ] A test refund removes access, and the removal is logged.
* [ ] The website's database user cannot write, verified by attempting a write.
* [ ] Rules text is byte-identical across website, in game, and Discord.
* [ ] Player markers are absent from the live map during a simulated event.
* [ ] RCON is unreachable from outside the host, verified by external scan.

---

## SECTION 19 - THE COMPLETE COMMAND REFERENCE

This section is the authoritative command list. Implement it, then generate the player-facing help text and the website command page **from this list**, so the three can never drift apart.

**Conventions used below:** angle brackets mark a required argument, square brackets mark an optional one. "All" means every player including a brand-new one on their first join.

### 19.1 Essentials - all players

| Command | Aliases | Description |
|---|---|---|
| /help [topic] | /? | Category-based help. Never a flat wall of text |
| /rules | | Open the rules GUI |
| /rules accept | | Accept the rules. Required on first join (14.5) |
| /spawn | /hub, /lobby | Return to spawn |
| /msg (player) (message) | /w, /tell, /pm | Private message |
| /reply (message) | /r | Reply to the last private message |
| /ignore (player) | | Block messages from a player |
| /ignorelist | | View your ignore list |
| /mail | | Offline mail: read, send, clear |
| /list | /online, /who | Online players by rank |
| /ping [player] | | Connection latency |
| /discord | | Discord invite link |
| /website | /site | Website link |
| /store | | Store link |
| /vote | | Voting links |
| /report (player) (reason) | | File a report with auto-attached evidence (14.7) |
| /reportstatus | | Check the status of your reports |
| /appeal | | Link to the appeal form |
| /afk | | Toggle AFK status |
| /suicide | /kill | Kill yourself. **Disabled while combat-tagged**, or it is an escape from a lost fight |

### 19.2 Settings and the menu - all players

| Command | Aliases | Description |
|---|---|---|
| /settings | /menu, /options, /laughtail | **The main control panel GUI** (Section 16) |
| /settings notifications | | Notification toggles |
| /settings chat | | Chat preferences |
| /settings display | | Scoreboard, action bar, holograms, particle density |
| /toggle (feature) | | Direct toggle for any single setting, for players who prefer typing |

### 19.3 Economy - all players

| Command | Aliases | Description |
|---|---|---|
| /balance [player] | /bal, /money | Berries balance |
| /pay (player) (amount) | | Transfer Berries. Taxed above a threshold (8.5). Confirmation required on large amounts |
| /baltop | /balancetop | Richest players |
| /shop | /menu shop | Open the shop GUI |
| /shop tiers | | **View the eight-tier ladder and your current unlock level** (10.3) |
| /sell hand | | Sell the held stack |
| /sell all (item) | | Sell all of one item from your inventory |
| /sell gui | | Sell interface |
| /worth [item] | /value | Current sell and buy price of an item |
| /prices | | Recently changed prices, so dynamic pricing is transparent (8.2) |
| /transactions | | Your own transaction history |

### 19.4 Auction house, orders, and trading - all players

| Command | Aliases | Description |
|---|---|---|
| /auctionhouse | /ah | Browse the auction house |
| /ah sell (price) | | List the held item at a buy-it-now price |
| /ah auction (start) (duration) | | List for bidding |
| /ah bid (id) (amount) | | Place a bid |
| /ah listings | /ah my | Your active listings |
| /ah expired | | Reclaim expired listings |
| /ah search (term) | | Search current listings |
| /ah history | | Your own auction history |
| /order buy (item) (qty) (price) | | **Post a buy order** (8.4) |
| /order sell (item) (qty) (price) | | Post a sell order |
| /order list | /orders | Your open orders |
| /order cancel (id) | | Cancel an order |
| /market [item] | | The order book with current best bid and ask |
| /trade (player) | | **Safe two-sided confirmation trade** (8.4) |
| /trade accept, /trade deny | | Respond to a trade request |

### 19.5 Homes and teleports - all players

| Command | Aliases | Description |
|---|---|---|
| /home [name] | /h | Teleport to a home. **Works from another home** (15.1) |
| /sethome (name) | | Set a home |
| /delhome (name) | | Delete a home, with confirmation |
| /renamehome (old) (new) | /homerename | **Rename a home** (15.1) |
| /homes | /homelist | GUI list of your homes |
| /buyhome | /homeslot | Buy an extra home slot with Berries, up to 20 |
| /tpa (player) | | Request to teleport to a player |
| /tpahere (player) | | Request that a player come to you |
| /tpaccept | /tpyes | Accept a request |
| /tpdeny | /tpno | Deny a request |
| /tpacancel | | Cancel your outgoing request |
| /tpauto (friends / party / off) | | **Auto-accept mode.** Never a blanket accept-from-anyone (15.2) |
| /rtp [world] | /wild | Random safe teleport, per-world cooldown |
| /resource | | Go to the monthly resource world (7.4) |
| /top | | Teleport to the highest safe block above you |
| /back | | Return to your previous location. **Never after a PvP death** (15.4) |
| /warp [name] | /warps | Public warps |

### 19.6 Claims - all players

| Command | Aliases | Description |
|---|---|---|
| /claim | | Claim land at your position |
| /unclaim | /abandonclaim | Release a claim |
| /claim trust (player) [level] | | Grant access at a trust level (7.3) |
| /claim untrust (player) | | Revoke access |
| /claim info | | Claim details and boundaries |
| /claim list | | Your claims |
| /claimblocks | | Your available and used claim allowance |
| /buyclaimblocks (amount) | | Buy claim allowance with Berries |
| /claim visualise | /claim show | Show claim boundaries |

### 19.7 Stats, rank, and season - all players

| Command | Aliases | Description |
|---|---|---|
| /stats [player] | | Full statistics (9.8) |
| /rank [player] | | Current rank, RP, and progress to the next tier |
| /ranks | /rankup | The full ladder and thresholds |
| /leaderboard [category] | /lb, /top rp | Leaderboards |
| /season | | Current season number, standing, and time remaining |
| /season history | | Past seasons and their final standings |
| /season rewards | | What the Champion receives (9.6) |
| /hof | /halloffame, /champions | **Every past Season Champion** (9.7) |
| /kd [player] | | Kill/death ratio |
| /killstreak | | Current and best killstreak |
| /playtime [player] | | **Hours until 24, then days and hours** (9.8) |

### 19.8 Cosmetics - all players, contents rank-gated

| Command | Aliases | Description |
|---|---|---|
| /cosmetics | /cos | Cosmetics GUI. Locked entries shown with their unlock rank |
| /cosmetics equip (id) | | Equip |
| /cosmetics unequip [slot] | | Unequip |
| /cosmetics dye (id) (colour) | | Recolour, costs Berries (8.5) |
| /cosmetics preview (id) | | Preview before unlocking |
| /cape | | Cape selection, Fighter and above |
| /wings | | Particle wings, Warrior and above |
| /trail | | Particle trail, Raider and above |
| /hat | | Wear the held block |
| /pack | | Resource pack info and re-download prompt |

### 19.9 War events and the Finale - all players

| Command | Aliases | Description |
|---|---|---|
| /war | /event | Current or next event info |
| /war join | | Sign up during the window |
| /war leave | | Withdraw before the start |
| /war lives | | Your remaining lives |
| /war roster | | Published participant list |
| /war spectate | | Spectate after elimination |
| /war history | | Past event results |
| /finale | | Finale bracket, schedule and qualification status (12.5) |

> **Deliberately absent: any betting or wagering command.** Gambling is prohibited (3.5). If you find such a command in any earlier draft, delete it.

### 19.10 Voice - all players

| Command | Aliases | Description |
|---|---|---|
| /voice | /vc | Voice settings: on/off, push-to-talk, volume (Section 13) |
| /voice test | | Verify your voice setup works |
| /voice group | | Create or join a voice group |
| /voice mute (player) | | Mute one player for yourself only |
| /voice help | | Setup guide, including the client-mod instructions |

### 19.11 Quality of life - all players

| Command | Aliases | Description |
|---|---|---|
| /craft | /workbench, /wb | Portable crafting |
| /enderchest | /ec | Ender chest access |
| /pv [number] | /vault | Personal vaults, identical count for everyone |
| /anvil, /grindstone | | Portable utility blocks |
| /repair | | Repair the held item, **costs Berries** |
| /nick (name) | | Nickname. **Impersonation blocked** (15.5) |
| /nick off | | Remove nickname |
| /nv | | Night vision toggle. **Disabled while combat-tagged** |
| /kit [name] | /kits | Available kits, identical for everyone |
| /rewards | | **Deterministic daily reward with a published list** (3.5) |
| /seen (player) | | Last-seen time |
| /whois (player) | | Public profile summary |

### 19.12 Helper

| Command | Description |
|---|---|
| /mute (player) (duration) (reason) | Short-duration mutes only |
| /unmute (player) | Remove a mute |
| /kick (player) (reason) | Kick |
| /warn (player) (reason) | Formal logged warning |
| /history (player) | Punishment history |
| /inspect | Toggle block-log inspection mode, read-only |
| /lookup (params) | Block-log lookup, read-only |
| /tppos (x) (y) (z) [world] | Teleport to coordinates |
| /report list, /report claim (id) | Work the report queue |
| /staffchat (message) | Staff-only channel |
| /vanish | Invisibility. **Must be genuinely undetectable**, or it is useless for observing suspected cheaters |

### 19.13 Mod and Senior Mod

| Command | Description |
|---|---|
| /tempban (player) (duration) (reason) | Temporary ban |
| /unban (player) | Lift a ban |
| /tpo (player) | Teleport to a player without consent. **Staff only, always logged** |
| /tphere (player) | Bring a player to you |
| /invsee (player) | Inspect inventory |
| /voice mute (player) (duration) | Server-side voice mute |
| /report close (id) (resolution) | Close a report |
| /freeze (player) | Freeze a player pending investigation |
| /alts (player) | Linked-account check |
| /appeals | Review queue, Senior Mod |
| /overturn (punishment id) | Reverse a junior's punishment, Senior Mod |

### 19.14 Admin - server management only

| Command | Description |
|---|---|
| /ban (player) (reason) | Permanent ban, with the two-person rule (17.4) |
| /war start, /war stop, /war cancel | Event control |
| /war setcap (n) | Set the event player cap |
| /war kick (player) | Remove a player from an event |
| /arena reset | Regenerate the arena |
| /finale start | Begin the Season Finale |
| /shop tier set (player) (tier) | Manual tier override, logged |
| /prices reload | Reload price config |
| /cosmetics grant (player) (id) | Grant a cosmetic, logged |
| /cosmetics revoke (player) (id) | Revoke a cosmetic, logged |
| /claim admin delete | Administrative claim removal |
| /claim admin transfer | Transfer claim ownership |
| /rules reload | Reload rules text |
| /laughtail reload | **Reload our own config. Never the vanilla server reload** (0.3) |
| /world (name) | Move between worlds |
| /tpall, /tphereall | Mass teleport, for events |
| /broadcast (message) | Server announcement |
| /maintenance (on / off) | Maintenance mode |
| /lookup preview | **Rollback preview only. The rollback itself is Owner-only** (14.2) |
| /performance | Live MSPT, TPS, memory, and watchdog state |
| /audit (player) | Staff action history for one player |

### 19.15 Owner only

| Command | Description |
|---|---|
| /rollback (params) | Execute a rollback |
| /restore (params) | Execute a restore |
| /purge (params) | Purge block logs. **The most dangerous command on the server** |
| /eco give, /eco take, /eco set | Direct balance modification |
| /eco reset | Economy reset |
| /season forcereset | Manual season reset |
| /season setchampion (player) | Emergency Champion assignment. Logged loudly, and never used casually |
| /whitelist add, /whitelist remove | **Access control. This is the paywall** (18.3) |
| /whitelist audit | Compare the whitelist against paid transactions. **Run this monthly** - it is how you find both revenue leaks and unauthorised grants |
| /backup now | Trigger a backup |
| /restore backup (id) | Restore from a backup |
| /perms (all subcommands) | Permission administration |
| /op, /deop | Operator status |
| /stop, /restart | Server lifecycle |
| /transfer (player) (target) | Data transfer between accounts, for account-migration support |
| /audit full | Complete audit log |
| /secrets rotate | Credential rotation |

### 19.16 Console and automation only

| Task | Notes |
|---|---|
| Season reset job | Idempotent (9.4) |
| Resource world regeneration | Named world only, never the main world (7.4) |
| Backup jobs | Hourly database, six-hourly world (5.4) |
| Economy audit | Nightly (8.3) |
| Weekly economy report | (8.5) |
| Watchdog actions | (6.6) |
| Whitelist grants from the store | Idempotent (18.3) |
| Restore drill | Monthly (5.4) |

### 19.17 Command implementation standards

* **Every command validates its own permission server-side.** Never rely on the GUI or the tab-completer to enforce access.
* **Every command that costs money or destroys something asks for confirmation**, or has an undo.
* **Rate-limit every command.** Assume every command will be spammed, because it will.
* **Tab completion for everything**, filtered by what the player can actually use.
* **Error messages must say what to do next**, not just what went wrong.
* **Every command responds within 100 ms** (6.1). Anything slower runs asynchronously with an immediate acknowledgement to the player.
* **No command may block the main thread on a database call.** Not one. This is the single most common cause of mysterious lag spikes in plugin code.
* Consistent colour scheme and message prefix across every command, so the server feels like one product rather than a pile of plugins.

---

## SECTION 20 - BUILD PHASES

Build in this order. Do not start a phase before the previous phase's acceptance criteria all pass. The ordering is deliberate: everything that could destroy data or destroy trust comes first, and everything cosmetic comes last.

### Phase 0 - Foundation

Docker Compose stack, all four services. Repository structure. Environment file and its example. Git initialised, secrets ignored. Paper installed and starting cleanly. Database with schema migrations. Backups running and **one restore drill completed**. Monitoring and alerting live. Firewall configured, ports verified externally including UDP.

**Gate:** the server starts from a clean checkout on a fresh machine with one command, and a restore drill has succeeded.

### Phase 1 - Access, permissions, and the paywall

Whitelist enforcement. Store integration end to end, including a test purchase and a test refund. Permission ladder with the full never-grant list verified. Rules acceptance gate. Punishment tooling and the published ladder. Anti-cheat installed in alert-only mode. Packet-level protection.

**Gate:** an unpaid account cannot connect. A paid test account can. An Admin test account is denied every node in 17.3.

### Phase 2 - The world

All five worlds created, borders set, pregenerated with Chunky. Spawn built and protected. Claims configured with the block-not-player rule verified. Resource world with its reset script, **tested against a copy first**. Difficulty and gamerules set.

**Gate:** the resource world regenerates cleanly and cannot touch the main world.

### Phase 3 - Economy

Berries. Shop with the derived price table. The arbitrage audit script, in CI and nightly. Auction house. Order book with atomic matching. Safe trade GUI. All money sinks. The weekly report.

**Gate:** zero positive-yield cycles, and an atomic-match crash test passes.

### Phase 4 - Combat, rank, and seasons

Combat tagging. Elo rating with every anti-farm protection. The rank ladder. Stats tracking. The season reset job, **tested for idempotency and for mid-run failure**. The countdown campaign. The season archive. **The Champion system, including the datapack advancement, tested on a fake season.**

**Gate:** two hours of mining moves RP by zero; the reset is idempotent; exactly one Champion is produced.

### Phase 5 - Shop gating, homes, and quality of life

The eight shop tiers with server-side enforcement. Homes to 20 with rename and home-to-home. All teleports with every guard. The quality-of-life set. The settings GUI.

**Gate:** a Tier 1 player cannot buy a Tier 8 item by any means, including a modified client.

### Phase 6 - Load testing and tuning

The bot load test at 10, 20, 30 and 40. The event scenario. Spark profiles captured and analysed. Config tuned. **The player cap set from the measured number.** The watchdog built and its degradation ladder verified.

**Gate:** MSPT under 25 ms at the chosen cap, and the watchdog demonstrably degrades and recovers.

### Phase 7 - Voice, cosmetics, and events

Discord voice channels. Proximity voice with the UDP port verified over the real internet. The Bedrock path decided and documented. Cosmetics with the particle budget. War events with full state snapshots. The Finale format.

**Gate:** voice works between two real clients; cosmetics cost under 2 ms; an event runs within the MSPT budget.

### Phase 8 - Web, launch preparation

Website on separate hosting. Store live. Legal pages. Leaderboards through the read-only user. Hall of Fame. Live map with markers off. Status page. Discord fully wired.

**Gate:** every acceptance test in Section 21 passes, and the documentation set in 5.6 is complete.

### Phase 9 - Soft launch

A small group of paying players. Watch MSPT continuously. Fix, do not add. Run one full season, including one real reset and one real Champion, before opening more widely.

**Gate:** one complete season with no data loss, no economy exploit, and no unexplained downtime.

---

## SECTION 21 - THE MASTER ACCEPTANCE TEST TABLE

This is the launch gate. **Every row must be marked pass, with evidence, before the first paying player connects.** "Evidence" means a log line, a screenshot, a spark report, a query result, or a recorded number - never an opinion.

Record results in `docs/acceptance.md` with the date, the tester, and the evidence reference.

| # | Test | Pass condition | Evidence |
|---|---|---|---|
| 1 | Cold start | Fresh checkout plus one command brings the whole stack up with no manual steps | Terminal log |
| 2 | Hardcoded values | Grep for IP addresses and absolute host paths across the repo returns nothing | Grep output |
| 3 | Fresh-VPS rebuild | Full stack rebuilt on a brand-new machine in under 30 minutes | Timed log |
| 4 | Restore drill | Backup restored into a scratch environment, world and database intact | Drill log entry |
| 5 | Port exposure | External scan shows only the intended ports; RCON unreachable | Scan output |
| 6 | UDP voice port | Verified open using a UDP-aware method, not a TCP checker | Test command output |
| 7 | Paid gate | An unpaid account is rejected at login | Login attempt log |
| 8 | Store to whitelist | Test purchase grants access within one minute | Transaction plus grant log |
| 9 | Duplicate webhook | A replayed payment webhook produces exactly one grant | Grant log |
| 10 | Offline purchase | A purchase made while the server is down applies on next start | Queue plus grant log |
| 11 | Refund path | Test refund removes access and is logged | Refund log |
| 12 | Whitelist audit | Whitelist matches paid transactions exactly, with zero unexplained entries | Audit output |
| 13 | **No-advantage audit** | No purchasable item, rank, permission, slot, or cosmetic grants any capability another paying player lacks | Written audit against 3.2 |
| 14 | **No-gambling audit** | Repo grep for betting, gambling, crate, key, lottery, spin, casino, wager, stake, coinflip and dice finds no randomised-for-value mechanic, and none of the forbidden commands in 3.5.1 are registered | Grep output plus in-game tab-complete check |
| 14a | **Wagering detector works** | Staged test: two accounts fight, one dies, the loser pays the winner within 60 seconds. The combat-correlated signature fires and appears in the staff alert queue | Alert record with timestamps |
| 14b | **Detector cannot auto-punish** | 20 staged innocent payments (loot splits, loan repayments, instalments) produce zero automated sanctions, and code review confirms no punishment path exists from detector output | Test log plus code review note |
| 14c | **No wagering escrow exists** | Repo grep for escrow and stake-holding logic returns nothing, and `docs/rejected.md` contains the wagering-escrow rejection with its reasoning | Grep output plus the rejection entry |
| 15 | Deterministic rewards | Every reward source publishes its exact contents in advance | Screenshots |
| 16 | Legal pages | Terms, Privacy, and Refund policy are live and linked before any payment is possible | URLs |
| 17 | Rules gate | A new player cannot move, build or chat before accepting; acceptance is stored with a version | Database row |
| 18 | Rules consistency | Rules text is identical across website, in game, and Discord | Diff output |
| 19 | MSPT at cap | Under 25 ms at the chosen player cap under normal play | Spark report |
| 20 | MSPT in event | Under 40 ms at the event cap with combat active | Spark report |
| 21 | Load test | Bot test at 10, 20, 30, 40 completed; cap set from the measured result | Load-test log |
| 22 | **Watchdog degradation** | Induced load triggers each degradation step in order, and recovery restores everything | Watchdog log |
| 23 | Login time | Under 3 seconds from connect to spawn | Timed measurement |
| 24 | Command latency | Every command responds within 100 ms, or acknowledges and runs async | Timing log |
| 25 | Main-thread database calls | No blocking database call on the main thread anywhere | Spark profile plus code review |
| 26 | Economy audit | Zero positive-yield cycles across all items and all recipe chains | Audit output |
| 27 | Price spread | Buy exceeds sell by the minimum spread at both extremes of the dynamic band | Audit output |
| 28 | Atomic order match | Server killed mid-match creates and destroys nothing | Before and after query |
| 29 | Trade safety | Disconnect, item-swap, and spam-click exploits all fail | Test log |
| 30 | Rank purity | Two hours of mining, farming and building changes RP by exactly zero | Before and after query |
| 31 | Anti-farm | Repeat kills follow the diminishing pattern then award zero | RP log |
| 32 | Alt farming | Same-IP kills award zero RP and raise an alert | Alert log |
| 33 | Combat log | Disconnecting while tagged is resolved as a death | Death log |
| 34 | Reset idempotency | The season reset run twice produces an identical result | Two-run comparison |
| 35 | Reset ordering | Rewards granted before archival, verified by mid-reset failure and re-run | Test log |
| 36 | **One Champion** | Exactly one Champion per season, enforced by a database constraint | Schema plus failed-insert test |
| 37 | **Champion advancement** | The custom advancement is granted, announced, and visible to a Bedrock client via Geyser | Screenshots, both platforms |
| 38 | Champion has no power | The Champion gains no Berries, items, stats, permissions or head start | Written audit |
| 39 | Hall of Fame | Monument and web page both update automatically after a season ends | Screenshots |
| 40 | Shop gating | A Tier 1 player cannot buy a Tier 8 item by any means, including a modified client | Test log |
| 41 | Selling ungated | A brand-new player can sell items in their first minute | Test log |
| 42 | Homes | 20 homes reachable, renameable, and home-to-home teleport works | Test log |
| 43 | Home persistence | Homes survive a container rebuild and a simulated migration | Before and after query |
| 44 | Teleport guards | Warmup, combat block, cooldown, and back-after-PvP-death block all verified | Test log |
| 45 | Claims protect blocks | A non-trusted player cannot break blocks or open containers in a claim | Test log |
| 46 | **Claims do not protect players** | A player can be killed inside their own claim | Test log |
| 47 | Fire and flood | Fire and lava do not cross a protected boundary; fireTick is off | Test log |
| 48 | Chat flood | 200 messages per second results in an auto-mute with no MSPT impact | Log plus spark |
| 49 | Packet abuse | A packet-abuse suite does not crash or degrade the server | Test log |
| 50 | Anti-cheat | Test flight and test reach cheats are both caught and logged with evidence | Alert log |
| 51 | Anti-cheat false positives | One full week of normal play produces zero punishments of honest players | Alert review |
| 52 | Rollback restriction | An Admin account cannot execute rollback, restore or purge | Permission test |
| 53 | Rollback dupe | An attempted rollback-based duplication fails and alerts | Test log |
| 54 | Never-grant list | An Admin test account is denied every node in 17.3, checked one by one | Checklist |
| 55 | Staff cannot earn RP | A staff account gets zero RP from a kill | RP log |
| 56 | Audit immutability | Staff actions are logged and a staff account cannot delete them | Test log |
| 57 | Reporting | A report reaches Discord with block-log evidence attached automatically | Discord message |
| 58 | Cosmetics free | No purchase path exists for any cosmetic, in Berries or money | Grep plus review |
| 59 | Cosmetics persist | Cosmetics survive a full season reset | Before and after query |
| 60 | Cosmetic cost | Maximum cosmetics on all players adds under 2 ms MSPT | Spark report |
| 61 | Pack optional | The server is fully playable with the resource pack declined | Test log |
| 62 | Bedrock parity | A Bedrock player can join, play, see particle cosmetics, and use the settings menu | Screenshots |
| 63 | Crossplay versions | The oldest and newest supported client versions both connect and fight | Test log |
| 64 | Voice works | Two Java clients hear each other over the public internet | Recording or screenshots |
| 65 | Voice for everyone | Bedrock and unmodded players have a documented working voice route | Screenshots |
| 66 | Voice moderation | Staff mute in voice works and is logged | Log |
| 67 | Voice off switch | Disabling voice by one flag leaves the server fully functional | Test log |
| 68 | Event integrity | Disconnect at one life eliminates; inventories restore perfectly, including after a crash | Test log |
| 69 | Event re-entry | An eliminated player plays survival immediately and joins the next event | Test log |
| 70 | Arena regeneration | No blocks, items or entities persist from the previous event | Test log |
| 71 | Website separation | The site is not served from the game host | DNS plus IP check |
| 72 | Web database user | The website user cannot write to game data | Failed write attempt |
| 73 | Leaderboard caching | Leaderboards are cached at least 60 seconds | Header or code review |
| 74 | Live map markers | Player markers are absent by default and during a simulated event | Screenshots |
| 75 | Alert routing | Staff alerts go only to a private channel | Channel check |
| 76 | Documentation | Every document in 5.6 exists and is current | File listing |
| 77 | Decision log | Every deviation from this prompt is recorded with its reasoning | Decision log |
| 78 | Migration script | The migration script has been executed successfully at least once, end to end | Migration log |

---

## SECTION 22 - THE MIGRATION RUNBOOK

The owner's plan: build now on a small box, and migrate to a bigger, cheaper VPS once there are players. **This is a good plan.** This section makes it a thirty-minute job instead of a weekend of panic.

### 22.1 The portability contract, restated

Everything in 5.1 exists for this section. Re-read it. If every rule there is honoured, migration is: copy a directory, bring up the stack, change DNS. If any rule is broken, migration is an outage.

### 22.2 How to choose the next host - in priority order

Most people buy on RAM. **That is the wrong metric and it is the most expensive mistake in server hosting.** Minecraft's main thread is largely single-threaded, so the game is bounded by how fast one core runs, not by how many gigabytes are idle.

| Priority | Criterion | Why it comes here |
|---|---|---|
| **1** | **Network latency to your players** | The owner's players are largely in India. A server in Singapore or Mumbai will feel dramatically better than a cheaper one in Germany, no matter how good the specs are. In PvP, latency **is** fairness. Ping decides who wins a fight, and no amount of RAM compensates for 200 ms |
| **2** | **Dedicated vCPU and single-core clock speed** | Shared or burstable vCPUs are the number one cause of unexplained lag spikes. Ask explicitly whether cores are dedicated. After purchase, **measure CPU steal time** - a persistently non-zero steal percentage means the host is overselling and your neighbours are stealing your ticks. Steal time is invisible from inside the game and will drive you mad if you do not know to look for it |
| **3** | **NVMe storage** | Chunk loading and saving is disk-bound. NVMe over SATA SSD is a visible difference when players spread out |
| **4** | **Bandwidth allowance and egress pricing** | Minecraft plus voice plus a live map consumes real bandwidth. Metered egress can quietly cost more than the server itself |
| **5** | **RAM** | Genuinely last. 8 GB on fast dedicated cores beats 32 GB on oversold shared cores, every time. Note from 6.4 that an oversized heap actively **hurts** through longer garbage-collection pauses |
| 6 | DDoS protection **with UDP support** | Required for Bedrock and voice (13.3) |
| 7 | Snapshot and backup features | Convenience, not a substitute for your own backups |
| 8 | Honest support | You will need it once, at the worst possible moment |

### 22.3 Sizing guide

| Concurrent players | vCPU | RAM | Heap | Notes |
|---|---|---|---|---|
| Up to 24 | 2 dedicated | 4 GB | ~2.5 GB | Current box. Adequate for launch |
| 40 to 60 | 4 dedicated | 8 GB | ~6 GB | The realistic first migration target |
| 60 to 100 | 6 to 8 dedicated | 16 GB | ~10 GB | Consider splitting the arena to a second instance behind a proxy |
| 100 plus | 8 plus dedicated | 32 GB | ~12 GB | Multi-instance behind a proxy is now mandatory, not optional. **A single Paper instance does not scale linearly no matter what you buy** |

Note the ceiling in that last row honestly: past roughly 100-150 concurrent players, the answer is never a bigger box. It is more boxes behind a proxy, or a regionalising fork. Plan for that architecture before you need it.

### 22.4 Notes on specific providers

Evaluate at the time of purchase, but these patterns hold:

* **Budget VPS providers with dedicated vCPU plans** are usually the best value for this workload, and are a straightforward step up from the current box.
* **Very cheap European providers** offer extraordinary specs per rupee. The catch for this project is **latency to India**, which no amount of specs fixes. Only consider them if the playerbase is actually European.
* **The cheapest oversold providers** show up as high steal time and unexplained stutter. Their price is real and so is the reason for it.
* **The current cloud provider** is fine for building and is convenient, but its **egress charges** are the strongest argument for moving once player traffic and voice traffic grow. Note that some cloud providers will waive egress fees specifically for a full migration away - if you are moving off, it is worth asking, because that is a discount that exists precisely for this situation.
* **Managed Minecraft hosts** are worth considering only if you want to stop being the sysadmin. They cost more and give less control, and this entire document assumes you keep control.

### 22.5 The evaluation protocol - never migrate on a promise

1. Buy **one month** of the candidate host. One month, not a year, no matter how good the annual discount looks.
2. Deploy the full stack from the repository. If this takes more than 30 minutes, the portability contract is broken - **fix the repository, not the host.**
3. Restore a real backup into it.
4. Measure: CPU steal time, single-core benchmark, disk throughput, and latency from several real player locations.
5. Run the full bot load test (6.8) on the new box. Compare MSPT against the current box at identical player counts.
6. **Only then** decide. If the numbers are not clearly better, you have lost one month's fee and learned something cheap.

### 22.6 The migration procedure

**SUPERSEDED BY SECTION 22.11.** This subsection was written before the Pelican Panel was in the picture and describes a manual full-stack relocation. It is kept only as the conceptual outline, because the ordering logic is still correct. **For the actual procedure, follow 22.11 (node transfer) or 22.12 (full relocation). Where this subsection and 22.11 disagree, 22.11 wins.**

Publish the window at least 48 hours in advance. Never migrate during a season ending, a War Event, or the Finale.

**Preparation, days before:**

1. New host provisioned, firewall configured, Docker installed.
2. Repository cloned; the environment file recreated with **freshly rotated secrets** - never reuse the old ones.
3. Full stack brought up and smoke-tested with a throwaway world.
4. Lower the DNS time-to-live to 60 seconds. Do this **days ahead**, or the low value will not have propagated when you need it.

**Migration day:**

5. Announce, then enable maintenance mode.
6. Stop the game server cleanly. **Never copy a live world directory** - a half-written region file is a corrupted world.
7. Take a fresh full backup and verify its checksum.
8. Transfer the state directory. Verify checksums on arrival.
9. Bring up the new stack. Watch the logs to a clean start.
10. **Verify before switching DNS:** world loaded, database connected, player data intact, a test login works, homes and balances correct, the voice UDP port responds, and the plugin set has no errors.
11. Switch DNS. Keep the old server **stopped but not deleted** for at least 72 hours.
12. Restore the DNS time-to-live to normal after propagation.

**After:**

13. Monitor MSPT for 24 hours and compare against the recorded baseline.
14. Confirm backups are running on the new host, then **run a restore drill there** before deleting the old server.
15. Rotate every remaining credential.
16. Only now destroy the old server.
17. Update the migration document with what actually happened, including anything that surprised you. The next migration will be easier only if you write this down.

### 22.7 Migration acceptance criteria

These are the general criteria. **Section 22.15 adds the Pelican-specific rows, and both sets must pass before the old server is deleted.**

* [ ] The whole procedure completes inside the announced window.
* [ ] Zero player data lost - balances, homes, claims, cosmetics, stats, season standings, Champion records.
* [ ] Voice works on the new host, verified over the real internet with a UDP-aware check.
* [ ] Bedrock connectivity works on the new host.
* [ ] MSPT is equal to or better than the old baseline at the same player count.
* [ ] A restore drill has succeeded on the new host.
* [ ] Every secret has been rotated.
* [ ] The migration document is updated.

### 22.8 What a Pelican backup contains, and what it does not

This is the single most dangerous misconception about migrating this server. **A Pelican backup is not a backup of your service.** It is a `tar.gz` of one server's data directory and nothing else.

| Inside a Pelican server backup | **Not** inside it |
| --- | --- |
| The world folders | **The game database** - Berries, ranks, season history, homes, claims, punishments |
| `plugins/` including every jar and config | **The Panel** and the Panel's own database |
| `server.properties`, `paper-global.yml`, `bukkit.yml`, `spigot.yml` | **The Panel's `APP_KEY`** |
| `datapacks/` | Wings configuration and the node token |
| The server jar | Firewall rules, DNS, cron jobs, systemd units |
| `eula.txt`, `ops.json`, `whitelist.json` | The Pelican egg definition |
| Player data files in `world/playerdata/` | Backup destination credentials |

Restoring a Pelican backup onto a fresh box gives you a folder of files with nothing to run them. **If the game database is not restored alongside it, every Berry balance, every rank, every season record, and every claim is gone** even though the world loads perfectly and looks fine. That failure mode is especially cruel because the server appears to work.

Use Pelican backups for what they are good at: a fast rollback of one server's files on the same infrastructure. Do not mistake them for a migration tool.

### 22.9 The three irreplaceable things

Everything about this server falls into one of two buckets. Knowing which is which is what makes migration a routine job.

| Irreplaceable - must be copied | Regenerated from the repository |
| --- | --- |
| **1. The world folders** (overworld, nether, end, resource world) | Every configuration file |
| **2. The game database dump** (economy ledger, ranks, seasons, homes, claims, punishments, cosmetic unlocks) | Every plugin, from the manifest with version and checksum |
| **3. The Panel's `APP_KEY`**, only if the Panel itself is moving | The custom LaughTail plugins, built from source |
| | The datapack |
| | `server.properties` and all Paper tuning |
| | Permission groups, shop tiers, rank ladder, price tables |
| | The scripts and the acceptance harness |

On the `APP_KEY`: Pelican encrypts sensitive values in its own database using that key, which lives in `/var/www/pelican/.env`. **Lose it and the encrypted data is irrecoverable even with a perfect database backup.** Copy it before you touch anything, and store it where the repository never will - it is a secret, and Section 29.11 forbids it from version control.

This split is the entire reason Sections 29 and 30 insist the repository is the only source of truth. It reduces migration from *move a server* to *move three things and redeploy the rest*.

### 22.10 Two shapes of migration - choose the easy one

| | **Option A: move the game server only** | **Option B: move everything, Panel included** |
| --- | --- | --- |
| What moves | The Minecraft server, to a new Pelican node | Panel, Wings, database, and server |
| New box runs | Wings only | Panel, Wings, MariaDB, Redis |
| Mechanism | **Pelican's built-in server transfer** | Manual rebuild and restore |
| `APP_KEY` risk | None. The Panel never moves | Real. Must be preserved exactly |
| Rollback | Trivial - the old node still holds the server | Harder |
| Downtime | 30 to 90 minutes | Half a day |
| Recommended | **Yes** | Only later, deliberately, as its own project |

**Take Option A.** Install Wings on the new VPS, register it as a second node on the Panel you already have, and use the Panel's transfer feature to move `laughtail` from the old node to the new one. Both boxes stay online throughout, and rollback is simply not deleting the old server.

Moving the Panel is a separate, optional job with no player-facing benefit. Do it on a quiet weekend months later, or never. A Panel on a small box is perfectly happy managing a node on a large one.

### 22.11 The node-transfer runbook (the recommended path)

Publish the window at least 48 hours ahead. **Never migrate during a season ending, a War Event, or the Finale.** Section 31.1 fixes the season instant, so this is easy to schedule around.

**Phase 1 - days before, zero risk, no downtime**

1. Provision the new VPS. Same OS family as the current one to avoid surprises.
2. Harden it: non-root user, key-only SSH, automatic security updates.
3. Open the firewall. **Every one of these, or something will silently fail:**

```
ufw allow 22/tcp        # SSH
ufw allow 2022/tcp      # Pelican SFTP
ufw allow 25565/tcp     # Minecraft Java
ufw allow 24454/udp     # Simple Voice Chat
ufw allow 19132/udp     # Bedrock via Geyser, if in scope
ufw enable
```

   Port 8080 stays closed to the internet; the Panel reaches Wings over it internally. Note that a TCP port checker **cannot** verify 24454 or 19132 - you need a UDP-aware check, and Section 13.3 says so for a reason.

4. Install Docker, then install Wings following the current Pelican documentation.
5. In the Panel: **Admin, Nodes, Create Node.** Point it at the new VPS, set its memory and disk to the real capacity minus a reserve for the OS and Wings, then copy the generated configuration to `/etc/pelican/config.yml` on the new box and start Wings.
6. Confirm the node shows a **green heartbeat** in the Panel. If it does not, stop here and fix it. Everything downstream depends on this.
7. Create at least one allocation on the new node for the game port.
8. **Measure the box before trusting it.** Per Section 22.5: `mpstat 1 10` for CPU steal time, a single-core benchmark, disk throughput, and latency from several real player locations. A non-zero steady steal percentage means the host is overselling and you should stop the migration and ask for a refund.
9. Lower the DNS time-to-live to 60 seconds. **Do this days ahead** or the low value will not have propagated when you need it.
10. Take a full backup of the game database and **verify you can restore it** onto the new box into a throwaway schema. An unverified backup is a rumour.

**Phase 2 - migration day**

11. Announce, then enable maintenance mode.
12. **Stop the server cleanly from the Panel console.** Never transfer a running server; a half-written region file is a corrupted world. Confirm the container is actually down.
13. Dump the game database and checksum it:

```
mysqldump --single-transaction --routines --triggers \
  -u root -p laughtail > laughtail-$(date +%F).sql
sha256sum laughtail-$(date +%F).sql
```

14. Copy the dump to the new box and verify the checksum matches on arrival. A dump that changed in transit is worse than no dump, because you will not notice.
15. Restore it into the new database, then confirm the schema version matches what Flyway expects. A schema mismatch after a restore is the most common post-migration failure.
16. **Now run the transfer.** In the Panel: the server, **Manage, Transfer**, choose the new node and its allocation. Pelican archives the volume on the old node, streams it to the new one, and repoints the server record. Watch it to completion; do not close the tab.
17. If the transfer fails partway, the server record stays on the old node. **Start it there and you are back in production.** That is the rollback, and it is why this path was chosen.
18. Once transferred, update the server's memory, disk, and CPU limit for the new box. Remember Pelican's CPU limit is a percentage: `200` means two cores, `800` means eight.
19. Update the startup variables and `-Xmx` per Section 22.13. **Do not simply scale the heap with the RAM.**
20. Start the server and watch the log to a clean start with zero plugin errors.

**Phase 3 - verify before you switch DNS**

Do not point players at the new box until every one of these passes:

21. World loaded, correct seed, correct borders on all four worlds.
22. Database connected, and `/balance` plus `/baltop` return the same values as before the move.
23. `/home`, `/claim info`, `/stats`, `/rank`, and `/season` all return correct pre-migration data for at least three real accounts.
24. Cosmetic unlocks intact, and the current Champion record is present in the archive.
25. A test login works from outside your own network.
26. Voice connects and audio passes, verified with a real second client, not a port check.
27. Bedrock connects, if in scope.
28. No plugin reports an error or a missing dependency at startup.
29. `scripts/healthcheck.sh` passes and `scripts/drift.sh` reports zero drift against the repository.
30. MSPT under a synthetic load is equal to or better than the recorded old baseline at the same player count. **This is the whole reason you moved. Verify it before celebrating.**

**Phase 4 - cut over**

31. Switch DNS to the new IP.
32. Keep the old server **stopped but not deleted for at least 72 hours.** Storage is cheap; a bad week without a rollback is not.
33. Restore the DNS time-to-live to its normal value once propagation completes.
34. Disable maintenance mode and announce.

**Phase 5 - after**

35. Monitor MSPT and tick health for 24 hours against the baseline.
36. Confirm backups are running **on the new host**, then run a full restore drill there.
37. Rotate every credential: panel API keys, SFTP passwords, database passwords, and any token that touched the old box. Rotation is more reliable than revocation.
38. Only now delete the old server and decommission the old VPS.
39. Write down what actually happened in `docs/06-migration.md`, including anything that surprised you. **The next migration is only easier if this step is done.**

### 22.12 The full-relocation runbook (only if the Panel moves too)

Only do this deliberately, as its own project, on a quiet day. It has **no player-facing benefit**. Everything in 22.11 still applies; these steps are additional.

**Before touching anything:**

1. **Copy `/var/www/pelican/.env` off the box and store it securely.** Read the `APP_KEY` line and confirm you have it. Pelican encrypts sensitive database values with this key. Lose it and that data is unrecoverable even from a perfect database backup. It is a secret: Section 29.11 forbids it from the repository, and Section 32.3 lists it as an owner-held item.
2. Dump the Panel's own database, separately from the game database:

```
mysqldump --single-transaction --routines --triggers \
  -u root -p panel > panel-$(date +%F).sql
sha256sum panel-$(date +%F).sql
```

3. Export the LaughTail egg from **Admin, Eggs, Export**. Commit the JSON to the repository. Section 29.7 already requires this, and this is the moment it pays for itself.

**On the new box:**

4. Install the Panel's dependencies: PHP 8.3 with the required extensions, MariaDB 10.11 or newer, Redis 7 or newer, Composer 2, Node 20, and a web server.
5. Install the Panel to `/var/www/pelican`.
6. Restore the Panel database dump.
7. Restore `.env` with the **identical `APP_KEY`**. Update only the database host, Redis host, and `APP_URL`. **Do not regenerate the key.** If a tool offers to, refuse.
8. Clear cached configuration, then run the migration command - on a restored database it should be a no-op. If it wants to create tables, your restore did not work and you must stop.
9. Install the scheduler cron, exactly this line:

```
* * * * * php /var/www/pelican/artisan schedule:run >> /dev/null 2>&1
```

10. Enable and start the queue worker service. **Without the cron and the queue worker, scheduled restarts and backups silently never run** - and nothing warns you.
11. Set up SSL. **If the Panel is served over HTTPS, Wings must also use SSL** or the Panel cannot talk to it. Mismatched SSL is the most common post-relocation failure.
12. Update every node's FQDN if the Panel's address changed, and restart Wings on each.
13. **Do not put the Wings endpoint behind a proxying CDN.** A proxy that returns an HTML error page produces the confusing error `could not unmarshal response: invalid character '<' looking for beginning of value`, which looks like a Wings bug and is not.
14. Re-issue both API keys per Section 29.13, and update anything that used them.
15. Verify the Panel can start, stop, and read files on every server on every node before declaring this finished.

### 22.13 Sizing the new box - do not give Minecraft 50 GB

The most tempting mistake on a large box is to hand the whole machine to the game. **Do not.** A larger heap makes garbage-collection pauses longer, and a long pause is a visible lag spike. Section 6.4 says this already; it matters most exactly when you finally have RAM to spare.

| Resource | Give the game | Why |
| --- | --- | --- |
| Heap (`-Xmx`) | **8 to 12 GB, never more** | Past roughly 12 GB, G1 pause times grow faster than the benefit. Aikar's flags are tuned for this range |
| Container allocation | Heap plus at least 25 per cent, or 768 MB minimum | Section 29.4. Java needs memory outside the heap, and an allocation equal to `-Xmx` **freezes** the server rather than crashing it |
| Pelican CPU limit | `400` to `600` on an 8-core box | The value is a percentage: `100` is one core. Leave headroom for Wings, the Panel, and backups |
| Concurrent players | Still **100 to 150 maximum** on one Paper instance | Hardware does not fix this. The main thread is largely single-threaded |

**A sensible split for 8 cores and 50 GB:**

| Purpose | RAM | Notes |
| --- | --- | --- |
| Production server | 12 GB allocation, 9 GB heap | Comfortable for 60 to 100 players |
| `laughtail-dev` | 4 GB allocation, 3 GB heap | Now it can run **at the same time** as production. This is the real luxury the bigger box buys |
| Arena or event instance | 8 GB allocation, 6 GB heap | Optional. Behind a proxy, this is how you get past the single-instance ceiling |
| Panel, MariaDB, Redis | 4 GB | |
| Website, map renderer, Discord bot | 4 GB | Section 5 wanted these off the game box; now they can come home |
| **Unallocated, left for the OS** | **12 GB or more** | Not waste. The OS page cache holds hot chunk data, and this genuinely improves chunk load times. **Do not allocate it.** |

The honest summary: that upgrade does not buy a bigger single server. It buys **more servers running at once**, real headroom, and the ability to keep dev permanently online instead of trading it against production. Both of those are worth more than a bigger heap.

When you cross this threshold, revisit Section 30.2. The two-servers-never-together rule exists only because a 4 GB box forces it. On the new box, run both, and delete that constraint from the runbook.

### 22.14 Realistic timings

| Step | Rehearsed | First time |
| --- | --- | --- |
| VPS provisioning, hardening, firewall | 20 to 30 min | 45 to 60 min |
| Docker and Wings install | 15 min | 30 to 45 min |
| Node creation and green heartbeat | 10 min | 20 to 40 min, most of the pain is SSL and FQDN |
| Measuring the box properly | 20 min | 20 min. **Never skip it** |
| Database dump, transfer, restore, verify | 10 to 20 min | 30 min |
| Pelican server transfer | 10 to 40 min | Same. Bounded by world size and network speed |
| Startup config, heap, CPU limit | 10 min | 20 min |
| The 10-point verification in Phase 3 | 30 min | 60 min |
| DNS cutover and propagation | 5 min plus TTL | Same |

**Player-facing downtime: 30 to 90 minutes.** Total wall clock including verification: **3 to 4 hours rehearsed, a full day the first time.**

Budget the full day. Announce a two-hour window and finish early - the reverse ruins trust, and on a paid server it produces refund requests.

The reason this is hours rather than a weekend is Section 30.5: dev to production at launch **is** the rehearsal. By the time you move to the big box you will have run the same procedure at least once with nothing at stake. Do not skip that rehearsal to save an afternoon.

### 22.15 Pelican migration acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 22-1 | The game database was dumped, checksummed, transferred, and the checksum re-verified on arrival | Two matching checksums recorded |
| 22-2 | The restored schema version matches what the migration tool expects | Migration tool status output |
| 22-3 | The `APP_KEY` was preserved unchanged, if the Panel moved | Before-and-after comparison, recorded in `docs/private/` |
| 22-4 | The egg JSON in the repository matches the egg on the new node | Exported JSON diffed against the committed copy |
| 22-5 | Balances, homes, claims, stats, cosmetics, and season history match pre-migration values for at least three real accounts | Before-and-after capture |
| 22-6 | The current Champion record survived the move | Season archive query |
| 22-7 | Voice audio passes on the new host, verified with a real second client, not a port check | Recorded test |
| 22-8 | `-Xmx` is at least 25 per cent below the container allocation, and no more than 12 GB | Startup flags plus panel allocation |
| 22-9 | MSPT at equal player count is equal to or better than the recorded old baseline | Two spark reports side by side |
| 22-10 | CPU steal time on the new host is effectively zero under load | `mpstat` output |
| 22-11 | The Panel cron and queue worker are running, proven by a scheduled restart firing | Scheduler log |
| 22-12 | Backups run on the new host **and** a full restore drill has succeeded there | Drill record in `docs/restore-drills.md` |
| 22-13 | Every credential that touched the old box has been rotated | Rotation checklist |
| 22-14 | The old server was kept stopped, not deleted, for at least 72 hours after cutover | Panel timestamps |
| 22-15 | `docs/06-migration.md` records what actually happened, including surprises | Committed document |

---

## SECTION 23 - THE DEFAULTS AND DECISIONS TABLE

Every decision already made, in one place. **If you are about to ask the owner a question, check here first.** Anything marked OPEN is a genuine question for Section 24; everything else is decided.

| Key | Decision |
|---|---|
| Server name and brand | LaughTail SMP |
| Currency | Berries. One currency only |
| **Access model** | **Paid whitelist only. Nobody joins without paying** |
| **Price structure** | **One price, the same for everyone. No tiers, no bundles, no discounts that create unequal capability** |
| **Price amount and recurrence** | **OPEN** (24.1) |
| **Donor ranks and perks** | **None. Deleted from the design entirely** (3.2) |
| **Gambling, crates, lotteries, betting** | **None. Prohibited and grepped for** (3.5) |
| **What is sold** | **Access, and nothing else, ever** (3.6) |
| Gameplay style | Survival SMP with unrestricted PvP and a combat-only ladder |
| Difficulty | Hard |
| Keep inventory | Off |
| Land claims | On. Protect blocks and containers, never players (7.3) |
| PvP inside claims | Enabled. There is no safe zone |
| Fire tick | Off |
| Mob griefing | Off |
| Worlds | Overworld, Nether, End, Resource, Arena |
| World borders | 6,000 / 2,000 / 3,000 / 3,000 / small |
| Resource world | Yes, regenerated monthly with the season (7.4) |
| Homes | Base allowance for all, expandable with Berries to a hard cap of 20 |
| Home rename | Yes |
| Home to home teleport | Yes |
| Personal vault pages | Identical count for every player |
| Transfer tax | Small, above a threshold only |
| Auction listing slots | Identical for every player. Never purchasable |
| Auction fees | Listing fee plus sale tax |
| Order book | Yes, with atomic matching (8.4) |
| Safe trade GUI | Yes, mandatory |
| Dynamic pricing | Plus or minus 35 percent band, 25 percent hard floor |
| Arbitrage audit | In CI and nightly. Build fails on any positive cycle |
| **Rank source** | **PvP only. Zero contribution from anything else** |
| Rating system | Elo, K of 24, start 1000, clamp +2 to +40 |
| Rank tiers | Ten, Wanderer to Mythic |
| Season length | One month |
| Season reset | 1st of the month, 00:00 server time |
| Reset type | Soft: compress toward 1000 at 0.35 |
| Reset warnings | Nine steps from 3 days to 1 minute (9.5) |
| Never reset | Berries, items, homes, claims, cosmetics, achievements, Hall of Fame |
| **Season champion** | **Exactly one per season. No podium, no shared titles** |
| **Champion decided by** | **Top 32 qualify by RP, then the Finale decides. Dragon finale** |
| **Champion reward** | **Custom datapack advancement, permanent title, crown cosmetic, Hall of Fame entry, season-exclusive set** |
| **Champion power gained** | **None. Glory only** |
| Hall of Fame | Physical monument at spawn plus a permanent web page |
| Shop access | Open to all. **Buying is rank-gated across eight tiers** |
| Selling | Never gated |
| Locked shop items | Shown greyed out, never hidden |
| Shop tier at reset | drop_one by default. **OPEN** for owner preference (24.2) |
| **Animations** | **Kept. Pack-driven animation costs the server nothing; particles are budgeted and watchdog-governed** (Section 11) |
| Cosmetic source | Earned by rank only. Never sold, for any currency |
| Cosmetic persistence | Kept forever, across all resets |
| Resource pack | Optional. Never forced |
| War events | Weekly or fortnightly, 48-hour prep, 3 lives |
| Elimination scope | Per event, never per season |
| Event player cap | 20 to 24 now, 40 after migration, 60 at full scale. Always from measurement |
| Season finale | Double elimination, top 32, dragon finish |
| **Voice chat** | **On. Discord day one, proximity voice as the flagship, a no-mod route for Bedrock and unmodded players** |
| **Voice port** | **A dedicated UDP port, conventionally 24454** |
| **Voice requirement** | **Never required for any feature, event or reward** |
| **Voice provider choice** | **OPEN** (24.3) |
| Anti-cheat | A free simulation-based movement anti-cheat first, in alert-only mode, then tuned. A combat layer added only on evidence |
| Auto-ban | Never on a single flag. Human decision plus evidence |
| Packet protection | Mandatory, a launch blocker |
| Punishment ladder | Published, identical in three places (14.4) |
| Bans refunded | No. Stated before purchase |
| Rules acceptance | Required on first join, version-stamped |
| Rollback rights | **Owner only.** Admins get preview only |
| Staff play accounts | Separate from staff accounts. Staff accounts earn zero RP |
| Audit log | Permanent, and staff cannot delete from it |
| AFK and auto-farm policy | Published explicitly. Macros and auto-clickers not permitted |
| Platform | Paper |
| Version policy | Latest stable that all critical plugins support. Never snapshots. Never a floating latest tag |
| Crossplay | Java plus Bedrock via Geyser and Floodgate, with legacy Java version support |
| Online mode | **True, permanently. Never disabled for any reason** |
| Player cap | 24 initially, set from measurement thereafter |
| View and simulation distance | 6 and 4 |
| MSPT target | Under 25 ms normal, under 40 ms in events |
| Watchdog | Built in-house, four-step degradation ladder (6.6) |
| Degradation policy | Degrade cosmetics and conveniences. **Never degrade gameplay** |
| Anti-lag plugins | None. No entity clearers, no mob stackers |
| Deployment | Docker Compose, all state under one directory |
| Database | Containerised, with schema migrations |
| Backups | Hourly database, six-hourly world, offsite, encrypted |
| Restore drills | Monthly, logged |
| Website hosting | **Separate from the game host. Non-negotiable** |
| Store integration | Established platform, idempotent grants, UUID-keyed |
| Leaderboards | Read-only database user, cached 60 seconds minimum |
| Live map | Optional. Player markers off by default, forcibly off during events |
| Appeals | One route, a Discord form or ticket bot |
| Datapacks | Yes, for recipes, advancements, loot tables. Never for permissions, currency or tick-heavy logic |
| Staff list | Published on the website |
| Documentation | Complete set in 5.6, kept current |
| Decision log | Every deviation recorded with reasoning |
| Language | English, with the option to add more later |

---

## SECTION 24 - OPEN QUESTIONS FOR THE OWNER

These are the only decisions genuinely left open. Batch them; do not stop work waiting for answers. Each has a working default so building can continue.

### 24.1 The price, and whether it recurs

The single most consequential unanswered question, because it determines the entire economics of the project.

* **A one-time fee** is simpler, feels fairer, avoids subscription churn and dunning, and has far lower support overhead. But revenue is front-loaded and does not cover ongoing hosting.
* **A recurring fee** funds hosting sustainably and naturally removes inactive players. But it requires subscription management, failed-payment handling, and access-expiry logic, and it creates a monthly reason for players to reconsider.

**Recommendation: a one-time access fee for launch.** It is far less to build, far less to support, and you can add a subscription later. Going the other way - taking subscriptions and then trying to convert to one-time - is much harder. Whichever is chosen, remember 3.3: the fee must be a direct fee for server access, not access gated on some out-of-game product or platform.

**Default while waiting:** build the whitelist and store pipeline to support both. Key access on a boolean plus an optional expiry timestamp. If the expiry is null, access is permanent. That one nullable column keeps both options open at zero cost.

### 24.2 Shop tier behaviour at the monthly reset

keep_peak, drop_one, or full_reset (10.4). **Default: drop_one.** All three are implemented behind one config key, so this is a one-line change after the owner sees real player reaction.

### 24.3 Which voice chat route

All three are built (13.2), but which is presented as **the** recommended route on the website matters:

* **Proximity voice with a client mod** gives the best experience but requires an install and needs a bridge for Bedrock.
* **Browser-based voice** works for absolutely everyone with no install but has lower fidelity and depends on an external service.

**Recommendation: lead with browser-based voice for universality, and offer the mod as the upgrade path for Java players who want the best quality.** That ordering means no paying player is ever excluded, which satisfies Law 3, while enthusiasts still get the premium experience.

### 24.4 Lifesteal hearts

A popular mechanic - win a fight, take a heart of maximum health from the loser. It is genuinely compelling and fits a combat-first server, but it is also brutal for newer players and can create an unrecoverable spiral.

**Built, and switched OFF.** Enable it for one season as an experiment once the playerbase is established, if the owner wants it. Do not launch with it - it changes the difficulty of the entire server and you will not be able to tell whether it or something else caused a retention problem.

### 24.5 Team, clan and guild structures

A clan system with shared claims, a clan tag and clan leaderboards is one of the strongest retention mechanics available, because it converts individual play into social obligation - which is what actually brings players back.

**Recommendation: not at launch, but early.** It is in Tier 1 of the roadmap (26.2). Launching with it would violate Law 2, but it should not wait long.

### 24.6 Bedrock support at launch, or after

Bedrock support roughly doubles the addressable playerbase and is genuinely valuable. It also brings real complexity: separate cosmetic packs, chat-signing differences, the voice bridge, and its own class of bugs.

**Recommendation: launch with it enabled but explicitly marked as best-effort**, with the known limitations published (11.2, 13.4). Do not hide it, and do not promise parity you cannot deliver.

### 24.7 Additional languages

Given the likely playerbase, a Hindi option for the rules, the store, the settings menu and key messages could measurably widen reach.

**Recommendation: build every user-facing string into a language file from day one**, even if only English is populated. Retrofitting internationalisation into a codebase that hardcoded its strings is genuinely painful work, and doing it right at the start costs almost nothing.

---

## SECTION 25 - SCOPE DISCIPLINE: WHAT WE DELIBERATELY DO NOT BUILD

This section is as important as any feature section. Law 2 says minimal and finished beats broad and half-working, and the owner has now said this three times in his own words. **The list below is a list of decisions, not a list of omissions.**

| Not building | Why not |
|---|---|
| **Any gambling mechanic** | Prohibited (3.5). Not a scope call - a hard rule |
| **Donor ranks or paid perks** | Would breach the licence conditions and Law 3 (3.2) |
| **Custom enchantment plugins** | The single most common source of duplication exploits, balance disasters and tick cost on economy servers. The vanilla enchantment set is well balanced and fully understood. This is the highest-risk-lowest-reward plugin category in existence |
| **Custom items, mobs or dimensions at launch** | Enormous surface area, endless maintenance, and every one is a potential exploit. Vanilla content plus excellent systems beats custom content plus buggy systems |
| **Minigames** | A different product. It splits attention, splits the playerbase, and competes for the same tick budget |
| **Skyblock, prisons, factions, or any second mode** | Same. Be one thing, well |
| **Player shops as physical chest shops** | The auction house and order book already solve trading, better and far more cheaply. Chest shops mean thousands of persistent loaded blocks and a chunk-loading problem |
| **An in-game currency exchange or stock market** | Fun to build, and a near-certain economy exploit |
| **Anti-lag plugins** | They fix a symptom by deleting player property. Fix the cause (6.7) |
| **Mob stackers** | Introduce more bugs and duplication risks than the lag they save |
| **A forum** | Nobody uses it. An abandoned forum makes a server look dead (14.7) |
| **A mobile app** | An enormous project for a feature Discord already provides |
| **A custom client or launcher** | A vast undertaking, a security burden, and a barrier to entry |
| **Cross-server networking at launch** | Correct at scale (12.4), wrong on 2 cores. It is in Tier 3 |
| **Automated moderation that punishes without review** | False positives cost paying customers. Always alert, never auto-punish (14.1) |
| **Anything that only works on one client** | Breaks Law 3 by creating first and second class players (16.3) |

**The standing instruction:** when tempted to add something not in this document, write it in the rejected-ideas log with the date and the reason, and move on. Revisit that log once a season. Most entries will look worse in hindsight, and the few that still look good will be obvious.

---

## SECTION 26 - THE ROADMAP AFTER LAUNCH

The owner asked what would make this the best SMP rather than merely a good one. The honest answer is that it is not a feature - it is **the order in which you add things.** Launch with the smallest set that is genuinely excellent, then add in this order.

### 26.1 Tier 0 - launch blockers

These are not features. Without them the server should not open to a paying customer.

1. Backups, verified by an actual restore drill.
2. The paid whitelist pipeline, tested end to end including a refund.
3. Packet-level flood protection.
4. Anti-cheat, tuned in alert-only mode first.
5. The economy arbitrage audit, green.
6. The rules-acceptance gate.
7. Legal pages live before any payment is possible.
8. The load test complete, and the player cap set from its result.

### 26.2 Tier 1 - the retention engine, first month after launch

The things that make players come back tomorrow. This tier matters more than everything in Tier 2 and Tier 3 combined.

1. **Clans or teams** (24.5). Social obligation is the strongest retention force in multiplayer games.
2. **Daily and weekly quests** with published, deterministic rewards. A reason to log in on a day when nothing is scheduled.
3. **A free battle pass** with a fully published track. Every reward visible in advance, so it is progression rather than gambling (3.5).
4. **A bounty system.** Players place Berry bounties on other players. It generates PvP organically, creates rivalries, and is a natural money sink. For a combat-ranked server this is close to a perfect feature.

### 26.3 Tier 2 - rhythm, months two and three

Things that make the server feel alive on a schedule.

1. **King of the Hill events.** Short, scheduled, contested-point PvP. Cheap to run and highly repeatable.
2. **Supply drops.** Scheduled drops at announced coordinates with deterministic, published contents. Instant conflict, zero randomness-for-money.
3. **Public build competitions** with community voting. Gives non-PvP players a reason to be there, without touching the combat ladder.
4. **Seasonal themes.** A small twist each month, announced in advance, so the reset feels like a new chapter rather than a loss.

### 26.4 Tier 3 - scale, after migration

1. **Velocity proxy** with the arena on its own instance (12.4).
2. **A separate build or creative world** on that second instance.
3. **A public statistics API** for the community to build on.
4. **Match replay or recorded highlights** from the Finale. The best marketing asset the server can produce.

### 26.5 The three things that actually decide success

Everything in this document supports these three. If you are ever unsure what to work on, work on whichever of these is weakest.

1. **Consistency.** A server that is always at 20 TPS and never loses data beats a feature-rich server that stutters. This is the owner's own conclusion, and it is correct. **Consistency beats features.**
2. **Fairness.** On a combat-ranked paid server, the perception that someone has an unfair advantage - whether through cheating, a paid perk, or a staff favour - is fatal. There is no recovering a reputation for being rigged. Every rule in Section 3 and Law 3 exists to protect this.
3. **Rhythm.** Something must always be about to happen. A season ending, an event on Saturday, a reset countdown, a Champion to be decided. Players return for the next thing, not the last thing. This is what the monthly season, the war events, and the single Champion are really for.

---

## APPENDIX A - PLUGIN AND COMPONENT CATEGORIES

Select specific plugins at build time by the criteria in 0.3: actively maintained, compatible with the chosen version, configuration read in full before installation, and tick cost measured after installation. **This list is deliberately by category, not by brand**, because a brand recommendation from today may be abandoned software by the time you build.

| Category | Requirement | Notes |
|---|---|---|
| Permissions | Group inheritance, per-world contexts, database storage, an audit trail | The backbone of Section 17. Choose the most widely used option |
| Core commands and homes | Multi-home with rename, teleport request handling, warmups and cooldowns | Must store data in the database, not flat files (15.1) |
| Economy provider | A single-currency ledger with transaction logging and an API | Never trust a plugin that stores balances in a flat file |
| Shop | Per-item permissions or a scriptable gate, dynamic pricing, transaction hooks | Must support the eight-tier gate server-side (10.3) |
| Auction house | Buy-it-now plus bidding, fees, expiry return | The order book is likely custom |
| Land claims | Trust levels, an accrual model, admin overrides, an API | Must allow PvP inside claims (7.3) |
| Region protection | Fine-grained flags including fire and fluid flow | Watch the high-frequency-flag performance setting (14.2) |
| Block logging | Database-backed, inspection, lookup, preview, rollback | Rollback must be permission-separable (14.2) |
| Punishments | Database-backed, cross-instance ready, evidence attachment | |
| Anti-cheat | Simulation-based, off-main-thread, alert-only mode | See 14.1 for the movement-versus-combat gap |
| Packet protection | Malformed-packet and rate protection | Launch blocker |
| Chat management | Rate limits, similarity detection, filters, escalating mutes | |
| Profiler | Tick and memory profiling, per-plugin attribution | Non-negotiable. Law 5 depends on it |
| Chunk pregeneration | Async, resumable | Run before launch, not during |
| Version compatibility | Multi-version client support | Publish one combat-mechanics rule (Section 4) |
| Bedrock bridge | Protocol translation plus authentication linking | (Section 4) |
| Placeholders | A shared placeholder API | Everything else depends on this |
| Scoreboard and tab | Async updates, low cost | Measure it; naive implementations are surprisingly expensive |
| Holograms | Async, packet-based, viewer-limited | Must be disableable by the watchdog (6.6) |
| Cosmetics | Pack-model support plus particle effects, permission-gated | See Section 11 for the animation reasoning |
| Voice chat | Proximity voice plus a no-mod route | Section 13 |
| Discord bridge | Two-way chat, alerts, account linking | Alerts to private channels only |
| Store integration | Idempotent command execution from completed payments | Section 18.3 |
| Live map | Async rendering, marker control | Markers off during events (18.5) |
| Leaderboard display | Reads cached data, not live queries | |
| Backup | Consistent snapshots, offsite, encrypted | With a tested restore path |

**Categories to avoid entirely:** custom enchantments, entity clearers, mob stackers, wholesale pre-tuned config packs, anything unmaintained for longer than one Minecraft version, and anything whose configuration you have not read completely.

---

## APPENDIX B - THE RANKING MATHEMATICS, IN FULL

    Constants
      K                = 24
      STARTING_CR      = 1000
      MIN_GAIN         = 2
      MAX_GAIN         = 40
      DECAY_RATE       = 0.01 per week
      DECAY_AFTER      = 7 days of inactivity
      RESET_FACTOR     = 0.35
      RESET_BASE       = 1000

    On a kill
      E     = 1 / (1 + 10 ^ ((CR_victim - CR_killer) / 400))
      raw   = K * (1 - E)
      gain  = clamp(raw, MIN_GAIN, MAX_GAIN)
      gain  = gain * repeat_multiplier(killer, victim)
      gain  = gain * zero_if_alt_or_reciprocal(killer, victim)
      gain  = gain * zero_if_spawn_region(location)

      CR_killer = CR_killer + gain
      CR_victim = max(tier_floor(CR_victim), CR_victim - gain)

    repeat_multiplier, per killer-victim pair, resetting after 6 hours
      1st kill  = 1.00
      2nd kill  = 0.50
      3rd kill  = 0.25
      4th kill  = 0.10
      5th onward = 0.00

    Weekly decay, only after DECAY_AFTER days of inactivity
      CR = max(tier_floor(CR), CR * (1 - DECAY_RATE))

    Monthly season reset
      CR_new = RESET_BASE + (CR_old - RESET_BASE) * RESET_FACTOR

    Rank points shown to the player
      RP = CR

**Invariants to assert in tests:**

* A kill can never reduce the killer's CR.
* A death can never take a player below their tier floor.
* No non-combat action changes CR by any amount.
* Two applications of the reset are identical to one application followed by no-op.
* The sum of CR changes in a single kill event is zero before clamping and flooring.

---

## APPENDIX C - CONFIGURATION FILES TO CREATE

| File | Purpose |
|---|---|
| Environment file | Every secret. Gitignored, with a committed example containing no real values |
| Compose file | The four services (5.2) |
| Server properties | Baseline in 6.4 |
| Paper and server tuning configs | Baseline in 6.4 |
| JVM flags file | Heap and garbage collection (6.4) |
| ranks.yml | Tier names, thresholds, prefixes, cosmetic unlocks |
| shop-tiers.yml | The eight tiers and their contents (10.2) |
| prices.yml | Derived from the base value formula, with assumptions documented |
| economy.yml | Taxes, fees, sinks, dynamic band, floor |
| seasons.yml | Length, reset time, reset factor, warning schedule, Champion rewards |
| war.yml | Prep window, lives, caps, arena settings, finale format |
| cosmetics.yml | The ladder, particle budgets, viewer limits |
| voice config | Port, bind address, codec settings, permissions |
| watchdog.yml | MSPT thresholds and the degradation ladder (6.6) |
| claims config | Accrual rate, minimum size, trust levels, reclamation threshold |
| rules.yml | Rules text and version, the source for all three publication points |
| punishments.yml | The published ladder (14.4) |
| messages.yml | **Every user-facing string.** One file, so translation is possible later (24.7) |
| permissions export | The full node tree, including the never-grant list, in version control |

---

## APPENDIX D - DATABASE SCHEMA OUTLINE

Use schema migrations from the first commit. Never modify a live schema by hand.

| Table | Contents |
|---|---|
| players | UUID, current name, first join, last seen, rules version accepted, access record |
| access_grants | UUID, transaction reference, granted at, expires at (nullable), revoked at, source |
| balances | UUID, Berries, last modified |
| transactions | Every Berry movement, with type, counterparty, amount, and reason |
| combat_ratings | UUID, current CR, peak CR, season |
| combat_events | Killer, victim, delta applied, multiplier applied, location, timestamp |
| stats | All tracked statistics per player (9.8) |
| homes | UUID, name, world, coordinates, created at |
| claims | Owner, bounds, trust list, created at, last active |
| shop_tier_state | UUID, current tier, peak tier, season |
| cosmetics_owned | UUID, cosmetic id, source, granted at. **Never deleted by a reset** |
| auction_listings | Seller, item data, price, type, expiry, state |
| orders | Player, side, item, quantity, price, filled quantity, state |
| order_matches | Both order references, quantity, price, timestamp |
| seasons | Season number, start, end, state, reset-completed flag |
| season_archive | Final standings snapshot per season, permanent |
| champions | Season number, UUID, final RP, awarded at. **Unique constraint on season number** |
| war_events | Event id, schedule, cap, state |
| war_participants | Event, player, lives remaining, placement |
| punishments | Target, type, duration, reason, evidence reference, issuing staff, timestamp |
| reports | Reporter, target, reason, evidence reference, state, handler |
| staff_audit | Staff UUID, action, target, parameters, timestamp. **Append-only** |
| preferences | Per-player settings from the menu (Section 16) |

**Rules:** every player-facing table keys on UUID and never on name. Every write that spans two tables runs in a transaction. Every table that grows without bound has a documented retention policy.

---

## APPENDIX E - SCRIPTS TO WRITE

| Script | Purpose |
|---|---|
| Health check | TPS, MSPT, memory, disk, container state, backup freshness. Runs on a schedule and alerts |
| Backup | Consistent database dump plus world archive, offsite upload, encryption, retention pruning |
| **Restore drill** | Restores the latest backup into a scratch environment and verifies integrity. **Monthly, logged** (5.4) |
| Economy audit | Full item and recipe cycle check. CI plus nightly (8.3) |
| Weekly economy report | Supply, created, destroyed, distribution, top balances (8.5) |
| Season reset | Idempotent. Archive, grant rewards, name the Champion, soft-reset ratings (9.4) |
| Resource world regeneration | Named world only, refuses to run against the main world (7.4) |
| Arena regeneration | Between events (12.3) |
| Load test | Bot ramp plus event scenario (6.8) |
| **Migration** | Full state transfer with checksum verification (22.6) |
| Whitelist audit | Whitelist versus paid transactions (19.15) |
| Secret rotation | Rotate and redeploy every credential |
| Hardcoded-value check | Greps for IPs and absolute host paths. **Runs in CI** (5.1) |
| Prohibited-mechanic check | Greps for gambling and paid-advantage patterns. **Runs in CI** (3.9) |

---

## APPENDIX F - REQUIREMENT TRACEABILITY MATRIX

Every requirement the owner stated, across every conversation, mapped to where it is answered. **Use this as a completeness check before declaring the build done.**

| # | Owner's requirement | Where it lives |
|---|---|---|
| 1 | A survival SMP inspired by DonutSMP but better | 1.1, 1.2 |
| 2 | Named LaughTail SMP | Title, 23 |
| 3 | Currency named Berries | 8.1, 23 |
| 4 | Sell and buy any item, priced by rarity | 8.2 |
| 5 | Auction house | 8.4 |
| 6 | An order and price-matching market | 8.4 |
| 7 | Stats: name, money, mob kills, deaths, playtime, rank | 9.8 |
| 8 | Playtime in hours, then days | 9.8 |
| 9 | A proper automatic ranking system | 9.1 to 9.3 |
| 10 | Ranking must not reward pure grinding | 9.1 |
| 11 | Ranking driven by PvP | 9.1, 23 |
| 12 | An in-game settings menu like the pause menu | 16.1, 16.2 |
| 13 | Up to 20 homes | 15.1 |
| 14 | Homes renameable | 15.1 |
| 15 | Teleport from home to home | 15.1 |
| 16 | Total optimisation | Section 6, Law 5 |
| 17 | Runs on 2 cores and 4 GB today | 1.4, 6.4 |
| 18 | Painless migration to a bigger VPS later | Section 5, Section 22 |
| 19 | Owner has all power, Admin has less | Section 17 |
| 20 | Admin can manage the server and nothing else | 17.2, 17.3 |
| 21 | A complete command list document | Section 19 |
| 22 | Research thoroughly, verify end to end | 0.5, Section 21 |
| 23 | The builder may improve things freely | 0.2 |
| 24 | RTP, TPA and teleport commands for everyone | 19.5 |
| 25 | Shop open to all, buying rank-gated | Section 10 |
| 26 | Rank increases only through PvP | 9.1 |
| 27 | Rank resets monthly | 9.4 |
| 28 | Escalating pop-ups from three days before reset | 9.5 |
| 29 | Rank-wise custom animated cosmetics | Section 11 |
| 30 | Animated capes and elytra | 11.2, 11.3 |
| 31 | A competitive war and elimination format | Section 12 |
| 32 | Preparation phase before fighting | 12.2 |
| 33 | Lose two or three and you are out | 12.2 |
| 34 | A dragon finale | 12.5 |
| 35 | Griefing and flooding not allowed | 14.2, 14.3 |
| 36 | Rules enforced by plugins and datapacks, not just written | 14.2, 14.9 |
| 37 | A separate rules website | 18.2 |
| 38 | Custom datapacks | 14.9 |
| 39 | Lots of web features | Section 18 |
| 40 | Accepts that 60 players will not fit on 2 cores | 1.4, 12.4 |
| 41 | Plan to migrate to a cheaper, bigger VPS | Section 22 |
| 42 | Advice on what makes it best in class | Section 26 |
| 43 | **Consistency beats features** | Law 1, 26.5 |
| 44 | **No cheating** | 14.1 |
| 45 | **No gambling** | 3.5 |
| 46 | **A clean server** | Section 14 |
| 47 | **Paid access only** | Section 3, 18.3 |
| 48 | **Everything smooth and fully optimised** | Section 6 |
| 49 | **Features minimal and perfect** | Law 2, Section 25 |
| 50 | **Nobody gets any advantage** | Law 3, 3.2 |
| 51 | **Everyone is the same** | Law 3, 15.6 |
| 52 | **Exactly one winner per season** | 9.6 |
| 53 | **The winner gets a custom achievement** | 9.6 |
| 54 | **Keep animations only if they do not hurt smoothness** | Section 11, Law 7 |
| 55 | **Add voice chat** | Section 13 |
| 56 | **Add anything the owner forgot** | 24, 25, 26 |
| 57 | **Tell the builder to improve on this if they can** | 0.2, Appendix G |
| 58 | **Everything perfect and portable** | 5.1, Section 22 |
| 59 | **One complete A-to-Z document, nothing skipped** | This document |

---

## APPENDIX G - WHAT THE OWNER DID NOT ASK FOR, AND WHY IT IS HERE

The owner explicitly asked to be told about anything missing. These were added on that authority. Each is here because omitting it would eventually cost real money, real players, or the server itself.

| Added | Why it matters |
|---|---|
| The licence-compliance section | Charging for access is permitted, but only under specific conditions. Getting this wrong risks the whole project. It is also what forced the removal of donor tiers |
| Merchant of record, tax, and refund handling | Taking money creates obligations that do not go away because the business is small |
| Terms, Privacy and Refund pages | Required by payment processors, and your only defence in a dispute |
| A stated no-refund-on-ban policy, published before purchase | Prevents the single most likely chargeback |
| Restore drills | A backup that has never been restored is a rumour. Most people discover their backups are broken on the day they need them |
| The bot load test | The player cap must come from measurement, not hope |
| The MSPT watchdog | Turns "the server sometimes lags" into an automatic, bounded, self-healing response. It is also what makes it safe to keep animations |
| The complete port table including UDP | The most commonly broken thing in a migration, and the reason voice chat silently dies |
| The economy arbitrage audit | A documented real-world exploit destroyed a comparable server's economy in one weekend |
| The safe trade GUI | Removes the largest category of player drama permanently |
| The resource world | Stops the map looking dead after two months |
| The rules-acceptance gate | Makes "I never agreed to that" impossible |
| Claims that protect blocks but not players | The only way to have both real PvP and a real building economy |
| Owner-only rollback | Rollback is a duplication vector, and log purging destroys evidence |
| Staff on separate play accounts | Removes an unresolvable fairness problem before it happens |
| The whitelist audit script | Finds both revenue leaks and unauthorised access grants |
| Idempotent grants and offline-purchase queuing | Never lose a paid grant, never double-charge |
| The decision log and the rejected-ideas log | Six months from now, nobody will remember why anything was chosen |
| The language file from day one | Retrofitting internationalisation is painful; doing it upfront is nearly free |
| The post-launch roadmap | The order of additions matters more than the additions |

### The standing invitation to the builder

This document is thorough, but it is not sacred. If you find a better way - a cheaper algorithm, a safer schema, a simpler feature that achieves the same player outcome, a plugin category that has been superseded, or a measurement that contradicts an assumption written here - **take it.** Implement the better thing, record what you changed and why in the decision log, and tell the owner in plain language.

The only things that are genuinely non-negotiable are these:

1. **Nobody who pays gets an advantage over anybody else who pays.**
2. **No gambling, in any form, however disguised.**
3. **No data loss, ever.**
4. **Consistency beats features.**
5. **Never claim something is done until it is measured and verified.**

Everything else is engineering judgement, and you are expected to use it.

---

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
## SECTION 29 - PELICAN, AND THE REPOSITORY AS THE ONLY SOURCE OF TRUTH

This section was added after the owner confirmed three things:

1. (Superseded by Section 30.) This section originally assumed the server was built on a local machine first. The owner has since decided to build directly on the VPS, and Section 30 is now authoritative on where the build happens.
2. The VPS already runs **Pelican Panel**, with a stock Minecraft server already live and uncustomised.
3. The entire result - configuration, custom plugins, datapacks, documentation - is published to GitHub as the owner's own project, and GitHub is the recovery path if the local copy is ever lost.

Those three facts change decisions in Section 5 and Section 22. **Where this section disagrees with an earlier section, this section wins.**

### 29.1 Verdict on the local-first plan

**SUPERSEDED BY SECTION 30. Build directly on the VPS.** Section 30 explains why that is the right call for this project, and Section 30.2 gives the two-server rule that makes it safe. This subsection and Section 29.2 are retained only as a record of the earlier reasoning. Sections 29.3 through 29.14 remain fully in force.

Why it is right:

- No live players, so every mistake costs nothing. A corrupted world, a bad migration, a plugin that deletes inventories - all free.
- The loop is faster. Restart in seconds, no upload step, no panel round trip.
- You can destroy and regenerate the world as many times as needed while the economy and world border numbers are still being tuned.
- The paid whitelist gate from Section 3 means there is no launch deadline and no audience waiting. Nothing forces you onto the VPS early.
- It matches the build order in Section 28: one phase per session, verified before the next begins.

**The four things local development cannot give you.** Be honest about these or the VPS will surprise you:

| Cannot be tested locally | Why | Where it must be tested |
| --- | --- | --- |
| Real tick performance | Your machine has more cores, faster storage, and no noisy neighbours | VPS only |
| CPU steal time | Steal only exists on shared virtualised hardware | VPS only |
| Real network behaviour | Latency, jitter, packet loss, and UDP handling for voice chat | VPS only |
| A genuine 20-plus player load | Local bots compete with the server for the same cores, so the result is meaningless | VPS only |

**Rule.** Functional acceptance criteria may pass locally. **Every performance criterion in Section 21 counts only when measured on the VPS.** Do not tick a performance row on local hardware, and do not let anyone quote a local MSPT figure as evidence.

### 29.2 Make local resemble the VPS, or the numbers will lie

The most common local-first failure is that everything feels smooth on a developer machine and then stutters on two shared cores. Prevent it by constraining the local container to roughly the target shape from the start:

```yaml
services:
  mc:
    image: itzg/minecraft-server
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 3g
```

This will not reproduce steal time or slower storage, but it does catch the large class of problems where a feature is quietly dependent on having spare cores. If a mechanic only holds tick rate with four cores, you want to know that in week two, not on launch night.

Also keep the local server on the same Java version, the same Paper build, and the same plugin versions as the VPS. Record all three in the manifest required by Section 5. A version difference between local and production turns every debugging session into guesswork.

### 29.3 What Pelican changes

Pelican Panel is a maintained MIT-licensed fork of Pterodactyl, and it is a reasonable choice. It uses the same egg format, so templates from the Pterodactyl and Pelican egg collections both work. Its vocabulary matters, because the build agent will need it:

| Term | What it actually is |
| --- | --- |
| **Panel** | The Laravel web UI plus its SQL database. Users, servers, nodes, scheduled tasks. |
| **Wings** | The Go daemon installed on each host. It talks to Docker and starts, stops and supervises the game server containers. It also serves SFTP. |
| **Node** | One Wings installation, as seen by the Panel. Panel and Wings can live on different machines. |
| **Allocation** | A reserved IP and port pair. Every server needs at least one. |
| **Egg** | The template defining what gets installed and the start command. |
| **Mount** | A host directory exposed into the container. Note: mounts are **not** visible in the Panel file manager and **not** reachable over SFTP, although the server itself can read them. |

**The architectural conflict, and its resolution.** Section 5 assumed a plain Docker Compose stack. Pelican also owns Docker. **Do not run both orchestrators against the same game server** - two systems creating, naming and stopping the same containers is how you lose a world directory. Resolve it by splitting cleanly by environment:

| Environment | Runtime | Deployment mechanism |
| --- | --- | --- |
| Local | Docker Compose, or a plain Java process | Edit files directly in the working tree |
| VPS | Pelican egg, container managed by Wings | Push the server tree in, per 29.8 |

This costs nothing, **because the repository does not contain a runtime. It contains a server tree.** Enforce that with one hard rule:

> **No file in the repository may contain an absolute host path, a container name, or a Pelican server UUID.** Every path is relative to the server root. This is the Section 5 portability contract, and Pelican is its first real test.

Four Pelican operational facts that will otherwise cost you a bad evening:

- **Back up the Panel APP_KEY off the server, today.** It encrypts stored credentials. If it is lost, that data is unrecoverable even with a full database backup.
- **Enable the Panel scheduler cron and the queue worker.** If they are not running, scheduled tasks and panel-side backups silently never fire, with no error anywhere.
- **If the Panel uses TLS, Wings must too**, and putting the Panel behind a proxying CDN commonly breaks the Panel-to-Wings handshake. Keep the Wings endpoint unproxied.
- **Treat the currently live stock server as disposable.** It has no customisation and no players. Do not attempt to preserve or upgrade it. Create a fresh server from the egg at migration time and delete the old one once the new one is verified.

### 29.4 The memory arithmetic that breaks Minecraft under Pelican

**This is the single most likely way the VPS bites you, and it has nothing to do with your code.**

The default Minecraft eggs set the Java maximum heap to the full container allocation. Java then needs a substantial amount of memory *outside* the heap: metaspace, code cache, garbage collector structures, thread stacks, direct byte buffers, and the JVM itself. When the heap grows toward its configured maximum, total container usage exceeds the hard limit, and the server freezes or is killed. This is a repeatedly reported failure against the official eggs at a 4 GB allocation, and the symptom - a server that runs fine for hours and then locks up - is easy to misdiagnose as a plugin bug.

Budget it explicitly. On the current 2 core / 4 GB box:

| Consumer | Approximate cost |
| --- | --- |
| OS plus Docker engine | 350 to 450 MB |
| Wings daemon | around 100 MB |
| Panel stack, if on the same box (PHP, web server, database, cache) | 500 to 800 MB |
| Remaining for the game server container | what is left, and it is less than you think |

Resulting settings:

| Layout | Container allocation | Maximum heap |
| --- | --- | --- |
| Panel and Wings both on the game box | 3.0 GB | 2.0 to 2.2 GB |
| Wings only, Panel elsewhere | 3.4 GB | 2.5 GB |

**Rules.**

- **The maximum heap must never equal the container allocation.** Leave at least 25 percent of the allocation, and never less than 768 MB, outside the heap.
- Set the initial heap equal to the maximum heap. A growing heap on a memory-constrained box causes avoidable garbage collection churn.
- Keep the Aikar flags already specified in Section 5, but override the egg's default heap value rather than accepting it.
- **Prove it before launch:** run at full expected player load for three continuous hours and confirm container memory plateaus and stays below the allocation. A container that climbs steadily has not passed.

Note also the standing Pelican recommendation to keep game server files on a partition separate from the root filesystem, so a filling disk cannot make the host unbootable.

### 29.5 Where the Panel should live

| Option | Trade-off |
| --- | --- |
| Panel and Wings on the game box (current) | Simplest. Costs 500 to 800 MB and some CPU on the box whose tick budget is already tight. |
| Panel on a separate small box, Wings on the game box | Gives the game server most of the RAM back. Costs a few dollars a month and a second machine to maintain. This is a normal Pelican deployment, not a workaround. |
| No panel, Compose only | Cheapest in resources. Loses the console, SFTP, scheduled restarts, resource graphs, and safe file access without SSH. |

**Recommendation:** keep the current layout through the build phase and do not change infrastructure on a guess. At the first real load test on the VPS, measure MSPT at 20 to 24 players. **If MSPT sits within 20 percent of the 40 ms warning line, move the Panel to its own box** and leave only Wings on the game host. Record the measurement and the decision in `docs/decisions.md` either way.

Do not remove Pelican merely to reclaim RAM. For a solo owner, the console, the start and stop control, and SFTP are worth real money in avoided mistakes.

### 29.6 The one-way flow rule

**Files flow local to git to VPS. Never the other direction. Never edit files on the VPS.**

This rule is the entire reason your GitHub recovery plan works, and Pelican makes it unusually easy to break: the Panel has a browser file editor, a console, and SFTP on port 2022. Changing one YAML value in the browser at two in the morning is a single click.

What breaks when the rule is broken:

- The next deploy silently reverts the fix, and the bug comes back with no explanation.
- Or the deploy conflicts, and you cannot tell which side is correct.
- Either way the repository stops describing the running server, and at that moment it stops being a backup of anything.

**The one permitted exception.** During a live incident you may edit on the server to stop the damage. **The change must be copied back into git in the same session, before you stop working.** If it is not in git by the end of the session, it did not happen and it will be lost.

**Drift detection.** Add `scripts/drift.sh`. It hashes every git-tracked configuration file on the VPS, compares against the committed version, prints any file that differs, and exits non-zero if any do. Run it as the first step of every deploy and as part of the daily health check. It must check only tracked files - the world, player data and the database differ constantly by design, and that is not drift.

### 29.7 What goes in git, and what must never

| Goes in git | Never in git |
| --- | --- |
| Server configuration: `server.properties`, `paper-global.yml`, `paper-world-defaults.yml`, `spigot.yml`, `bukkit.yml` | `.env` and every real secret |
| Every `plugins/<Plugin>/config.yml` and permission definition | `world/`, `world_nether/`, `world_the_end/`, `resource_world/` |
| `datapacks/laughtail/` in full | Player data, statistics, advancements |
| Custom plugin source code, build files, tests | Any `.jar` - server jar and plugin binaries alike |
| `db/migrations/`, `scripts/`, `docs/` including the specification | Logs, caches, `libraries/`, `versions/` |
| `docker-compose.yml` for local use, `.env.example`, `.gitignore` | Backup archives |
| `AGENTS.md`, `README.md`, `LICENSE` | The Panel database and the Panel APP_KEY |
| The exported Pelican egg JSON, so the runtime is reproducible | Plugin data directories holding player state (`.db`, `.mv.db`, `data/`) |

**The asymmetry that matters.** Before launch, local is the source of truth for everything. After launch this splits permanently:

- **Git is the source of truth for code and configuration.**
- **The VPS is the source of truth for player data.**

Neither can reconstruct the other. So:

> **GitHub protects you from losing your work. Backups protect you from losing your players' work. They are different problems and they need different mechanisms.** Publishing to GitHub does not reduce the Section 22 backup and restore-drill requirements by one line.

### 29.8 The deploy procedure

Once the VPS is live, every change reaches it this way and no other way.

| Step | Action | Gate |
| --- | --- | --- |
| 0 | Run `scripts/drift.sh` | Stop if it reports drift. Reconcile first. |
| 1 | Build and test locally: compile, unit tests, plugin loads clean on a fresh local server | Any failure stops the deploy |
| 2 | Commit, push, and tag the release | The tag is what you roll back to |
| 3 | Announce the restart in-game and on the site | Whitelist server, so a short notice is enough |
| 4 | Stop the server from the Panel, cleanly | Never kill the container to stop it |
| 5 | Take a backup: world, database, plugin data - and confirm it restores | An unverified backup is not a backup |
| 6 | Push the server tree over SFTP on port 2022 using the deploy script | Script only. No manual file manager edits. |
| 7 | Start, watch the console to fully loaded, confirm the plugin list matches the manifest | Unexpected or missing plugin means roll back |
| 8 | Run the functional smoke subset of Section 21 | Any failure means roll back |
| 9 | Record the deploy, the git tag and the result in `docs/progress.md` | Undocumented deploys make the next incident unsolvable |

**Rollback path:** stop the server, restore the pre-deploy backup, redeploy the previous tag. **If you cannot state the rollback path out loud before step 4, do not deploy.**

**Rule.** The deploy script is the only mechanism by which files reach the VPS. Not the file manager, not an ad-hoc SFTP client, not a console command.

### 29.9 Three migrations, and why the first is a rehearsal

You will migrate at least three times:

1. **Local to VPS** - planned, no players, nothing at risk.
2. **VPS to a larger VPS** - later, with real players, real balances, and time pressure.
3. **Any future provider or panel change** - whenever it comes.

All three use the Section 22 runbook. The important consequence: **migration one is a free, zero-risk rehearsal of migration two.** Treat it that way. Time each step. Write down every manual action, including the ones that felt too obvious to record. Note everything you had to look up. **The deliverable of migration one is not a working server - it is a runbook accurate enough that migration two is boring.**

Two decisions to settle before migration one:

- **Fix the production world seed now and never change it.** Regenerating the world later destroys every player build.
- **Chunk pregeneration:** pregenerating locally and transferring region files saves VPS CPU, but those files are large. Measure the transfer against simply pregenerating on the VPS overnight before assuming local is faster.

### 29.10 The portfolio standard: what "human written" has to mean

This requirement is worth taking seriously, because as a *quality gate* it makes the codebase genuinely better. But it is two separate requirements, and they need separating.

**Requirement A: the code carries no machine residue and meets a real professional standard.**

- No generated attribution anywhere: no "generated with" notices, no co-author trailers, no tool names in comments or commit messages.
- No comment that restates the code. Comments explain **why**, never what.
- No speculative abstraction: no interface with a single implementation, no configuration option nothing reads, no factory for one object.
- No dead code, no commented-out blocks, no unused imports, no leftover debug logging.
- One style, enforced by a formatter and a linter in CI, so style stops being a matter of opinion.
- **Commits are one logical change each**, with an imperative subject under 72 characters and a body explaining why. Never a commit titled "implement section 8". If a session produced a four-thousand-line commit, split it with an interactive rebase before pushing.
- The README, the architecture notes and the decision records are written **in your own words**. They are the part a reader actually reads.

**Requirement B: you can explain every line.** This is the one that decides whether the project is worth anything to you.

- Nothing merges to `main` until you have read every line of it.
- For each file, you must be able to answer: what does this do, why does it exist, what breaks if it is deleted, and why this approach rather than the obvious alternative.
- **Anything you cannot answer gets rewritten by you, or deleted. There is no third option.**
- Budget roughly a third of your time for review. If a session generates more than you can review in that session, the session was too large - the same rule as Section 28.6, for the same reason. Having plenty of credit does not raise this limit, because the limit is your review capacity and the context window, not the budget.

**One thing worth saying plainly.** Building a project with AI assistance and then presenting it as your project is ordinary practice, and nobody expects you to have typed every character. What does not work is claiming a process you did not follow if someone asks directly - an employer, a university, or a competition with disclosure rules. Answer that honestly if it is ever asked. It costs you nothing, because the thing that impresses a competent reviewer here was never typing speed.

**And you are undervaluing what you actually authored.** The specification is yours: rating driven purely by PvP, monthly resets, absolute equality with no purchasable advantage, exactly one champion per season, the refusal to build a wagering escrow, the paid whitelist as the anti-cheat strategy, the portability contract. Those are product and architecture decisions, and they are precisely what a senior reviewer looks for. **Commit the specification and the decision records alongside the code.** A well-argued `docs/decisions.md` and `docs/rejected.md` will do more for you than any quantity of source, because almost no portfolio project has them - and `rejected.md` in particular demonstrates the judgement that hiring managers claim to want and rarely see evidence of.

What the README must contain: the problem, the constraints you designed against, the three hardest decisions and why you chose as you did, the measured performance numbers with the method used to obtain them, and what you would do differently next time.

### 29.11 What must not be published

A public repository publishes your own countermeasures. Treat the following as sensitive:

- The wagering detector signatures, windows and thresholds from Section 3.5.1.
- The shop arbitrage guard and the economy value model constants from Section 8.
- Anti-cheat configuration and tolerance values.
- Rate limits, and the exact backup and restore schedule.
- Staff command lists with their permission nodes.
- Anything documenting what is **not** monitored.

**Rule: never publish a threshold that tells someone exactly how to stay underneath it.**

The practical approach: **keep the repository private until launch.** After launch, publish the code and configuration, exclude a `docs/private/` directory, and keep trust-and-safety detail in a separate private repository. You lose nothing for portfolio purposes - a reviewer cares about the architecture and the decision records, not your detector constants.

And per Section 28.10: **a secret that reaches a public commit is compromised permanently.** A later commit does not remove it from history. Rotate it.

### 29.12 Licensing for a public repository

- **Add a LICENSE file when the repository is created, not later.** Without one, nobody may legally reuse the work, and an unlicensed "project" reads as unconsidered.
- **Check the licence of anything you build against.** Some plugins in the candidate list are GPL-3.0. If you publish plugin source that links against GPL-3.0 code, the safe reading is that your plugin must also be GPL-3.0. Three clean ways out: license your own plugin GPL-3.0, use a soft dependency and reflection so you do not link against it, or choose a differently licensed plugin. **Decide before writing the code and record it in `docs/decisions.md`** - discovering this after the plugin is written is an expensive rewrite.
- **Never commit third-party jars.** Reference them in the Section 5 manifest with versions and checksums.
- **Never commit the Minecraft server jar or any paid plugin binary.** Paid resources almost always prohibit redistribution, and a public repository is redistribution.

### 29.13 Access model: what the API can do, and what still needs SSH

**SUPERSEDED BY SECTION 33.1.** The owner has chosen to grant root SSH access to the host and to create **no Pelican API keys at all**. Root SSH is a strict superset of both key types, so nothing here becomes impossible. **Do not ask the owner for API keys.** This subsection is retained because the distinction below is still worth understanding, and because it becomes relevant again if API access is ever added for automation. Read Section 33.1 for the access model actually in force, including the file-ownership trap that root access introduces.

The key created in the panel admin area is **not sufficient on its own**, and the reason is structural rather than a permissions mistake. Pelican exposes two separate APIs with different key types, and file operations are not in the administrative one.

| | **Application API** | **Client API** |
| --- | --- | --- |
| Key created at | Admin area, API Keys | Your account settings, API credentials |
| Base path | `/api/application` | `/api/client` |
| Purpose | Administrative CRUD on panel objects | Operating a server you own |
| Covers | Servers (create, update, delete, transfer), nodes, allocations, users, eggs, database hosts, server databases, mounts, roles | Power state, console, **all file operations** (list, read, write, upload, download, copy, rename, compress, decompress, pull remote file, permissions), backups, schedules, startup variables, network |
| Does **not** cover | Any file operation, power control, or console access | Anything administrative: creating servers, nodes, or users |

**Conclusion: the migration needs both keys.** The admin key provisions the server; the client key puts files into it and starts it. Neither can do the other's job, and this separation is long-standing behaviour in this codebase family, not a bug to work around.

**The third access path: SFTP.** Wings serves SFTP on port **2022**, authenticated live through the Panel, with the username format `<panel-username>.<8-character-server-id>`. For pushing an entire directory tree this is the practical tool - far better than issuing hundreds of file-write API calls. Two caveats: host mounts are not visible over SFTP, and some paths may be refused because they sit on the egg's denylist.

**Which mechanism each migration stage uses:**

| Stage | Mechanism |
| --- | --- |
| Create the production server: node, allocation, egg, memory, disk, CPU limits | Application API |
| Create the server database, if using a panel-managed one | Application API |
| Set startup variables, including the heap value from 29.4 | Client API |
| Upload the built server tree | SFTP on 2022, or Client API upload or pull plus decompress |
| Start, stream the console, confirm the plugin list | Client API |
| Take a backup and verify it restores | Client API |
| Delete the old server, after the new one passes | Application API |

**None of that requires host SSH.** The migration itself is fully automatable from the two keys plus SFTP.

#### Scope the admin key down

Setting every permission to Read and Write, as the panel's "Set All Permissions" shortcut invites, hands any holder of that key full control of the panel. Given that this key will be used by an automated build agent, apply least privilege:

| Permission | Set to | Reason |
| --- | --- | --- |
| Server | Read and Write | Create the new server, delete the old one |
| Allocation | Read and Write | Assign the game port |
| Egg | Read | Select an egg; never modify one from a script |
| Node | Read | Read capacity only |
| Server Database | Read and Write **only** if using a panel-managed database, otherwise None | Least privilege |
| Database Host | None | Deploys never reconfigure database hosts |
| User | **None** | A key that can write users can create an administrator |
| Role | **None** | Same reason |
| Mount | None | Mounts require host access regardless |
| Plugin | None | No deploy script needs to touch panel plugins |

Also on that same screen:

- **Use the Whitelisted IPv4 Addresses field.** It is the strongest control available on the key creation page. Restrict the key to the machine that runs deploys. Residential addresses change, so expect to update it.
- **Write a real Description.** Unlabelled keys cannot be audited or safely revoked later.
- The key is displayed once. Store it in a password manager, never in the repository, never in a committed environment file. Sections 28.10 and 29.7 apply without exception.
- **Client API keys currently have no scopes at all** - they are all or nothing. Treat the client key as the more dangerous of the two despite its name, and rotate it after migration.

#### What genuinely requires SSH

SSH is not needed for the migration. It is needed for the host, and several items below are direct requirements of this specification:

| Task | Why the API cannot do it | Reference |
| --- | --- | --- |
| Open UDP 24454 for voice chat in the host firewall | The host firewall sits outside the panel | Voice section |
| Measure CPU steal time | Not observable from inside a container | Section 21 |
| Back up the Panel APP_KEY | Lives in the Panel environment file on the host | 29.3 |
| Enable the scheduler cron and the queue worker | systemd and crontab | 29.3 |
| Change Wings configuration: allowed mounts, SFTP port, overallocation | `/etc/pelican/config.yml` plus a service restart | - |
| Move the Panel to its own machine | Full reinstall | 29.5 |
| Put server files on a separate partition | Host storage layout | 29.3 |
| Patch the OS, Docker engine, and Wings | Host package management | Section 22 |
| Recover when the Panel itself is down | The API is unavailable exactly when it is needed most | Section 22 |

> **Rule: keep SSH access. Use the API for deploys and SSH for the host.** These are not competing options. Configure SSH with key authentication only, password authentication disabled, root login disabled, and the non-root user required by 28.3.

#### The delete order

Nothing on the currently live stock server is worth keeping, and deleting it is correct. **But the order matters, because deleting a server deletes its volume, and 4 GB will not run the old and new servers simultaneously.**

1. Export the egg JSON and commit it, per 29.7.
2. Record the allocation, port, and server identifier.
3. Stop the old server. **Do not delete it yet.**
4. Create the new server, upload the built tree, start it, and run the functional smoke subset of Section 21.
5. Only once it passes, delete the old server.
6. Rotate the panel password and SFTP credentials afterwards. Credential revocation on server deletion has historically been unreliable in this codebase family, so rotate rather than assume.

#### The clean-slate rule

What crosses from local to production, and what must not:

| Migrates from local | Must start empty on the VPS |
| --- | --- |
| Server and plugin configuration | The world, or a freshly pregenerated world on the fixed seed |
| Datapacks | Player data, statistics, advancements |
| Custom plugin jars built from committed source | The economy database and the full ledger |
| Permission definitions | Ranks, ratings, and season history |
| Database migration files | The whitelist |

The reason is not tidiness. A local test world carries administrator-granted items, invented balances, and test kills. **The Section 8 economy audit and the Section 9 rating system both assume a clean ledger from day one.** Carrying test data forward silently invalidates every economy acceptance number in Section 21, and there is no way to separate it out afterwards.

#### Give the agent the right reference

The authoritative endpoint list for the installed panel version is served by the panel itself at `/docs/api` - sign in to the panel first, then open it. Point the build agent there rather than at any third-party API reference, because it matches the exact version running. If panel access is wired into the agent through an MCP server rather than direct HTTP calls, review that server's source before granting it a key, per 28.1.

### 29.14 Acceptance criteria

| ID | Criterion | Evidence |
| --- | --- | --- |
| 29-1 | No file in the repository contains an absolute host path, container name, or Pelican server UUID | Grep across the tree, output empty |
| 29-2 | The local container is constrained to the VPS core and memory shape | Compose file plus a screenshot of the running limits |
| 29-3 | Panel APP_KEY is backed up off the server | Owner confirmation, location recorded in the runbook |
| 29-4 | Panel scheduler cron and queue worker are both running | Service status output |
| 29-5 | Maximum heap is at least 25 percent below the container allocation, minimum 768 MB of headroom | Start command plus allocation screenshot |
| 29-6 | Container memory plateaus below the allocation across a three-hour full-load run | Memory graph over the full window |
| 29-7 | `scripts/drift.sh` exists, runs clean, and is invoked by the deploy script and the daily health check | Script plus two consecutive clean runs |
| 29-8 | A deploy has been performed end to end using only the deploy script, with a verified pre-deploy backup | Deploy log entry in `docs/progress.md` with git tag |
| 29-9 | A rollback has been rehearsed at least once on the VPS before launch | Restore drill record per Section 22 |
| 29-10 | Migration one produced a timed, step-by-step runbook | `docs/06-migration.md` with recorded timings |
| 29-11 | `.gitignore` excludes every item in the right-hand column of 29.7, and no excluded item appears in history | `git log` search for each pattern, all empty |
| 29-12 | LICENSE present, and any GPL linkage decision recorded | LICENSE file plus the `docs/decisions.md` entry |
| 29-13 | Every file in `main` has been read by the owner, and nothing unexplainable remains | Owner sign-off recorded per phase in `docs/progress.md` |
| 29-14 | Both an Application API key and a Client API key exist, each scoped as narrowly as the panel allows, and neither appears anywhere in the repository | Panel key list plus a git history search for both key prefixes |
| 29-15 | The Application API key is IP-restricted and carries a description, with User, Role, Mount, Plugin and Database Host all set to None | Panel key list screenshot |
| 29-16 | The old server was deleted only after the new one passed the smoke subset, and panel and SFTP credentials were rotated afterwards | Deploy log entry in `docs/progress.md` |
| 29-17 | Production world, player data, and economy database all started empty or freshly generated | First-day economy audit showing a zero-balance ledger |

---

## SECTION 30 - THE BUILD ENVIRONMENT DECISION: BUILD ON THE VPS

**This section supersedes Sections 29.1 and 29.2 where they disagree.** Those sections recommended building locally first. The owner has decided to build directly on the VPS, and on re-examination that is the correct decision for this project. Sections 29.3 through 29.14 remain fully in force.

### 30.1 The decision, and why it is right here

Build directly on the VPS. Do not build on the owner's PC. This is final. Do not reopen it in a later session.

The reasoning, recorded so no future session has to rediscover it:

* **The target environment already exists.** Pelican Panel and Wings are installed and working on the VPS, and a stock Paper server is already live on it. Building locally would mean constructing a second copy of an environment that is already running, then maintaining both of them forever.
* **The owner's PC cannot validate a single Section 21 performance criterion.** It cannot reproduce CPU steal time, the container memory limit, the real network path, or genuine concurrent player load. Every performance number produced locally would have to be measured again on the VPS before it could be trusted. A measurement that must be repeated is not a test, it is a rehearsal.
* **One environment cannot drift from itself.** Section 29.6 exists because two environments diverge. Removing the second environment removes the failure mode entirely.
* **Law 1.** Fewer moving parts. Simplicity is a feature on this project, not a compromise.

What is lost, stated plainly rather than glossed over:

* A slower edit-and-test loop. Section 30.3 recovers most of it.
* No free safety net: a destructive command reaches the only copy that exists. Section 30.2 is the answer to that, and it is not optional.

### 30.2 Two servers on one panel: the rule that makes this safe

Create **two** servers in Pelican, not one.

| Server | Identifier | Purpose | When it runs |
| --- | --- | --- | --- |
| Development | `laughtail-dev` | Every build, test, experiment, and restart loop | Throughout the build. Stopped after launch except during deploy rehearsals |
| Production | `laughtail` | The server players connect to | Stopped until launch. Running afterwards |

The rules, all of them hard:

1. **All agent work happens on dev.** The agent may never write to production by any route except running `scripts/deploy.sh`.
2. **Only one of the two runs at a time.** This box is 2 vCPU and 4 GB. It cannot host two Paper servers at once, and it does not need to.
3. **Production is created empty and stays empty until launch.** World, player data, economy ledger, ranks, season history, and whitelist all start from nothing. This restates the clean-slate rule in Section 29.13 and it is not negotiable: Section 8's economy audit and Section 9's rating both assume a ledger with no prior history.
4. **The existing stock server is disposable.** Stop it, do not delete it, until dev has booted and passed a smoke test. Then delete it and reclaim its allocation and its port.

Memory, extending the arithmetic in Section 29.4:

| Server | Container allocation | `-Xmx` | Reasoning |
| --- | --- | --- | --- |
| `laughtail-dev` | 1.5 GB | 1.0 GB | Enough to boot, run integration tests, and hold two to four test clients |
| `laughtail` | 3.0 GB | 2.0 to 2.2 GB | Per Section 29.4, with the Panel co-located on the same box |

The combined 4.5 GB exceeds the box, and that is acceptable **only** because the two never run together. Set the node memory limit to physical RAM minus the reserve for the OS, the Panel, and Wings, then enable memory overallocation on the node and enforce the never-both-running rule by procedure. If overallocation is uncomfortable, drop dev to 1.0 GB with `-Xmx 768m`; it will still boot and still run every test.

`-Xmx` must never equal the container allocation. Leave at least 25 per cent, or 768 MB, outside the heap. Section 29.4 explains what happens when this is ignored, and it is a freeze, not a crash.

### 30.3 Keeping the loop fast without a local server

* **Run the Kiro CLI on the owner's PC, not on the VPS.** The agent edits the git working copy locally, then ships changes to dev with `scripts/deploy.sh` over SFTP on port 2022. Two reasons: an agentic CLI running on a 2-vCPU box competes for CPU with the very server it is measuring, and the agent's working state should not live on the machine that later becomes production.
* **Compile and unit-test locally.** Java compilation and MockBukkit tests need neither a Minecraft server nor the VPS. Only integration tests need dev. Most of the loop time lives here, and it stays local and fast.
* **Keep dev warm.** Do not restart for every change. Use `/laughtail reload` for configuration-only changes, and never `/reload`.
* **Read logs through the Pelican console** rather than over SSH wherever the console is sufficient.
* **One deploy per task, not one per edit.** Batch a task's changes, deploy once, test once.

### 30.4 What must never be done directly on the VPS

Every one of these breaks portability, which the owner named as a hard requirement.

1. **Never edit a configuration file through the panel file manager or SFTP as the primary action.** Edit it in the repository, commit, then deploy. If a file is edited on the server to test a hypothesis, it must be copied back into the repository and committed in the same session, or reverted before that session ends.
2. **Never install a plugin by uploading a jar by hand** without recording it in the repository manifest with version, source URL, and checksum.
3. **Never run a one-off state-changing command** without adding it to a script in `scripts/`.
4. **Never let data exist only on the VPS**, other than the live world and the live database, both of which backups already cover.
5. **Every session ends with `scripts/drift.sh` reporting zero drift** between the repository and dev. A session that ends with drift is not a finished session.

### 30.5 Migration becomes three rehearsed moves

| Move | From and to | When | What it proves |
| --- | --- | --- | --- |
| 1 | dev to production, same box | Launch | First real use of `deploy.sh`, on a box where a mistake costs nothing |
| 2 | production to a larger VPS | When demand passes 20 to 24 concurrent players | Move 1 already proved the procedure end to end |
| 3 | Any later move | Later | Identical procedure, no new risk introduced |

Because every move runs the same script against the same repository, the owner's requirement to migrate without deleting anything is satisfied by construction. Nothing is deleted. A new server is built from the repository and the data volume is restored into it. The old server is stopped, kept until the new one passes its smoke test, and only then removed.

### 30.6 Acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 30-1 | Two servers exist in Pelican, dev and production, and production is empty | Panel view plus an empty world directory listing |
| 30-2 | Production has never been written to except by `deploy.sh` | Deploy log cross-checked against file timestamps |
| 30-3 | The two servers have never run simultaneously | Panel activity log |
| 30-4 | `scripts/drift.sh` reports zero drift at the end of every session | Script output committed to `docs/progress.md` |
| 30-5 | Every deployed plugin appears in the repository manifest with version and checksum | Manifest diffed against the running server |
| 30-6 | A full deploy from a clean checkout onto an empty dev server succeeds unattended | Timed run recorded in `docs/06-migration.md` |

---

## SECTION 31 - THE COMPLETENESS PASS

Fourteen items found by auditing this document against the owner's requirement that nothing be skipped. Each names the section it amends. Where this section and an earlier section disagree, **this section wins**.

None of these are new features. Every one is a hole in something this document already promised.

### 31.1 The season boundary: an exact instant (amends Section 9)

This document specified monthly resets and a nine-stage countdown, but never defined when a month actually ends. A season that produces exactly one Champion cannot have an ambiguous end time.

* **Seasons end at 00:00 IST (UTC+05:30) on the first day of each calendar month.** The owner may change the hour, but it must be a fixed, published hour.
* Store the instant in the database in **UTC**. Display it in local time where the client allows, otherwise in IST with the offset shown.
* The standings snapshot is taken in **one transaction at that instant**. A kill resolved after the instant belongs to the new season, regardless of when the fight began.
* The countdown stages of 3 days, 2 days, 24 hours, 12 hours, 6 hours, 1 hour, 15 minutes, 5 minutes, and 1 minute are computed from this instant, never from drifting server uptime.
* If the server is offline at the instant, the reset job runs on next boot and uses the **scheduled** instant for every calculation, not the boot time. Section 9 already requires idempotency; this makes the job time-correct as well.
* Publish the instant on the website and in `/season`. Players will plan their final hours around it, which is exactly the intended drama.

### 31.2 The Champion tiebreak chain (amends Section 9)

Section 9 states the principle: if the format can produce a tie, the format is wrong. That is a principle, not a procedure. RP is an integer and the roster is 20 to 24 players, so exact ties are likely rather than hypothetical.

Apply in order, stopping at the first criterion that separates:

1. Higher RP at the season instant
2. More kills during the season
3. Fewer deaths during the season
4. Earlier timestamp of first reaching their own season-peak RP
5. Sudden-death duel

Duel rules: within 48 hours of the season instant, in the finale arena, on the fixed finale kit, best of three, refereed by an Admin, recorded. If a tied player cannot be reached after **two announced attempts across those 48 hours**, the reachable player wins by walkover, and the archive records it as a walkover rather than a duel victory. If no duel can be held at all, criterion 4 decides.

**Never share the title. Never award two crowns. Never end a season without a Champion.**

### 31.3 Combat tagging, in full (amends Sections 14 and 9)

This is the mechanic that makes a PvP-only rating trustworthy, and the document gave it two lines. If a losing player can disconnect before dying, the rating system is decorative.

* **Tag duration: 15 seconds**, refreshed on every hit given or received between players.
* **Blocked while tagged:** `/home`, `/sethome`, `/tpa`, `/tpahere`, `/tpaccept`, `/rtp`, `/resource`, `/spawn`, `/warp`, `/back`, `/hub`, `/lobby`, `/ec`, `/pv`, `/kit`, `/craft`, `/anvil`, `/grindstone`, `/repair`, `/shop`, `/sell`, `/ah`, `/order`, `/trade`.
* **Mob damage does not tag.** Only player-versus-player damage tags. Dying to a creeper mid-fight is not a combat log.
* **Disconnecting while tagged is resolved as a death.** Full item drop at the disconnect location, the killer receives the complete Elo award as though the kill had landed, and the disconnecting player takes the normal RP loss **plus an additional flat penalty**, so logging out is strictly worse than dying. Publish the flat penalty as a rule; keep detector internals private per Section 29.11.
* **A third combat log inside 30 days is a punishable offence** under Section 14, not merely a mechanical penalty.
* Acceptance requires an automated test that disconnects a tagged bot and asserts the death, the item drop, the killer's award, and the extra penalty.

### 31.4 Totem of Undying and Mending (amends Sections 7, 8, and 12)

These two items shape modern Minecraft PvP more than anything else in the game, and neither appeared anywhere in this document.

| Context | Totem of Undying | Mending |
| --- | --- | --- |
| Survival world | Allowed | Allowed |
| War events | Banned, enforced by the arena inventory check | Allowed |
| The Finale | Banned | Banned; the finale kit is fixed and provided |

The economic consequence is the part that matters. **Mending removes gear attrition, and gear attrition is the demand side of the Berry economy.** If armour never wears out, there is no recurring reason to buy any. Compensate by meeting Section 8's 60 to 80 per cent sink target from sinks Mending cannot defeat: repair costs on non-Mending items, claim block purchases, home slots, auction house tax, `/pay` tax, and war entry costs. Cosmetics are earned and never sold, so they are not a sink and must not be counted as one.

If sink coverage falls below target, **add a sink. Never nerf Mending after players have earned it.**

### 31.5 Farms and production rate, not just prices (amends Section 8)

Section 8 prices items with `base_worth = (expected_minutes_to_obtain * target_berries_per_hour) / 60`. That formula assumes a human obtaining an item by hand. It does not survive an AFK farm.

The owner explicitly rejected the idea that mining around the clock should reach the top of the ladder. The identical logic applies to earning, and the document never applied it.

* Every item sellable to the server shop must carry a **stated assumed acquisition method**.
* If a farm exists that beats the assumed method by more than **3x**, the sell price is derived from the farm rate, not the manual rate.
* Price from farm rates for at minimum: iron, gold, copper, any mob drop obtainable from a spawner or trap farm, bamboo, sugar cane, kelp, cactus, honey, and anything a villager will trade in volume.
* **Cap per-player shop sell volume per item per day.** This is a blunt instrument and it works. Publish the cap; it is a game rule, not a detector, so hiding it only confuses honest players.
* The economy audit script in Appendix E must add a **production report**: the top ten Berry sources by volume each week, with the ratio of actual to modelled earn rate. Anything above 3x is repriced at the next pricing window.

Note the distinction this closes. Section 8 already handles crafting-chain arbitrage well, including smelting, uncrafting, and villager trades. Arbitrage is a **pricing** exploit. Farms are a **production** exploit. Only the first was covered.

### 31.6 New player protection (amends Sections 7 and 14)

A paid, whitelist-gated server cannot allow a new arrival to be farmed at spawn. The document had a refund policy but no prevention.

* **PvP disabled inside the spawn region.** Section 7's WorldGuard flags already deny PvP by region; state it explicitly for spawn and verify it.
* **30 minutes of cumulative playtime grace on first join**, during which the player can neither deal nor receive player damage. Shown as a visible countdown so it is never a surprise.
* Grace **ends early and permanently** the moment the player attacks another player. It cannot be regained.
* Grace does not apply to a known alt account of an existing player, and is void inside a war arena.
* **Camping the spawn exit region is a Section 14 offence.** Enforce it, because a paid player who cannot leave spawn will ask for a refund and will be right to.

### 31.7 Server list presentation (amends Sections 18 and 16)

None of these existed anywhere in the document, and the first is the first thing any player ever sees.

* **MOTD:** two lines, the server name and the current season with days remaining. **Generated, not hand-typed**, so it can never go stale.
* **Server icon:** a 64x64 PNG committed to the repository.
* **Tab list:** rank prefix, player name, ping. Updated asynchronously. Header shows the season and days remaining; footer shows the website.
* **Bossbar: reserved.** Used only for war events and the final hour of a season. An always-on bossbar is visual noise and wastes the one attention-grabbing surface the game gives you.
* **Sample player list in the server ping: disabled**, so the online roster cannot be scraped by third-party listing sites.

### 31.8 Scheduled restarts (amends Sections 5 and 6)

Section 5 mentions announced restarts in one clause with no schedule attached. Paper degrades over long uptimes, so this needs to be concrete.

* **One restart per day at 05:00 IST**, chosen as the lowest-traffic hour for an India-centred playerbase.
* Warnings at 15 minutes, 5 minutes, 1 minute, and 10 seconds.
* Implement it as a **Pelican schedule, not a cron job inside the container**, so it survives a container rebuild and stays visible in the panel.
* **Never restart during a war event or the final hour of a season.** The scheduler must check both and defer, then restart once the event ends.
* Acceptance: the uptime graph shows a restart inside the expected window every day, and no restart inside an event.

### 31.9 Staff account security (amends Sections 17 and 29.13)

An Admin can `/eco give`. An Owner can `/rollback`. A compromised staff account is an economy-ending event on a server whose entire premise is a fair ledger, and the document covered panel key hygiene without ever covering the accounts behind it.

* **Two-factor authentication is mandatory** on the Pelican panel, the GitHub account or organisation, the domain registrar, the store account, and the email address that can reset all of them.
* **Staff Minecraft accounts must have Microsoft account 2FA enabled.** Verify at appointment and re-verify each season.
* **No shared staff accounts.** One human, one account, one name in the audit log. A shared account makes the audit trail worthless exactly when it matters.
* **Staff must not connect through a proxy or VPN**, because it defeats the alt and ban-evasion checks. Enforce this by policy rather than IP blocking, which produces false positives on Indian mobile networks.
* **Owner-level commands require a second confirmation step** and are logged to a destination the Owner does not solely control.

### 31.10 Market abuse on the order book (amends Sections 8 and 14)

The order-book market invites two abuses that alt-detection will never catch, because no rule is being evaded.

* **Wash trading:** two accounts trading with each other to manufacture a false price signal. Detect by flagging counterparties with an abnormally high mutual trade ratio and few or no other counterparties.
* **Cornering:** buying the entire supply of an item to push the dynamic price band upward, then selling into it. The existing band of plus or minus 35 per cent with a 25 per cent floor limits the damage; add a per-player share-of-volume alert on top.
* Both are **alert-only for the first full season**, consistent with how Section 3.5 treats the wagering detector. Watch the data before writing a rule around it.
* Thresholds live in the private documentation, never in the public repository, per Section 29.11.

### 31.11 Illegal items and crash vectors (amends Sections 14 and 6)

The plugins were listed. The policy was not.

**An illegal item is** any item with NBT or component data unobtainable in survival on this version, any stack above its vanilla maximum, any item carrying an enchantment above its vanilla maximum or an enchantment that cannot legitimately apply to it, or any container holding another container.

* **On detection:** remove the item, log it with its full data, notify staff, and do **not** punish automatically. The first response to an illegal item is an investigation, because the usual cause is a bug in our own code, not a cheater.
* Block the known crash vectors: oversized books and written-book NBT, oversized signs, malformed packets, entity-count and chunk-load abuse, and firework and elytra chunk-ban patterns.
* **Downtime on a paid server converts directly into refund requests.** That makes exploit hardening a commercial requirement, not a technical nicety.

### 31.12 Resource world reset (amends Section 7)

The resource world has a 3,000 block border and no reset cadence, which means it is stripped bare by month three and the gathering half of the economy quietly dies.

* **Reset the resource world at the season instant, every month**, immediately after the season reset job completes.
* Announce it on the same countdown schedule as the season, so nobody loses a base they did not know was temporary.
* Player inventories and everything in the main world are unaffected. **Nothing in the resource world is preserved** - that is the entire point of it, and it must be stated in `/rules` and on the website.
* **The main survival world is never reset. Ever.** Say this plainly and permanently on the website, because every prospective player will ask, and it is the single biggest reason a builder chooses one server over another.

### 31.13 Player data, deletion, and retention (amends Sections 3 and 18)

Taking real money from Indian players and storing gameplay data means Indian law applies.

* **The governing law is India's Digital Personal Data Protection Act 2023, not GDPR.** Do not copy a GDPR notice and assume it is sufficient.
* Publish what is collected, why, how long it is kept, and how to request deletion.
* **On a deletion request:** remove the account identifier, chat logs, IP records, and payment linkage. Retain aggregate and anonymised season results, including any Champion record, under a pseudonymous identifier. State this in the privacy notice so it is never a surprise.
* **Retention:** chat and connection logs 90 days, moderation records 2 years, and the economy ledger for the life of the server because it is a financial audit trail.
* **A deletion request does not erase a ban.** Retain the minimum needed to enforce it, and say so.

### 31.14 Language (amends Sections 18 and 13)

* The server, the website, and every command are **English-only at launch**. This is a recorded decision, not an omission.
* Rationale: one language is one set of strings to keep correct, and mixed-language moderation is how rule enforcement becomes inconsistent and disputes become unwinnable.
* **All player-facing strings live in one message file**, so a translation can be added later without touching a line of code.
* Voice chat is unmoderated by design. Section 13's rules apply regardless of the language being spoken.

### 31.15 Acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 31-1 | The season instant is stored in UTC and rendered correctly in IST | Database row plus `/season` output |
| 31-2 | A reset triggered while the server was offline uses the scheduled instant, not boot time | Test log from a simulated outage |
| 31-3 | Two players forced to an identical RP resolve to exactly one Champion through the chain | Test log naming the deciding criterion |
| 31-4 | A tagged bot that disconnects dies, drops items, and pays the extra penalty | Automated test output |
| 31-5 | Teleport and container commands are all refused while combat-tagged | Test log covering every blocked command |
| 31-6 | Totems and Mending are refused by the arena and finale inventory checks | Event log |
| 31-7 | Sink coverage sits inside the 60 to 80 per cent target with Mending in play | Economy audit report |
| 31-8 | No shop item earns above 3x its modelled rate for two consecutive weeks | Production report |
| 31-9 | Daily per-item sell caps are enforced and published | Config plus `/rules` |
| 31-10 | A new account cannot deal or take player damage for 30 minutes, and loses grace on attacking | Test log |
| 31-11 | MOTD and tab list show the live season and days remaining, generated not hard-coded | Server list screenshot plus source |
| 31-12 | The daily restart fires in its window and defers during a war event | Uptime graph plus scheduler log |
| 31-13 | 2FA is verified on all five owner-controlled accounts and on every staff Minecraft account | Signed checklist in `docs/private/` |
| 31-14 | Wash-trading and cornering alerts fire on seeded synthetic data | Alert log |
| 31-15 | Every illegal-item class is detected, removed, logged, and does not auto-punish | Test log |
| 31-16 | The resource world resets at the season instant and the main world does not | Two consecutive season logs |
| 31-17 | A data deletion request completes while the ban and the anonymised Champion record survive | Redacted request record |
| 31-18 | Every player-facing string resolves from the single message file | Grep for hard-coded strings returns nothing |

---

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

## END OF DOCUMENT

**LaughTail SMP - Master Build Prompt, Version 6.0.**

This document supersedes and replaces every previous version and every addendum. If any earlier document conflicts with this one, this one wins.

Before declaring the project complete, verify:

* Every acceptance criterion in every section is marked pass, with evidence.
* Every row in Section 21 is green.
* Every requirement in Appendix F is traceable to working, tested code.
* Every deviation is recorded in the decision log.
* A full migration has been performed successfully at least once.

Then, and only then, open the doors.
