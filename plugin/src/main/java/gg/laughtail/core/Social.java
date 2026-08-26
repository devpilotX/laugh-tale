package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.OfflinePlayer;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

import java.sql.SQLException;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;

/**
 * Friends and leaderboards. Two of the features from D-0035's list.
 *
 * FRIENDSHIP IS SYMMETRIC AND STORED ONCE. The friends table keys on (uuid_low, uuid_high) - the two
 * UUIDs sorted - rather than on (owner, friend). Storing it twice, once per direction, means the two
 * rows can disagree: A thinks they are friends, B does not, and every query has to pick a side. One
 * row cannot disagree with itself.
 *
 * IT REQUIRES CONSENT. A request sits in `pending` until the other player accepts. A one-sided friend
 * list is a following list, and a following list is a harassment vector - somebody can attach
 * themselves to a player who wants nothing to do with them and, if friends ever gate teleports or
 * visibility, follow them around.
 *
 * FRIENDSHIP DELIBERATELY GRANTS NOTHING YET. No teleport bypass, no shared homes, no claim trust.
 * Law 1 says every player is equal, and a friends list that unlocks capability is a quiet way to make
 * a well-connected player stronger than a lone one. It is a convenience - see who is online - and any
 * future power granted through it needs its own decision.
 *
 * LEADERBOARDS SHOW RATING, KILLS, KILLSTREAK AND PLAYTIME, and deliberately NOT Berries. A richest
 * list turns the economy into a scoreboard and rewards hoarding over playing; worse, it tells every
 * thief who to target. Rank is the competitive axis on this server, so rank is what is ranked.
 */
final class Social {

    private final LaughTailPlugin plugin;
    private final Database db;

