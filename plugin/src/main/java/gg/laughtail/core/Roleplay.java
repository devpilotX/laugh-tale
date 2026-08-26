package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextColor;
import net.kyori.adventure.text.format.TextDecoration;
import org.bukkit.Material;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.player.PlayerMoveEvent;
import net.kyori.adventure.title.Title;

import java.sql.SQLException;
import java.time.Duration;
import java.util.EnumMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;

/**
 * Roleplay: Paths, Houses, titles. See docs/roleplay-design.md.
 *
 * XP IS BATCHED, NOT WRITTEN PER EVENT. A block break fires many times a second per player, and a
 * database write per break would be the single heaviest thing this plugin does. Deltas accumulate in
 * memory and flush every 30 seconds on an async task - the same mechanism the stats tracker already
 * uses, for the same reason. The cost of a crash is up to 30 seconds of XP, which nobody notices; the
 * cost of not batching is a server that stutters whenever anyone mines.
 *
 * MOVEMENT IS SAMPLED, NOT COUNTED. PlayerMoveEvent fires on every head turn - dozens per second per
 * player - and doing arithmetic in it is how plugins destroy TPS. Wayfinder XP is instead sampled on a
 * timer from the player's position, which costs nothing and cannot be told apart by a player.
 *
 * AND THE RULE, ONCE MORE, BECAUSE IT IS THE WHOLE DESIGN: nothing awarded here changes a number that
 * matters in a fight. Titles, colours, House standing, recognition. Never damage, health, speed, drops,
 * discounts or permissions. A Path that made a player stronger would break Law 1 and would make rank
 * measure grinding rather than fighting.
 */
final class Roleplay implements Listener {

    private static final long FLUSH_TICKS = 20L * 30;

    private final LaughTailPlugin plugin;
    private final Database db;
    /**
     * The Chronicle is fed from the SAME events, rather than from its own listeners.
     *
     * Two listeners on BlockBreakEvent would double the cost of the hottest event on the server for no
     * benefit. One listener, two consumers.
     */
    private Chronicles chronicles;

    /** Pending XP per player per Path, awaiting a flush. */
    private final Map<UUID, Map<Path, Long>> pending = new ConcurrentHashMap<>();
    /** Last sampled position, for Wayfinder distance. */
    private final Map<UUID, org.bukkit.Location> lastSample = new ConcurrentHashMap<>();

