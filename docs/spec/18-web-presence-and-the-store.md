## SECTION 18 - WEB PRESENCE AND THE STORE

### 18.1 The rule that comes before everything else in this section

> **Never host the website on the game VPS.**

On 2 cores this is not a preference, it is a hard rule. A web server competes for exactly the CPU the game needs, and worse, a public website is the natural target for a traffic flood. If the site and the game share a machine, then **anyone who floods the website has also lagged the game.** Separate them and that attack is impossible.

Use free or near-free static hosting on a separate platform. This is both faster and safer than anything self-hosted, and it costs nothing.

### 18.2 What the site must contain

| Page | Purpose |
|---|---|
| **Home** | What LaughTail is, in one screen. Live player count and server status |
| **Store** | The **only** thing sold is access (3.6). One price, for everyone |
| **Rules** | The canonical rules and the punishment ladder, matching in-game and Discord exactly (14.6) |
| **Terms of Service, Privacy Policy, Refund Policy** | Non-negotiable. Required by payment processors, and your protection in a dispute (3.8) |
| **How to join** | Payment, then whitelist, then connect. With the voice-chat setup guide (13.4) and the resource-pack note |
| **Leaderboards** | Live top RP, top balance, top killstreak, current season standing |
| **Hall of Fame** | Every Season Champion, forever (9.7) |
| **Season history** | Archived final standings for every past season |
| **Live map** | Optional, with the constraints in 18.5 |
| **Status page** | Uptime and current state, hosted externally |
| **Staff list** | Who has authority (17.4) |

Include the non-affiliation statement: LaughTail is not an official Minecraft product and is not approved by or associated with Mojang or Microsoft.

### 18.3 The store to whitelist pipeline - the most important integration in the project

This is the mechanism that makes the paid server actually work, so it must be built with more care than any cosmetic feature.

**The flow:** payment succeeds, then the player's account is added to the whitelist automatically, then they receive a confirmation with connection instructions.

**Requirements:**

| Requirement | Detail |
|---|---|
| **Use an established Minecraft monetisation platform** | Do not hand-roll payment handling. An established platform gives you tax handling, fraud screening, chargeback tooling, and a supported path from a completed purchase to an in-game command |
| **Idempotent grants** | A duplicated webhook must not create two entries or two charges. Key every grant on the transaction ID |
| **Verify the username properly** | Resolve to the account UUID, not the display name. Names change; UUIDs do not. A whitelist keyed on names will break the first time a customer renames |
| **Handle the offline case** | If the server is down when payment completes, the grant must queue and apply on the next start. **Never lose a paid grant** |
| **Handle refunds and chargebacks** | An automatic whitelist removal path, with the policy published in advance |
| **Never expose RCON to the internet** | If the platform integration needs a channel to the server, use its supported method behind the firewall (5.3) |
| **Log every grant and revoke** | With timestamp, transaction reference, and resulting UUID. This log is your answer to every access dispute |
| **Test the entire path end to end before launch**, including a refund | The first real customer must not be the first test |

### 18.4 Leaderboards and stats on the web

* Read from the game database through a **dedicated read-only database user**. The website must be structurally incapable of writing to game data, so that a web compromise cannot become an economy compromise.
* **Cache aggressively**, at least 60 seconds. An uncached leaderboard is a way for the public internet to make the game server do database work on demand.
* Precompute rankings on a schedule, not on page load.

### 18.5 The live map, and its one real risk

A live web map is excellent marketing and is genuinely popular. It has one non-obvious problem:

> **A live map showing player positions is a real-time intelligence feed for raiders and for PvP hunting.**

Rules:

* **Player markers off by default.** Show the world, not the people.
* **Player markers must be forcibly disabled during War Events and the Season Finale.** Otherwise the map becomes a wallhack that spectators can relay to competitors, and the integrity of the Finale - and therefore of the Champion title - is compromised.
* Render on a schedule, at low priority, and **never during an event window**. Map rendering is disk and CPU heavy.
* If it costs measurable MSPT after tuning, turn it off. It is marketing, and Law 1 says consistency wins.

### 18.6 Discord

Discord is where the community actually lives; the website is where it is advertised.

* Two-way chat relay between in-game and one channel, with rate limiting on both directions.
* Automatic announcements: season countdown, reset complete, **the new Champion**, War Event schedules, and downtime notices.
* Automated staff alerts: anti-cheat flags, economy anomalies, the MSPT watchdog (6.6), and backup failures. **Alerts go to a private staff channel, never to a public one** - a public alert feed tells cheaters exactly which checks fire and which do not.
* Voice channels, live from day one (13.2).
* Appeals and reports via a form or ticket bot (14.7).
* Account linking, so a Discord identity maps to a Minecraft UUID. This is also how you handle support for a player who cannot log in.

### 18.7 Acceptance criteria

* [ ] The website is not served from the game host, verified by DNS and by IP.
* [ ] A test purchase results in an automatic whitelist grant within one minute.
* [ ] A duplicated payment webhook produces exactly one grant.
* [ ] A purchase made while the server is offline is applied on next start.
* [ ] A test refund removes access, and the removal is logged.
* [ ] The website's database user cannot write, verified by attempting a write.
* [ ] Rules text is byte-identical across website, in game, and Discord.
* [ ] Player markers are absent from the live map during a simulated event.
* [ ] RCON is unreachable from outside the host, verified by external scan.

---

