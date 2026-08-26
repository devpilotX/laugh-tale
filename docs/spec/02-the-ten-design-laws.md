## SECTION 2 - THE TEN DESIGN LAWS

These are the tie-breakers. When two implementations both work, the one that better satisfies these wins.

**Law 1 - Consistency beats features.** One laggy weekend undoes a month of good marketing. A small clean server beats a big broken one, every time. Ship less, ship it solid.

**Law 2 - Minimal, finished features only.** Ten features that are perfect beat forty that are nearly right. Every half-finished system is a permanent support burden and a permanent bug source. If you cannot finish it to the Section 0.5 standard, do not start it.

**Law 3 - Everyone is equal.** Identical price, identical access, identical capability. The only differences between two players are skill, time played, and reputation. No exceptions, not for donors, not for friends, not for staff.

**Law 4 - Prevention scales, moderation does not.** A rule you cannot enforce automatically is not a rule, it is a wish. Build the guardrail, do not plan to police the violation.

**Law 5 - Measure, never guess.** MSPT and profiler output decide performance arguments. Not opinion, not "it feels fine", not TPS alone. TPS can read 20 while the server is drowning; MSPT tells the truth.

**Law 6 - The server is disposable, the data is not.** Any container can be destroyed and rebuilt from git plus a backup, with zero unique state on the host. Portability is designed in from hour one, not retrofitted before a migration.

**Law 7 - Client-side work is free, server-side work is not.** Push every possible cost to the player's machine. A resource pack animating a texture costs the server exactly nothing. A particle effect costs CPU and bandwidth every tick for every viewer. Prefer the former, budget the latter.

**Law 8 - Fail closed, fail loud.** If the economy service is unreachable, refuse the transaction; never silently succeed. If a check cannot run, deny the action. Log every failure somewhere a human will actually see it.

**Law 9 - Trust nothing the client says.** Every price, every permission, every rank check, every cooldown is validated server-side at the moment of the transaction. A GUI is a picture of the truth, never the truth itself.

**Law 10 - Write it down or it did not happen.** Undocumented config is a future outage. Undocumented decisions get reversed by the next person, including future-you.

---

