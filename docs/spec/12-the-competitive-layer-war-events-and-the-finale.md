## SECTION 12 - THE COMPETITIVE LAYER: WAR EVENTS AND THE FINALE

The owner described it as: players prepare, then a large organised fight, lose two or three times and you are out, culminating in something like a dragon fight. Very competitive. Here is that, made buildable.

### 12.1 Three layers of competition

| Layer | Frequency | What it is |
|---|---|---|
| **Open-world PvP** | Always | The baseline. Any fight anywhere feeds RP |
| **War Events** | Weekly or fortnightly, scheduled | Organised elimination battles with a preparation phase |
| **Season Finale** | Once a month, end of season | Decides the single Champion (9.6) |

### 12.2 War Event format

1. **Announcement and prep window, 48 hours by default.** Players know the time. They farm, gear up, form alliances and plan. **The preparation phase is the event** for many players - it drives a burst of economy activity and coordination every single cycle. Do not shorten it.
2. **Sign-up** closes shortly before the start. Publish the roster.
3. **The fight.** All participants enter the arena world. Each player has **3 lives**. Lose all three and you are out of this event.
4. **Winner:** the last player or team standing.

**The correction that matters, and it is important:** elimination is scoped to **the event, not the season**. A player knocked out of one War Event plays in the next one, and the next. Locking someone out for weeks because they lost three fights would be the fastest possible way to lose a paying player - and on a paid server that is a refund request and a bad review. The drama of elimination stays; the punishment does not extend past the event.

### 12.3 Hard mechanical requirements

| Requirement | Why |
|---|---|
| **Disconnecting counts as losing a life** | Otherwise force-quitting is the optimal play at one life remaining |
| Deterministic seeded spawn placement | No advantage from spawn luck, and reproducible for dispute review |
| Full inventory snapshot on entry, restored on exit | Nobody loses their survival inventory to an event bug |
| Arena regenerates between events, scripted | No residual advantage from the previous fight |
| Spectator mode for eliminated players | Keeps the audience engaged, which is half the value of an event |
| Every kill, death and life loss logged with a timestamp | Disputes get settled with data, never with memory |
| Event caps: **20 to 24 now, 40 after the first migration, 60 at full scale** | Set from the measured load test, never from ambition |
| Cosmetic particles off during events | Protects the tick budget exactly when it matters most |
| **No betting or wagering of any kind** | Section 3.5. The previously specified war betting command is removed from this design |

### 12.4 If the arena costs too much

On 2 cores, sixty players in one arena is not achievable, and the owner has accepted this. Mitigations in order of preference:

1. Cap the event at the measured number. A great 20-player event beats a stuttering 60-player one.
2. Run the arena in a separate world with reduced view and simulation distance.
3. Disable all cosmetics, holograms and non-essential scheduled tasks during the event window.
4. **After migration:** move the arena to a **separate server instance behind a Velocity proxy**, so an event can never affect the survival world at all. This is the correct long-term architecture and is why Velocity appears in the Tier 3 roadmap.

### 12.5 The Season Finale

Once a month, deciding one Champion:

1. **Qualification:** top 32 by RP at the season cutoff.
2. **Bracket:** double elimination, so one unlucky fight does not end a strong player's season. Published bracket, scheduled times, spectators welcome.
3. **The final stage - the dragon.** The last remaining players face the Ender Dragon **while still able to fight each other**. Whoever lands the killing blow and survives is Champion. This is a genuinely excellent finale: dramatic, legible to spectators, with precedent in the largest Minecraft events, and the cooperate-or-betray tension in the final minutes will be the best content the server produces all month.
4. Tie-break by sudden-death duel. **There is exactly one Champion.**
5. Record everything. The Finale is the server's marketing material - the clips from it are what recruit next month's players.

### 12.6 Acceptance criteria

* [ ] Disconnecting at one life results in elimination, verified.
* [ ] An eliminated player can immediately play normal survival and can join the next event.
* [ ] Inventories are perfectly restored on event exit, including after a crash mid-event.
* [ ] MSPT stays under 40 ms at the configured event cap with combat active.
* [ ] Arena regeneration leaves no blocks, items or entities from the previous event.
* [ ] Exactly one Champion is produced, and the tie-break path has been tested.
* [ ] No betting or wagering command exists anywhere in the codebase.

---