    Social(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    boolean handle(CommandSender sender, String cmd, String[] args) {
        switch (cmd) {
            case "friend", "friends": return friends(sender, args);
            case "baltop": return false;   // owned by Economy
            case "top", "leaderboard": return leaderboard(sender, args);
            default: return false;
        }
    }

    // ---- friends -------------------------------------------------------------

    private boolean friends(CommandSender sender, String[] args) {
        if (!(sender instanceof Player p)) {
            sender.sendMessage("Friends are per-player; run this in game.");
            return true;
        }
        String sub = args.length > 0 ? args[0].toLowerCase() : "list";
        switch (sub) {
            case "add" -> {
                if (args.length < 2) {
                    p.sendMessage(Component.text("Usage: /friend add <player>",
                        NamedTextColor.GRAY));
                    return true;
                }
                request(p, args[1]);
            }
            case "accept" -> {
                if (args.length < 2) {
                    p.sendMessage(Component.text("Usage: /friend accept <player>",
                        NamedTextColor.GRAY));
                    return true;
                }
                accept(p, args[1]);
            }
            case "remove", "deny" -> {
                if (args.length < 2) {
                    p.sendMessage(Component.text("Usage: /friend remove <player>",
                        NamedTextColor.GRAY));
                    return true;
                }
                remove(p, args[1]);
            }
            case "requests" -> listRequests(p);
            default -> listFriends(p);
        }
        return true;
    }

    /** Resolves a name to a UUID without a blocking web lookup. */
    private UUID resolve(String name) {
        Player online = plugin.getServer().getPlayerExact(name);
        if (online != null) return online.getUniqueId();
        // Offline players are only resolvable if they have joined before, which is correct here:
        // a friend request to somebody who has never played is a typo, and Mojang's API is a
        // blocking network call that has no business inside a command.
        OfflinePlayer off = plugin.getServer().getOfflinePlayerIfCached(name);
        return off == null ? null : off.getUniqueId();
    }

    private void request(Player p, String name) {
        UUID target = resolve(name);
        if (target == null) {
            p.sendMessage(Component.text("No player called " + name + " has played here.",
                NamedTextColor.RED));
            return;
        }
        if (target.equals(p.getUniqueId())) {
            p.sendMessage(Component.text("You cannot befriend yourself.", NamedTextColor.GRAY));
            return;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                Database.FriendResult r = db.friendRequest(p.getUniqueId(), target);
                reply(p, switch (r) {
                    case ALREADY_FRIENDS -> Component.text("You are already friends with " + name
                        + ".", NamedTextColor.GRAY);
                    case ALREADY_PENDING -> Component.text("You have already asked " + name
                        + ". They need to accept.", NamedTextColor.GRAY);
                    case ACCEPTED_EXISTING -> Component.text("You and " + name
                        + " are now friends - they had already asked you.", NamedTextColor.GREEN);
                    case CREATED -> Component.text("Friend request sent to " + name + ".",
                        NamedTextColor.GREEN);
                });
                Player t = plugin.getServer().getPlayer(target);
                if (t != null && r == Database.FriendResult.CREATED) {
                    final Player tt = t;
                    plugin.getServer().getScheduler().runTask(plugin, () -> tt.sendMessage(
                        Component.text(p.getName() + " wants to be your friend. ",
                            NamedTextColor.AQUA)
                        .append(Component.text("/friend accept " + p.getName(),
                            NamedTextColor.WHITE))));
                }
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "friend request failed: " + e.getMessage());
                reply(p, Component.text("That did not work. Try again.", NamedTextColor.RED));
            }
        });
    }

    private void accept(Player p, String name) {
        UUID target = resolve(name);
        if (target == null) {
            p.sendMessage(Component.text("No player called " + name + " has played here.",
                NamedTextColor.RED));
            return;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                boolean ok = db.friendAccept(p.getUniqueId(), target);
                reply(p, ok
                    ? Component.text("You and " + name + " are now friends.",
                        NamedTextColor.GREEN)
                    : Component.text(name + " has not asked to be your friend. You cannot "
                        + "accept a request that does not exist.", NamedTextColor.GRAY));
                if (ok) {
                    Player t = plugin.getServer().getPlayer(target);
                    if (t != null) {
                        final Player tt = t;
                        plugin.getServer().getScheduler().runTask(plugin, () -> tt.sendMessage(
                            Component.text(p.getName() + " accepted your friend request.",
                                NamedTextColor.GREEN)));
                    }
                }
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "friend accept failed: " + e.getMessage());
                reply(p, Component.text("That did not work. Try again.", NamedTextColor.RED));
            }
        });
    }

    private void remove(Player p, String name) {
        UUID target = resolve(name);
        if (target == null) {
            p.sendMessage(Component.text("No player called " + name + " has played here.",
                NamedTextColor.RED));
            return;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                boolean removed = db.friendRemove(p.getUniqueId(), target);
                // Removing works on a pending request too, so a request can be withdrawn and an
                // unwanted one refused with the same command. Two commands for one intent is worse.
                reply(p, removed
                    ? Component.text("Removed " + name + ".", NamedTextColor.GREEN)
                    : Component.text("You have no friendship or request with " + name + ".",
                        NamedTextColor.GRAY));
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "friend remove failed: " + e.getMessage());
                reply(p, Component.text("That did not work. Try again.", NamedTextColor.RED));
            }
        });
    }

    private void listFriends(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<UUID> ids = db.friendList(p.getUniqueId(), "accepted");
                int pending = db.friendList(p.getUniqueId(), "pending").size();
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Friends (" + ids.size() + ")",
                        NamedTextColor.GOLD));
                    if (ids.isEmpty()) {
                        p.sendMessage(Component.text("  nobody yet - /friend add <player>",
                            NamedTextColor.GRAY));
                    }
                    for (UUID id : ids) {
                        Player online = plugin.getServer().getPlayer(id);
                        String n = online != null ? online.getName()
                            : plugin.getServer().getOfflinePlayer(id).getName();
                        p.sendMessage(Component.text("  " + (n == null ? id.toString() : n),
                            online != null ? NamedTextColor.GREEN : NamedTextColor.DARK_GRAY)
                            .append(Component.text(online != null ? "  online" : "  offline",
                                NamedTextColor.DARK_GRAY)));
                    }
                    if (pending > 0) {
                        p.sendMessage(Component.text("  " + pending
                            + " pending - /friend requests", NamedTextColor.AQUA));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "friend list failed: " + e.getMessage());
            }
        });
    }

    private void listRequests(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<UUID> ids = db.friendIncoming(p.getUniqueId());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Friend requests waiting for you ("
                        + ids.size() + ")", NamedTextColor.GOLD));
                    if (ids.isEmpty()) {
                        p.sendMessage(Component.text("  none", NamedTextColor.GRAY));
                    }
                    for (UUID id : ids) {
                        String n = plugin.getServer().getOfflinePlayer(id).getName();
                        p.sendMessage(Component.text("  " + (n == null ? id.toString() : n)
                            + "  ", NamedTextColor.WHITE)
                            .append(Component.text("/friend accept " + n, NamedTextColor.AQUA)));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "friend requests failed: " + e.getMessage());
            }
        });
    }

    // ---- leaderboards --------------------------------------------------------

    private boolean leaderboard(CommandSender sender, String[] args) {
        String kind = args.length > 0 ? args[0].toLowerCase() : "rank";
        final String metric = switch (kind) {
            case "kills" -> "kills";
            case "streak" -> "killstreak_best";
            case "playtime" -> "playtime_seconds";
            default -> "rank";
        };
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<String> rows = metric.equals("rank")
                    ? db.topByRating(10)
                    : db.topByStat(metric, 10);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text("Top 10 - " + label(metric),
                        NamedTextColor.GOLD));
                    if (rows.isEmpty()) {
                        sender.sendMessage(Component.text("  nothing recorded yet",
                            NamedTextColor.GRAY));
                    }
                    int i = 1;
                    for (String r : rows) {
                        sender.sendMessage(Component.text(String.format("  %2d. ", i++)
                            + r, NamedTextColor.WHITE));
                    }
                    sender.sendMessage(Component.text(
                        "  /top rank | kills | streak | playtime", NamedTextColor.DARK_GRAY));
                    // Stated on the leaderboard itself, not only in the documentation, because the
                    // absence is a deliberate design choice and players will ask.
                    sender.sendMessage(Component.text(
                        "  There is no richest list - it would reward hoarding and tell thieves "
                      + "who to target.", NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "leaderboard failed: " + e.getMessage());
            }
        });
        return true;
    }

    private String label(String metric) {
        return switch (metric) {
            case "kills" -> "kills";
            case "killstreak_best" -> "best killstreak";
            case "playtime_seconds" -> "playtime";
            default -> "rank (this season)";
        };
    }

    private void reply(Player p, Component c) {
        plugin.getServer().getScheduler().runTask(plugin, () -> {
            if (p.isOnline()) p.sendMessage(c);
        });
    }
}
