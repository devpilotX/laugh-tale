## SECTION 19 - THE COMPLETE COMMAND REFERENCE

This section is the authoritative command list. Implement it, then generate the player-facing help text and the website command page **from this list**, so the three can never drift apart.

**Conventions used below:** angle brackets mark a required argument, square brackets mark an optional one. "All" means every player including a brand-new one on their first join.

### 19.1 Essentials - all players

| Command | Aliases | Description |
|---|---|---|
| /help [topic] | /? | Category-based help. Never a flat wall of text |
| /rules | | Open the rules GUI |
| /rules accept | | Accept the rules. Required on first join (14.5) |
| /spawn | /hub, /lobby | Return to spawn |
| /msg (player) (message) | /w, /tell, /pm | Private message |
| /reply (message) | /r | Reply to the last private message |
| /ignore (player) | | Block messages from a player |
| /ignorelist | | View your ignore list |
| /mail | | Offline mail: read, send, clear |
| /list | /online, /who | Online players by rank |
| /ping [player] | | Connection latency |
| /discord | | Discord invite link |
| /website | /site | Website link |
| /store | | Store link |
| /vote | | Voting links |
| /report (player) (reason) | | File a report with auto-attached evidence (14.7) |
| /reportstatus | | Check the status of your reports |
| /appeal | | Link to the appeal form |
| /afk | | Toggle AFK status |
| /suicide | /kill | Kill yourself. **Disabled while combat-tagged**, or it is an escape from a lost fight |

### 19.2 Settings and the menu - all players

| Command | Aliases | Description |
|---|---|---|
| /settings | /menu, /options, /laughtail | **The main control panel GUI** (Section 16) |
| /settings notifications | | Notification toggles |
| /settings chat | | Chat preferences |
| /settings display | | Scoreboard, action bar, holograms, particle density |
| /toggle (feature) | | Direct toggle for any single setting, for players who prefer typing |

### 19.3 Economy - all players

| Command | Aliases | Description |
|---|---|---|
| /balance [player] | /bal, /money | Berries balance |
| /pay (player) (amount) | | Transfer Berries. Taxed above a threshold (8.5). Confirmation required on large amounts |
| /baltop | /balancetop | Richest players |
| /shop | /menu shop | Open the shop GUI |
| /shop tiers | | **View the eight-tier ladder and your current unlock level** (10.3) |
| /sell hand | | Sell the held stack |
| /sell all (item) | | Sell all of one item from your inventory |
| /sell gui | | Sell interface |
| /worth [item] | /value | Current sell and buy price of an item |
| /prices | | Recently changed prices, so dynamic pricing is transparent (8.2) |
| /transactions | | Your own transaction history |

### 19.4 Auction house, orders, and trading - all players

| Command | Aliases | Description |
|---|---|---|
| /auctionhouse | /ah | Browse the auction house |
| /ah sell (price) | | List the held item at a buy-it-now price |
| /ah auction (start) (duration) | | List for bidding |
| /ah bid (id) (amount) | | Place a bid |
| /ah listings | /ah my | Your active listings |
| /ah expired | | Reclaim expired listings |
| /ah search (term) | | Search current listings |
| /ah history | | Your own auction history |
| /order buy (item) (qty) (price) | | **Post a buy order** (8.4) |
| /order sell (item) (qty) (price) | | Post a sell order |
| /order list | /orders | Your open orders |
| /order cancel (id) | | Cancel an order |
| /market [item] | | The order book with current best bid and ask |
| /trade (player) | | **Safe two-sided confirmation trade** (8.4) |
| /trade accept, /trade deny | | Respond to a trade request |

### 19.5 Homes and teleports - all players

| Command | Aliases | Description |
|---|---|---|
| /home [name] | /h | Teleport to a home. **Works from another home** (15.1) |
| /sethome (name) | | Set a home |
| /delhome (name) | | Delete a home, with confirmation |
| /renamehome (old) (new) | /homerename | **Rename a home** (15.1) |
| /homes | /homelist | GUI list of your homes |
| /buyhome | /homeslot | Buy an extra home slot with Berries, up to 20 |
| /tpa (player) | | Request to teleport to a player |
| /tpahere (player) | | Request that a player come to you |
| /tpaccept | /tpyes | Accept a request |
| /tpdeny | /tpno | Deny a request |
| /tpacancel | | Cancel your outgoing request |
| /tpauto (friends / party / off) | | **Auto-accept mode.** Never a blanket accept-from-anyone (15.2) |
| /rtp [world] | /wild | Random safe teleport, per-world cooldown |
| /resource | | Go to the monthly resource world (7.4) |
| /top | | Teleport to the highest safe block above you |
| /back | | Return to your previous location. **Never after a PvP death** (15.4) |
| /warp [name] | /warps | Public warps |

