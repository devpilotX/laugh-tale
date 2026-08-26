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

