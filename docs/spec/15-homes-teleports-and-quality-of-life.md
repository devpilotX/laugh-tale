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

