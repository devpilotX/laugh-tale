## APPENDIX D - DATABASE SCHEMA OUTLINE

Use schema migrations from the first commit. Never modify a live schema by hand.

| Table | Contents |
|---|---|
| players | UUID, current name, first join, last seen, rules version accepted, access record |
| access_grants | UUID, transaction reference, granted at, expires at (nullable), revoked at, source |
| balances | UUID, Berries, last modified |
| transactions | Every Berry movement, with type, counterparty, amount, and reason |
| combat_ratings | UUID, current CR, peak CR, season |
| combat_events | Killer, victim, delta applied, multiplier applied, location, timestamp |
| stats | All tracked statistics per player (9.8) |
| homes | UUID, name, world, coordinates, created at |
| claims | Owner, bounds, trust list, created at, last active |
| shop_tier_state | UUID, current tier, peak tier, season |
| cosmetics_owned | UUID, cosmetic id, source, granted at. **Never deleted by a reset** |
| auction_listings | Seller, item data, price, type, expiry, state |
| orders | Player, side, item, quantity, price, filled quantity, state |
| order_matches | Both order references, quantity, price, timestamp |
| seasons | Season number, start, end, state, reset-completed flag |
| season_archive | Final standings snapshot per season, permanent |
| champions | Season number, UUID, final RP, awarded at. **Unique constraint on season number** |
| war_events | Event id, schedule, cap, state |
| war_participants | Event, player, lives remaining, placement |
| punishments | Target, type, duration, reason, evidence reference, issuing staff, timestamp |
| reports | Reporter, target, reason, evidence reference, state, handler |
| staff_audit | Staff UUID, action, target, parameters, timestamp. **Append-only** |
| preferences | Per-player settings from the menu (Section 16) |

**Rules:** every player-facing table keys on UUID and never on name. Every write that spans two tables runs in a transaction. Every table that grows without bound has a documented retention policy.

---

