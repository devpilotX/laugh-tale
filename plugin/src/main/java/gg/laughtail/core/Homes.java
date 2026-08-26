package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;

/**
 * Homes, per Section 15: up to 20, renameable, home-to-home, with slots bought using Berries.
 *
 * FREE SLOTS = 2. Section 15 caps homes at 20 and says slots are bought, but never states how
 * many come free. Two is a decision under D-0031: one is not enough to be useful (a base and
 * nowhere else), and more than two removes the reason to ever buy one.
 *
 * THE PRICE CURVE ESCALATES, and that is the point. Every slot costs
 * 2 hours of play more than the last, priced against P2's 1,200 Berries per hour. So the first
 * bought slot is 2,400 and the eighteenth is 43,200. A flat price would make the twentieth home
 * as cheap as the third, and a player with a large balance would buy all of them in one go -
 * which turns a progression into a formality.
 *
 * THE RESOURCE WORLD IS EXCLUDED. 7.4 is explicit that nothing is claimable there and it resets
 * monthly. A home there would be silently destroyed every reset, and a player would rightly
 * call that a bug. Setting one is refused with the reason, rather than allowed and then broken.
 *
 * WARMUP AND CANCEL-ON-MOVE. 15.x wants teleport guards. The warmup exists so a player losing a
 * fight cannot escape instantly, and it is cancelled if they move - which means it costs nothing
 * to an honest player standing still and everything to someone running.
 *
 * WHAT IS DELIBERATELY MISSING: the combat tag. 15.x and row 33 want a teleport blocked while
 * tagged, and the tag itself is not built yet - its duration is not stated anywhere in the
 * specification. The hook is marked below so it is obvious where it goes rather than being
 * quietly forgotten.
 */
final class Homes {

    static final int FREE_SLOTS = 2;
    static final int MAX_HOMES = 20;
    /** P2: 1,200 Berries per hour. Each slot costs two more hours than the last. */
    static final long SLOT_HOURS_STEP = 2L;
    static final long BERRIES_PER_HOUR = 1200L;

    private static final long WARMUP_MILLIS = 3_000L;
    private static final long COOLDOWN_MILLIS = 15_000L;

    private final LaughTailPlugin plugin;
    private final Database db;
    private final Map<UUID, Long> lastTeleport = new ConcurrentHashMap<>();
    private final Map<UUID, Location> warmupFrom = new ConcurrentHashMap<>();

