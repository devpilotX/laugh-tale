# Should everything become one custom plugin?

The owner asked to build "all in one plugin for 26.2" so nothing depends on third parties. This document
answers that plugin by plugin, because the honest answer is different for each one.

## The instinct is right, and it is already mostly done

The worry behind the request is real: a third-party plugin that does not update to a new Minecraft
version blocks the whole server. That has already happened once here — GrimAC does not support 26.2 and
that single dependency is now the largest thing standing between this server and paying players.

So the instinct is correct. It is also, for gameplay, already satisfied. **Everything that makes this
server what it is was written from scratch and depends on nothing:** the economy and its ledger, the
shop with its dynamic prices and arbitrage audit, the bazaar and its matching engine, ratings and
seasons, the combat tag, homes, teleports, friends, moderation, access grants, the GUI, the HUD, Paths,
Houses, the Chronicle. That is one plugin, `LaughTail`, 24 source files, and it needs only Paper.

The nine remaining plugins are not gameplay. They are infrastructure — protocol translation, permissions
storage, world management, pregeneration, profiling. Which changes the question from "can we write our
own?" to "would ours be better?"

## Plugin by plugin

| Plugin | What it does | Absorb it? |
| --- | --- | --- |
| **Geyser** | Lets Bedrock players connect at all | **Never.** See below |
| **Floodgate** | Bedrock account authentication for Geyser | **Never.** Same reason |
| **ViaVersion / ViaBackwards** | Lets clients on other Minecraft versions connect | **Never.** Same reason |
| **LuckPerms** | Permission storage and inheritance | **No.** See below |
| **Multiverse-Core** | Creating and managing the five worlds | **Yes, eventually.** Worth doing |
| **Chunky** | Pregenerates chunks so players do not generate them | **Yes, but pointless.** See below |
| **spark** | Performance profiling | **No.** It is a tool, not a dependency |
| **simple-voice-chat** | Proximity voice | **Never.** Needs a client mod on the other end |
| **GrimAC** | Anti-cheat | **Removed already**, and this is the real problem |

### The four that must never be absorbed

Geyser, Floodgate, ViaVersion and simple-voice-chat all implement **network protocols spoken by software
we do not control**. Geyser translates the entire Bedrock protocol; ViaVersion translates between
Minecraft versions; voice chat speaks to a mod installed in the player's own game.

Writing our own would mean reimplementing tens of thousands of lines of protocol work, then maintaining
it against every Bedrock and Java release forever. Geyser is maintained by a large team full time. An
in-house version would be worse in a month and unmaintainable in a year — and its failure mode is
"Bedrock players cannot join", which is exactly the outcome the request is trying to avoid.

**These are not dependencies in the risky sense.** They are how the outside world reaches the server. A
custom one would not reduce risk; it would concentrate all of it on one person.

### LuckPerms: the one where doing it ourselves is actively worse

Permissions look easy. They are not, and this project has already been bitten by the part that is hard.

`docs/decisions.md` D-0034 records it: a wildcard denial on the admin group made `default: op` in
`plugin.yml` grant **nothing**, so every permission had to be granted by name. That is inheritance
resolution and negation precedence — subtle, security-critical behaviour that LuckPerms gets right and
that a homegrown version would get wrong in ways nobody notices until an admin can do something they
should not.

The permission ladder is also **already ours**: `server/permissions.yml` is the source of truth, applied
by script and then verified node by node. LuckPerms is the storage engine underneath, not the design.
Replacing it would mean rewriting the one component where a bug means privilege escalation, to gain
nothing a player would ever see.

**Recommendation: keep it.** If it ever fails to support a Minecraft version, the ladder is a committed
file and can be applied a different way in an afternoon.

### Multiverse: worth absorbing, and the only genuine candidate

This is the one where the request is right on the merits.

Multiverse is a large plugin and this server uses a sliver of it: create five worlds, apply a border,
apply gamerules, teleport between them. **The gamerules and borders are already enforced by our own
code** — `WorldRules.java` applies them on every world load, precisely because doing it through
Multiverse commands proved unreliable across the 26.2 rename of `doFireTick`.

What is left is world creation and the `/mv` teleports, which is a few hundred lines against Bukkit's
own `WorldCreator`. And the version risk is real: Multiverse is currently pinned to `5.8.1-pre.3`, a
**pre-release**, accepted because no stable build supported 26.2.

**Recommendation: absorb it**, once the features that affect players are finished. Depending on a
pre-release for world creation is the second-largest version risk after anti-cheat.

### Chunky: absorbable, and not worth the afternoon

A pregenerator is a loop that loads chunks slowly enough not to stall the server. Genuinely simple to
write. But it runs **once**, before launch, and never again — and it is not loaded at runtime, so it
cannot break anything. Rewriting a tool that has already done its job is effort spent for no return.

**Recommendation: leave it. Remove it after pregeneration is complete**, which removes the dependency
without writing a line.

### GrimAC: the request cannot fix this one

Anti-cheat is the dependency that is actually hurting, and it is the one an in-house plugin cannot
replace. Detecting movement cheats means simulating Minecraft's own physics accurately enough to know
what a legitimate client could and could not have sent. GrimAC is years of work by people who do
nothing else.

A homegrown one would either miss real cheaters or ban innocent players for lag — and on a server whose
entire value is a fair PvP ladder, false bans are worse than no anti-cheat.

**This remains OA-32: a decision, not an engineering task.**

## What this means in practice

The dependency count goes from nine to seven, and both removals are real reductions in risk:

1. **Absorb Multiverse** into the core plugin. Removes a pre-release dependency from the boot path.
2. **Drop Chunky** once pregeneration is done. Costs nothing.

The other seven stay, and `AGENTS.md` says why in one line: *prefer the boring, well-supported plugin
over the clever custom one.* That bias exists because a custom plugin is only better while the person
who wrote it is available and remembers how it works.

## The one thing worth doing regardless

Every third-party plugin is pinned to an exact version with a checksum in `server/manifest.yml`, and
never-break rule 9 forbids installing anything that is not. That is what makes these dependencies
survivable: nothing updates by surprise, and a version that works keeps working until it is deliberately
changed.

The remaining exposure is a plugin that never supports a **future** Minecraft version. The answer to that
is not to write nine plugins — it is to accept that upgrading Minecraft is a project each time, with the
manifest as the checklist of what must be proven first.
