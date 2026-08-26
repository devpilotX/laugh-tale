package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

import java.sql.SQLException;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;

/**
 * Berries. The single currency.
 *
 * THE LEDGER IS THE SOURCE OF TRUTH AND THE BALANCE IS A CACHE. Every movement writes a
 * `transactions` row in the SAME database transaction that changes the balance, and records
 * the resulting balance on the row. Two consequences follow, and both are the point:
 *
 *   - The Phase 3 arbitrage audit can see every movement. An audit that cannot see a movement
 *     cannot find the loop that creates money, and a positive-yield loop is the one failure
 *     that ends an economy outright.
 *   - The ledger is self-checking. Because each row carries `balance_after`, corruption can be
 *     found by scanning consecutive rows rather than by replaying every transaction from zero.
 *
 * THE TRANSFER TAX IS BOTH A SINK AND A DETECTOR (P10). 5% above 5,000 Berries. The tax is the
 * sink; the threshold is the detector - bulk movement between accounts is how a suspended
 * player moves value to an alt and how real-money trading settles in game, so a transfer over
 * the threshold is deliberately made *notable* in the ledger rather than merely charged for.
 *
 * NEGATIVE BALANCES ARE IMPOSSIBLE, enforced in three places on purpose: the column is signed
 * so an underflow fails rather than wrapping to a vast positive number, a CHECK constraint
 * rejects it at the database, and the transfer reads the balance inside the transaction with
 * FOR UPDATE so two simultaneous transfers cannot both see the same funds. Any one of those
 * alone would be a bug away from a duplication exploit.
 */
final class Economy {

    /** P10. Both values are decisions from D-0031, not guesses. */
    static final double TRANSFER_TAX_RATE = 0.05;
    static final long TRANSFER_TAX_THRESHOLD = 5_000L;

    private final LaughTailPlugin plugin;
    private final Database db;

