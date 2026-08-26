package gg.laughtail.core;

import io.papermc.paper.scoreboard.numbers.NumberFormat;
import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextColor;
import net.kyori.adventure.text.format.TextDecoration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.scoreboard.Criteria;
import org.bukkit.scoreboard.DisplaySlot;
import org.bukkit.scoreboard.Objective;
import org.bukkit.scoreboard.Scoreboard;
import org.bukkit.scoreboard.Team;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The sidebar HUD: icons, colour, and an animated title, with no score numbers.
 *
 * THE 1-9 ON THE RIGHT WERE SCOREBOARD SCORES. Every sidebar line has an integer score, and
 * vanilla renders it in red down the right edge. The usual workarounds are ugly - hiding them
 * behind long lines, or setting every score to the same value so they collapse. Paper 1.20.5 and
 * later expose `Objective#numberFormat`, so `NumberFormat.blank()` removes them properly. This
 * server is 26.2, so the correct tool exists and is used.
 *
 * LINES ARE RENDERED THROUGH TEAM PREFIXES, not as entry strings. A scoreboard entry is limited
 * and must be unique - which is why the previous version needed invisible padding like " " and
 * "  " to make blank lines distinct, and why a changing value meant removing and re-adding an
 * entry every refresh. Using a team per line with a fixed invisible entry and the visible text in
 * the prefix means values update in place with no flicker and no uniqueness games.
 *
 * THE ANIMATION IS A SHIMMER ACROSS THE TITLE, nothing more. It updates only the objective's
 * display name - one small packet per player per frame - at 5 frames a second. A moving sidebar
 * body would be genuinely expensive and, worse, unreadable: the eye cannot read a number that is
 * changing colour. So the data stays still and only the header moves, which is the effect people
 * actually mean by "animated scoreboard".
 *
 * COST, stated because 31.7 puts a budget on decoration: 5 title packets per second per player,
 * 120 a second at 24 players. That is trivial next to movement and chunk traffic, and it is
 * deliberately the ONLY animated element. If MSPT ever comes under pressure this is the first
 * thing that should be switched off, and the watchdog in 6.6 is where that switch belongs.
 */
final class Hud implements Listener {

    private record Snapshot(long berries, int rp, String tier, int season, int homes,
                            int homeMax, int champTitles, int kills, int deaths,
                            String pathName, long pathXp, int pathLevel, String title) { }

    /** The shimmer palette - gold moving through pale yellow and back. */
    private static final List<TextColor> SHIMMER = List.of(
        TextColor.fromHexString("#FFB302"),
        TextColor.fromHexString("#FFC93C"),
        TextColor.fromHexString("#FFE07D"),
        TextColor.fromHexString("#FFF3C4"),
        TextColor.fromHexString("#FFE07D"),
        TextColor.fromHexString("#FFC93C")
    );

    private static final String TITLE_TEXT = "LAUGH TALE";

    private final LaughTailPlugin plugin;
    private final Database db;
    private final Map<UUID, Snapshot> cache = new ConcurrentHashMap<>();
    private int frame = 0;

    Hud(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    void start() {
        // Body every second: values change slowly and a redraw is cheap.
        plugin.getServer().getScheduler().runTaskTimer(plugin, this::renderAll, 20L, 20L);
        // Title every 4 ticks: 5 frames a second is smooth enough to read as movement without
        // being a flicker.
        plugin.getServer().getScheduler().runTaskTimer(plugin, this::animateAll, 20L, 4L);
        // Data every 10 seconds, off the main thread. See the class note on row 25.
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(plugin, this::refreshAll,
            20L, 200L);
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin,
            () -> refresh(e.getPlayer().getUniqueId()));
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        cache.remove(e.getPlayer().getUniqueId());
    }

    private void refreshAll() {
        for (Player p : plugin.getServer().getOnlinePlayers()) refresh(p.getUniqueId());
    }

    private void refresh(UUID id) {
        try {
            int season = db.activeSeason();
            int rp = db.currentRp(id, season);
            int[] kd = db.killsAndDeaths(id);
            Object[] ap = db.activePath(id);
            String[] worn = db.wornTitle(id);
            cache.put(id, new Snapshot(
                db.balance(id), rp, Rating.tierName(rp), season,
                db.homeNames(id).size(),
                Math.min(Homes.MAX_HOMES, Homes.FREE_SLOTS + db.purchasedSlots(id)),
                db.championSeasons(id).size(), kd[0], kd[1],
                ap == null ? null : ((Path) ap[0]).display(),
                ap == null ? 0L : (Long) ap[1],
                ap == null ? 0 : (Integer) ap[2],
                worn == null ? null : worn[0]));
        } catch (SQLException e) {
            // Keep the previous snapshot. Stale beats a sidebar that flickers empty.
            plugin.getLogger().fine("HUD refresh failed: " + e.getMessage());
        }
    }

    // ---- rendering -----------------------------------------------------------

    private Objective objectiveFor(Player p) {
        Scoreboard board = p.getScoreboard();
        if (board == plugin.getServer().getScoreboardManager().getMainScoreboard()) {
            board = plugin.getServer().getScoreboardManager().getNewScoreboard();
            p.setScoreboard(board);
        }
        Objective o = board.getObjective("laughtail");
        if (o == null) {
            o = board.registerNewObjective("laughtail", Criteria.DUMMY, title(0));
            o.setDisplaySlot(DisplaySlot.SIDEBAR);
            // The whole reason the numbers are gone.
            o.numberFormat(NumberFormat.blank());
        }
        return o;
    }

