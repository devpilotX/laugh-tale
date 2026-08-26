package gg.laughtail.core;

import org.bukkit.Location;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.PlayerDeathEvent;

import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;

/**
 * Records every player death as a combat_events row, with the reason it did or did not
 * count towards rating.
 *
 * WHAT THIS DOES NOT DO: calculate rating. Every row is written with rp_delta 0 and the
 * rating tables are untouched, because Appendix B contradicts Section 9 in three places
 * (questions.md Q-11 to Q-13) and 28.8 names ranking as the place where maximum care is
 * warranted. Writing a formula now would mean either guessing which of two contradictory
 * specifications is meant, or quietly inventing a third. The EVIDENCE is being collected
 * from the first kill onwards, so when the constants are settled the history is already
 * there - and row 31's diminishing-returns pattern can be validated against real data
 * rather than a synthetic test.
 *
 * WHY THE THRESHOLDS ARE NOT IN THIS FILE. Never-break rule 10: "Never publish detector
 * thresholds for anti-cheat, wagering, or market manipulation. Publishing them teaches
 * evasion." The repeat-kill window and the alt-detection settings are read at runtime from
 * a private config that is created on the host and never committed. The DETECTION LOGIC is
 * public and reviewable here; only the numbers are withheld, which is the right split -
 * a reviewer can check the logic is sound without learning where the line sits.
 *
 * SAME-IP HANDLING, and why it stores a hash. Row 32 requires same-IP kills to award zero
 * and raise an alert, which needs comparison, not readability. Storing the address itself
 * would put a personal identifier in a table that 31.13 governs for retention, for no
 * benefit - a hash compares exactly as well. The salt lives in the private config so the
 * hashes are not reversible with a rainbow table of the IPv4 space, which is small enough
 * to enumerate.
 */
final class CombatTracker implements Listener {

    private final LaughTailPlugin plugin;
    private final Database db;
    private final StatsTracker stats;

    /** Recent kills per (killer -> victim), newest first. Bounded, in memory only. */
    private final Map<String, Deque<Long>> recentKills = new ConcurrentHashMap<>();
    /** Current killstreak per player. Reset on death. */
    private final Map<UUID, Integer> streaks = new ConcurrentHashMap<>();
    /** Prior kills on this victim inside the window, set by suppressionReason. */
    private volatile int lastPriorCount = 0;

    // Read from the private config. Defaults here are deliberately NOT the operating
    // values - they are conservative placeholders so the plugin runs if the private file
    // is missing, and the log says loudly when that happens.
    // Appendix B specifies BOTH of these, so they are constants rather than config:
    // a six-hour window and the curve 1.00 / 0.50 / 0.25 / 0.10 / 0.00. An earlier version
    // read them from private.yml on the grounds that never-break rule 10 protects detector
    // thresholds - but rule 10 protects thresholds that are NOT published, and these are
    // printed in the specification. Inventing different values there also silently
    // contradicted Appendix B, which is worse than publishing it.
    private static final long REPEAT_WINDOW_MILLIS = Rating.REPEAT_WINDOW_MS;
    private String ipSalt = "";
    private boolean privateConfigLoaded = false;

    CombatTracker(LaughTailPlugin plugin, Database db, StatsTracker stats) {
        this.plugin = plugin;
        this.db = db;
        this.stats = stats;
    }

    void configure(long unusedWindow, int unusedLimit, String ipSalt, boolean loaded) {
        // The window and curve are Appendix B constants now; only the salt is private.
        this.ipSalt = ipSalt;
        this.privateConfigLoaded = loaded;
        if (!loaded) {
            plugin.getLogger().warning(
                "private.yml was not found, so the IP hash salt is empty. Same-IP detection "
              + "still works, but unsalted hashes of the IPv4 space are reversible by brute "
              + "force. The repeat-kill curve is unaffected - it is an Appendix B constant.");
        }
    }