    Economy(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    /** Tax on a transfer. Zero at or below the threshold. */
    static long taxOn(long amount) {
        if (amount <= TRANSFER_TAX_THRESHOLD) return 0L;
        return Math.round(amount * TRANSFER_TAX_RATE);
    }

    boolean handle(CommandSender sender, String cmd, String[] args) {
        switch (cmd) {
            case "balance": return balance(sender, args);
            case "pay":     return pay(sender, args);
            case "baltop":  return baltop(sender);
            case "berries": return ledger(sender, args);
            default:        return false;
        }
    }

    private boolean balance(CommandSender sender, String[] args) {
        final String who = args.length > 0 ? args[0] : sender.getName();
        final boolean other = args.length > 0 && !who.equalsIgnoreCase(sender.getName());
        if (other && !sender.hasPermission("laughtail.staff.chat")) {
            // 9.8 makes stats public, but a balance is not a stat - it is a target. Viewing
            // someone else's is staff-only until the owner decides otherwise.
            sender.sendMessage(Component.text("You can only check your own balance.",
                NamedTextColor.RED));
            return true;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID id = db.uuidByName(who);
                if (id == null) {
                    reply(sender, Component.text("Unknown player.", NamedTextColor.RED));
                    return;
                }
                long b = db.balance(id);
                reply(sender, Component.text(who + " has " + b + " Berries",
                    NamedTextColor.GOLD));
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "balance failed: " + e.getMessage());
                reply(sender, Component.text("Could not read the balance.", NamedTextColor.RED));
            }
        });
        return true;
    }

    private boolean pay(CommandSender sender, String[] args) {
        if (!(sender instanceof Player from)) {
            sender.sendMessage(Component.text("Only a player can pay.", NamedTextColor.RED));
            return true;
        }
        if (args.length < 2) {
            sender.sendMessage(Component.text("Usage: /pay <player> <amount>", NamedTextColor.GRAY));
            return true;
        }
        final long amount;
        try {
            amount = Long.parseLong(args[1]);
        } catch (NumberFormatException e) {
            sender.sendMessage(Component.text("'" + args[1] + "' is not a whole number of Berries.",
                NamedTextColor.RED));
            return true;
        }
        if (amount <= 0) {
            sender.sendMessage(Component.text("Amount must be positive.", NamedTextColor.RED));
            return true;
        }
        final String toName = args[0];
        if (toName.equalsIgnoreCase(from.getName())) {
            // Not merely pointless: a self-transfer would let a player generate tax-free
            // ledger noise to bury a real transfer in.
            sender.sendMessage(Component.text("You cannot pay yourself.", NamedTextColor.RED));
            return true;
        }

        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID to = db.uuidByName(toName);
                if (to == null) {
                    reply(sender, Component.text("No player called '" + toName
                        + "' has joined, so they have no balance to pay into.", NamedTextColor.RED));
                    return;
                }
                long tax = taxOn(amount);
                Database.TransferResult r = db.transfer(from.getUniqueId(), to, amount, tax);
                switch (r.outcome()) {
                    case OK -> reply(sender, Component.text("Paid " + (amount - tax)
                        + " Berries to " + toName
                        + (tax > 0 ? " (" + tax + " tax on a transfer over "
                            + TRANSFER_TAX_THRESHOLD + ")" : "")
                        + ". You now have " + r.senderBalance() + ".", NamedTextColor.GREEN));
                    case INSUFFICIENT -> reply(sender, Component.text(
                        "You have " + r.senderBalance() + " Berries and need " + amount + ".",
                        NamedTextColor.RED));
                    case NO_SENDER_ACCOUNT -> reply(sender, Component.text(
                        "You have no Berries yet.", NamedTextColor.RED));
                }
                if (r.outcome() == Database.Outcome.OK) {
                    Player online = plugin.getServer().getPlayerExact(toName);
                    if (online != null) {
                        plugin.getServer().getScheduler().runTask(plugin, () ->
                            online.sendMessage(Component.text("You received " + (amount - tax)
                                + " Berries from " + from.getName(), NamedTextColor.GREEN)));
                    }
                }
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "transfer failed: " + e.getMessage());
                reply(sender, Component.text(
                    "The transfer failed and NOTHING was moved. Your balance is unchanged.",
                    NamedTextColor.RED));
            }
        });
        return true;
    }

    private boolean baltop(CommandSender sender) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<String> rows = db.richList(10);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text("Richest players", NamedTextColor.GOLD));
                    if (rows.isEmpty()) {
                        sender.sendMessage(Component.text("  nobody has any Berries yet",
                            NamedTextColor.GRAY));
                    }
                    for (String r : rows) {
                        sender.sendMessage(Component.text("  " + r, NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "baltop failed: " + e.getMessage());
            }
        });
        return true;
    }

    /** /berries - the player's own ledger. Transparency is part of the fairness reputation. */
    private boolean ledger(CommandSender sender, String[] args) {
        final String who = (args.length > 0 && sender.hasPermission("laughtail.staff.chat"))
            ? args[0] : sender.getName();
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                UUID id = db.uuidByName(who);
                if (id == null) {
                    reply(sender, Component.text("Unknown player.", NamedTextColor.RED));
                    return;
                }
                List<String> rows = db.ledgerFor(id, 15);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    sender.sendMessage(Component.text("Berry ledger for " + who
                        + " (" + rows.size() + " most recent)", NamedTextColor.GOLD));
                    if (rows.isEmpty()) {
                        sender.sendMessage(Component.text("  no movements yet", NamedTextColor.GRAY));
                    }
                    for (String r : rows) {
                        sender.sendMessage(Component.text("  " + r, NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "ledger failed: " + e.getMessage());
            }
        });
        return true;
    }

    private void reply(CommandSender sender, Component msg) {
        plugin.getServer().getScheduler().runTask(plugin, () -> sender.sendMessage(msg));
    }
}
