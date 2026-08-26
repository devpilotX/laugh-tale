# Proposals awaiting owner approval

Every number in this file is a **proposal, not a decision**. Nothing here is implemented. They exist so the owner approves or amends a concrete figure instead of inventing one from scratch — which is what spec 32 asks for and what `docs/questions.md` **Q-10** has been blocking on.

Each proposal states the value, the derivation, and **what breaks if it is wrong in each direction**. That last part matters more than the number: a value you can reason about is one you can correct later.

Reply with "approve P1" style, or give a different figure. Anything not approved stays unbuilt.

---

## P1 — The access price (blocks OA-12, and Phase 1 entirely)

**Proposed: ₹199 one-time, per account, INR only.**

**Derivation.** The market comparison is Indian Minecraft SMPs, which cluster between ₹50 and ₹300 for whitelist access. Below ₹100 the payment-processor fee becomes a large fraction of revenue — Razorpay-class fees are roughly 2% plus GST, so on ₹50 you lose real margin on every sale and a refund costs more than the sale earned. Above ₹300 you are competing with servers that have an established Champion history, which LaughTail does not have yet.

₹199 also sits under the psychological ₹200 line and is a single clean number to put on a store page.

**Why one-time rather than recurring.** Spec 24.1 leaves this open and D-0002 already built `access_grants.expires_at` as nullable so both work with no schema change. One-time is proposed because:
- It matches what the market expects, so it needs no explanation on the store page.
- Recurring billing on a 20-player server is administratively heavier than the revenue justifies — failed renewals, dunning, and involuntary churn all become support work.
- Mojang's Commercial Usage Guidelines permit a single access fee cleanly; recurring adds no legal difficulty but does add refund complexity.

**If it is too low:** you undercharge for a server with real running costs, and the player base skews towards people who churn. Recoverable — raise it for new grants; existing grants are permanent and honouring them is good faith.

**If it is too high:** the soft launch does not fill, and Phase 9 cannot produce the one full season its gate requires. Harder to recover, because a price cut visibly devalues what earlier buyers paid. **So err low.**

**What this unblocks:** OA-12, and with it the store product (OA-10) and Phase 1's entire paywall.

---

## P2 — `target_berries_per_hour` = **1,200**

The anchor from which every price derives. Appendix B's base-value formula needs it.

**Derivation.** Assume a competent player playing deliberately for one hour: roughly a stack and a half of iron-tier ore, some mob drops, a little farming. Set that hour to 1,200 Berries and every other price follows as a multiple of "how long should this take to afford".

That gives a legible scale:
- A full set of iron gear ≈ 1 hour
- A modest home upgrade ≈ 2–3 hours
- A Tier 7 luxury item ≈ 20–40 hours

**If too high:** everything is affordable too quickly, the shop stops being a goal, and Berries inflate because supply outruns sinks.
**If too low:** the game feels like unpaid work, which on a *paid* server is the worse failure — people who have already paid resent grinding.

**Err high.** Inflation is fixable with sinks; resentment is not fixable at all.

---

## P3 — Minimum buy/sell spread = **12%**

Acceptance row 27 tests "the minimum spread" and the specification never states one, so this row is currently untestable.

**Derivation.** The spread is the server's cut and the anti-arbitrage margin in one. Below about 8%, rounding on cheap items can produce a positive-yield loop — buy 64, sell 64, come out ahead by one Berry — which is exactly what the Phase 3 arbitrage audit is built to fail the build over. Above roughly 20% trading feels punitive and players stop using the shop, which pushes them to unmonitored player-to-player trades and defeats the ledger.

12% leaves margin for rounding at every quantity while staying invisible on a single trade.

**If too tight:** the arbitrage audit fails the build, which is the system working — annoying, not dangerous.
**If too wide:** the shop is bypassed and the economy moves off-ledger, where the audit cannot see it. That is the dangerous direction, so **err tight**.

---

## P4 — Price elasticity = **0.15 per 1,000 units traded**, band **±40%** of base

**Derivation.** 8.x wants dynamic prices in a bounded band. Elasticity has to be slow enough that a single player cannot move a price meaningfully in one session, and fast enough that a genuine supply glut is visible within a day. At 0.15 per 1,000 units, one player selling 500 units moves the price about 7.5% — noticeable but not exploitable. Twenty players doing it moves it to the band edge, which is the correct signal.

The ±40% band means the floor is 60% of base, so nothing becomes worthless and nothing becomes a money printer.

**If too elastic:** one coordinated group crashes a market deliberately — 31.10's market-manipulation territory.
**If too inelastic:** prices are static in all but name and the "dynamic" claim is decoration.

---

## P5 — Price recovery = **5% of the gap per hour**, toward base

Prices drift back when trading stops, so a market crashed by a glut heals in roughly a day rather than staying broken until someone intervenes.

**If too fast:** manipulation becomes free — crash it, buy cheap, wait an hour.
**If too slow:** an early glut permanently disfigures a market. **Err slow**, because a slow recovery is visible and can be nudged, whereas fast recovery is an exploit.

---

## P6 — Daily sell caps = **3× `target_berries_per_hour` per item category**, i.e. 3,600/day/category

31.5 requires daily sell caps and gives no number.

**Derivation.** A cap per *category* rather than per item stops the obvious dodge of rotating between similar items. Three hours' worth per category per day means a player can sell a full session's honest haul, but an automated farm running unattended for twenty hours cannot convert its whole output.

