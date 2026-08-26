package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextDecoration;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;

/**
 * Chronicles: the server-wide story. See docs/roleplay-design.md.
 *
 * PROGRESS IS SERVER-WIDE, NOT PER PLAYER, and that is the central decision. Per-player quest chains
 * need NPCs, dialogue trees and a state machine for every player - which is what makes roleplay
 * plugins expensive, and none of it fits in the memory this box has. Server-wide progress instead:
 *
 *   - makes strangers cooperate without a party system, because everyone's mining counts toward the
 *     same number;
 *   - costs one row per objective rather than one row per player per objective;
 *   - produces the thing this server has no other source of - a sense that something is happening.
 *
 * EVERY CHAPTER NEEDS MORE THAN ONE KIND OF PLAYER. A chapter might require blocks mined AND mobs
 * killed AND orders filled, so no single play style can finish it alone. That is deliberate: it makes
 * the farmer and the fighter useful to each other, which is the only honest way to build cooperation
 * without mechanical coercion.
 *
 * REWARDS ARE LORE AND A TITLE. Never an item, never Berries, never a bonus - same rule as the rest of
 * the roleplay system (D-0038). A Chronicle that paid out gear would turn the story into a farm.
 *
 * COUNTERS ARE BATCHED for the same reason Path XP is: these hook block breaks and mob deaths, and a
 * database write per event would be the heaviest thing on the server.
 */
final class Chronicles {

    /** The season's story. Written here rather than in the database so it is version-controlled. */
    private record Chapter(int number, String title, String narrative, String[][] objectives) { }

    /**
     * Five chapters, following the server's own name.
     *
     * The arc is deliberately about *searching* rather than fighting, because the PvP ladder already
     * supplies conflict and a story that also demanded conflict would just be the ladder again with
     * extra words.
     */
    private static final Chapter[] STORY = {
        new Chapter(1, "The Rumour",
            "Someone came back. Nobody agrees from where. They spoke of an island at the end of "
          + "every chart, where the last people to arrive were laughing. Then they stopped talking "
          + "about it, which is how everyone knew it was true. The first thing any expedition needs "
          + "is not courage. It is supplies.",
            new String[][] {
                { "Mine 25,000 blocks", "blocks_mined", "25000" },
                { "Harvest 2,000 crops", "crops_harvested", "2000" },
                { "Fill 25 market orders", "orders_filled", "25" }
            }),
        new Chapter(2, "The First Marker",
            "A stone, half-buried, cut by hands that did not use iron. The marks on it are not "
          + "writing. They are a distance - and the distance points away from everything anyone has "
          + "mapped. Whoever follows it will need to survive what lives out there.",
            new String[][] {
                { "Travel 500,000 blocks between you", "distance_travelled", "500000" },
                { "Defeat 5,000 hostile creatures", "mobs_killed", "5000" },
                { "Craft 5,000 items", "items_crafted", "5000" }
            }),
        new Chapter(3, "Deep Water",
            "The charts end here and the water does not. Three expeditions have turned back. The "
          + "fourth sent one message before the silence: 'It is not empty. It is waiting.' Someone "
          + "has to go deeper than is sensible, and someone has to keep the ones who do alive.",
            new String[][] {
                { "Reach the depths: mine 5,000 deep blocks", "deep_mined", "5000" },
                { "Defeat 500 dangerous creatures", "elite_kills", "500" },
                { "Move 250,000 Berries through the market", "berries_traded", "250000" }
            }),
        new Chapter(4, "What the Stones Remember",
            "The markers are not directions. They are a record - of everyone who tried this before, "
          + "and there have been many. None of them were the first. The joke at the end of the world "
          + "is that the island has been found before, and forgotten every time, because whoever "
          + "arrives stops wanting to leave.",
            new String[][] {
                { "Mine 100,000 blocks", "blocks_mined", "100000" },
                { "Defeat 20,000 hostile creatures", "mobs_killed", "20000" },
                { "Fill 250 market orders", "orders_filled", "250" }
            }),
        new Chapter(5, "Laugh Tale",
            "You arrive. It is smaller than the stories. There is no treasure, no throne, nothing to "
          + "carry home - only the evidence that the crossing is possible, left by people who wanted "
          + "someone else to know it. That is the whole of it. And standing there, everyone who "
          + "reaches it does the same thing, for the same reason, which is why it has the name it has.",
            new String[][] {
                { "Everyone: 250,000 blocks mined", "blocks_mined", "250000" },
                { "Everyone: 50,000 creatures defeated", "mobs_killed", "50000" },
                { "Everyone: 1,000,000 Berries traded", "berries_traded", "1000000" }
            })
    };

    private final LaughTailPlugin plugin;
    private final Database db;
    private final Map<String, Long> pending = new ConcurrentHashMap<>();

