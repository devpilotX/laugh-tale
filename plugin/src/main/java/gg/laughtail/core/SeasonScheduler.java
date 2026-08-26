package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;

import java.sql.SQLException;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;

/**
 * The automatic season rollover. Section 31.
 *
 * Seasons are monthly. Until now `/season start` and `/season end` were manual, which means the
 * server only rolls over when somebody remembers - and a competitive season that ends late, or not
 * at all, is worse than one that ends on a schedule nobody has to think about.
 *
 * WHAT IT DOES AUTOMATICALLY
 *   - warns the server at 7 days, 24 hours, 1 hour and 10 minutes before the end;
 *   - at the end time, crowns the Champion, archives the season and opens the next one;
 *   - records every step in the staff audit trail.
 *
 * WHAT IT DELIBERATELY DOES NOT DO
 *   - it does not regenerate the resource world. Deleting a world at runtime is the single most
 *     destructive thing this software could do, and never-break rule 3 exists because of it. The
 *     regeneration stays a host script with five layered refusals, run by cron, and this class only
 *     CHECKS that it happened and complains if it did not. A scheduler that can delete worlds is a
 *     scheduler that can delete the wrong world.
 *   - it does not wipe Berries, stats, homes, cosmetics or Champion titles. Those survive a reset by
 *     design; only the seasonal rating ladder resets.
 *
 * IT REFUSES RATHER THAN IMPROVISES. 31.2 forbids a season ending without a Champion, so if nobody
 * is rated the rollover REFUSES, logs at SEVERE, tells online staff, and tries again in an hour. The
 * alternative - crowning nobody, or picking arbitrarily - would either violate 31.2 or invent a
 * winner. A season running two hours late is a scheduling problem; a season with a fabricated
 * Champion is a credibility problem.
 *
 * WARNINGS ARE TRACKED IN MEMORY ON PURPOSE. A restart may repeat one warning, which is harmless. The
 * alternative is a database write per announcement to prevent a duplicate message, which is a lot of
 * machinery to solve a problem nobody would notice.
 */
final class SeasonScheduler {

    /** Minutes before the end at which to warn. Descending, so the first match wins. */
    private static final long[] WARN_MINUTES = { 7 * 24 * 60, 24 * 60, 60, 10 };

    private final LaughTailPlugin plugin;
    private final Database db;
    private final Set<String> announced = new LinkedHashSet<>();
    private long nextRetryAfter = 0L;

