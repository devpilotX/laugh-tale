package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Material;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

import java.sql.SQLException;
import java.util.List;
import java.util.logging.Level;

/**
 * The bazaar commands. `/order`.
 *
 * ONLY CATALOGUE MATERIALS CAN BE TRADED HERE, and that is not laziness. An order book trades
 * fungible goods - "500 iron, any iron" - and the moment NBT is allowed, a buy order for an iron
 * ingot could be filled with a renamed or differently enchanted one, and every fill needs a
 * comparison nobody can reason about. Anything with NBT belongs in the auction house, where you buy
 * one specific item you can see.
 *
 * ITEM ESCROW IS TAKEN BEFORE THE DATABASE CALL, on the main thread, and returned if the call fails.
 * The reverse order would create the order first and then discover the player no longer has the
 * items - and an unfunded sell order is a promise, which is a whole class of problem escrow removes.
 */
final class Market {

    private final LaughTailPlugin plugin;
    private final Database db;
    private final OrderBook book;

    Market(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
        this.book = new OrderBook(db);
    }

    OrderBook book() { return book; }

    boolean handle(CommandSender sender, String cmd, String[] args) {
        if (!cmd.equals("order") && !cmd.equals("orders") && !cmd.equals("bazaar")) return false;
        if (!(sender instanceof Player p)) {
            sender.sendMessage("The bazaar is per-player; run this in game.");
            return true;
        }
        String sub = args.length > 0 ? args[0].toLowerCase() : "list";
        switch (sub) {
            case "buy"    -> place(p, args, "buy");
            case "sell"   -> place(p, args, "sell");
            case "cancel" -> cancel(p, args);
            case "claim"  -> claim(p);
            case "book"   -> showBook(p, args);
            default       -> listMine(p);
        }
        return true;
    }

