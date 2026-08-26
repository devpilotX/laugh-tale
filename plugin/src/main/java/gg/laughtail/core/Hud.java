package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.scoreboard.Criteria;
import org.bukkit.scoreboard.DisplaySlot;
import org.bukkit.scoreboard.Objective;
import org.bukkit.scoreboard.Scoreboard;

import java.sql.SQLException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The sidebar HUD. Rank, season, Berries and homes, always visible.
 *
 * A scoreboard sidebar renders on the RIGHT of the screen, vertically centred, which is exactly
 * where the owner asked for it. It is also the only way to get persistent on-screen text that
 * works on a vanilla client and through Geyser for Bedrock - the action bar and the boss bar are
 * the alternatives and both are worse here: the action bar is transient and was already rejected
 * as spam, and a boss bar sits at the top and competes with 31.7's cosmetic budget.
 *
 * DATA IS READ ASYNCHRONOUSLY AND CACHED. The sidebar refreshes every two seconds, but a
 * database read every two seconds per player would be 12 queries a minute each - 288 a minute at
 * 24 players, in a hot path, which is exactly the sort of thing acceptance row 25 exists to stop.
 * So values are fetched off the main thread every ten seconds into a per-player snapshot, and the
 * sidebar renders from the snapshot. Berries and rank do not change often enough for anyone to
 * notice ten seconds, and the alternative is a database call inside the tick loop.
 *
 * ONE LINE PER FACT, no decoration, no borders. The owner asked for clean and organised, and a
 * sidebar is small - every character spent on a box-drawing frame is a character not spent on
 * information.
 */
final class Hud implements Listener {

    private record Snapshot(long berries, int rp, String tier, int season, int homes,
                            int homeMax, int champTitles) { }

    private final LaughTailPlugin plugin;
    private final Database db;
    private final Map<UUID, Snapshot> cache = new ConcurrentHashMap<>();

    Hud(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    void start() {
        // Render often, read rarely. See the class note.
        plugin.getServer().getScheduler().runTaskTimer(plugin, this::renderAll, 40L, 40L);
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(plugin, this::refreshAll,
            20L, 200L);
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        // Refresh immediately rather than waiting up to ten seconds, so a joining player does
        // not see an empty or stale sidebar - first impressions are 7.5's whole argument.
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin,
            () -> refresh(e.getPlayer().getUniqueId()));
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        cache.remove(e.getPlayer().getUniqueId());
    }

    private void refreshAll() {
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            refresh(p.getUniqueId());
        }
    }

    private void refresh(UUID id) {
        try {
            long berries = db.balance(id);
            int season = db.activeSeason();
            int rp = db.currentRp(id, season);
            int homes = db.homeNames(id).size();
            int purchased = db.purchasedSlots(id);
            int champs = db.championSeasons(id).size();
            cache.put(id, new Snapshot(berries, rp, Rating.tierName(rp), season, homes,
                Math.min(Homes.MAX_HOMES, Homes.FREE_SLOTS + purchased), champs));
        } catch (SQLException e) {
            // A failed refresh leaves the previous snapshot in place rather than blanking the
            // sidebar. Stale information is better than a display that flickers empty on every
            // transient database hiccup.
            plugin.getLogger().fine("HUD refresh failed for " + id + ": " + e.getMessage());
        }
    }

    private void renderAll() {
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            Snapshot s = cache.get(p.getUniqueId());
            if (s == null) continue;
            render(p, s);
        }
    }

    private void render(Player p, Snapshot s) {
        Scoreboard board = p.getScoreboard();
        // A player on the main shared scoreboard must be given their own, or every player would
        // see the same numbers.
        if (board == plugin.getServer().getScoreboardManager().getMainScoreboard()) {
            board = plugin.getServer().getScoreboardManager().getNewScoreboard();
            p.setScoreboard(board);
        }
        Objective o = board.getObjective("laughtail");
        if (o == null) {
            o = board.registerNewObjective("laughtail", Criteria.DUMMY,
                Component.text("Laugh Tale", NamedTextColor.GOLD));
            o.setDisplaySlot(DisplaySlot.SIDEBAR);
        }

        // Scoreboard lines are keyed by entry string, so a changing value needs the old entry
        // removed or lines accumulate. Rebuilding is simpler and cheap at this size.
        for (String entry : board.getEntries()) {
            board.resetScores(entry);
        }

        int line = 9;
        set(o, line--, "\u00A77Rank \u00A7f" + s.tier());
        set(o, line--, "\u00A77RP \u00A7f" + s.rp());
        set(o, line--, " ");
        set(o, line--, "\u00A77Berries \u00A76" + s.berries());
        set(o, line--, "  ");
        set(o, line--, "\u00A77Homes \u00A7f" + s.homes() + "\u00A78/" + s.homeMax());
        if (s.champTitles() > 0) {
            set(o, line--, "\u00A77Titles \u00A76" + s.champTitles() + " \u00A7eChampion");
        }
        set(o, line--, "   ");
        set(o, line--, s.season() > 0
            ? "\u00A77Season \u00A7f" + s.season()
            : "\u00A78no active season");
    }

    private void set(Objective o, int line, String text) {
        o.getScore(text).setScore(line);
    }
}
