## APPENDIX G - WHAT THE OWNER DID NOT ASK FOR, AND WHY IT IS HERE

The owner explicitly asked to be told about anything missing. These were added on that authority. Each is here because omitting it would eventually cost real money, real players, or the server itself.

| Added | Why it matters |
|---|---|
| The licence-compliance section | Charging for access is permitted, but only under specific conditions. Getting this wrong risks the whole project. It is also what forced the removal of donor tiers |
| Merchant of record, tax, and refund handling | Taking money creates obligations that do not go away because the business is small |
| Terms, Privacy and Refund pages | Required by payment processors, and your only defence in a dispute |
| A stated no-refund-on-ban policy, published before purchase | Prevents the single most likely chargeback |
| Restore drills | A backup that has never been restored is a rumour. Most people discover their backups are broken on the day they need them |
| The bot load test | The player cap must come from measurement, not hope |
| The MSPT watchdog | Turns "the server sometimes lags" into an automatic, bounded, self-healing response. It is also what makes it safe to keep animations |
| The complete port table including UDP | The most commonly broken thing in a migration, and the reason voice chat silently dies |
| The economy arbitrage audit | A documented real-world exploit destroyed a comparable server's economy in one weekend |
| The safe trade GUI | Removes the largest category of player drama permanently |
| The resource world | Stops the map looking dead after two months |
| The rules-acceptance gate | Makes "I never agreed to that" impossible |
| Claims that protect blocks but not players | The only way to have both real PvP and a real building economy |
| Owner-only rollback | Rollback is a duplication vector, and log purging destroys evidence |
| Staff on separate play accounts | Removes an unresolvable fairness problem before it happens |
| The whitelist audit script | Finds both revenue leaks and unauthorised access grants |
| Idempotent grants and offline-purchase queuing | Never lose a paid grant, never double-charge |
| The decision log and the rejected-ideas log | Six months from now, nobody will remember why anything was chosen |
| The language file from day one | Retrofitting internationalisation is painful; doing it upfront is nearly free |
| The post-launch roadmap | The order of additions matters more than the additions |

### The standing invitation to the builder

This document is thorough, but it is not sacred. If you find a better way - a cheaper algorithm, a safer schema, a simpler feature that achieves the same player outcome, a plugin category that has been superseded, or a measurement that contradicts an assumption written here - **take it.** Implement the better thing, record what you changed and why in the decision log, and tell the owner in plain language.

The only things that are genuinely non-negotiable are these:

1. **Nobody who pays gets an advantage over anybody else who pays.**
2. **No gambling, in any form, however disguised.**
3. **No data loss, ever.**
4. **Consistency beats features.**
5. **Never claim something is done until it is measured and verified.**

Everything else is engineering judgement, and you are expected to use it.

---

