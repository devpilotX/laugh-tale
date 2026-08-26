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