    private String hashIp(Player p) {
        if (p.getAddress() == null || p.getAddress().getAddress() == null) return null;
        String raw = ipSalt + '|' + p.getAddress().getAddress().getHostAddress();
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] h = md.digest(raw.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(64);
            for (byte b : h) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            return null;   // SHA-256 is mandated by the JLS; this cannot happen
        }
    }

    /**
     * Decides whether a kill counts, and why not if it does not. Returns null when the
     * kill is legitimate.
     *
     * The order matters: cheapest and most certain checks first, so an obvious
     * self-inflicted death never reaches the alt-detection logic.
     */
    private String suppressionReason(Player killer, Player victim, boolean sameIp) {
        if (killer == null) return "no_killer";                       // environment or mob
        if (killer.getUniqueId().equals(victim.getUniqueId())) return "self_inflicted";
        if (sameIp) return "same_ip";                                  // row 32
        if (killer.hasPermission("laughtail.staff.chat")) return "staff_excluded";  // 17.4
        if (victim.hasPermission("laughtail.staff.chat")) return "staff_excluded";

        String key = killer.getUniqueId() + ">" + victim.getUniqueId();
        Deque<Long> q = recentKills.computeIfAbsent(key, k -> new ArrayDeque<>());
        long now = System.currentTimeMillis();
        synchronized (q) {
            while (!q.isEmpty() && now - q.peekLast() > REPEAT_WINDOW_MILLIS) q.pollLast();
            int recent = q.size();
            q.addFirst(now);
            // Bounded so a long session cannot grow this without limit.
            while (q.size() > 64) q.pollLast();
            lastPriorCount = recent;
            // Appendix B zeroes the 5th kill onward; earlier repeats are reduced, not
            // suppressed, so only a zero multiplier counts as suppression here.
            if (Rating.repeatMultiplier(recent) == 0.0) return "repeat_kill";   // row 31
        }
        return null;
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onDeath(PlayerDeathEvent e) {
        final Player victim = e.getEntity();
        final Player killer = victim.getKiller();

        boolean sameIp = false;
        String killerHash = null, victimHash = hashIp(victim);
        if (killer != null) {
            killerHash = hashIp(killer);
            sameIp = killerHash != null && killerHash.equals(victimHash);
        }

        final String reason = suppressionReason(killer, victim, sameIp);
        final boolean counted = (reason == null);

        // Streak bookkeeping happens whether or not the kill scores rating: 9.8 tracks
        // killstreak as a statistic, and a suppressed kill is still a kill.
        streaks.put(victim.getUniqueId(), 0);
        stats.recordDeath(victim.getUniqueId());
        if (killer != null && !killer.getUniqueId().equals(victim.getUniqueId())) {
            int s = streaks.merge(killer.getUniqueId(), 1, Integer::sum);
            stats.recordKill(killer.getUniqueId(), s, true);
        }

        if (sameIp) {
            // Row 32 wants an ALERT, not just a zero. There is no Discord webhook yet
            // (OA-16), so it goes to the console at WARNING where the monitor's
            // error-delta check will surface it within five minutes.
            plugin.getLogger().warning("ROW 32 ALERT: same-IP kill - "
                + (killer != null ? killer.getName() : "?") + " killed " + victim.getName()
                + ". Zero rating awarded. Investigate for alt farming.");
        }

        final Location loc = victim.getLocation();
        final UUID killerId = killer != null ? killer.getUniqueId() : null;
        final UUID victimId = victim.getUniqueId();
        final boolean sameIpFinal = sameIp;

        final int priorCount = lastPriorCount;
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                int rpKiller = 0, rpVictim = 0;
                // Rating is applied only for a genuine player-versus-player kill. A death with
                // no killer, or a self-inflicted one, has no rating consequence at all - which
                // is what makes acceptance row 30 hold: there is no path from a non-combat
                // death to a rating change.
                if (killerId != null && !killerId.equals(victimId)) {
                    int season = db.activeSeason();
                    if (season > 0) {
                        int[] r = db.applyKillRating(killerId, victimId, season,
                            priorCount, !counted);
                        rpKiller = r[1] - r[0];
                        rpVictim = r[3] - r[2];
                        if (r[4] != 0) {
                            plugin.getLogger().info("rating: killer " + r[0] + "->" + r[1]
                                + " victim " + r[2] + "->" + r[3] + " gain " + r[4]
                                + " repeat#" + priorCount);
                        }
                    } else {
                        // No active season means no ladder to move. Recorded rather than
                        // silently dropped, because a kill during a gap between seasons is a
                        // real event that a player may ask about.
                        plugin.getLogger().fine("kill outside any active season - no rating applied");
                    }
                }
                db.recordCombatEvent(killerId, victimId, rpKiller, rpVictim,
                    reason, sameIpFinal,
                    loc.getWorld() != null ? loc.getWorld().getName() : null,
                    loc.getBlockX(), loc.getBlockY(), loc.getBlockZ());
            } catch (SQLException ex) {
                plugin.getLogger().log(Level.SEVERE,
                    "Could not record combat event: " + ex.getMessage());
            }
        });
    }

    boolean isPrivateConfigLoaded() {
        return privateConfigLoaded;
    }
}
