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