    Roleplay(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    void setChronicles(Chronicles c) { this.chronicles = c; }

    private void chronicle(String metric, long amount) {
        if (chronicles != null) chronicles.advance(metric, amount);
    }

    void start() {
        plugin.getServer().getScheduler().runTaskTimerAsynchronously(plugin, this::flush,
            FLUSH_TICKS, FLUSH_TICKS);
        // Sample movement every 5 seconds instead of handling PlayerMoveEvent. See the class note.
        plugin.getServer().getScheduler().runTaskTimer(plugin, this::sampleMovement, 100L, 100L);
    }

    // ---- earning -------------------------------------------------------------

    private void award(UUID id, Path path, long xp) {
        if (xp <= 0) return;
        pending.computeIfAbsent(id, k -> new EnumMap<>(Path.class))
            .merge(path, xp, Long::sum);
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        Material m = e.getBlock().getType();
        // Ore is worth more than stone, because a Path that levels equally from cobblestone would be
        // a ladder anyone climbs by facing a wall. The multiplier is XP only - it changes nothing else.
        long xp = switch (m) {
            case ANCIENT_DEBRIS -> 60;
            case DIAMOND_ORE, DEEPSLATE_DIAMOND_ORE, EMERALD_ORE, DEEPSLATE_EMERALD_ORE -> 25;
            case GOLD_ORE, DEEPSLATE_GOLD_ORE, LAPIS_ORE, DEEPSLATE_LAPIS_ORE,
                 REDSTONE_ORE, DEEPSLATE_REDSTONE_ORE -> 8;
            case IRON_ORE, DEEPSLATE_IRON_ORE, COPPER_ORE, DEEPSLATE_COPPER_ORE,
                 COAL_ORE, DEEPSLATE_COAL_ORE, NETHER_QUARTZ_ORE, NETHER_GOLD_ORE -> 4;
            default -> 1;
        };
        if (isCrop(m)) {
            award(e.getPlayer().getUniqueId(), Path.CULTIVATOR, 3);
            chronicle("crops_harvested", 1);
        } else {
            award(e.getPlayer().getUniqueId(), Path.DELVER, xp);
            chronicle("blocks_mined", 1);
            // Deepslate is the marker for "deep", which is what chapter 3 asks for.
            if (m.name().startsWith("DEEPSLATE") || m == Material.ANCIENT_DEBRIS) {
                chronicle("deep_mined", 1);
            }
        }
    }

    private boolean isCrop(Material m) {
        return switch (m) {
            case WHEAT, CARROTS, POTATOES, BEETROOTS, NETHER_WART, SUGAR_CANE, MELON, PUMPKIN,
                 COCOA, SWEET_BERRY_BUSH, BAMBOO -> true;
            default -> false;
        };
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        award(e.getPlayer().getUniqueId(), Path.ARTIFICER, 1);
        chronicle("items_crafted", 1);
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onMobDeath(EntityDeathEvent e) {
        if (e.getEntity() instanceof Player) return;   // player kills are the PvP ladder, not this one
        Player killer = e.getEntity().getKiller();
        if (killer == null) return;
        long xp = switch (e.getEntityType()) {
            case ENDER_DRAGON -> 2000;
            case WITHER -> 1000;
            case WARDEN -> 800;
            case ELDER_GUARDIAN -> 200;
            case RAVAGER, EVOKER -> 60;
            case BLAZE, WITHER_SKELETON, GUARDIAN, PIGLIN_BRUTE -> 15;
            case ZOMBIE, SKELETON, SPIDER, CREEPER -> 4;
            default -> 2;
        };
        award(killer.getUniqueId(), Path.HUNTER, xp);
        chronicle("mobs_killed", 1);
        // "Elite" is defined by the XP weight rather than a second list, so the two cannot drift.
        if (xp >= 15) chronicle("elite_kills", 1);
    }

    /** Called by ShopService and Market so market activity has a ladder too. */
    void awardBroker(UUID id, long berriesMoved) {
        // Scaled down hard: a 1,000-Berry trade is 1 XP, so Broker rewards sustained trading rather
        // than one large transaction, and cannot be farmed by moving Berries back and forth - the
        // shop's 12% spread makes that lose money faster than it earns XP.
        award(id, Path.BROKER, Math.max(1, berriesMoved / 1000));
        chronicle("berries_traded", berriesMoved);
        chronicle("orders_filled", 1);
    }

    private void sampleMovement() {
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            org.bukkit.Location now = p.getLocation();
            org.bukkit.Location before = lastSample.put(p.getUniqueId(), now.clone());
            if (before == null || !before.getWorld().equals(now.getWorld())) continue;
            double d = before.distance(now);
            // Ignore teleports: a 500-block jump in 5 seconds was not travelled. Without this, /rtp
            // would be the fastest Wayfinder XP on the server.
            if (d < 2 || d > 200) continue;
            award(p.getUniqueId(), Path.WAYFINDER, (long) Math.max(1, d / 10));
            chronicle("distance_travelled", (long) d);
        }
    }

    // ---- flushing and levelling ----------------------------------------------

    private void flush() {
        if (pending.isEmpty()) return;
        Map<UUID, Map<Path, Long>> batch = new ConcurrentHashMap<>(pending);
        pending.clear();
        for (Map.Entry<UUID, Map<Path, Long>> e : batch.entrySet()) {
            for (Map.Entry<Path, Long> pe : e.getValue().entrySet()) {
                try {
                    Database.PathResult r = db.addPathXp(e.getKey(), pe.getKey(), pe.getValue());
                    if (r.levelledUp()) {
                        celebrate(e.getKey(), pe.getKey(), r.newLevel());
                    }
                } catch (SQLException ex) {
                    plugin.getLogger().log(Level.WARNING, "path xp flush failed: "
                        + ex.getMessage());
                }
            }
        }
    }

    /**
     * Announces a level and grants any title it earns.
     *
     * A level-up is the payoff for everything above it, so it is deliberately loud - a title, a sound,
     * and a server announcement at the milestone levels. A progression system whose rewards arrive
     * silently is a progression system nobody notices they are on.
     */
    private void celebrate(UUID id, Path path, int level) {
        String title = path.titleAt(level);
        if (title != null) {
            try {
                db.grantTitle(id, "path." + path.key() + "." + level, title,
                    Path.colourAt(level), "path");
            } catch (SQLException e) {
                plugin.getLogger().warning("could not grant title: " + e.getMessage());
            }
        }
        plugin.getServer().getScheduler().runTask(plugin, () -> {
            Player p = plugin.getServer().getPlayer(id);
            if (p == null) return;
            p.showTitle(Title.title(
                Component.text(path.display() + " " + level,
                    TextColor.fromHexString(Path.colourAt(level))),
                Component.text(title != null ? "New title: " + title : "Path level up",
                    NamedTextColor.GRAY),
                Title.Times.times(Duration.ofMillis(300), Duration.ofSeconds(2),
                    Duration.ofMillis(600))));
            p.playSound(p.getLocation(), org.bukkit.Sound.UI_TOAST_CHALLENGE_COMPLETE, 0.7f, 1.0f);
            if (title != null) {
                plugin.getServer().broadcast(Component.text(p.getName() + " is now ",
                        NamedTextColor.GRAY)
                    .append(Component.text(title, TextColor.fromHexString(Path.colourAt(level)))
                        .decoration(TextDecoration.BOLD, true))
                    .append(Component.text(".", NamedTextColor.GRAY)));
            }
        });
    }

    /** Flushes everything immediately. Called on disable so a restart does not drop pending XP. */
    void flushNow() {
        flush();
    }

    // ---- commands ------------------------------------------------------------

    boolean handle(CommandSender sender, String cmd, String[] args) {
        if (!(sender instanceof Player p)) return false;
        switch (cmd) {
            case "path", "paths": return paths(p, args);
            case "house": return house(p, args);
            case "title", "titles": return titles(p, args);
            case "me": return emote(p, args);
            case "local": return local(p, args);
            case "hc": return houseChat(p, args);
            default: return false;
        }
    }

    private boolean paths(Player p, String[] args) {
        if (args.length >= 2 && args[0].equalsIgnoreCase("focus")) {
            Path chosen = Path.fromKey(args[1]);
            if (chosen == null) {
                p.sendMessage(Component.text("No such Path. One of: delver, cultivator, hunter, "
                    + "wayfinder, artificer, broker.", NamedTextColor.RED));
                return true;
            }
            plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
                try {
                    db.setActivePath(p.getUniqueId(), chosen);
                    plugin.getServer().getScheduler().runTask(plugin, () -> p.sendMessage(
                        Component.text("Your HUD now shows the " + chosen.display() + " Path.",
                            NamedTextColor.GREEN)));
                } catch (SQLException e) {
                    plugin.getLogger().warning("set path failed: " + e.getMessage());
                }
            });
            return true;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                Map<Path, long[]> all = db.allPaths(p.getUniqueId());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Your Paths", NamedTextColor.GOLD));
                    for (Path path : Path.values()) {
                        long[] v = all.getOrDefault(path, new long[] { 0, 0 });
                        long xp = v[0];
                        int level = (int) v[1];
                        p.sendMessage(Component.text("  " + path.display(),
                                TextColor.fromHexString(Path.colourAt(level)))
                            .append(Component.text("  " + level + "  " + Path.bar(xp)
                                + "  " + xp + " xp", NamedTextColor.GRAY)));
                    }
                    p.sendMessage(Component.text("  /path focus <name> to show one on your HUD",
                        NamedTextColor.DARK_GRAY));
                    p.sendMessage(Component.text("  Paths grant titles and recognition only - "
                        + "never an advantage in a fight.", NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().warning("paths failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean house(Player p, String[] args) {
        if (args.length >= 2 && args[0].equalsIgnoreCase("join")) {
            final String h = args[1].toLowerCase();
            if (!h.equals("ember") && !h.equals("tide") && !h.equals("verdant")
                    && !h.equals("ashen")) {
                p.sendMessage(Component.text("Houses: ember, tide, verdant, ashen.",
                    NamedTextColor.RED));
                return true;
            }
            plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
                try {
                    String result = db.joinHouse(p.getUniqueId(), h);
                    plugin.getServer().getScheduler().runTask(plugin, () -> {
                        p.sendMessage(Component.text(result, NamedTextColor.GREEN));
                        plugin.getServer().broadcast(Component.text(p.getName()
                            + " has joined House " + h.substring(0, 1).toUpperCase()
                            + h.substring(1) + ".", NamedTextColor.GRAY));
                    });
                } catch (SQLException e) {
                    plugin.getLogger().warning("join house failed: " + e.getMessage());
                }
            });
            return true;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                java.util.List<String> standing = db.houseStanding();
                String mine = db.myHouse(p.getUniqueId());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Houses", NamedTextColor.GOLD));
                    p.sendMessage(Component.text("  Yours: "
                        + (mine == null ? "none - /house join <name>" : mine),
                        NamedTextColor.WHITE));
                    for (String s : standing) {
                        p.sendMessage(Component.text("  " + s, NamedTextColor.GRAY));
                    }
                    p.sendMessage(Component.text("  Standing comes from everything members do, "
                        + "not only fighting - a House of farmers can win.",
                        NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().warning("house failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean titles(Player p, String[] args) {
        if (args.length >= 2 && args[0].equalsIgnoreCase("wear")) {
            final String key = args[1];
            plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
                try {
                    boolean ok = db.wearTitle(p.getUniqueId(), key);
                    plugin.getServer().getScheduler().runTask(plugin, () -> p.sendMessage(ok
                        ? Component.text("Title changed.", NamedTextColor.GREEN)
                        : Component.text("You have not earned that title.",
                            NamedTextColor.RED)));
                } catch (SQLException e) {
                    plugin.getLogger().warning("wear title failed: " + e.getMessage());
                }
            });
            return true;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                java.util.List<String> owned = db.ownedTitles(p.getUniqueId());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Your titles (" + owned.size() + ")",
                        NamedTextColor.GOLD));
                    if (owned.isEmpty()) {
                        p.sendMessage(Component.text("  none yet - level a Path to earn one",
                            NamedTextColor.GRAY));
                    }
                    for (String s : owned) {
                        p.sendMessage(Component.text("  " + s, NamedTextColor.GRAY));
                    }
                    p.sendMessage(Component.text("  /title wear <key>", NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().warning("titles failed: " + e.getMessage());
            }
        });
        return true;
    }

    // ---- in-character chat ---------------------------------------------------
    //
    // SOFT RP, NOT HARD RP (D-0038). Breaking character is not punishable. Hard-RP enforcement needs
    // constant staff attention this server does not have, and it turns moderation into taste policing -
    // which is the fastest way to make a small server feel hostile. These are tools for people who WANT
    // to roleplay, not rules imposed on people who do not.

    /** `/me <action>` - the oldest roleplay verb there is. */
    boolean emote(Player p, String[] args) {
        if (args.length == 0) {
            p.sendMessage(Component.text("Usage: /me <what you are doing>", NamedTextColor.GRAY));
            return true;
        }
        String action = String.join(" ", args);
        if (action.length() > 160) action = action.substring(0, 160);
        // Radius-limited, like local chat: an emote broadcast server-wide is indistinguishable from
        // chat and stops meaning anything.
        Component msg = Component.text("* " + p.getName() + " " + action, NamedTextColor.LIGHT_PURPLE)
            .decoration(TextDecoration.ITALIC, true);
        int heard = 0;
        for (Player other : plugin.getServer().getOnlinePlayers()) {
            if (other.getWorld().equals(p.getWorld())
                    && other.getLocation().distance(p.getLocation()) <= LOCAL_RADIUS) {
                other.sendMessage(msg);
                heard++;
            }
        }
        if (heard == 1) {
            p.sendMessage(Component.text("  (nobody nearby heard that)", NamedTextColor.DARK_GRAY));
        }
        return true;
    }

    /** How far local chat and emotes carry. 100 blocks is roughly a shout across a build. */
    private static final int LOCAL_RADIUS = 100;

    /** `/local <message>` - speak to people who can actually see you. */
    boolean local(Player p, String[] args) {
        if (args.length == 0) {
            p.sendMessage(Component.text("Usage: /local <message>", NamedTextColor.GRAY));
            return true;
        }
        String said = String.join(" ", args);
        if (said.length() > 200) said = said.substring(0, 200);
        Component msg = Component.text("[local] ", NamedTextColor.DARK_AQUA)
            .append(Component.text(p.getName() + ": ", NamedTextColor.WHITE))
            .append(Component.text(said, NamedTextColor.GRAY));
        int heard = 0;
        for (Player other : plugin.getServer().getOnlinePlayers()) {
            if (other.getWorld().equals(p.getWorld())
                    && other.getLocation().distance(p.getLocation()) <= LOCAL_RADIUS) {
                other.sendMessage(msg);
                heard++;
            }
        }
        if (heard == 1) {
            p.sendMessage(Component.text("  (nobody within " + LOCAL_RADIUS + " blocks)",
                NamedTextColor.DARK_GRAY));
        }
        return true;
    }

    /** `/hc <message>` - the House channel, reaching members wherever they are. */
    boolean houseChat(Player p, String[] args) {
        if (args.length == 0) {
            p.sendMessage(Component.text("Usage: /hc <message>", NamedTextColor.GRAY));
            return true;
        }
        final String said = args.length > 0
            ? (String.join(" ", args).length() > 200
                ? String.join(" ", args).substring(0, 200) : String.join(" ", args))
            : "";
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                String house = db.houseKeyOf(p.getUniqueId());
                if (house == null) {
                    plugin.getServer().getScheduler().runTask(plugin, () -> p.sendMessage(
                        Component.text("You are not in a House. /house join <name>",
                            NamedTextColor.RED)));
                    return;
                }
                java.util.List<UUID> members = db.houseMemberIds(house);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    Component msg = Component.text("[" + house + "] ", NamedTextColor.GOLD)
                        .append(Component.text(p.getName() + ": ", NamedTextColor.WHITE))
                        .append(Component.text(said, NamedTextColor.GRAY));
                    for (UUID id : members) {
                        Player m = plugin.getServer().getPlayer(id);
                        if (m != null) m.sendMessage(msg);
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().warning("house chat failed: " + e.getMessage());
            }
        });
        return true;
    }}
