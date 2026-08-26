package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Material;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

import java.sql.SQLException;
import java.util.logging.Level;

/**
 * Buying and selling. The commands and their guards.
 *
 * ROW 40 IS ENFORCED HERE AND ONLY HERE, server-side, after the player's peak tier is read from
 * the database. "A Tier 1 player cannot buy a Tier 8 item by any means, including a modified
 * client" - so the GUI's greyed-out button is decoration, not the control. A client that fabricates
 * a click on a hidden slot still arrives at this method, and this method still refuses.
 *
 * SELLING IS NEVER GATED (10.3). A new player must be able to convert what they mine into Berries
 * in their first minute or the economy has no entry point.
 *
 * THE DAILY SELL CAP (P6, 3,600 per category) is checked and applied inside the same transaction
 * as the payment, so two simultaneous sales cannot both pass the same remaining-cap check. Caps
 * that are checked and then applied separately are how a cap becomes a suggestion.
 */
final class ShopService {

    private final LaughTailPlugin plugin;
    private final Database db;

    ShopService(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    boolean handle(CommandSender sender, String cmd, String[] args) {
        if (!(sender instanceof Player p)) return false;
        switch (cmd) {
            case "shop": return shopInfo(p, args);
            case "sell": return sell(p, args);
            case "buy":  return buy(p, args);
            default: return false;
        }
    }

    private boolean shopInfo(Player p, String[] args) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                int season = db.activeSeason();
                int rp = db.currentRp(p.getUniqueId(), season);
                int tier = Shop.tierForRp(rp);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Shop - your tier is " + tier + " of 8",
                        NamedTextColor.GOLD));
                    p.sendMessage(Component.text(
                        "Selling is never tier-gated. Buying is (10.3).", NamedTextColor.GRAY));
                    p.sendMessage(Component.text(
                        "  /sell hand    sell what you are holding", NamedTextColor.GRAY));
                    p.sendMessage(Component.text(
                        "  /sell all     sell every sellable item in your inventory",
                        NamedTextColor.GRAY));
                    p.sendMessage(Component.text(
                        "  /buy <item> [amount]", NamedTextColor.GRAY));
                    p.sendMessage(Component.text("  /menu -> Shop for the full list",
                        NamedTextColor.DARK_GRAY));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "shop info failed: " + e.getMessage());
            }
        });
        return true;
    }

    private boolean sell(Player p, String[] args) {
        final String mode = args.length > 0 ? args[0].toLowerCase() : "hand";
        if (mode.equals("all")) return sellAll(p);

        ItemStack held = p.getInventory().getItemInMainHand();
        if (held == null || held.getType() == Material.AIR) {
            p.sendMessage(Component.text("Hold what you want to sell, or use /sell all.",
                NamedTextColor.GRAY));
            return true;
        }
        Shop.Entry e = Shop.entry(held.getType());
        if (e == null) {
            p.sendMessage(Component.text("The shop does not buy " + held.getType().name() + ".",
                NamedTextColor.RED));
            return true;
        }
        int amount = Shop.countIn(p, held.getType());
        sellItem(p, e, amount);
        return true;
    }

    private boolean sellAll(Player p) {
        int sold = 0;
        for (Material m : Shop.catalogue().keySet()) {
            int have = Shop.countIn(p, m);
            if (have <= 0) continue;
            sellItem(p, Shop.entry(m), have);
            sold++;
        }
        if (sold == 0) {
            p.sendMessage(Component.text("Nothing in your inventory is sellable.",
                NamedTextColor.GRAY));
        }
        return true;
    }

    private void sellItem(Player p, Shop.Entry e, int amount) {
        if (amount <= 0) return;
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                long unitBuy = db.currentPrice(e);
                long unitSell = Shop.sellPrice(unitBuy);
                if (unitSell <= 0) {
                    reply(p, Component.text(e.material().name()
                        + " is worth nothing to sell - it is too common.", NamedTextColor.GRAY));
                    return;
                }
                Database.SellResult r = db.sell(p.getUniqueId(), e, amount, unitSell);
                if (r.soldUnits() <= 0) {
                    reply(p, Component.text("Daily sell limit reached for "
                        + e.category() + ". It resets at midnight UTC.", NamedTextColor.YELLOW));
                    return;
                }
                final int toRemove = r.soldUnits();
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    // Items are removed only AFTER the payment is committed. If the order were
                    // reversed, a database failure between the two would take a player's items
                    // and pay nothing - which is theft rather than a bug.
                    int actually = Shop.removeFrom(p, e.material(), toRemove);
                    p.sendMessage(Component.text("Sold " + actually + " x "
                        + e.material().name() + " for " + r.paid() + " Berries. Balance "
                        + r.balance() + ".", NamedTextColor.GREEN));
                    if (actually < toRemove) {
                        plugin.getLogger().warning("SELL MISMATCH for " + p.getName()
                            + ": paid for " + toRemove + " but removed " + actually
                            + ". Investigate - the player has been overpaid.");
                    }
                    if (r.cappedAt() > 0) {
                        p.sendMessage(Component.text("Daily limit for " + e.category()
                            + " reached at " + r.cappedAt() + " Berries.", NamedTextColor.YELLOW));
                    }
                });
            } catch (SQLException ex) {
                plugin.getLogger().log(Level.SEVERE, "sell failed: " + ex.getMessage());
                reply(p, Component.text("The sale failed. Nothing was taken or paid.",
                    NamedTextColor.RED));
            }
        });
    }

    private boolean buy(Player p, String[] args) {
        if (args.length < 1) {
            p.sendMessage(Component.text("Usage: /buy <item> [amount]", NamedTextColor.GRAY));
            return true;
        }
        final Material m;
        try {
            m = Material.valueOf(args[0].toUpperCase());
        } catch (IllegalArgumentException ex) {
            p.sendMessage(Component.text("No such item: " + args[0], NamedTextColor.RED));
            return true;
        }
        Shop.Entry e = Shop.entry(m);
        if (e == null) {
            p.sendMessage(Component.text("The shop does not sell " + m.name() + ".",
                NamedTextColor.RED));
            return true;
        }
        final int amount;
        try {
            amount = args.length > 1 ? Integer.parseInt(args[1]) : 1;
        } catch (NumberFormatException ex) {
            p.sendMessage(Component.text("'" + args[1] + "' is not a number.", NamedTextColor.RED));
            return true;
        }
        if (amount <= 0 || amount > 3456) {   // 3456 = 54 slots x 64
            p.sendMessage(Component.text("Amount must be between 1 and 3456.",
                NamedTextColor.RED));
            return true;
        }
        buyItem(p, e, amount);
        return true;
    }

    private void buyItem(Player p, Shop.Entry e, int amount) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                int season = db.activeSeason();
                int rp = db.currentRp(p.getUniqueId(), season);
                int tier = Shop.tierForRp(rp);

                // ROW 40. Server-side, after reading rank from the database. The GUI's greyed
                // button is decoration; this is the control.
                if (!Shop.canBuy(tier, e)) {
                    reply(p, Component.text(e.material().name() + " needs shop tier "
                        + e.tier() + ". You are tier " + tier + ". Rank up by winning fights - "
                        + "there is no other way to unlock it and no way to buy the unlock.",
                        NamedTextColor.RED));
                    db.audit(null, "SHOP", "buy.tier_refused", p.getUniqueId(), p.getName(),
                        e.material().name() + " tier " + e.tier() + " vs player tier " + tier, null);
                    return;
                }

                long unit = db.currentPrice(e);
                long total = unit * amount;
                Database.BuyResult r = db.buy(p.getUniqueId(), e, amount, unit);
                if (!r.ok()) {
                    reply(p, Component.text("You need " + total + " Berries and have "
                        + r.balance() + ".", NamedTextColor.RED));
                    return;
                }
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    // Give the items, and refund anything that did not fit rather than silently
                    // dropping it on the floor where it can despawn.
                    java.util.Map<Integer, ItemStack> leftover =
                        p.getInventory().addItem(new ItemStack(e.material(), amount));
                    int notGiven = leftover.values().stream().mapToInt(ItemStack::getAmount).sum();
                    p.sendMessage(Component.text("Bought " + (amount - notGiven) + " x "
                        + e.material().name() + " for " + (unit * (amount - notGiven))
                        + " Berries.", NamedTextColor.GREEN));
                    if (notGiven > 0) {
                        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
                            try {
                                db.adjustBalance(p.getUniqueId(), unit * notGiven,
                                    "shop_refund", "inventory full, " + notGiven + " not delivered");
                                reply(p, Component.text("Your inventory was full - "
                                    + notGiven + " were refunded.", NamedTextColor.YELLOW));
                            } catch (SQLException ignored) {
                                plugin.getLogger().severe("REFUND FAILED for " + p.getName()
                                    + ": owed " + (unit * notGiven));
                            }
                        });
                    }
                });
            } catch (SQLException ex) {
                plugin.getLogger().log(Level.SEVERE, "buy failed: " + ex.getMessage());
                reply(p, Component.text("The purchase failed. Nothing was charged.",
                    NamedTextColor.RED));
            }
        });
    }

    private void reply(Player p, Component c) {
        plugin.getServer().getScheduler().runTask(plugin, () -> {
            if (p.isOnline()) p.sendMessage(c);
        });
    }
}
