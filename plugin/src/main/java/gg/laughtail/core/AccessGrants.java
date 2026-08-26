package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.command.CommandSender;
import org.bukkit.profile.PlayerProfile;

import java.sql.SQLException;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;

/**
 * The paywall, under the manual model of D-0032.
 *
 * The owner takes payment out of band and runs one command. That command does BOTH halves -
 * writes the `access_grants` row and adds the whitelist entry - in that order.
 *
 * THE ORDER IS THE POINT. Acceptance row 12 requires "the whitelist matches paid
 * transactions exactly, with zero unexplained entries". Adding to the whitelist by hand in
 * the Panel would satisfy the player and leave no record, and the row would fail an audit
 * six months later with nobody able to reconstruct why an account was there. Writing the
 * grant FIRST means a whitelisted player without a grant row cannot be produced by this
 * command at all: if the database write fails, the whitelist is never touched.
 *
 * The reverse failure - a grant row written and the whitelist add failing - is recoverable
 * and visible, because /access audit finds it and reports it. That asymmetry is deliberate:
 * of the two ways to be inconsistent, only one is detectable, so the code is arranged to
 * fail into the detectable one.
 *
 * UUID RESOLUTION goes through Mojang for players who have never joined, because a manual
 * grant usually happens BEFORE the player's first login - that is the whole point of a
 * whitelist. An offline-mode UUID would be useless under online-mode=true (D-0017), so the
 * lookup must be authoritative rather than computed.
 */
final class AccessGrants {

    private final LaughTailPlugin plugin;
    private final Database db;