### 19.6 Claims - all players

| Command | Aliases | Description |
|---|---|---|
| /claim | | Claim land at your position |
| /unclaim | /abandonclaim | Release a claim |
| /claim trust (player) [level] | | Grant access at a trust level (7.3) |
| /claim untrust (player) | | Revoke access |
| /claim info | | Claim details and boundaries |
| /claim list | | Your claims |
| /claimblocks | | Your available and used claim allowance |
| /buyclaimblocks (amount) | | Buy claim allowance with Berries |
| /claim visualise | /claim show | Show claim boundaries |

### 19.7 Stats, rank, and season - all players

| Command | Aliases | Description |
|---|---|---|
| /stats [player] | | Full statistics (9.8) |
| /rank [player] | | Current rank, RP, and progress to the next tier |
| /ranks | /rankup | The full ladder and thresholds |
| /leaderboard [category] | /lb, /top rp | Leaderboards |
| /season | | Current season number, standing, and time remaining |
| /season history | | Past seasons and their final standings |
| /season rewards | | What the Champion receives (9.6) |
| /hof | /halloffame, /champions | **Every past Season Champion** (9.7) |
| /kd [player] | | Kill/death ratio |
| /killstreak | | Current and best killstreak |
| /playtime [player] | | **Hours until 24, then days and hours** (9.8) |

### 19.8 Cosmetics - all players, contents rank-gated

| Command | Aliases | Description |
|---|---|---|
| /cosmetics | /cos | Cosmetics GUI. Locked entries shown with their unlock rank |
| /cosmetics equip (id) | | Equip |
| /cosmetics unequip [slot] | | Unequip |
| /cosmetics dye (id) (colour) | | Recolour, costs Berries (8.5) |
| /cosmetics preview (id) | | Preview before unlocking |
| /cape | | Cape selection, Fighter and above |
| /wings | | Particle wings, Warrior and above |
| /trail | | Particle trail, Raider and above |
| /hat | | Wear the held block |
| /pack | | Resource pack info and re-download prompt |

### 19.9 War events and the Finale - all players

| Command | Aliases | Description |
|---|---|---|
| /war | /event | Current or next event info |
| /war join | | Sign up during the window |
| /war leave | | Withdraw before the start |
| /war lives | | Your remaining lives |
| /war roster | | Published participant list |
| /war spectate | | Spectate after elimination |
| /war history | | Past event results |
| /finale | | Finale bracket, schedule and qualification status (12.5) |

> **Deliberately absent: any betting or wagering command.** Gambling is prohibited (3.5). If you find such a command in any earlier draft, delete it.

### 19.10 Voice - all players

| Command | Aliases | Description |
|---|---|---|
| /voice | /vc | Voice settings: on/off, push-to-talk, volume (Section 13) |
| /voice test | | Verify your voice setup works |
| /voice group | | Create or join a voice group |
| /voice mute (player) | | Mute one player for yourself only |
| /voice help | | Setup guide, including the client-mod instructions |

### 19.11 Quality of life - all players

| Command | Aliases | Description |
|---|---|---|
| /craft | /workbench, /wb | Portable crafting |
| /enderchest | /ec | Ender chest access |
| /pv [number] | /vault | Personal vaults, identical count for everyone |
| /anvil, /grindstone | | Portable utility blocks |
| /repair | | Repair the held item, **costs Berries** |
| /nick (name) | | Nickname. **Impersonation blocked** (15.5) |
| /nick off | | Remove nickname |
| /nv | | Night vision toggle. **Disabled while combat-tagged** |
| /kit [name] | /kits | Available kits, identical for everyone |
| /rewards | | **Deterministic daily reward with a published list** (3.5) |
| /seen (player) | | Last-seen time |
| /whois (player) | | Public profile summary |

### 19.12 Helper

| Command | Description |
|---|---|
| /mute (player) (duration) (reason) | Short-duration mutes only |
| /unmute (player) | Remove a mute |
| /kick (player) (reason) | Kick |
| /warn (player) (reason) | Formal logged warning |
| /history (player) | Punishment history |
| /inspect | Toggle block-log inspection mode, read-only |
| /lookup (params) | Block-log lookup, read-only |
| /tppos (x) (y) (z) [world] | Teleport to coordinates |
| /report list, /report claim (id) | Work the report queue |
| /staffchat (message) | Staff-only channel |
| /vanish | Invisibility. **Must be genuinely undetectable**, or it is useless for observing suspected cheaters |