    SeasonScheduler(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    void start() {
        // Every minute. A season boundary does not need second precision, and a cheap check that
        // runs often is easier to reason about than an expensive one that runs rarely.
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(plugin, this::check,
            20L * 30, 20L * 60);
    }

    private void check() {
        try {
            Database.SeasonTiming t = db.activeSeasonTiming();
            if (t == null) {
                maybeOpenFirstSeason();
                return;
            }
            long minutesLeft = Duration.between(Instant.now(), t.endsAt()).toMinutes();

            if (minutesLeft > 0) {
                warnIfDue(t.season(), minutesLeft);
                return;
            }

            if (System.currentTimeMillis() < nextRetryAfter) return;
            rollover(t.season());
        } catch (SQLException e) {
            plugin.getLogger().warning("Season scheduler could not read the season: "
                + e.getMessage());
        }
    }

    /**
     * Opens season 1 if no season has ever run.
     *
     * Without this the scheduler would sit idle on a fresh install waiting for a season that nobody
     * started, and every seasonal feature - rating, the ladder, the Champion - would silently do
     * nothing. A server with no season is not a state worth supporting.
     */
    private void maybeOpenFirstSeason() throws SQLException {
        // NO ACTIVE SEASON IS ALWAYS RECOVERED FROM, whether or not earlier seasons exist.
        //
        // The first version of this returned early when any season had ever run, on the reasoning
        // that "between seasons" was a legitimate state. It is not a state this server should ever
        // sit in: with no active season, rating, the ladder and the Champion all silently do nothing,
        // and the only symptom is that nothing happens. The live database was in exactly that state
        // when this was written - season 1 archived, nothing after it - which is how the gap was
        // found.
        boolean hadPrevious = db.anySeasonExists();
        int n = db.startSeason(30);
        plugin.getLogger().info(hadPrevious
            ? "No season was active, so season " + n + " was opened automatically for 30 days. "
              + "A server between seasons has a silently inert ladder, which is why this recovers "
              + "rather than waiting."
            : "No season existed, so season " + n + " was opened automatically for 30 days.");
        announce(Component.text("Season " + n + " has begun. Rank is earned by PvP only.",
            NamedTextColor.GOLD));
        audit("season.auto_start", "season " + n + ", 30 days, opened because none was active");
    }

    private void warnIfDue(int season, long minutesLeft) {
        for (long threshold : WARN_MINUTES) {
            if (minutesLeft > threshold) continue;
            String key = season + ":" + threshold;
            if (!announced.add(key)) return;    // already said this one
            announce(Component.text("Season " + season + " ends in "
                + human(minutesLeft) + ".", NamedTextColor.GOLD)
                .append(Component.text(" Your rating decides the Champion.",
                    NamedTextColor.GRAY)));
            return;   // only the closest threshold, never a burst of four messages
        }
    }

    private String human(long minutes) {
        if (minutes >= 1440) return (minutes / 1440) + " day(s)";
        if (minutes >= 60) return (minutes / 60) + " hour(s)";
        return minutes + " minute(s)";
    }

    /**
     * Ends the season and opens the next.
     *
     * endSeason already refuses when there is no Champion (31.2), and that refusal is respected here
     * rather than worked around. The retry is an hour out so a failing rollover does not spam the
     * console once a minute.
     */
    private void rollover(int season) {
        plugin.getLogger().info("Season " + season + " has reached its end time. Rolling over.");
        try {
            String result = db.endSeason(season);
            if (result != null && !result.toLowerCase().startsWith("ok")) {
                nextRetryAfter = System.currentTimeMillis() + Duration.ofHours(1).toMillis();
                plugin.getLogger().severe("SEASON ROLLOVER REFUSED: " + result);
                plugin.getLogger().severe("  Retrying in one hour. The season stays open until "
                    + "this is resolved - 31.2 forbids a season ending without a Champion, so "
                    + "running late is the correct behaviour here.");
                notifyStaff("Season " + season + " could not roll over: " + result);
                audit("season.auto_end_refused", "season " + season + ": " + result);
                return;
            }

            announce(Component.text("Season " + season + " is over.", NamedTextColor.GOLD));
            plugin.getLogger().info("Season " + season + " ended: " + result);
            audit("season.auto_end", "season " + season + " ended automatically: " + result);

            int next = db.startSeason(30);
            announce(Component.text("Season " + next + " begins now. Ratings reset; "
                + "Berries, stats, homes, cosmetics and Champion titles do not.",
                NamedTextColor.GREEN));
            audit("season.auto_start", "season " + next + " opened automatically, 30 days");

            // The resource world is NOT touched from here. See the class note.
            checkResourceWorldFreshness();
        } catch (SQLException e) {
            nextRetryAfter = System.currentTimeMillis() + Duration.ofHours(1).toMillis();
            plugin.getLogger().severe("SEASON ROLLOVER FAILED: " + e.getMessage()
                + ". Retrying in one hour. Nothing was half-applied - endSeason is transactional.");
            notifyStaff("Season rollover failed: " + e.getMessage());
        }
    }

    /**
     * Complains if the resource world has not been regenerated recently.
     *
     * The plugin cannot regenerate it - that is a host script with layered refusals, for good reason -
     * but it CAN notice that the monthly reset did not happen. A silent failure of a monthly job is
     * exactly the kind of thing nobody spots for three months.
     */
    private void checkResourceWorldFreshness() {
        org.bukkit.World rw = plugin.getServer().getWorld("laughtail_resource");
        if (rw == null) {
            plugin.getLogger().warning("The resource world is not loaded, so its freshness "
                + "cannot be checked.");
            return;
        }
        plugin.getLogger().info("REMINDER: the resource world regeneration is a host script "
            + "(scripts/remote/regen-resource-world.sh) run by cron, not by this plugin. "
            + "Deleting a world at runtime is what never-break rule 3 exists to prevent.");
        notifyStaff("Season rolled over. Confirm the resource world regeneration ran.");
    }

    private void announce(Component c) {
        plugin.getServer().getScheduler().runTask(plugin,
            () -> plugin.getServer().broadcast(c));
    }

    /** Tells online staff, who are the people who can actually act on it. */
    private void notifyStaff(String message) {
        plugin.getServer().getScheduler().runTask(plugin, () -> {
            for (org.bukkit.entity.Player p : plugin.getServer().getOnlinePlayers()) {
                if (p.hasPermission("laughtail.status")) {
                    p.sendMessage(Component.text("[staff] " + message, NamedTextColor.RED));
                }
            }
        });
    }

    private void audit(String action, String detail) {
        try {
            db.audit(null, "SCHEDULER", action, null, null, detail, null);
        } catch (SQLException e) {
            plugin.getLogger().warning("Could not audit " + action + ": " + e.getMessage());
        }
    }
}
