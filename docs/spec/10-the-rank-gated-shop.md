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

