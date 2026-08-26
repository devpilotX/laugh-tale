## SECTION 31 - THE COMPLETENESS PASS

Fourteen items found by auditing this document against the owner's requirement that nothing be skipped. Each names the section it amends. Where this section and an earlier section disagree, **this section wins**.

None of these are new features. Every one is a hole in something this document already promised.

### 31.1 The season boundary: an exact instant (amends Section 9)

This document specified monthly resets and a nine-stage countdown, but never defined when a month actually ends. A season that produces exactly one Champion cannot have an ambiguous end time.

* **Seasons end at 00:00 IST (UTC+05:30) on the first day of each calendar month.** The owner may change the hour, but it must be a fixed, published hour.
* Store the instant in the database in **UTC**. Display it in local time where the client allows, otherwise in IST with the offset shown.
* The standings snapshot is taken in **one transaction at that instant**. A kill resolved after the instant belongs to the new season, regardless of when the fight began.
* The countdown stages of 3 days, 2 days, 24 hours, 12 hours, 6 hours, 1 hour, 15 minutes, 5 minutes, and 1 minute are computed from this instant, never from drifting server uptime.
* If the server is offline at the instant, the reset job runs on next boot and uses the **scheduled** instant for every calculation, not the boot time. Section 9 already requires idempotency; this makes the job time-correct as well.
* Publish the instant on the website and in `/season`. Players will plan their final hours around it, which is exactly the intended drama.

### 31.2 The Champion tiebreak chain (amends Section 9)

Section 9 states the principle: if the format can produce a tie, the format is wrong. That is a principle, not a procedure. RP is an integer and the roster is 20 to 24 players, so exact ties are likely rather than hypothetical.

Apply in order, stopping at the first criterion that separates:

1. Higher RP at the season instant
2. More kills during the season
3. Fewer deaths during the season
4. Earlier timestamp of first reaching their own season-peak RP
5. Sudden-death duel

Duel rules: within 48 hours of the season instant, in the finale arena, on the fixed finale kit, best of three, refereed by an Admin, recorded. If a tied player cannot be reached after **two announced attempts across those 48 hours**, the reachable player wins by walkover, and the archive records it as a walkover rather than a duel victory. If no duel can be held at all, criterion 4 decides.

**Never share the title. Never award two crowns. Never end a season without a Champion.**

### 31.3 Combat tagging, in full (amends Sections 14 and 9)

This is the mechanic that makes a PvP-only rating trustworthy, and the document gave it two lines. If a losing player can disconnect before dying, the rating system is decorative.

* **Tag duration: 15 seconds**, refreshed on every hit given or received between players.
* **Blocked while tagged:** `/home`, `/sethome`, `/tpa`, `/tpahere`, `/tpaccept`, `/rtp`, `/resource`, `/spawn`, `/warp`, `/back`, `/hub`, `/lobby`, `/ec`, `/pv`, `/kit`, `/craft`, `/anvil`, `/grindstone`, `/repair`, `/shop`, `/sell`, `/ah`, `/order`, `/trade`.
* **Mob damage does not tag.** Only player-versus-player damage tags. Dying to a creeper mid-fight is not a combat log.
* **Disconnecting while tagged is resolved as a death.** Full item drop at the disconnect location, the killer receives the complete Elo award as though the kill had landed, and the disconnecting player takes the normal RP loss **plus an additional flat penalty**, so logging out is strictly worse than dying. Publish the flat penalty as a rule; keep detector internals private per Section 29.11.
* **A third combat log inside 30 days is a punishable offence** under Section 14, not merely a mechanical penalty.
* Acceptance requires an automated test that disconnects a tagged bot and asserts the death, the item drop, the killer's award, and the extra penalty.

### 31.4 Totem of Undying and Mending (amends Sections 7, 8, and 12)

These two items shape modern Minecraft PvP more than anything else in the game, and neither appeared anywhere in this document.

| Context | Totem of Undying | Mending |
| --- | --- | --- |
| Survival world | Allowed | Allowed |
| War events | Banned, enforced by the arena inventory check | Allowed |
| The Finale | Banned | Banned; the finale kit is fixed and provided |

The economic consequence is the part that matters. **Mending removes gear attrition, and gear attrition is the demand side of the Berry economy.** If armour never wears out, there is no recurring reason to buy any. Compensate by meeting Section 8's 60 to 80 per cent sink target from sinks Mending cannot defeat: repair costs on non-Mending items, claim block purchases, home slots, auction house tax, `/pay` tax, and war entry costs. Cosmetics are earned and never sold, so they are not a sink and must not be counted as one.

If sink coverage falls below target, **add a sink. Never nerf Mending after players have earned it.**

### 31.5 Farms and production rate, not just prices (amends Section 8)

Section 8 prices items with `base_worth = (expected_minutes_to_obtain * target_berries_per_hour) / 60`. That formula assumes a human obtaining an item by hand. It does not survive an AFK farm.