**If too low:** honest players hit a wall and it feels arbitrary — the worst kind of limit.
**If too high:** AFK farms print money, which is the failure mode the resource world and the caps exist to prevent together.

---

## P7 — Balance-growth alert = **4× the median active balance**, checked nightly

Not a cap — an alert. A player legitimately far ahead should not be punished, but they should be looked at.

Median, not mean, deliberately: one wealthy player drags a mean upward and hides the next one.

---

## P8 — Anti-snipe window = **30 seconds**

An auction bid inside the last 30 seconds extends the auction by 30 seconds. Standard, well understood by players, and it removes the reflex-and-latency advantage — which matters on a server whose players are on Indian domestic connections with variable ping to Mumbai.

---

## P9 — Auction listing slots = **6 per player**, +2 per shop tier above 4

**If too few:** players cannot clear inventory and use chest shops instead, off-ledger.
**If too many:** the auction house becomes a search problem and a memory cost on a 3.8 GB box.

---

## P10 — Transfer tax = **5% on transfers above 5,000 Berries**

Wealth transfer between players is how a suspended account moves its balance to an alt, and how real-money trading settles in game. A threshold means small legitimate gifts are untaxed while bulk movement is both taxed and, more importantly, **logged as notable**.

The tax is a sink; the threshold is a detector. The 5,000 figure is roughly four hours of play, so it does not catch ordinary generosity.

---

## What I need from you

**P1 is the one that matters most** — it unblocks Phase 1, which is the paywall, which is the product's entire commercial model.

**P2 unblocks Phase 3**, and P3 to P10 are only meaningful once P2 is fixed, because every one of them is expressed relative to it.

If you would rather not decide ten things at once: **approve P1 and P2 alone** and I will build Phase 1 and the economy's skeleton, then bring you P3–P10 with real numbers from a running ledger rather than from reasoning.


---

# The ranking contradictions (Q-11 to Q-13)

These three are different in kind from P1–P10. They are not missing numbers — they are places where **Appendix B and Section 9 say incompatible things**, so any implementation contradicts one of them. Spec 28.8 names ranking as where maximum care is warranted, so I am not picking silently.

Each proposal says which text I would follow and why.

## P11 — `MAX_GAIN` is unreachable (Q-11)

**The contradiction.** Appendix B sets `MAX_GAIN = 40`, but also computes `raw = 24 * (1 - E)`. Since `E` is a probability between 0 and 1, `raw` is always below 24. The cap can never bind, so it is either dead code or one of the two numbers is wrong.

**Proposed: keep `raw = 24 * (1 - E)` and set `MAX_GAIN = 24`.**

The 24 coefficient is doing the real work — it is the K-factor that decides how fast the ladder moves, and 24 gives a season-length ladder that settles in roughly 30–40 fights. Changing it to make 40 reachable would make rank swing far faster than a monthly season wants.

So `MAX_GAIN` becomes a genuine ceiling at the value the formula can actually produce, and stays in the code as a guard against a future multiplier pushing a single gain higher than one clean upset should.

## P12 — The death floor removes demotion (Q-12)

**The contradiction.** 9.2 says a death cannot drop you below "the bottom of the ladder". Appendix B says the floor is `max(tier_floor(CR_victim), ...)` — the bottom of *your current tier*. Under Appendix B you can never fall out of a tier you have reached, which means **there is no demotion at all**, and a ladder without demotion is a high-water mark, not a rank.

**Proposed: follow 9.2. The floor is the bottom of the entire ladder, not of your tier.**

Rank is the product's core promise and it must be able to go down, or it stops measuring current skill and starts measuring peak skill — which `stats.peak_rp` already records separately and correctly.

**The cost, stated honestly:** players will lose tiers, and cosmetics unlock by tier (Section 11). Losing a visible cosmetic hurts more than losing a number, and that is a real retention risk. Mitigation: unlocks should be **permanent once earned** — `cosmetics_owned` in Appendix D is already marked "never deleted by a reset", which suggests the specification already intends this. So you can be demoted in rank without losing what you unlocked.

## P13 — Decay is twentyfold different (Q-13)

**The contradiction.** 9.2 says decay is "1% per week above the tier floor". Appendix B says `CR * (1 - DECAY_RATE)`. At CR 2000 with a tier floor of, say, 1800, the first reading decays 1% of 200 = **2 points/week**; the second decays 1% of 2000 = **20 points/week**. Ten times different at that rating, and worse higher up.

**Proposed: follow 9.2 — decay 1% per week of the distance ABOVE the tier floor, never below it.**

Decay exists to stop an inactive player holding a top position, not to punish absence. Appendix B's form is proportional to total rating, which means it hits the most active, highest-rated players hardest for a single week away — the opposite of the intent. 9.2's form is self-limiting: it approaches the tier floor and stops, so a week off costs a little and a month off costs progressively less.

**Also proposed:** decay should not apply during the first week of a season, so a player who joins late is not decaying before they have played.

---

## Why these three are safe to approve now

They are internally consistent with each other, they follow Section 9 over Appendix B in every case where the two disagree, and none needs a number that does not already exist in the specification. Approving them lets Phase 4's rating engine be built against the combat-event history that is **already being recorded** — so the first implementation can be validated against real kills rather than synthetic tests.

If you would rather not rule on ranking maths at all, say so and I will build everything in Phase 4 that does not depend on it: the season lifecycle, the reset job with its idempotency, the archive, and the Champion mechanism. Only the rating arithmetic itself has to wait.
