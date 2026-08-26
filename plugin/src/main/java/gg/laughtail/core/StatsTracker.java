package gg.laughtail.core;

import org.bukkit.Material;
import org.bukkit.entity.EntityType;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;

import java.sql.SQLException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;

/**
 * Tracks the statistics 9.8 lists.
 *
 * THE DESIGN CONSTRAINT IS ACCEPTANCE ROW 25: no database call on the main thread. Every
 * event here fires on the main thread and some fire constantly - a block break per swing,
 * a movement update per tick. Writing to MariaDB inside those handlers would put network
 * latency inside the tick loop, which is how a server with a healthy CPU still stutters.
 *
 * So events only touch an in-memory counter, and a scheduled asynchronous task flushes
 * deltas to the database every 30 seconds. Counters are DELTAS, not totals, and are
 * applied with `col = col + ?` - which means a flush that races with another server
 * process cannot lose counts, and a flush that fails simply retries with the delta still
 * pending.
 *
 * ROW 30 IS SATISFIED BY CONSTRUCTION, NOT BY A CHECK. "Mining, farming and building for
 * two hours changes RP by exactly zero." Blocks mined and placed are recorded here, in a
 * class that has no access to rating at all - the only thing that writes combat_ratings is
 * CombatTracker, and the only thing that calls it is a player death. There is no code path
 * from a pickaxe to a rating point, which is a stronger guarantee than a test.
 */
final class StatsTracker implements Listener {

    private final LaughTailPlugin plugin;
    private final Database db;

    /** Pending deltas, keyed by player. Cleared on successful flush. */
    private final Map<UUID, Delta> pending = new ConcurrentHashMap<>();
    /** When each online player's playtime last counted, for active-time accrual. */
    private final Map<UUID, Long> lastTick = new ConcurrentHashMap<>();

    private static final class Delta {
        long kills, deaths, mined, placed, playtimeSeconds;
        int killstreakCurrent = -1;   // -1 means "unchanged"
        int killstreakBest = -1;
        final Map<String, Long> mobKills = new ConcurrentHashMap<>();
        final Map<String, Long> distance = new ConcurrentHashMap<>();

        boolean isEmpty() {
            return kills == 0 && deaths == 0 && mined == 0 && placed == 0
                && playtimeSeconds == 0 && killstreakCurrent < 0 && killstreakBest < 0
                && mobKills.isEmpty() && distance.isEmpty();
        }
    }

    StatsTracker(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    private Delta delta(UUID u) {
        return pending.computeIfAbsent(u, k -> new Delta());
    }

    void start() {
        // 30 seconds: frequent enough that a crash loses little, rare enough that it is
        // 2 writes a minute per active player rather than thousands.
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(
            plugin, this::flush, 20L * 30, 20L * 30);

        // Playtime accrues on the main thread but writes nothing - it only increments a
        // counter. 7.3 requires claim area to accrue with ACTIVE playtime and not idle
        // time, and 9.8's playtime must agree with it or the two contradict each other.
        // "Active" here means online; genuine AFK detection needs a movement threshold and
        // is deliberately left until claims are built, so this currently over-counts an
        // idle player. Recorded rather than hidden.
        plugin.getServer().getScheduler().runTaskTimer(plugin, () -> {
            long now = System.currentTimeMillis();
            for (Player p : plugin.getServer().getOnlinePlayers()) {
                Long last = lastTick.put(p.getUniqueId(), now);
                if (last != null) {
                    long seconds = (now - last) / 1000L;
                    if (seconds > 0 && seconds < 300) {   // ignore absurd gaps
                        delta(p.getUniqueId()).playtimeSeconds += seconds;
                    }
                }
            }
        }, 20L * 20, 20L * 20);
    }

    /** Flushes and clears pending deltas. Runs OFF the main thread. */
    void flush() {
        if (pending.isEmpty()) return;
        for (UUID u : pending.keySet().toArray(new UUID[0])) {
            Delta d = pending.remove(u);
            if (d == null || d.isEmpty()) continue;
            try {
                db.applyStatsDelta(u, d.kills, d.deaths, d.mined, d.placed,
                    d.playtimeSeconds, d.killstreakCurrent, d.killstreakBest,
                    d.mobKills, d.distance);
            } catch (SQLException e) {
                // Put it back rather than dropping it. A lost stat is invisible; a
                // repeated attempt is not.
                pending.merge(u, d, (a, b) -> {
                    a.kills += b.kills; a.deaths += b.deaths;
                    a.mined += b.mined; a.placed += b.placed;
                    a.playtimeSeconds += b.playtimeSeconds;
                    return a;
                });
                plugin.getLogger().log(Level.WARNING,
                    "Stats flush failed for " + u + ", delta retained: " + e.getMessage());
            }
        }
    }

    // ---- counters ------------------------------------------------------------

    void recordKill(UUID killer, int newStreak, boolean newBest) {
        Delta d = delta(killer);
        d.kills++;
        d.killstreakCurrent = newStreak;
        if (newBest) d.killstreakBest = newStreak;
    }

    void recordDeath(UUID victim) {
        Delta d = delta(victim);
        d.deaths++;
        d.killstreakCurrent = 0;   // a death always ends the streak
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        // 9.8 marks this informational only. Nothing here can reach rating.
        delta(e.getPlayer().getUniqueId()).mined++;
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        delta(e.getPlayer().getUniqueId()).placed++;
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onMobDeath(EntityDeathEvent e) {
        if (e.getEntity() instanceof Player) return;          // player deaths are combat
        Player killer = e.getEntity().getKiller();
        if (killer == null) return;                            // died to environment
        EntityType t = e.getEntity().getType();
        delta(killer.getUniqueId()).mobKills.merge(t.name(), 1L, Long::sum);
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        lastTick.put(e.getPlayer().getUniqueId(), System.currentTimeMillis());
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        UUID u = e.getPlayer().getUniqueId();
        lastTick.remove(u);
        // Flush this player's numbers now rather than waiting: a quit is the most likely
        // moment for the server to stop, and losing a session's stats to a restart is
        // exactly the sort of quiet data loss players notice and cannot prove.
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, this::flush);
    }

    /** Unused for now; kept because 9.8 asks for distance by method and the schema has it. */
    void recordDistance(UUID u, String method, long centimetres) {
        delta(u).distance.merge(method, centimetres, Long::sum);
    }

    int pendingCount() {
        return pending.size();
    }
}
