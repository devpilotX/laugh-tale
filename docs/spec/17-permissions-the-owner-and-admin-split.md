## SECTION 17 - PERMISSIONS: THE OWNER AND ADMIN SPLIT

### 17.1 The staff ladder

Default, Helper, Mod, SrMod, Admin, Owner, Console.

The owner's instruction is explicit: **the Owner has every power. The Admin has meaningfully less - they can manage the server and nothing else.** "Nothing else" is interpreted, correctly, as: an Admin can run the server day to day, but cannot touch the things that could destroy the server, corrupt the economy, or hide their own actions.

### 17.2 What each tier gets

| Tier | Scope |
|---|---|
| **Helper** | Answer questions, inspect block logs read-only, mute and kick short durations, claim and view reports, teleport to coordinates |
| **Mod** | Everything above, plus temporary bans, teleport to players, close reports, voice mute, inventory inspection |
| **SrMod** | Everything above, plus longer bans, ban appeals review, punishment history review, ability to overturn a junior's punishment |
| **Admin** | Everything above, plus **server management**: start and stop events, manage the arena, reload LaughTail config, manage claims administratively, grant and revoke cosmetics, adjust shop tiers, world management, **preview** rollbacks, permanent bans |
| **Owner** | Everything. Including the never-grant list below |
| **Console** | Automation only. Scheduled tasks, the reset job, backups. No human uses console as their identity |

### 17.3 The never-grant-to-Admin list

These permissions belong to the Owner and to Console alone. This list exists because every one of these is either a **server-destruction risk**, an **economy-corruption risk**, or an **audit-evasion risk**.

| Never granted to Admin | Why |
|---|---|
| Wildcard permission of any kind | Silently grants everything, including everything on this list, and everything added in future |
| Permission-plugin administration | Whoever can edit permissions can grant themselves everything. This is the single most important line in this table |
| Operator status, granting or removing | Bypasses the entire permission system |
| Stop, restart, or reload the server | An unscheduled restart mid-event is a server-wide incident |
| Plugin management at runtime | Loading or unloading plugins live is both a stability risk and an audit hole |
| Unlimited money, resetting balances, editing prices | Direct economy corruption. One command could end the season's economy |
| **Rollback, restore, or purge block logs** | An item-duplication vector, and purge specifically destroys the evidence trail. **Purge is the most dangerous permission on the server** |
| Backup, restore, or database access | Contains every player's data; restore can roll back the whole world |
| Season management, manual reset or manual Champion assignment | The integrity of the competition depends on this being untouchable by staff |
| World editing on live worlds | One mistyped selection can delete a region of the map |
| Whitelist add and remove | The whitelist **is** the paywall (Section 3). Manual grants bypass payment, which is both revenue loss and a fairness breach |
| Audit-log access and secret access | Staff must not be able to read or edit the record of what staff did |
| Shell access to the host | Bypasses everything above at once |

### 17.4 Staff conduct rules that must be enforced technically

* **Staff play on separate accounts from their staff accounts.** A staff member competing on the ladder with access to staff tools is an unresolvable fairness problem, and on a paid server it is a refund-generating scandal. Enforce it: the staff account cannot earn RP.
* **All staff actions are logged, permanently, to the database**, including who, what, when, and to whom - and staff cannot delete these logs.
* **Two-person rule for permanent bans** where possible: one issues, one reviews.
* **Rotate every credential when a staff member leaves.** Every one, immediately, without exception or discussion.
* Publish the staff list on the website, so players know exactly who has authority and impersonators are easy to spot.

### 17.5 Acceptance criteria

* [ ] An Admin-level test account is denied every single node in 17.3, verified one by one and recorded.
* [ ] Permission inheritance is verified by a test matrix, not by assumption.
* [ ] A staff account earns zero RP from a kill.
* [ ] Every staff action appears in the audit log, and a staff account cannot delete from it.

---