    Homes(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    /** Cost of the next purchased slot, given how many are already owned. */
    static long slotCost(int alreadyPurchased) {
        return (alreadyPurchased + 1) * SLOT_HOURS_STEP * BERRIES_PER_HOUR;
    }

    boolean handle(CommandSender sender, String cmd, String[] args) {
        if (!(sender instanceof Player p)) {
            if (cmd.equals("home") || cmd.equals("sethome") || cmd.equals("homes")
             || cmd.equals("delhome") || cmd.equals("buyhome")) {
                sender.sendMessage(Component.text("Only a player has homes.", NamedTextColor.RED));
                return true;
            }
            return false;
        }
        switch (cmd) {
            case "sethome": return setHome(p, args);
            case "home":    return goHome(p, args);
            case "homes":   return listHomes(p);
            case "delhome": return delHome(p, args);
            case "buyhome": return buySlot(p);
            default:        return false;
        }
    }

    private boolean setHome(Player p, String[] args) {
        final String name = (args.length > 0 ? args[0] : "home").toLowerCase();
        if (!name.matches("[a-z0-9_]{1,24}")) {
            p.sendMessage(Component.text(
                "Home names may use letters, numbers and underscores, up to 24 characters.",
                NamedTextColor.RED));
            return true;
        }
        final World w = p.getWorld();
        if (w.getName().contains("resource")) {
            p.sendMessage(Component.text(
                "You cannot set a home in the resource world - it is regenerated every month "
              + "and the home would be destroyed with it (7.4).", NamedTextColor.RED));
            return true;
        }
        if (w.getName().contains("arena")) {
            p.sendMessage(Component.text("The arena is for events only.", NamedTextColor.RED));
            return true;
        }
        final Location loc = p.getLocation();
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                int purchased = db.purchasedSlots(p.getUniqueId());
                int allowed = Math.min(MAX_HOMES, FREE_SLOTS + purchased);
                List<String> existing = db.homeNames(p.getUniqueId());
                boolean replacing = existing.stream().anyMatch(n -> n.equalsIgnoreCase(name));
                if (!replacing && existing.size() >= allowed) {
                    reply(p, Component.text("You have " + existing.size() + " of " + allowed
                        + " homes. Buy another slot with /buyhome ("
                        + slotCost(purchased) + " Berries).", NamedTextColor.YELLOW));
                    return;
                }
                db.setHome(p.getUniqueId(), name, w.getName(), loc.getX(), loc.getY(),
                    loc.getZ(), loc.getYaw(), loc.getPitch());
                reply(p, Component.text((replacing ? "Moved home '" : "Set home '") + name
                    + "' here. " + (replacing ? existing.size() : existing.size() + 1)
                    + " of " + allowed + " used.", NamedTextColor.GREEN));
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "sethome failed: " + e.getMessage());
                reply(p, Component.text("The home was NOT saved.", NamedTextColor.RED));
            }
        });
        return true;
    }

    private boolean goHome(Player p, String[] args) {
        final String name = (args.length > 0 ? args[0] : "home").toLowerCase();

        long since = System.currentTimeMillis()
            - lastTeleport.getOrDefault(p.getUniqueId(), 0L);
        if (since < COOLDOWN_MILLIS) {
            p.sendMessage(Component.text("Wait " + ((COOLDOWN_MILLIS - since) / 1000 + 1)
                + "s before teleporting again.", NamedTextColor.YELLOW));
            return true;
        }

        // COMBAT TAG HOOK. Row 33 and 15.x want this blocked while tagged. The tag is not built
        // - its duration is stated nowhere in the specification - so this is the one place it
        // must be added, marked rather than forgotten.
        // if (combatTag.isTagged(p)) { refuse; return true; }

        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                Database.HomeRow h = db.getHome(p.getUniqueId(), name);
                if (h == null) {
                    List<String> names = db.homeNames(p.getUniqueId());
                    reply(p, Component.text(names.isEmpty()
                        ? "You have no homes. Use /sethome."
                        : "No home called '" + name + "'. You have: " + String.join(", ", names),
                        NamedTextColor.RED));
                    return;
                }
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    World w = plugin.getServer().getWorld(h.world());
                    if (w == null) {
                        // A home in a world that no longer exists. The resource world is
                        // refused at set time, so this means a world was removed - say so
                        // rather than throwing.
                        p.sendMessage(Component.text("The world '" + h.world()
                            + "' no longer exists, so that home cannot be reached.",
                            NamedTextColor.RED));
                        return;
                    }
                    final Location target = new Location(w, h.x(), h.y(), h.z(), h.yaw(), h.pitch());
                    warmupFrom.put(p.getUniqueId(), p.getLocation());
                    p.sendMessage(Component.text("Teleporting in "
                        + (WARMUP_MILLIS / 1000) + "s - do not move.", NamedTextColor.GRAY));
                    plugin.getServer().getScheduler().runTaskLater(plugin, () -> {
                        Location from = warmupFrom.remove(p.getUniqueId());
                        if (!p.isOnline()) return;
                        if (from != null && from.distanceSquared(p.getLocation()) > 1.0) {
                            p.sendMessage(Component.text("Teleport cancelled - you moved.",
                                NamedTextColor.RED));
                            return;
                        }
                        lastTeleport.put(p.getUniqueId(), System.currentTimeMillis());
                        p.teleportAsync(target).thenAccept(ok -> {
                            if (ok) p.sendMessage(Component.text("Welcome home.",
                                NamedTextColor.GREEN));
                        });
                    }, WARMUP_MILLIS / 50);
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "home failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean listHomes(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<String> names = db.homeNames(p.getUniqueId());
                int purchased = db.purchasedSlots(p.getUniqueId());
                int allowed = Math.min(MAX_HOMES, FREE_SLOTS + purchased);
                reply(p, Component.text("Homes " + names.size() + "/" + allowed
                    + (names.isEmpty() ? "" : ": " + String.join(", ", names)),
                    NamedTextColor.GOLD));
                if (allowed < MAX_HOMES) {
                    reply(p, Component.text("Next slot: " + slotCost(purchased)
                        + " Berries (/buyhome)", NamedTextColor.GRAY));
                }
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "homes failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean delHome(Player p, String[] args) {
        if (args.length < 1) {
            p.sendMessage(Component.text("Usage: /delhome <name>", NamedTextColor.GRAY));
            return true;
        }
        final String name = args[0].toLowerCase();
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                boolean gone = db.deleteHome(p.getUniqueId(), name);
                reply(p, Component.text(gone
                    ? ("Home '" + name + "' deleted. The slot stays yours.")
                    : ("No home called '" + name + "'."),
                    gone ? NamedTextColor.GREEN : NamedTextColor.RED));
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "delhome failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean buySlot(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                int purchased = db.purchasedSlots(p.getUniqueId());
                int allowed = Math.min(MAX_HOMES, FREE_SLOTS + purchased);
                if (allowed >= MAX_HOMES) {
                    reply(p, Component.text("You already have the maximum of " + MAX_HOMES
                        + " home slots.", NamedTextColor.YELLOW));
                    return;
                }
                long cost = slotCost(purchased);
                // The purchase and the slot are one transaction. A charge without a slot is
                // theft; a slot without a charge is free money.
                String result = db.buyHomeSlot(p.getUniqueId(), cost);
                if (result == null) {
                    reply(p, Component.text("Home slot bought for " + cost
                        + " Berries. You now have " + (allowed + 1) + " slots.",
                        NamedTextColor.GREEN));
                } else {
                    reply(p, Component.text(result, NamedTextColor.RED));
                }
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "buyhome failed: " + e.getMessage());
                reply(p, Component.text("Nothing was charged and no slot was added.",
                    NamedTextColor.RED));
            }
        });
        return true;
    }

    private void reply(Player p, Component msg) {
        plugin.getServer().getScheduler().runTask(plugin, () -> {
            if (p.isOnline()) p.sendMessage(msg);
        });
    }
}