The owner explicitly rejected the idea that mining around the clock should reach the top of the ladder. The identical logic applies to earning, and the document never applied it.

* Every item sellable to the server shop must carry a **stated assumed acquisition method**.
* If a farm exists that beats the assumed method by more than **3x**, the sell price is derived from the farm rate, not the manual rate.
* Price from farm rates for at minimum: iron, gold, copper, any mob drop obtainable from a spawner or trap farm, bamboo, sugar cane, kelp, cactus, honey, and anything a villager will trade in volume.
* **Cap per-player shop sell volume per item per day.** This is a blunt instrument and it works. Publish the cap; it is a game rule, not a detector, so hiding it only confuses honest players.
* The economy audit script in Appendix E must add a **production report**: the top ten Berry sources by volume each week, with the ratio of actual to modelled earn rate. Anything above 3x is repriced at the next pricing window.

Note the distinction this closes. Section 8 already handles crafting-chain arbitrage well, including smelting, uncrafting, and villager trades. Arbitrage is a **pricing** exploit. Farms are a **production** exploit. Only the first was covered.

### 31.6 New player protection (amends Sections 7 and 14)

A paid, whitelist-gated server cannot allow a new arrival to be farmed at spawn. The document had a refund policy but no prevention.

* **PvP disabled inside the spawn region.** Section 7's WorldGuard flags already deny PvP by region; state it explicitly for spawn and verify it.
* **30 minutes of cumulative playtime grace on first join**, during which the player can neither deal nor receive player damage. Shown as a visible countdown so it is never a surprise.
* Grace **ends early and permanently** the moment the player attacks another player. It cannot be regained.
* Grace does not apply to a known alt account of an existing player, and is void inside a war arena.
* **Camping the spawn exit region is a Section 14 offence.** Enforce it, because a paid player who cannot leave spawn will ask for a refund and will be right to.

### 31.7 Server list presentation (amends Sections 18 and 16)

None of these existed anywhere in the document, and the first is the first thing any player ever sees.

* **MOTD:** two lines, the server name and the current season with days remaining. **Generated, not hand-typed**, so it can never go stale.
* **Server icon:** a 64x64 PNG committed to the repository.
* **Tab list:** rank prefix, player name, ping. Updated asynchronously. Header shows the season and days remaining; footer shows the website.
* **Bossbar: reserved.** Used only for war events and the final hour of a season. An always-on bossbar is visual noise and wastes the one attention-grabbing surface the game gives you.
* **Sample player list in the server ping: disabled**, so the online roster cannot be scraped by third-party listing sites.

### 31.8 Scheduled restarts (amends Sections 5 and 6)

Section 5 mentions announced restarts in one clause with no schedule attached. Paper degrades over long uptimes, so this needs to be concrete.

* **One restart per day at 05:00 IST**, chosen as the lowest-traffic hour for an India-centred playerbase.
* Warnings at 15 minutes, 5 minutes, 1 minute, and 10 seconds.
* Implement it as a **Pelican schedule, not a cron job inside the container**, so it survives a container rebuild and stays visible in the panel.
* **Never restart during a war event or the final hour of a season.** The scheduler must check both and defer, then restart once the event ends.
* Acceptance: the uptime graph shows a restart inside the expected window every day, and no restart inside an event.

### 31.9 Staff account security (amends Sections 17 and 29.13)

An Admin can `/eco give`. An Owner can `/rollback`. A compromised staff account is an economy-ending event on a server whose entire premise is a fair ledger, and the document covered panel key hygiene without ever covering the accounts behind it.

* **Two-factor authentication is mandatory** on the Pelican panel, the GitHub account or organisation, the domain registrar, the store account, and the email address that can reset all of them.
* **Staff Minecraft accounts must have Microsoft account 2FA enabled.** Verify at appointment and re-verify each season.
* **No shared staff accounts.** One human, one account, one name in the audit log. A shared account makes the audit trail worthless exactly when it matters.
* **Staff must not connect through a proxy or VPN**, because it defeats the alt and ban-evasion checks. Enforce this by policy rather than IP blocking, which produces false positives on Indian mobile networks.
* **Owner-level commands require a second confirmation step** and are logged to a destination the Owner does not solely control.

### 31.10 Market abuse on the order book (amends Sections 8 and 14)

The order-book market invites two abuses that alt-detection will never catch, because no rule is being evaded.

* **Wash trading:** two accounts trading with each other to manufacture a false price signal. Detect by flagging counterparties with an abnormally high mutual trade ratio and few or no other counterparties.
* **Cornering:** buying the entire supply of an item to push the dynamic price band upward, then selling into it. The existing band of plus or minus 35 per cent with a 25 per cent floor limits the damage; add a per-player share-of-volume alert on top.
* Both are **alert-only for the first full season**, consistent with how Section 3.5 treats the wagering detector. Watch the data before writing a rule around it.
* Thresholds live in the private documentation, never in the public repository, per Section 29.11.

