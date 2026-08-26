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

    /**
     * The palette. Five accents, one label grey, one value white.
     *
     * Chosen as a set rather than picked per line. The previous version used the sixteen legacy
     * Minecraft colours, which is why it looked unprofessional - those colours were designed for
     * 1990s terminals and several of them clash badly against a bright sky. These are one warm
     * family (amber to gold) plus two cool accents, which is the smallest palette that still lets
     * each line be told apart at a glance.
     *
     * Labels are grey and values white, so the eye lands on the number rather than the word.
     */
    private static final TextColor LABEL       = TextColor.fromHexString("#8A8F98");
    private static final TextColor VALUE       = TextColor.fromHexString("#FFFFFF");
    private static final TextColor BAR         = TextColor.fromHexString("#5A6570");
    private static final TextColor ACCENT_WARM  = TextColor.fromHexString("#E8734A");
    private static final TextColor ACCENT_GOLD  = TextColor.fromHexString("#F2B33D");
    private static final TextColor ACCENT_COOL  = TextColor.fromHexString("#5BA8D4");
    private static final TextColor ACCENT_LEAF  = TextColor.fromHexString("#79B851");
    private static final TextColor ACCENT_MUTED = TextColor.fromHexString("#9A6A6A");
    /** The header shimmer. Four steps, close together, so it reads as a sheen not a strobe. */
    private static final List<TextColor> SHIMMER = List.of(
        TextColor.fromHexString("#F2B33D"),
        TextColor.fromHexString("#F7C765"),
        TextColor.fromHexString("#FFDC96"),
        TextColor.fromHexString("#F7C765")
    );

    // Shorter than "LAUGH TALE": the header sets the sidebar's minimum width, so a long title makes
    // every line below it sit further from the edge of the screen.
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
        // 8 ticks, not 4. Two and a half frames a second reads as a slow sheen crossing the title, which
        // is what "minimal" means here - at 5 frames it was closer to a flicker, and it also halves the
        // packet cost to roughly 60 a second at 24 players.
        plugin.getServer().getScheduler().runTaskTimer(plugin, this::animateAll, 20L, 8L);
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

        // SIX LINES OF DATA AT MOST, and no blank spacers.
        //
        // The previous version ran to twelve lines with two blank separators, which covered a
        // noticeable share of the screen. A sidebar competes with the game for the same pixels, so
        // anything on it has to be worth blocking the view for. Homes count and the "/menu" hint were
        // dropped: neither changes minute to minute, and both are one keystroke away.
        //
        // The scoreboard sidebar is ALWAYS drawn at the right edge, vertically centred - that position
        // is decided by the client and a server cannot move it. The only lever is how much of it is
        // used, so that is the lever this pulls.

        line(board, o, i++, row("\u2694", "Rank", s.tier(), ACCENT_WARM));
        line(board, o, i++, row("\u2605", "RP", String.valueOf(s.rp()), ACCENT_COOL));
        line(board, o, i++, row("\u2620", "K/D", s.kills() + "/" + s.deaths(), ACCENT_MUTED));
        line(board, o, i++, row("\u25C8", "Berries", String.valueOf(s.berries()), ACCENT_GOLD));

        // The Path bar is the one line that moves while you play, so it earns its place. Level and bar
        // share a line rather than taking two.
        if (s.pathName() != null) {
            line(board, o, i++, Component.text("\u2692 ", ACCENT_LEAF)
                .append(Component.text(shortPath(s.pathName()) + " ", LABEL))
                .append(Component.text(String.valueOf(s.pathLevel()) + " ", VALUE))
                .append(Component.text(Path.bar(s.pathXp()), BAR)));
        }

        if (s.champTitles() > 0) {
            line(board, o, i++, row("\u265B", "Champion", "x" + s.champTitles(), ACCENT_GOLD));
        }

        line(board, o, i++, s.season() > 0
            ? row("\u25F7", "Season", String.valueOf(s.season()), ACCENT_COOL)
            : Component.text("\u25F7 ", ACCENT_MUTED)
                .append(Component.text("No season", LABEL)));

        // Any line left over from a previous render - the Champion line after a reset, or the Path line
        // if it was unfocused - must be removed or it lingers with stale text.
        for (int stale = i; stale < 16; stale++) {
            Team t = board.getTeam("lt" + stale);
            if (t != null) {
                for (String entry : t.getEntries()) board.resetScores(entry);
                t.unregister();
            }
        }
    }

    /**
     * One line: coloured icon, grey label, white value.
     *
     * The owner asked for labels grey and values white, which is also simply better - the eye lands on
     * the number rather than on the word next to it. Colour is spent on the icon alone, so the palette
     * stays legible instead of turning into a rainbow of competing text.
     */
    private Component row(String icon, String label, String value, TextColor iconColour) {
        return Component.text(icon + " ", iconColour)
            .append(Component.text(label + " ", LABEL))
            .append(Component.text(value, VALUE));
    }

    /** Trims a Path name so the line cannot force the sidebar wider than it needs to be. */
    private String shortPath(String name) {
        return name.length() > 10 ? name.substring(0, 10) : name;
    }
}
