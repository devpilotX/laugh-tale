## SECTION 4 - PLATFORM, VERSIONS, AND CLIENT SUPPORT

### 4.1 Server software

**Paper.** Not Spigot (slower, fewer optimisation knobs), not vanilla (no plugin API), not Folia yet (Folia's threaded regions are a real win at high player counts but the plugin ecosystem is not there for an economy server; revisit only after migration, and only if a specific measured bottleneck justifies it).

Purpur is acceptable if and only if you need a specific Purpur-only config toggle; document which one and why. Otherwise stay on Paper for the larger tested plugin surface.

### 4.2 Minecraft version policy

Minecraft moved to **calendar-style versioning** after 1.21.11. There is no 1.22; the line went 1.21.11 -> 26.1 -> 26.2 and onward. Notes that matter to you:

* Modern releases require a recent JDK. Use the JDK the current Paper build asks for, not an older one you happen to have.
* Paper removed the legacy remapper in the 26.1 line. Plugins compiled against very old internals may simply not load. Check every plugin's stated support for your exact version before install, not after.

**Policy:** run the **latest stable release that all critical plugins support.** Never run a snapshot in production. Never update on launch day of a new version - wait for anti-cheat and the economy plugins to confirm support. Pin the exact version in the compose file; never use a floating `latest` tag.

### 4.3 Client version support

**ViaVersion + ViaBackwards + ViaRewind** so older clients can connect. This is close to mandatory for an Indian playerbase where many players are on older or lower-spec setups.

**Do not let Via become an excuse for a mixed-integrity PvP environment.** Combat mechanics changed significantly across versions. Decide and publish one rule: either (a) all players are translated to current combat mechanics, or (b) accept the variance and say so. Recommended: (a), and state on the website which client version gives the reference experience.

### 4.4 Bedrock crossplay

**Geyser + Floodgate.** Xbox Live authentication satisfies the genuine-copy requirement in 3.2. Things to know before promising crossplay:

* Bedrock players cannot install Java client mods. Anything requiring a client mod excludes them (this drives the voice chat decision in Section 13).
* Geyser does not convert Java resource packs. Bedrock cosmetics need a separate Bedrock pack, or must be delivered by a mechanism that works without packs.
* Chat signing needs handling for Bedrock; set Paper's chat signing off or use the standard compatibility plugin, and set a clear Floodgate username prefix so staff can always tell platforms apart.
* **Datapack content reaches Bedrock players automatically through Geyser**, because it is server-side. This is the single best reason to use datapacks for advancements and recipes.

### 4.5 Lunar Client and the pause menu question

The owner uses Lunar Client and admired DonutSMP's server-specific entry in the ESC pause menu.

**The honest technical position:** a server cannot add arbitrary buttons to the vanilla pause menu. What DonutSMP-style servers do is either (a) use Lunar's Apollo integration, which allows a server to influence certain client-side features for Lunar users only, or (b) not touch the pause menu at all and instead provide an in-game settings GUI opened by a command.

**Decision:** build the settings GUI (Section 16) as the primary, universal, works-for-everyone surface. Bind it to `/settings`, with `/menu` and `/options` as aliases. Optionally add Apollo integration for Lunar users as a nicety, clearly marked as a bonus, never as the only path to a setting. **No setting may be reachable only through a specific client.** That would violate Law 3.

---