### 19.13 Mod and Senior Mod

| Command | Description |
|---|---|
| /tempban (player) (duration) (reason) | Temporary ban |
| /unban (player) | Lift a ban |
| /tpo (player) | Teleport to a player without consent. **Staff only, always logged** |
| /tphere (player) | Bring a player to you |
| /invsee (player) | Inspect inventory |
| /voice mute (player) (duration) | Server-side voice mute |
| /report close (id) (resolution) | Close a report |
| /freeze (player) | Freeze a player pending investigation |
| /alts (player) | Linked-account check |
| /appeals | Review queue, Senior Mod |
| /overturn (punishment id) | Reverse a junior's punishment, Senior Mod |

### 19.14 Admin - server management only

| Command | Description |
|---|---|
| /ban (player) (reason) | Permanent ban, with the two-person rule (17.4) |
| /war start, /war stop, /war cancel | Event control |
| /war setcap (n) | Set the event player cap |
| /war kick (player) | Remove a player from an event |
| /arena reset | Regenerate the arena |
| /finale start | Begin the Season Finale |
| /shop tier set (player) (tier) | Manual tier override, logged |
| /prices reload | Reload price config |
| /cosmetics grant (player) (id) | Grant a cosmetic, logged |
| /cosmetics revoke (player) (id) | Revoke a cosmetic, logged |
| /claim admin delete | Administrative claim removal |
| /claim admin transfer | Transfer claim ownership |
| /rules reload | Reload rules text |
| /laughtail reload | **Reload our own config. Never the vanilla server reload** (0.3) |
| /world (name) | Move between worlds |
| /tpall, /tphereall | Mass teleport, for events |
| /broadcast (message) | Server announcement |
| /maintenance (on / off) | Maintenance mode |
| /lookup preview | **Rollback preview only. The rollback itself is Owner-only** (14.2) |
| /performance | Live MSPT, TPS, memory, and watchdog state |
| /audit (player) | Staff action history for one player |

### 19.15 Owner only

| Command | Description |
|---|---|
| /rollback (params) | Execute a rollback |
| /restore (params) | Execute a restore |
| /purge (params) | Purge block logs. **The most dangerous command on the server** |
| /eco give, /eco take, /eco set | Direct balance modification |
| /eco reset | Economy reset |
| /season forcereset | Manual season reset |
| /season setchampion (player) | Emergency Champion assignment. Logged loudly, and never used casually |
| /whitelist add, /whitelist remove | **Access control. This is the paywall** (18.3) |
| /whitelist audit | Compare the whitelist against paid transactions. **Run this monthly** - it is how you find both revenue leaks and unauthorised grants |
| /backup now | Trigger a backup |
| /restore backup (id) | Restore from a backup |
| /perms (all subcommands) | Permission administration |
| /op, /deop | Operator status |
| /stop, /restart | Server lifecycle |
| /transfer (player) (target) | Data transfer between accounts, for account-migration support |
| /audit full | Complete audit log |
| /secrets rotate | Credential rotation |

### 19.16 Console and automation only

| Task | Notes |
|---|---|
| Season reset job | Idempotent (9.4) |
| Resource world regeneration | Named world only, never the main world (7.4) |
| Backup jobs | Hourly database, six-hourly world (5.4) |
| Economy audit | Nightly (8.3) |
| Weekly economy report | (8.5) |
| Watchdog actions | (6.6) |
| Whitelist grants from the store | Idempotent (18.3) |
| Restore drill | Monthly (5.4) |

### 19.17 Command implementation standards

* **Every command validates its own permission server-side.** Never rely on the GUI or the tab-completer to enforce access.
* **Every command that costs money or destroys something asks for confirmation**, or has an undo.
* **Rate-limit every command.** Assume every command will be spammed, because it will.
* **Tab completion for everything**, filtered by what the player can actually use.
* **Error messages must say what to do next**, not just what went wrong.
* **Every command responds within 100 ms** (6.1). Anything slower runs asynchronously with an immediate acknowledgement to the player.
* **No command may block the main thread on a database call.** Not one. This is the single most common cause of mysterious lag spikes in plugin code.
* Consistent colour scheme and message prefix across every command, so the server feels like one product rather than a pile of plugins.

---

