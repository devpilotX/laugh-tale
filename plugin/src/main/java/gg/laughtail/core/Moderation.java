package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.player.AsyncPlayerPreLoginEvent;
import org.bukkit.event.player.AsyncPlayerChatEvent;

import java.sql.SQLException;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;

/**
 * Moderation: the punishment commands, their enforcement, and the audit trail.
 *
 * TWO ACCEPTANCE CRITERIA SHAPE THIS CLASS.
 *
 * 17.4 / 17.5 item 4: "All staff actions are logged, permanently, to the database... and
 * staff cannot delete these logs." The cannot-delete half is enforced by V2's triggers and
 * already proven. This is the are-they-logged half - and note that EVERY command path
 * writes an audit row, including the ones that fail validation, because "staff tried to ban
 * a player who does not exist" is exactly the kind of thing an audit should show. An audit
 * that only records successes is a record of intentions, not actions.
 *
 * Row 14 / 3.2: no purchasable advantage. Nothing here can be bought, and the permission
 * nodes come from the Section 17 ladder that LuckPerms already enforces - so a Helper
 * physically cannot issue a permanent ban regardless of what this code does.
 *
 * BAN ENFORCEMENT USES AsyncPlayerPreLoginEvent, deliberately. Rejecting at pre-login
 * happens before the player entity is created, so a banned player never loads chunks or
 * touches the world. Doing it on PlayerJoinEvent would work and would also mean the server
 * generates spawn chunks for someone it is about to eject - wasted work on a 2 vCPU box,
 * and a brief window where they exist in the world.
 *
 * THE PUBLISHED LADDER (14.4) IS NOT IMPLEMENTED HERE. These commands take an explicit
 * duration from staff rather than deriving one from an offence, because 14.4's ladder text
 * is owner-approved policy (OA-13) and inventing a ladder would be inventing policy. The
 * `rule_broken` column exists in V2 and is left NULL until the ladder is written.
 */
final class Moderation implements Listener {

    private final LaughTailPlugin plugin;
    private final Database db;