    Chronicles(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    void start() {
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(plugin, this::flush,
            20L * 40, 20L * 30);
        // SEEDING RUNS ON A TIMER, NOT ONCE AFTER A DELAY.
        //
        // The first version seeded once, 15 seconds after enable. That RACED the season scheduler,
        // which opens a season on its own schedule - so on a database with no season, seeding found
        // nothing to attach chapters to, gave up, and the server ran with an empty Chronicle. It
        // happened for real the first time seasons were reset to 1: season 1 opened correctly and the
        // story silently did not exist.
        //
        // A one-shot task that depends on another task having finished is a race whichever delay is
        // chosen. Retrying is cheap - one COUNT when already seeded - and it also covers the case
        // that matters most: a NEW season needs its own chapters, and that happens long after boot.
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(plugin, this::seed,
            20L * 10, 20L * 30);
    }

    /** Advances a metric. Batched; safe to call from any thread and from hot events. */
    void advance(String metric, long amount) {
        if (amount <= 0) return;
        pending.merge(metric, amount, Long::sum);
    }

    /**
     * Creates this season's chapters if they do not exist, and activates chapter 1.
     *
     * Idempotent by the unique key on (season, chapter), so it can run on every boot. Chapters are
     * seeded per SEASON so the story restarts with each one - a story that only ever runs once leaves
     * every later season with nothing to discover.
     */
    private void seed() {
        try {
            int season = db.activeSeason();
            if (season <= 0) return;
            // Cheap early exit so running every 30 seconds costs one COUNT rather than five SELECTs.
            if (db.chapterCount(season) >= STORY.length) return;
            int created = 0;
            for (Chapter ch : STORY) {
                if (db.ensureChapter(season, ch.number(), ch.title(), ch.narrative(),
                        ch.objectives())) {
                    created++;
                }
            }
            if (created > 0) {
                plugin.getLogger().info("Chronicle seeded for season " + season + ": "
                    + created + " chapter(s). Chapter 1 is active.");
            }
        } catch (SQLException e) {
            plugin.getLogger().log(Level.WARNING, "chronicle seed failed: " + e.getMessage());
        }
    }

    private void flush() {
        if (pending.isEmpty()) return;
        Map<String, Long> batch = new ConcurrentHashMap<>(pending);
        pending.clear();
        try {
            for (Map.Entry<String, Long> e : batch.entrySet()) {
                db.advanceObjectives(e.getKey(), e.getValue());
            }
            Database.ChapterCompletion done = db.completeChapterIfDone();
            if (done != null) announceCompletion(done);
        } catch (SQLException e) {
            plugin.getLogger().log(Level.WARNING, "chronicle flush failed: " + e.getMessage());
        }
    }

    /**
     * Announces a completed chapter loudly.
     *
     * A server-wide story whose milestones pass quietly is a story nobody is in. This is the payoff
     * for thousands of blocks of collective work, so it interrupts.
     */
    private void announceCompletion(Database.ChapterCompletion done) {
        plugin.getServer().getScheduler().runTask(plugin, () -> {
            plugin.getServer().broadcast(Component.empty());
            plugin.getServer().broadcast(Component.text("  THE CHRONICLE ADVANCES",
                NamedTextColor.GOLD).decoration(TextDecoration.BOLD, true));
            plugin.getServer().broadcast(Component.text("  Chapter " + done.chapter() + " - "
                + done.title() + " is complete.", NamedTextColor.YELLOW));
            if (done.nextTitle() != null) {
                plugin.getServer().broadcast(Component.text("  Next: " + done.nextTitle(),
                    NamedTextColor.WHITE));
                plugin.getServer().broadcast(Component.text("  /chronicle to read it",
                    NamedTextColor.DARK_GRAY));
            } else {
                plugin.getServer().broadcast(Component.text("  The Chronicle is finished. "
                    + "This season's story is complete.", NamedTextColor.GREEN));
            }
            plugin.getServer().broadcast(Component.empty());
            for (org.bukkit.entity.Player p : plugin.getServer().getOnlinePlayers()) {
                p.playSound(p.getLocation(), org.bukkit.Sound.UI_TOAST_CHALLENGE_COMPLETE,
                    1.0f, 0.8f);
            }
        });
        // Everyone online when a chapter lands gets the title. Presence is the contribution that
        // matters for a collective goal, and per-player contribution accounting would need a row per
        // player per objective - the exact cost this design avoids.
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            for (org.bukkit.entity.Player p : plugin.getServer().getOnlinePlayers()) {
                try {
                    db.grantTitle(p.getUniqueId(), "chronicle." + done.season() + "."
                        + done.chapter(), done.title(), "#C77DFF", "chronicle");
                } catch (SQLException ignored) { }
            }
        });
    }

    /** `/chronicle` - read the story and see where the server has got to. */
    boolean handle(org.bukkit.command.CommandSender sender, String cmd) {
        if (!cmd.equals("chronicle") && !cmd.equals("story")) return false;
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                Database.ChapterView v = db.currentChapter();
                List<String> objectives = v == null ? List.of() : db.chapterObjectives(v.id());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (v == null) {
                        sender.sendMessage(Component.text("The Chronicle has not begun.",
                            NamedTextColor.GRAY));
                        return;
                    }
                    sender.sendMessage(Component.text("Chapter " + v.chapter() + " - " + v.title(),
                        NamedTextColor.GOLD).decoration(TextDecoration.BOLD, true));
                    // The narrative is wrapped rather than sent as one long line, because chat wraps
                    // mid-word and unreadable lore is lore nobody reads.
                    for (String line : wrap(v.narrative(), 62)) {
                        sender.sendMessage(Component.text("  " + line, NamedTextColor.GRAY)
                            .decoration(TextDecoration.ITALIC, true));
                    }
                    sender.sendMessage(Component.empty());
                    for (String o : objectives) {
                        sender.sendMessage(Component.text("  " + o, NamedTextColor.WHITE));
                    }
                    sender.sendMessage(Component.text("  Everyone's work counts toward these.",
                        NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "chronicle read failed: " + e.getMessage());
            }
        });
        return true;
    }

    private static List<String> wrap(String text, int width) {
        List<String> out = new java.util.ArrayList<>();
        StringBuilder line = new StringBuilder();
        for (String word : text.split(" ")) {
            if (line.length() + word.length() + 1 > width) {
                out.add(line.toString());
                line.setLength(0);
            }
            if (line.length() > 0) line.append(' ');
            line.append(word);
        }
        if (line.length() > 0) out.add(line.toString());
        return out;
    }
}