### 31.11 Illegal items and crash vectors (amends Sections 14 and 6)

The plugins were listed. The policy was not.

**An illegal item is** any item with NBT or component data unobtainable in survival on this version, any stack above its vanilla maximum, any item carrying an enchantment above its vanilla maximum or an enchantment that cannot legitimately apply to it, or any container holding another container.

* **On detection:** remove the item, log it with its full data, notify staff, and do **not** punish automatically. The first response to an illegal item is an investigation, because the usual cause is a bug in our own code, not a cheater.
* Block the known crash vectors: oversized books and written-book NBT, oversized signs, malformed packets, entity-count and chunk-load abuse, and firework and elytra chunk-ban patterns.
* **Downtime on a paid server converts directly into refund requests.** That makes exploit hardening a commercial requirement, not a technical nicety.

### 31.12 Resource world reset (amends Section 7)

The resource world has a 3,000 block border and no reset cadence, which means it is stripped bare by month three and the gathering half of the economy quietly dies.

* **Reset the resource world at the season instant, every month**, immediately after the season reset job completes.
* Announce it on the same countdown schedule as the season, so nobody loses a base they did not know was temporary.
* Player inventories and everything in the main world are unaffected. **Nothing in the resource world is preserved** - that is the entire point of it, and it must be stated in `/rules` and on the website.
* **The main survival world is never reset. Ever.** Say this plainly and permanently on the website, because every prospective player will ask, and it is the single biggest reason a builder chooses one server over another.

### 31.13 Player data, deletion, and retention (amends Sections 3 and 18)

Taking real money from Indian players and storing gameplay data means Indian law applies.

* **The governing law is India's Digital Personal Data Protection Act 2023, not GDPR.** Do not copy a GDPR notice and assume it is sufficient.
* Publish what is collected, why, how long it is kept, and how to request deletion.
* **On a deletion request:** remove the account identifier, chat logs, IP records, and payment linkage. Retain aggregate and anonymised season results, including any Champion record, under a pseudonymous identifier. State this in the privacy notice so it is never a surprise.
* **Retention:** chat and connection logs 90 days, moderation records 2 years, and the economy ledger for the life of the server because it is a financial audit trail.
* **A deletion request does not erase a ban.** Retain the minimum needed to enforce it, and say so.

### 31.14 Language (amends Sections 18 and 13)

* The server, the website, and every command are **English-only at launch**. This is a recorded decision, not an omission.
* Rationale: one language is one set of strings to keep correct, and mixed-language moderation is how rule enforcement becomes inconsistent and disputes become unwinnable.
* **All player-facing strings live in one message file**, so a translation can be added later without touching a line of code.
* Voice chat is unmoderated by design. Section 13's rules apply regardless of the language being spoken.

### 31.15 Acceptance criteria

| # | Criterion | Evidence |
| --- | --- | --- |
| 31-1 | The season instant is stored in UTC and rendered correctly in IST | Database row plus `/season` output |
| 31-2 | A reset triggered while the server was offline uses the scheduled instant, not boot time | Test log from a simulated outage |
| 31-3 | Two players forced to an identical RP resolve to exactly one Champion through the chain | Test log naming the deciding criterion |
| 31-4 | A tagged bot that disconnects dies, drops items, and pays the extra penalty | Automated test output |
| 31-5 | Teleport and container commands are all refused while combat-tagged | Test log covering every blocked command |
| 31-6 | Totems and Mending are refused by the arena and finale inventory checks | Event log |
| 31-7 | Sink coverage sits inside the 60 to 80 per cent target with Mending in play | Economy audit report |
| 31-8 | No shop item earns above 3x its modelled rate for two consecutive weeks | Production report |
| 31-9 | Daily per-item sell caps are enforced and published | Config plus `/rules` |
| 31-10 | A new account cannot deal or take player damage for 30 minutes, and loses grace on attacking | Test log |
| 31-11 | MOTD and tab list show the live season and days remaining, generated not hard-coded | Server list screenshot plus source |
| 31-12 | The daily restart fires in its window and defers during a war event | Uptime graph plus scheduler log |
| 31-13 | 2FA is verified on all five owner-controlled accounts and on every staff Minecraft account | Signed checklist in `docs/private/` |
| 31-14 | Wash-trading and cornering alerts fire on seeded synthetic data | Alert log |
| 31-15 | Every illegal-item class is detected, removed, logged, and does not auto-punish | Test log |
| 31-16 | The resource world resets at the season instant and the main world does not | Two consecutive season logs |
| 31-17 | A data deletion request completes while the ban and the anonymised Champion record survive | Redacted request record |
| 31-18 | Every player-facing string resolves from the single message file | Grep for hard-coded strings returns nothing |

---