    /** The shimmering header. Each character takes its colour from a moving offset. */
    private Component title(int f) {
        Component out = Component.text("\u2726 ", TextColor.fromHexString("#FFF3C4"));
        for (int i = 0; i < TITLE_TEXT.length(); i++) {
            TextColor c = SHIMMER.get(Math.floorMod(i + f, SHIMMER.size()));
            out = out.append(Component.text(String.valueOf(TITLE_TEXT.charAt(i)), c)
                .decoration(TextDecoration.BOLD, true));
        }
        return out.append(Component.text(" \u2726", TextColor.fromHexString("#FFF3C4")));
    }

    private void animateAll() {
        frame++;
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            if (cache.containsKey(p.getUniqueId())) {
                objectiveFor(p).displayName(title(frame));
            }
        }
    }

    private void renderAll() {
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            Snapshot s = cache.get(p.getUniqueId());
            if (s != null) render(p, s);
        }
    }

    /**
     * One team per line. The entry is an invisible unique marker and the visible text lives in
     * the team prefix, so a value can change without removing and re-adding anything.
     */
    private void line(Scoreboard board, Objective o, int index, Component text) {
        String key = "lt" + index;
        Team t = board.getTeam(key);
        if (t == null) {
            t = board.registerNewTeam(key);
            // A colour code as the entry: invisible, unique per line, and stable.
            t.addEntry("\u00A7" + "0123456789abcdef".charAt(index % 16) + "\u00A7r");
        }
        t.prefix(text);
        o.getScore(t.getEntries().iterator().next()).setScore(30 - index);
    }

    private void render(Player p, Snapshot s) {
        Objective o = objectiveFor(p);
        Scoreboard board = p.getScoreboard();
        int i = 0;

        line(board, o, i++, Component.text("\u2694 ", NamedTextColor.RED)
            .append(Component.text("Rank ", NamedTextColor.GRAY))
            .append(Component.text(s.tier(), NamedTextColor.WHITE)));

        line(board, o, i++, Component.text("\u2605 ", NamedTextColor.AQUA)
            .append(Component.text("RP ", NamedTextColor.GRAY))
            .append(Component.text(String.valueOf(s.rp()), NamedTextColor.WHITE)));

        line(board, o, i++, Component.text("\u2620 ", NamedTextColor.DARK_RED)
            .append(Component.text("K/D ", NamedTextColor.GRAY))
            .append(Component.text(s.kills() + "/" + s.deaths(), NamedTextColor.WHITE)));

        line(board, o, i++, Component.empty());

        line(board, o, i++, Component.text("\u25C8 ", NamedTextColor.GOLD)
            .append(Component.text("Berries ", NamedTextColor.GRAY))
            .append(Component.text(String.valueOf(s.berries()), NamedTextColor.YELLOW)));

        line(board, o, i++, Component.text("\u2302 ", NamedTextColor.GREEN)
            .append(Component.text("Homes ", NamedTextColor.GRAY))
            .append(Component.text(s.homes() + "/" + s.homeMax(), NamedTextColor.WHITE)));

        if (s.champTitles() > 0) {
            line(board, o, i++, Component.text("\u265B ", NamedTextColor.GOLD)
                .append(Component.text("Champion ", NamedTextColor.GRAY))
                .append(Component.text("x" + s.champTitles(), NamedTextColor.GOLD)));
        }

        // The Path bar is the second ladder: something that always moves, for players who are not
        // winning fights. It is deliberately shown next to rank rather than hidden in a menu.
        if (s.pathName() != null) {
            line(board, o, i++, Component.text("\u2692 ", NamedTextColor.YELLOW)
                .append(Component.text(s.pathName() + " ", NamedTextColor.GRAY))
                .append(Component.text(String.valueOf(s.pathLevel()), NamedTextColor.WHITE)));
            line(board, o, i++, Component.text("  " + Path.bar(s.pathXp()),
                NamedTextColor.DARK_GRAY));
        }

        line(board, o, i++, Component.empty());

        line(board, o, i++, s.season() > 0
            ? Component.text("\u25F7 ", NamedTextColor.LIGHT_PURPLE)
                .append(Component.text("Season ", NamedTextColor.GRAY))
                .append(Component.text(String.valueOf(s.season()), NamedTextColor.WHITE))
            : Component.text("\u25F7 ", NamedTextColor.DARK_GRAY)
                .append(Component.text("No active season", NamedTextColor.DARK_GRAY)));

        line(board, o, i++, Component.text("\u2726 ", TextColor.fromHexString("#FFE07D"))
            .append(Component.text("/menu", NamedTextColor.WHITE)));

        // Any line left over from a previous render - for instance the Champion line after a
        // reset - must be removed or it would linger with stale text.
        for (int stale = i; stale < 16; stale++) {
            Team t = board.getTeam("lt" + stale);
            if (t != null) {
                for (String entry : t.getEntries()) board.resetScores(entry);
                t.unregister();
            }
        }
    }
}
