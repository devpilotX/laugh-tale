## SECTION 9 - RANK, SEASONS, AND THE ONE CHAMPION

### 9.1 The ranking rule

**Rank is earned by PvP and by nothing else.**

This is the owner's explicit and repeated instruction, and it is the identity of the server. Mining for twenty-four hours a day must not raise rank by a single point. Playtime, money, blocks broken, mobs killed are all tracked and displayed in stats, and none of them affect rank.

    Rank Points (RP) = Combat Rating (CR)

Nothing else feeds in. No activity component, no participation bonus, no weighting. One input.

### 9.2 Combat rating - Elo, with anti-farm protection

Use a standard Elo formulation so beating a strong player is worth far more than beating a weak one:

    E = 1 / (1 + 10 to the power of ((CR_victim - CR_killer) / 400))
    delta = K * (1 - E)
    K = 24
    Starting CR = 1000
    Clamp: minimum +2, maximum +40 per kill

The victim loses a symmetric amount, floored so a player cannot be driven below the bottom of the ladder.

**Anti-farm protections, all mandatory:**

| Exploit | Protection |
|---|---|
| Killing the same player repeatedly | Diminishing returns per pair: 100 percent, then 50, 25, 10, then 0 percent, resetting after 6 hours |
| Alt-account farming | Same-IP and same-payment-source kills award zero RP and raise a staff alert. The paid gate makes alts expensive, which makes this rare, but check anyway |
| Friends trading kills | Detect reciprocal kill patterns between the same pair and zero them, with a staff alert |
| Spawn camping | No RP for kills within a defined radius of spawn or of a player's own respawn point, plus a brief post-respawn invulnerability that ends the instant the player attacks |
| Logging out to avoid a loss | Combat tag: disconnecting while tagged is resolved as a death |
| Inactivity squatting | RP decays 1 percent per week above the tier floor after 7 days of inactivity, so the ladder reflects who is actually playing |

### 9.3 The rank ladder

Ten tiers, each with a name, an RP threshold, a chat prefix, and a cosmetic unlock (Section 11):

Wanderer, Settler, Raider, Fighter, Warrior, Gladiator, Champion, Warlord, Legend, Mythic.

Thresholds live in config, tunable without a code change. Set them from the measured RP distribution after the first season, not from guesswork. The top tier should be genuinely rare.

### 9.4 Monthly reset

**The season resets on the 1st of every month at 00:00 server time.**

* **Soft reset, not a wipe.** Compressing toward the mean keeps the ladder meaningful while giving everyone a real chance:

    RP_new = 1000 + (RP_old - 1000) * 0.35

* The reset job must be **idempotent**. If it runs twice, or the server restarts mid-reset, the outcome is identical. Guard with a database flag on the season row, not with a timestamp comparison.
* **Archive first, reset second.** The full final standings are written to the season archive before anything is modified. Season history is permanent and must be queryable and visible on the website forever.
* **Rewards are granted before the wipe, in the same transaction.** A reset that clears standings before granting rewards is a data-loss bug, and it will happen at midnight when nobody is awake unless you order it correctly.
* What resets: RP, CR, and the seasonal leaderboards.
* **What never resets: Berries, items, homes, claims, cosmetics, achievements, and Hall of Fame entries.** Players must never fear a reset destroying their work.

### 9.5 The countdown campaign

Escalating notifications before reset, starting three days out as the owner specified:

3 days, 2 days, 24 hours, 12 hours, 6 hours, 1 hour, 15 minutes, 5 minutes, 1 minute.

Delivery: chat announcement, title or action-bar flash at the shorter intervals, a scoreboard countdown inside the final day, a website banner, and Discord announcements at the 3-day, 24-hour, and 1-hour marks. Escalate the visual weight as it gets closer, so by the final minute it is impossible to miss. Every message states plainly **what will and will not be lost**.

### 9.6 THE SEASON CHAMPION - exactly one per season

This is a headline requirement from the owner and it deserves to be the centrepiece of the competitive design.

> **At the end of each season, exactly one player is named Champion of LaughTail. Not a top three. Not a podium. One name.**

**How the Champion is decided.** Winning on ladder points alone is anticlimactic - the last week becomes a spreadsheet exercise, and the leader just stops fighting to protect their score. Instead:

1. **The season ladder qualifies you.** The top 32 by RP at the season cutoff earn a place in the Finale.
2. **The Season Finale decides it.** One scheduled event (12.5) produces one winner.
3. **One Champion. One name. No shared titles.** If the format could produce a tie, the format is wrong - build in a decisive sudden-death tiebreak rather than sharing the title.

**What the Champion receives:**

| Reward | Detail |
|---|---|
| **A custom advancement** | Implemented as a **datapack advancement**, granted only to that player, titled with the season, for example "Champion of Season 3". It sits in their advancement tree permanently, it is announced server-wide when granted, and it can never be granted again. This is exactly the custom achievement the owner asked for, and a datapack is the right tool because it is server-side and therefore **also visible to Bedrock players through Geyser**. |
| **A permanent title** | A unique chat and tab prefix marking them as a past Champion, kept forever, through every future season. |
| **A crown cosmetic** | A visible head-slot cosmetic, Champion-only, never obtainable any other way. |
| **A place in the Hall of Fame** | Name, season number and date carved permanently into the monument at spawn, and listed forever on the website. |
| **A season-exclusive cosmetic set** | Never reissued in any later season. |

**What the Champion does NOT receive:** no Berries, no items, no gear, no stat bonus, no permission, no shop discount, no head start next season. **The prize is glory and nothing else.** This is not a limitation, it is the design. A Champion who begins the next season stronger breaks Law 3, and the reward is more valuable precisely because it cannot be converted into an advantage.

**Implementation notes:** grant the advancement, the title and the crown in a **single database transaction** together with the season archive write. Test the entire path on a fake season before the first real one ends. This code runs once a month, so a bug in it is both highly visible and permanently embarrassing.

### 9.7 The Hall of Fame

A physical monument at spawn plus a permanent website page. One entry per season: the Champion's name, the season number, the date, and their final RP. It grows by exactly one line every month. Within a year it becomes the most-looked-at build on the server, and it is the cheapest retention mechanic in existence, because it makes the competition feel like it has a history.

### 9.8 Stats tracking

Tracked, shown on the stats screen, and available on the website. Rank comes only from PvP, but everything is measured:

| Stat | Notes |
|---|---|
| Player name and rank | Current tier and RP |
| Berries balance | Current |
| Kills, deaths, ratio | Kills are the only stat that feeds rank |
| Killstreak | Current and best ever |
| Mob kills | By type |
| Blocks mined and placed | Informational only |
| Playtime | **Shown in hours until 24, then in days and hours** - as the owner specified |
| Distance travelled | By method |
| Seasons played, best finish | Historical |
| Champion titles held | The stat everyone wants |

All stats persist across seasons. Viewing another player's stats is public. Transparency is part of the fairness reputation.

### 9.9 Acceptance criteria

* [ ] Mining, farming and building for two hours changes RP by exactly zero.
* [ ] Killing the same alt five times yields RP only on the diminishing pattern, then zero.
* [ ] The reset runs twice in a row and produces an identical result.
* [ ] Rewards are granted before archival, verified by killing the server mid-reset and re-running.
* [ ] Exactly one Champion exists per season row, enforced by a database constraint and not by application logic alone.
* [ ] The Champion advancement is visible to a Bedrock client through Geyser.
* [ ] The Hall of Fame monument and web page both update automatically.

---

