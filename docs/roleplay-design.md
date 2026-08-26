# Roleplay design - the Second Ladder

Written 2026-08-26. The owner delegated this ("only you know better than anyone my server. we want fun
and addictive role play and like wow"), so this document makes the decision and explains it well enough
to be argued with.

## The problem this actually solves

There is a hole in the product, and it is worse than the missing feature.

**Right now the only progression on this server is PvP rank.** A player who loses fights has nothing to
climb. They mine, they build, they trade - and none of it moves any number that anyone can see. Row 30
guarantees that, deliberately and correctly: two hours of mining must change rating by *exactly zero*.

That guarantee is what makes the ladder honest. It is also a retention hole, because most players are
not top-decile fighters, and a server where 80% of players have no visible progress loses them.

**So roleplay is not decoration here. It is the second ladder** - a place to climb for everyone who is
not winning fights, built so it can never leak into the first one.

## What "like WoW" means here, and what it deliberately does not

Taking the reading generously, WoW is addictive for four reasons, and three of them are free:

| WoW does | Taken? | Why |
| --- | --- | --- |
| A visible progression bar that always moves | **Yes** | This is the engine of the whole thing |
| Social identity and belonging to a group | **Yes** | Cheap, powerful, and this server has none |
| Unfolding story with a sense of place | **Yes** | This is the "wow" |
| Levels and gear that make you STRONGER | **No** | This would end the server |

That last row is not squeamishness. **A profession that grants damage, health, speed, reach or drop
rate breaks Law 1's total equality and violates row 30 directly.** It would also make the PvP ladder
meaningless: rank would measure who ground their profession, not who fought better. Every server that
adds "just a small combat perk" to a profession discovers within a month that the perk is the only
thing anyone talks about.

**So the rule for the entire system is one sentence: roleplay grants status, never power.**

This is not a new invention - it is exactly how the Champion title already works (9.6: a permanent
prefix, a crown, a Hall of Fame entry, and explicitly no Berries, items, gear, stats, permissions or
discounts). The Champion title is valuable *because* it buys nothing. The whole roleplay system is
built on that same insight, scaled up.

## The design, in four parts

### 1. Paths - the personal ladder

Six Paths, each levelling from what you already do:

| Path | Advances from |
| --- | --- |
| **Delver** | Mining, depth reached, rare ore found |
| **Cultivator** | Farming, breeding, unique crops grown |
| **Hunter** | Mob kills, dangerous mobs, boss fights |
| **Wayfinder** | Distance travelled, biomes visited, structures found |
| **Artificer** | Crafting, enchanting, blocks placed |
| **Broker** | Trades completed, orders filled, market volume |

Every Path levels independently and visibly - the HUD shows your active Path and its progress, so
something is always moving. Levels award **titles, cosmetics, emotes, and Chronicle access**. Never a
statistic.

**Why six and why these:** each maps onto an activity players already do, so no grind is invented for
its own sake. And Broker exists deliberately so that market play - which is real skill - has a ladder
too, instead of being invisible.

### 2. Houses - the group identity

Four Houses with lore, chosen once, changeable rarely. A House earns standing from **every** activity of
its members - Path levels, Chronicle chapters, market volume, and yes, PvP - so a House full of farmers
can beat a House of fighters. Seasonal House standing pays out in banners, a title, a monument entry,
and nothing else.

**Why this matters more than it looks:** it gives a losing player a team that is winning. Belonging is
the cheapest retention mechanic in existence and this server currently has none.

**The trap avoided:** Houses are NOT factions with land, war declarations, or taxes. Taxes would create
a second economy alongside the Berry ledger, which is the same mistake as the shard shop refused in
D-0035, and would break the arbitrage audit's guarantee that there is exactly one place value is
created.

### 3. Chronicles - the story

A seasonal server-wide narrative delivered in chapters. Each chapter has objectives spread across the
Paths, so no single player type can complete it alone - a chapter might need 10,000 blocks mined, a
boss killed, and 50 orders filled. Progress is server-wide and visible.

**Why server-wide rather than per-player:** it makes strangers cooperate without forcing them into a
party, it costs almost nothing to compute, and it produces the thing this server has no other source of
- a sense that something is *happening*. Per-player quest chains would need NPCs, dialogue trees and
far more memory than 500 MB allows.

Chapter rewards: lore, a title, a cosmetic, and the next chapter. Never an item.

### 4. Voice - the in-character layer

Local chat with a radius, a House channel, and `/me`. Cheap to build, and it is what actually makes
people roleplay rather than merely having roleplay statistics.

**Soft RP, not hard RP.** Breaking character is not punishable. Hard-RP enforcement needs constant
staff attention this server does not have, and it turns moderation into taste policing - which is the
fastest way to make a small server feel hostile.

## What this costs, honestly

Paths and Houses are counters and a level table: a handful of columns, updated from events already being
tracked for stats. Chronicles are one row per chapter plus server-wide counters. **No NPCs, no dialogue
trees, no pathfinding, no per-player quest state machines** - those are what make roleplay plugins
expensive, and every one of them is avoided.

The heaviest new cost is Path XP updates on common events, and those batch through the same async delta
mechanism the stats tracker already uses.

## The single line to hold onto

**If a roleplay reward ever changes a number that matters in a fight, the design has failed.** Titles,
colours, banners, emotes, lore, access, recognition - unlimited. Damage, health, speed, drops,
discounts, permissions - never.

That is what keeps the PvP ladder worth climbing, and it is the reason this system can be as generous
and as addictive as it likes without ever threatening the thing the server is actually selling.