    AccessGrants(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    boolean handle(CommandSender sender, String[] args) {
        if (!sender.hasPermission("laughtail.whitelist.add")) {
            sender.sendMessage(Component.text(
                "Access management is Owner and Console only (17.3: the whitelist IS the paywall).",
                NamedTextColor.RED));
            return true;
        }
        String sub = args.length > 0 ? args[0].toLowerCase() : "help";
        switch (sub) {
            case "grant":  return grant(sender, args);
            case "revoke": return revoke(sender, args);
            case "list":   return list(sender);
            case "audit":  return audit(sender);
            default:
                sender.sendMessage(Component.text("Usage:", NamedTextColor.GOLD));
                sender.sendMessage(Component.text(
                    "  /access grant <player> <reference> [amount] - record payment and whitelist",
                    NamedTextColor.GRAY));
                sender.sendMessage(Component.text(
                    "  /access revoke <player> <reason>            - revoke and unwhitelist",
                    NamedTextColor.GRAY));
                sender.sendMessage(Component.text(
                    "  /access list                                - live grants",
                    NamedTextColor.GRAY));
                sender.sendMessage(Component.text(
                    "  /access audit                               - row 12: whitelist vs grants",
                    NamedTextColor.GRAY));
                return true;
        }
    }

    private boolean grant(CommandSender sender, String[] args) {
        if (args.length < 3) {
            sender.sendMessage(Component.text(
                "Usage: /access grant <player> <payment reference> [amount in rupees]",
                NamedTextColor.GRAY));
            sender.sendMessage(Component.text(
                "The reference is whatever you have - a UPI id, a date and name, a screenshot "
              + "filename. It is what makes the grant auditable later.", NamedTextColor.DARK_GRAY));
            return true;
        }
        final String name = args[1];
        final String reference = args[2];
        final Long amountMinor = args.length > 3 ? parseRupees(args[3]) : null;
        if (args.length > 3 && amountMinor == null) {
            sender.sendMessage(Component.text("Could not read '" + args[3]
                + "' as an amount in rupees. Leave it out if you are unsure.", NamedTextColor.RED));
            return true;
        }

        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                // Authoritative UUID. A manual grant normally precedes the first login, so
                // the local players table will not have them.
                // update() is the supported Bukkit path and returns a future; join() is safe
                // because this whole block already runs off the main thread. The older
                // PlayerProfile.complete(boolean) is Paper-legacy and is not on the 26.2 API.
                PlayerProfile profile = plugin.getServer().createPlayerProfile(name);
                UUID uuid = null;
                try {
                    PlayerProfile resolvedProfile = profile.update().join();
                    uuid = resolvedProfile.getUniqueId();
                    if (resolvedProfile.getName() != null) profile = resolvedProfile;
                } catch (Exception lookupFailed) {
                    plugin.getLogger().warning("Mojang lookup failed for '" + name + "': "
                        + lookupFailed.getMessage());
                }
                if (uuid == null) {
                    reply(sender, Component.text("Mojang does not know a player called '"
                        + name + "'. Check the spelling - an offline-mode UUID would be "
                        + "useless here because the server runs online-mode=true.",
                        NamedTextColor.RED));
                    db.audit(null, sender.getName(), "access.grant.unknown_player",
                        null, name, "reference=" + reference, null);
                    return;
                }
                final String realName = profile.getName() != null ? profile.getName() : name;

                // Grant FIRST. If this throws, the whitelist is never touched.
                long id = db.grantAccess(uuid, realName, "manual", reference, amountMinor, "INR");
                if (id < 0) {
                    reply(sender, Component.text(
                        "That payment reference has already been used for a grant. "
                      + "Every reference must be unique - that is what stops one payment "
                      + "granting access twice.", NamedTextColor.RED));
                    db.audit(null, sender.getName(), "access.grant.duplicate_reference",
                        uuid, realName, "reference=" + reference, null);
                    return;
                }

                db.audit(null, sender.getName(), "access.grant", uuid, realName,
                    "id=" + id + " reference=" + reference
                  + " amount=" + (amountMinor == null ? "unrecorded" : amountMinor + " paise"), null);

                // Whitelist SECOND, on the main thread as the API requires.
                final UUID grantedUuid = uuid;
                final long grantId = id;
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    org.bukkit.OfflinePlayer op = plugin.getServer().getOfflinePlayer(grantedUuid);
                    op.setWhitelisted(true);
                    plugin.getServer().reloadWhitelist();
                    sender.sendMessage(Component.text("Access granted to " + realName
                        + " (grant #" + grantId + ") and whitelisted.", NamedTextColor.GREEN));
                    sender.sendMessage(Component.text("  uuid " + grantedUuid, NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "Access grant failed: " + e.getMessage());
                reply(sender, Component.text(
                    "The grant was NOT recorded and the player was NOT whitelisted. "
                  + "Nothing changed. Fix the database and try again.", NamedTextColor.RED));
            }
        });
        return true;
    }

    private boolean revoke(CommandSender sender, String[] args) {
        if (args.length < 3) {
            sender.sendMessage(Component.text("Usage: /access revoke <player> <reason>",
                NamedTextColor.GRAY));
            return true;
        }
        final String name = args[1];
        final String reason = String.join(" ", java.util.Arrays.copyOfRange(args, 2, args.length));
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID uuid = db.uuidByName(name);
                if (uuid == null) {
                    try {
                        uuid = plugin.getServer().createPlayerProfile(name)
                                     .update().join().getUniqueId();
                    } catch (Exception ignored) {
                        // leave uuid null; reported below
                    }
                }
                if (uuid == null) {
                    reply(sender, Component.text("Unknown player.", NamedTextColor.RED));
                    return;
                }
                final UUID target = uuid;
                boolean revoked = db.revokeAccess(target, reason);
                db.audit(null, sender.getName(), "access.revoke", target, name,
                    "revoked=" + revoked + " reason=" + reason, null);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    org.bukkit.OfflinePlayer op = plugin.getServer().getOfflinePlayer(target);
                    op.setWhitelisted(false);
                    plugin.getServer().reloadWhitelist();
                    org.bukkit.entity.Player online = plugin.getServer().getPlayer(target);
                    if (online != null) {
                        online.kick(Component.text("Your access has been revoked: " + reason,
                            NamedTextColor.RED));
                    }
                    sender.sendMessage(Component.text(revoked
                        ? ("Access revoked for " + name + " and removed from the whitelist.")
                        : ("No live grant found for " + name + ", but the whitelist entry was removed."),
                        NamedTextColor.YELLOW));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "Access revoke failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean list(CommandSender sender) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<String> rows = db.liveGrants();
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text("Live access grants (" + rows.size() + "):",
                        NamedTextColor.GOLD));
                    for (String r : rows) {
                        sender.sendMessage(Component.text("  " + r, NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "grant list failed: " + e.getMessage());
            }
        });
        return true;
    }

    /**
     * Acceptance row 12, as a command the owner can run at any time.
     *
     * Compares the live whitelist against live grants in BOTH directions, because the two
     * failure modes are different problems: a whitelisted player with no grant is unexplained
     * access (revenue and fairness), and a granted player missing from the whitelist is
     * someone who paid and cannot get in (a refund conversation).
     */
    private boolean audit(CommandSender sender) {
        // The whitelist must be read on the main thread; the grants must not be.
        final java.util.Set<UUID> whitelisted = new java.util.HashSet<>();
        for (org.bukkit.OfflinePlayer op : plugin.getServer().getWhitelistedPlayers()) {
            whitelisted.add(op.getUniqueId());
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                java.util.Set<UUID> granted = db.liveGrantUuids();
                java.util.Set<UUID> unexplained = new java.util.HashSet<>(whitelisted);
                unexplained.removeAll(granted);
                java.util.Set<UUID> paidButLockedOut = new java.util.HashSet<>(granted);
                paidButLockedOut.removeAll(whitelisted);

                db.audit(null, sender.getName(), "access.audit", null, null,
                    "whitelist=" + whitelisted.size() + " grants=" + granted.size()
                  + " unexplained=" + unexplained.size()
                  + " lockedout=" + paidButLockedOut.size(), null);

                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text("ROW 12 AUDIT", NamedTextColor.GOLD));
                    sender.sendMessage(Component.text("  whitelist entries: " + whitelisted.size()
                        + "   live grants: " + granted.size(), NamedTextColor.GRAY));
                    if (unexplained.isEmpty() && paidButLockedOut.isEmpty()) {
                        sender.sendMessage(Component.text(
                            "  PASS - the whitelist matches paid grants exactly.",
                            NamedTextColor.GREEN));
                        return;
                    }
                    if (!unexplained.isEmpty()) {
                        sender.sendMessage(Component.text("  UNEXPLAINED ACCESS - whitelisted "
                            + "with no live grant (" + unexplained.size() + "):", NamedTextColor.RED));
                        for (UUID u : unexplained) {
                            sender.sendMessage(Component.text("    " + u + "  "
                                + nameOf(u), NamedTextColor.RED));
                        }
                    }
                    if (!paidButLockedOut.isEmpty()) {
                        sender.sendMessage(Component.text("  PAID BUT NOT WHITELISTED - these "
                            + "people cannot get in (" + paidButLockedOut.size() + "):",
                            NamedTextColor.YELLOW));
                        for (UUID u : paidButLockedOut) {
                            sender.sendMessage(Component.text("    " + u + "  "
                                + nameOf(u), NamedTextColor.YELLOW));
                        }
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "access audit failed: " + e.getMessage());
            }
        });
        return true;
    }

    private String nameOf(UUID u) {
        org.bukkit.OfflinePlayer op = plugin.getServer().getOfflinePlayer(u);
        return op.getName() == null ? "(name unknown)" : op.getName();
    }

    private void reply(CommandSender sender, Component msg) {
        plugin.getServer().getScheduler().runTask(plugin, () -> sender.sendMessage(msg));
    }

    /** "199" or "199.00" to paise. Null when unreadable. */
    static Long parseRupees(String s) {
        try {
            java.math.BigDecimal d = new java.math.BigDecimal(s.replace(",", ""));
            if (d.signum() < 0) return null;
            return d.movePointRight(2).longValueExact();
        } catch (Exception e) {
            return null;
        }
    }
}