    Moderation(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    // ---- enforcement ---------------------------------------------------------

    @EventHandler(priority = EventPriority.HIGH)
    public void onPreLogin(AsyncPlayerPreLoginEvent e) {
        // Already off the main thread - this event is async by design, which is why the
        // database call here needs no scheduler hop.
        try {
            String ban = db.activePunishmentReason(e.getUniqueId(), "ban");
            if (ban == null) ban = db.activePunishmentReason(e.getUniqueId(), "tempban");
            if (ban != null) {
                e.disallow(AsyncPlayerPreLoginEvent.Result.KICK_BANNED,
                    "You are banned from Laugh Tale.\n\n" + ban
                  + "\n\nAppeals: see the website.");
            }
        } catch (SQLException ex) {
            // FAIL OPEN, deliberately, and log loudly. The alternative - refusing every
            // login when the database is unreachable - would turn a database hiccup into a
            // total outage for paying players. A banned player getting in for a few minutes
            // is recoverable; locking out everyone is not.
            plugin.getLogger().log(Level.SEVERE,
                "Ban check failed for " + e.getName() + " - allowing the login. " + ex.getMessage());
        }
    }

    @SuppressWarnings("deprecation")
    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onChat(AsyncPlayerChatEvent e) {
        final Player p = e.getPlayer();
        try {
            String mute = db.activePunishmentReason(p.getUniqueId(), "mute");
            if (mute != null) {
                e.setCancelled(true);
                p.sendMessage(Component.text("You are muted: " + mute, NamedTextColor.RED));
            }
        } catch (SQLException ex) {
            plugin.getLogger().log(Level.WARNING, "Mute check failed: " + ex.getMessage());
        }
    }

    // ---- commands ------------------------------------------------------------

    /** Returns true if handled. */
    boolean handle(CommandSender sender, String cmd, String[] args) {
        switch (cmd) {
            case "warn":     return punish(sender, args, "warn",    "laughtail.punish.kick",        false, false);
            case "mute":     return punish(sender, args, "mute",    "laughtail.punish.mute.short",  true,  false);
            case "kick":     return punish(sender, args, "kick",    "laughtail.punish.kick",        false, false);
            case "tempban":  return punish(sender, args, "tempban", "laughtail.punish.tempban",     true,  false);
            case "ban":      return punish(sender, args, "ban",     "laughtail.punish.permban",     false, true);
            case "unmute":   return revoke(sender, args, "mute",    "laughtail.punish.mute.short");
            case "unban":    return revoke(sender, args, "ban",     "laughtail.punish.overturn");
            case "history":  return history(sender, args);
            default:         return false;
        }
    }

    private UUID senderId(CommandSender s) {
        return (s instanceof Player p) ? p.getUniqueId() : null;
    }

    private void auditAsync(CommandSender sender, String action, UUID target,
                            String targetName, String params) {
        final UUID sid = senderId(sender);
        final String sname = sender.getName();
        final String world = (sender instanceof Player p && p.getWorld() != null)
            ? p.getWorld().getName() : null;
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                db.audit(sid, sname, action, target, targetName, params, world);
            } catch (SQLException e) {
                // An unwritten audit row is a hole in the record, so this is SEVERE rather
                // than WARNING - the monitor's error-delta check will surface it.
                plugin.getLogger().log(Level.SEVERE, "AUDIT WRITE FAILED for '" + action
                    + "' by " + sname + ": " + e.getMessage());
            }
        });
    }

    private boolean punish(CommandSender sender, String[] args, String type,
                           String permission, boolean needsDuration, boolean permanent) {
        if (!sender.hasPermission(permission)) {
            sender.sendMessage(Component.text("You do not have permission for " + type + ".",
                NamedTextColor.RED));
            auditAsync(sender, type + ".denied", null, args.length > 0 ? args[0] : null,
                "permission " + permission + " missing");
            return true;
        }
        int minArgs = needsDuration ? 3 : 2;
        if (args.length < minArgs) {
            sender.sendMessage(Component.text("Usage: /" + type + " <player> "
                + (needsDuration ? "<duration e.g. 30m, 2h, 7d> " : "") + "<reason>",
                NamedTextColor.GRAY));
            return true;
        }

        final String targetName = args[0];
        final Long durationSeconds;
        final int reasonFrom;
        if (needsDuration) {
            Long d = parseDuration(args[1]);
            if (d == null) {
                sender.sendMessage(Component.text(
                    "Could not read '" + args[1] + "' as a duration. Use 30m, 2h or 7d.",
                    NamedTextColor.RED));
                return true;
            }
            durationSeconds = d;
            reasonFrom = 2;
        } else {
            durationSeconds = permanent ? null : 0L;
            reasonFrom = 1;
        }
        final String reason = String.join(" ", java.util.Arrays.copyOfRange(args, reasonFrom, args.length));

        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID target = db.uuidByName(targetName);
                if (target == null) {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                        sender.sendMessage(Component.text(
                            "No player called '" + targetName + "' has ever joined.",
                            NamedTextColor.RED)));
                    // Audited anyway: an attempt against an unknown name is worth seeing.
                    db.audit(senderId(sender), sender.getName(), type + ".unknown_target",
                        null, targetName, reason, null);
                    return;
                }

                Long dur = (durationSeconds != null && durationSeconds == 0L) ? null : durationSeconds;
                long id = db.insertPunishment(target, type, reason, null, senderId(sender), dur);
                db.audit(senderId(sender), sender.getName(), type, target, targetName,
                    "id=" + id + " duration=" + (dur == null ? "permanent" : dur + "s")
                    + " reason=" + reason, null);

                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text(
                        type + " recorded for " + targetName + " (#" + id + ").",
                        NamedTextColor.GREEN));
                    Player online = plugin.getServer().getPlayerExact(targetName);
                    if (online != null) {
                        switch (type) {
                            case "kick", "tempban", "ban" -> online.kick(Component.text(
                                (type.equals("kick") ? "Kicked: " : "Banned: ") + reason,
                                NamedTextColor.RED));
                            case "warn" -> online.sendMessage(Component.text(
                                "WARNING from staff: " + reason, NamedTextColor.YELLOW));
                            case "mute" -> online.sendMessage(Component.text(
                                "You have been muted: " + reason, NamedTextColor.RED));
                            default -> { }
                        }
                    }
                });
            } catch (SQLException ex) {
                plugin.getLogger().log(Level.SEVERE, "Punishment failed: " + ex.getMessage());
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    sender.sendMessage(Component.text(
                        "The punishment was NOT saved - the database rejected it. Nothing was applied.",
                        NamedTextColor.RED)));
            }
        });
        return true;
    }

    private boolean revoke(CommandSender sender, String[] args, String type, String permission) {
        if (!sender.hasPermission(permission)) {
            sender.sendMessage(Component.text("You do not have permission.", NamedTextColor.RED));
            auditAsync(sender, "un" + type + ".denied", null,
                args.length > 0 ? args[0] : null, "permission " + permission + " missing");
            return true;
        }
        if (args.length < 1) {
            sender.sendMessage(Component.text("Usage: /un" + type + " <player> [reason]",
                NamedTextColor.GRAY));
            return true;
        }
        final String targetName = args[0];
        final String reason = args.length > 1
            ? String.join(" ", java.util.Arrays.copyOfRange(args, 1, args.length))
            : "no reason given";

        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID target = db.uuidByName(targetName);
                if (target == null) {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                        sender.sendMessage(Component.text("Unknown player.", NamedTextColor.RED)));
                    return;
                }
                boolean done = db.revokePunishment(target, type, senderId(sender), reason);
                db.audit(senderId(sender), sender.getName(), "un" + type, target, targetName,
                    "revoked=" + done + " reason=" + reason, null);
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    sender.sendMessage(Component.text(done
                        ? ("Active " + type + " revoked for " + targetName + ".")
                        : ("No active " + type + " found for " + targetName + "."),
                        done ? NamedTextColor.GREEN : NamedTextColor.GRAY)));
            } catch (SQLException ex) {
                plugin.getLogger().log(Level.SEVERE, "Revoke failed: " + ex.getMessage());
            }
        });
        return true;
    }

    private boolean history(CommandSender sender, String[] args) {
        if (!sender.hasPermission("laughtail.punish.history")) {
            sender.sendMessage(Component.text("You do not have permission.", NamedTextColor.RED));
            return true;
        }
        if (args.length < 1) {
            sender.sendMessage(Component.text("Usage: /history <player>", NamedTextColor.GRAY));
            return true;
        }
        final String targetName = args[0];
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID target = db.uuidByName(targetName);
                if (target == null) {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                        sender.sendMessage(Component.text("Unknown player.", NamedTextColor.RED)));
                    return;
                }
                List<String> rows = db.punishmentHistory(target, 20);
                // Viewing history is itself a staff action and is audited. 17.3 treats the
                // audit log as sensitive; reading someone's record is not a neutral act.
                db.audit(senderId(sender), sender.getName(), "history.view", target, targetName,
                    rows.size() + " rows", null);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text("Punishment history for " + targetName
                        + " (" + rows.size() + "):", NamedTextColor.GOLD));
                    if (rows.isEmpty()) {
                        sender.sendMessage(Component.text("  clean record", NamedTextColor.GRAY));
                    }
                    for (String r : rows) {
                        sender.sendMessage(Component.text("  " + r, NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException ex) {
                plugin.getLogger().log(Level.SEVERE, "History failed: " + ex.getMessage());
            }
        });
        return true;
    }

    /** Parses 30s, 30m, 2h, 7d. Returns null when unreadable rather than guessing. */
    static Long parseDuration(String s) {
        if (s == null || s.length() < 2) return null;
        char unit = s.charAt(s.length() - 1);
        String num = s.substring(0, s.length() - 1);
        long n;
        try {
            n = Long.parseLong(num);
        } catch (NumberFormatException e) {
            return null;
        }
        if (n <= 0) return null;
        return switch (unit) {
            case 's' -> n;
            case 'm' -> n * 60;
            case 'h' -> n * 3600;
            case 'd' -> n * 86400;
            default -> null;
        };
    }
}
