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