    private void help(Player p) {
        p.sendMessage(Component.text("Bazaar - buy and sell orders, matched automatically",
            NamedTextColor.GOLD));
        p.sendMessage(Component.text("  /order buy <item> <qty> <price each>",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("  /order sell <item> <qty> <price each>",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("  /order book <item>    see what is on offer",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("  /order claim          collect what your orders earned",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("  /order cancel <id>    withdraw and get your escrow back",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("Nobody has to be online for your order to fill.",
            NamedTextColor.DARK_GRAY));
    }

    private void place(Player p, String[] args, String side) {
        if (args.length < 4) {
            help(p);
            return;
        }
        final Material m;
        try {
            m = Material.valueOf(args[1].toUpperCase());
        } catch (IllegalArgumentException e) {
            p.sendMessage(Component.text("No such item: " + args[1], NamedTextColor.RED));
            return;
        }
        if (Shop.entry(m) == null) {
            p.sendMessage(Component.text("The bazaar only trades shop resources. "
                + m.name() + " is not one - use the auction house for it.",
                NamedTextColor.RED));
            return;
        }
        final int qty;
        final long price;
        try {
            qty = Integer.parseInt(args[2]);
            price = Long.parseLong(args[3]);
        } catch (NumberFormatException e) {
            p.sendMessage(Component.text("Quantity and price must both be numbers.",
                NamedTextColor.RED));
            return;
        }
        if (qty <= 0 || qty > 3456 || price <= 0 || price > 1_000_000L) {
            p.sendMessage(Component.text("Quantity 1-3456, price 1-1000000.",
                NamedTextColor.RED));
            return;
        }

        if (side.equals("sell")) {
            // Items leave the inventory FIRST, here on the main thread, and come back if the
            // database refuses. The reverse order creates an order the player cannot honour.
            int have = Shop.countIn(p, m);
            if (have < qty) {
                p.sendMessage(Component.text("You have " + have + " and tried to sell "
                    + qty + ".", NamedTextColor.RED));
                return;
            }
            int taken = Shop.removeFrom(p, m, qty);
            if (taken < qty) {
                // Put back whatever was taken. A partial take is worse than no take.
                giveBack(p, m, taken);
                p.sendMessage(Component.text("Could not take the items. Nothing was listed.",
                    NamedTextColor.RED));
                return;
            }
        }

        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                OrderBook.PlaceResult r = book.place(p.getUniqueId(), side, m.name(), qty, price);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (!r.ok()) {
                        if (side.equals("sell")) giveBack(p, m, qty);
                        p.sendMessage(Component.text("Refused: " + r.refusal(),
                            NamedTextColor.RED));
                        return;
                    }
                    p.sendMessage(Component.text("Order #" + r.orderId() + " placed: "
                        + side + " " + qty + " x " + m.name() + " at " + price + " each.",
                        NamedTextColor.GREEN));
                    if (r.filledImmediately() > 0) {
                        p.sendMessage(Component.text("  " + r.filledImmediately()
                            + " filled immediately for " + r.spentOrEarned()
                            + " Berries. Use /order claim to collect.", NamedTextColor.GREEN));
                    } else {
                        p.sendMessage(Component.text("  Nothing matched yet. It will fill when "
                            + "someone takes the other side, online or not.",
                            NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "order place failed: " + e.getMessage());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (side.equals("sell")) giveBack(p, m, qty);
                    p.sendMessage(Component.text("That failed. Nothing was charged and your "
                        + "items are back.", NamedTextColor.RED));
                });
            }
        });
    }

    /** Returns items, dropping what will not fit. Never deletes. */
    private void giveBack(Player p, Material m, int amount) {
        if (amount <= 0) return;
        for (ItemStack left : p.getInventory().addItem(new ItemStack(m, amount)).values()) {
            p.getWorld().dropItemNaturally(p.getLocation(), left);
        }
    }

    private void claim(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<Database.Payout> payouts = db.claimOrderPayouts(p.getUniqueId());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (payouts.isEmpty()) {
                        p.sendMessage(Component.text("Nothing to collect.", NamedTextColor.GRAY));
                        return;
                    }
                    long berries = 0;
                    for (Database.Payout po : payouts) {
                        berries += po.berries();
                        if (po.items() > 0) {
                            try {
                                giveBack(p, Material.valueOf(po.material()), po.items());
                            } catch (IllegalArgumentException ignored) {
                                plugin.getLogger().warning("payout for unknown material "
                                    + po.material());
                            }
                        }
                    }
                    p.sendMessage(Component.text("Collected " + berries + " Berries and your "
                        + "bought items.", NamedTextColor.GREEN));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "claim failed: " + e.getMessage());
                plugin.getServer().getScheduler().runTask(plugin, () -> p.sendMessage(
                    Component.text("Claim failed. Nothing was lost - try again.",
                        NamedTextColor.RED)));
            }
        });
    }

    private void cancel(Player p, String[] args) {
        if (args.length < 2) {
            p.sendMessage(Component.text("Usage: /order cancel <id>", NamedTextColor.GRAY));
            return;
        }
        final long id;
        try {
            id = Long.parseLong(args[1]);
        } catch (NumberFormatException e) {
            p.sendMessage(Component.text("That is not an order id.", NamedTextColor.RED));
            return;
        }
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                Database.CancelResult r = db.cancelOrder(p.getUniqueId(), id);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (!r.ok()) {
                        p.sendMessage(Component.text(r.message(), NamedTextColor.RED));
                        return;
                    }
                    if (r.items() > 0) {
                        try {
                            giveBack(p, Material.valueOf(r.material()), r.items());
                        } catch (IllegalArgumentException ignored) { }
                    }
                    p.sendMessage(Component.text("Order #" + id + " cancelled. "
                        + (r.berries() > 0 ? r.berries() + " Berries returned. " : "")
                        + (r.items() > 0 ? r.items() + " items returned." : ""),
                        NamedTextColor.GREEN));
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.SEVERE, "cancel failed: " + e.getMessage());
            }
        });
    }

    private void showBook(Player p, String[] args) {
        if (args.length < 2) {
            p.sendMessage(Component.text("Usage: /order book <item>", NamedTextColor.GRAY));
            return;
        }
        final String mat = args[1].toUpperCase();
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<String> buys = db.bookSide(mat, "buy", 5);
                List<String> sells = db.bookSide(mat, "sell", 5);
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Order book - " + mat, NamedTextColor.GOLD));
                    p.sendMessage(Component.text("  Selling (cheapest first)",
                        NamedTextColor.RED));
                    if (sells.isEmpty()) {
                        p.sendMessage(Component.text("    nothing", NamedTextColor.DARK_GRAY));
                    }
                    for (String s : sells) {
                        p.sendMessage(Component.text("    " + s, NamedTextColor.GRAY));
                    }
                    p.sendMessage(Component.text("  Buying (highest first)", NamedTextColor.GREEN));
                    if (buys.isEmpty()) {
                        p.sendMessage(Component.text("    nothing", NamedTextColor.DARK_GRAY));
                    }
                    for (String s : buys) {
                        p.sendMessage(Component.text("    " + s, NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "book failed: " + e.getMessage());
            }
        });
    }

    private void listMine(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                List<String> mine = db.myOrders(p.getUniqueId());
                plugin.getServer().getScheduler().runTask(plugin, () -> {
                    p.sendMessage(Component.text("Your orders (" + mine.size() + ")",
                        NamedTextColor.GOLD));
                    if (mine.isEmpty()) help(p);
                    for (String s : mine) {
                        p.sendMessage(Component.text("  " + s, NamedTextColor.GRAY));
                    }
                });
            } catch (SQLException e) {
                plugin.getLogger().log(Level.WARNING, "my orders failed: " + e.getMessage());
            }
        });
    }
}
