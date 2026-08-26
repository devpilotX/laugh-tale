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

