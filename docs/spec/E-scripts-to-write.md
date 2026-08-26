## APPENDIX E - SCRIPTS TO WRITE

| Script | Purpose |
|---|---|
| Health check | TPS, MSPT, memory, disk, container state, backup freshness. Runs on a schedule and alerts |
| Backup | Consistent database dump plus world archive, offsite upload, encryption, retention pruning |
| **Restore drill** | Restores the latest backup into a scratch environment and verifies integrity. **Monthly, logged** (5.4) |
| Economy audit | Full item and recipe cycle check. CI plus nightly (8.3) |
| Weekly economy report | Supply, created, destroyed, distribution, top balances (8.5) |
| Season reset | Idempotent. Archive, grant rewards, name the Champion, soft-reset ratings (9.4) |
| Resource world regeneration | Named world only, refuses to run against the main world (7.4) |
| Arena regeneration | Between events (12.3) |
| Load test | Bot ramp plus event scenario (6.8) |
| **Migration** | Full state transfer with checksum verification (22.6) |
| Whitelist audit | Whitelist versus paid transactions (19.15) |
| Secret rotation | Rotate and redeploy every credential |
| Hardcoded-value check | Greps for IPs and absolute host paths. **Runs in CI** (5.1) |
| Prohibited-mechanic check | Greps for gambling and paid-advantage patterns. **Runs in CI** (3.9) |

---

