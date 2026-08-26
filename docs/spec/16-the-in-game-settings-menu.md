## SECTION 16 - THE IN-GAME SETTINGS MENU

### 16.1 What the owner asked for, and the honest technical answer

The owner described the Minecraft pause menu - the escape-key screen with Back to Game, Advancements, Statistics, Multiplayer, Options, and on Lunar Client an extra Lunar Options entry - and wants a LaughTail entry there.

**The honest answer, which was given before and is repeated here because it constrains the design:** a Minecraft server **cannot add arbitrary buttons to the vanilla pause menu.** That menu is client-side. Options are either compiled into the client, or added by a client mod. The Lunar Options button exists because Lunar is a modified client. No plugin, on any server, can put a button there for a vanilla player.

What the server *can* do is provide the same thing through a surface every client can reach.

### 16.2 The design: one command, three aliases, one GUI

Build a **settings GUI** opened by a settings command, with **menu and options as aliases**, because those are the words players will instinctively try.

This GUI is the LaughTail control panel and it should feel like a real settings screen, not a plugin menu: clear categories, obvious toggles, current values visible at a glance, and no dead ends.

| Category | Contents |
|---|---|
| **Profile** | Your rank, RP, position on the ladder, season standing, Champion titles held |
| **Cosmetics** | Equip, unequip, dye, preview. Locked entries visible and labelled with their unlock rank |
| **Homes** | List, teleport, rename, delete, buy a slot |
| **Notifications** | Toggle join and leave messages, death messages, event announcements, season-countdown pings |
| **Chat** | Global chat on or off, private message toggle, ignore list |
| **Teleports** | Auto-accept mode, request notifications |
| **Voice** | Voice on or off, push-to-talk or open-mic, volume, per-player mute (Section 13) |
| **Display** | Scoreboard on or off, action-bar info, hologram visibility, **particle density** - which doubles as a player-side performance control |
| **Stats** | Full personal statistics (9.8) |
| **Server** | Rules, how the ranking works, the season countdown, the Hall of Fame, and links to the website and Discord |

### 16.3 Rules for the menu

* **Every setting is reachable from this one GUI.** No setting may be available only through a chat command, and none may be available only through one particular client.
* **All preferences persist in the database**, per player, surviving restarts and migrations.
* **Sensible defaults for new players.** A brand-new player should never need to open this menu to have a good first session.
* **If the owner uses Lunar Client**, integrating with its server-side API is a legitimate **bonus** - it can offer things like server-controlled waypoints and cooldown displays for Lunar users. But it is strictly additive. **No feature, and no setting, may be reachable only through Lunar.** Anything else silently splits the playerbase into first and second class, which breaks Law 3.
* Keep the GUI cheap: build the inventory once per open, never on a repeating task, and never hold a per-player scheduled task open for a menu that is closed.

---

