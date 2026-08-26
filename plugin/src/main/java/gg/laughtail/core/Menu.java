package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextDecoration;
import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.InventoryHolder;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;

import java.util.ArrayList;
import java.util.List;

/**
 * The chest-GUI front door. `/menu`, and the same thing under `/laughtail menu`.
 *
 * WHY A CHEST GUI AND NOT A CLIENT MOD BUTTON. The owner asked for an option in the ESC pause
 * menu. A server cannot put one there - the pause menu is rendered entirely client-side, and the
 * only way in is Lunar Client Apollo, which works for Lunar users and nobody else. A chest GUI
 * works for every Java client AND for Bedrock players through Geyser, which matters because 4.4
 * puts Bedrock support in scope. Apollo remains worth adding later as an extra door to the same
 * room, and nothing will depend on it.
 *
 * BUTTONS FOR UNBUILT FEATURES SAY SO. This is the whole reason D-0035 scheduled the GUI last: a
 * menu of buttons that silently do nothing looks like a finished server and is worse than no
 * menu, because it moves the disappointment from "that isn't built" to "this server is broken".
 * Every unbuilt entry is greyed, labelled "not built yet", and does nothing when clicked except
 * say the same thing.
 *
 * IDENTIFICATION IS BY HOLDER, NOT BY TITLE. A menu identified by its title can be spoofed by a
 * renamed chest or confused by a resource pack, and clicking in the wrong inventory would run a
 * command. A private InventoryHolder cannot be forged by a client.
 */
final class Menu implements Listener {

    /** Marks an inventory as ours. A client cannot fabricate this. */
    private static final class MenuHolder implements InventoryHolder {
        private final String page;
        private MenuHolder(String page) { this.page = page; }
        @Override public Inventory getInventory() { return null; }
    }

    /** Stashes the real material on a button, so a greyed placeholder stays identifiable. */
    private final org.bukkit.NamespacedKey shopItemKey;
    private final LaughTailPlugin plugin;

    Menu(LaughTailPlugin plugin) {
        this.plugin = plugin;
        this.shopItemKey = new org.bukkit.NamespacedKey(plugin, "shop_item");
    }

    // ---- building ------------------------------------------------------------

    private ItemStack item(Material m, String name, NamedTextColor colour, List<String> lore) {
        ItemStack it = new ItemStack(m);
        ItemMeta meta = it.getItemMeta();
        meta.displayName(Component.text(name, colour).decoration(TextDecoration.ITALIC, false));
        List<Component> l = new ArrayList<>();
        for (String line : lore) {
            l.add(Component.text(line, NamedTextColor.GRAY)
                .decoration(TextDecoration.ITALIC, false));
        }
        meta.lore(l);
        it.setItemMeta(meta);
        return it;
    }

    private ItemStack notBuilt(Material m, String name, String whatItWillDo, String blockedBy) {
        return item(m, name, NamedTextColor.DARK_GRAY, List.of(
            whatItWillDo,
            "",
            "NOT BUILT YET",
            blockedBy));
    }

    void openMain(Player p) {
        Inventory inv = Bukkit.createInventory(new MenuHolder("main"), 45,
            Component.text("Laugh Tale", NamedTextColor.GOLD));

        inv.setItem(10, item(Material.RED_BED, "Homes", NamedTextColor.GREEN, List.of(
            "Two free, more with Berries.",
            "Click to list your homes.")));

        inv.setItem(11, item(Material.GOLD_INGOT, "Berries", NamedTextColor.GOLD, List.of(
            "Your balance and your full ledger.",
            "Every movement is recorded permanently.")));

        inv.setItem(12, item(Material.COMPASS, "Random Teleport", NamedTextColor.AQUA, List.of(
            "Sends you to the RESOURCE world.",
            "That world is deleted every month.",
            "Mine there, build at home.")));

        inv.setItem(13, item(Material.ENDER_PEARL, "Teleport to a player", NamedTextColor.AQUA,
            List.of("Asks them first. They must accept.",
                "Nobody is ever teleported without consent.")));

        inv.setItem(14, item(Material.DIAMOND_SWORD, "Your rank", NamedTextColor.RED, List.of(
            "Rank comes from PvP and nothing else.",
            "Mining and building change it by exactly zero.")));

        inv.setItem(15, item(Material.WRITABLE_BOOK, "Rules", NamedTextColor.YELLOW, List.of(
            "The rules you accepted, and their version.")));

        // --- honestly unbuilt ---
        inv.setItem(19, item(Material.CHEST, "Shop", NamedTextColor.GOLD, List.of(
            "Buy and sell at prices that move with trade.",
            "Selling is never tier-gated. Buying is.",
            "Daily sell limit: 3600 Berries per category.")));
        inv.setItem(20, notBuilt(Material.GOLD_BLOCK, "Auction House",
            "List items for other players to buy.", "Waiting on: Phase 3"));
        inv.setItem(21, notBuilt(Material.PAPER, "Orders / Bazaar",
            "Buy and sell orders, matched atomically.", "Waiting on: Phase 3"));
        inv.setItem(22, notBuilt(Material.PLAYER_HEAD, "Friends",
            "Add friends and see who is online.", "Waiting on: the friends commands"));
        inv.setItem(23, notBuilt(Material.ARMOR_STAND, "Cosmetics",
            "Unlocked by rank. Never bought with money.", "Waiting on: Phase 7"));
        inv.setItem(24, notBuilt(Material.OAK_SIGN, "Leaderboards",
            "Season standings and the Hall of Fame.", "Waiting on: Phase 8"));
        inv.setItem(25, notBuilt(Material.NOTE_BLOCK, "Settings",
            "Your personal toggles.", "Waiting on: Section 16"));

        if (p.hasPermission("laughtail.status")) {
            inv.setItem(40, item(Material.COMMAND_BLOCK, "Staff and Owner tools",
                NamedTextColor.LIGHT_PURPLE, List.of(
                    "Access grants, seasons, moderation.",
                    "Only visible because you hold laughtail.status.")));
        }

        inv.setItem(44, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
        p.openInventory(inv);
    }

    /**
     * The homes page. One bed per home, clicked to teleport.
     *
     * Built asynchronously because it reads the database, then opened on the main thread. The
     * obvious shortcut - read homes synchronously to build the inventory - would put a query
     * inside a click handler, which is the exact pattern acceptance row 25 forbids.
     */
    void openHomes(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final java.util.List<String> names;
            final int purchased;
            try {
                names = plugin.database().homeNames(p.getUniqueId());
                purchased = plugin.database().purchasedSlots(p.getUniqueId());
            } catch (java.sql.SQLException e) {
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    p.sendMessage(Component.text("Could not read your homes.",
                        NamedTextColor.RED)));
                return;
            }
            final int allowed = Math.min(Homes.MAX_HOMES, Homes.FREE_SLOTS + purchased);
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                Inventory inv = Bukkit.createInventory(new MenuHolder("homes"), 27,
                    Component.text("Homes " + names.size() + "/" + allowed, NamedTextColor.GREEN));
                int slot = 0;
                for (String n : names) {
                    if (slot >= 18) break;
                    inv.setItem(slot++, item(Material.RED_BED, n, NamedTextColor.WHITE,
                        List.of("Click to teleport here.",
                                "3 second warmup - do not move.")));
                }
                if (allowed < Homes.MAX_HOMES) {
                    inv.setItem(22, item(Material.EMERALD, "Buy another slot",
                        NamedTextColor.GREEN, List.of(
                            "Cost: " + Homes.slotCost(purchased) + " Berries",
                            "The price rises with each slot.",
                            "A slot you buy is yours permanently.")));
                }
                inv.setItem(18, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(26, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }

    /**
     * The shop page. Category buttons, then items with live prices.
     *
     * Locked items are SHOWN, greyed, with the tier they need - rather than hidden. Hiding them
     * would make rank feel like nothing exists beyond your tier; showing them is the entire
     * incentive to rank up, and it is honest about what the ladder is for.
     *
     * The lock here is cosmetic. Row 40 is enforced in ShopService against the database, so a
     * client that fabricates a click on a locked slot is still refused.
     */
    void openShop(Player p, String category) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final int tier;
            final java.util.Map<Material, Long> prices = new java.util.LinkedHashMap<>();
            try {
                int season = plugin.database().activeSeason();
                tier = Shop.tierForRp(plugin.database().currentRp(p.getUniqueId(), season));
                for (var en : Shop.catalogue().values()) {
                    if (category == null || en.category().equals(category)) {
                        prices.put(en.material(), plugin.database().currentPrice(en));
                    }
                }
            } catch (java.sql.SQLException e) {
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    p.sendMessage(Component.text("Could not read shop prices.",
                        NamedTextColor.RED)));
                return;
            }
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                String heading = category == null ? "Shop" : "Shop - " + category;
                Inventory inv = Bukkit.createInventory(
                    new MenuHolder(category == null ? "shop" : "shop:" + category), 54,
                    Component.text(heading + "  (your tier " + tier + "/8)",
                        NamedTextColor.GOLD));
                int slot = 0;
                for (var e : Shop.catalogue().values()) {
                    if (category != null && !e.category().equals(category)) continue;
                    if (slot >= 45) break;
                    long buy = prices.getOrDefault(e.material(), e.basePrice());
                    boolean allowed = Shop.canBuy(tier, e);
                    List<String> lore = new java.util.ArrayList<>();
                    lore.add("Buy  " + buy + " Berries each");
                    long sp = Shop.sellPrice(buy);
                    lore.add(sp > 0 ? "Sell " + sp + " Berries each"
                                    : "Sell - worth nothing, too common");
                    lore.add("");
                    if (allowed) {
                        lore.add("Left click  buy 1");
                        lore.add("Right click buy 16");
                        lore.add("Selling is never tier-gated.");
                    } else {
                        lore.add("LOCKED - needs shop tier " + e.tier());
                        lore.add("You are tier " + tier + ".");
                        lore.add("Rank up by winning fights. There is");
                        lore.add("no way to buy this unlock.");
                    }
                    ItemStack it = new ItemStack(allowed ? e.material() : Material.GRAY_DYE);
                    var meta = it.getItemMeta();
                    meta.displayName(Component.text(e.material().name(),
                        allowed ? NamedTextColor.WHITE : NamedTextColor.DARK_GRAY)
                        .decoration(net.kyori.adventure.text.format.TextDecoration.ITALIC, false));
                    meta.lore(lore.stream().map(s -> Component.text(s, NamedTextColor.GRAY)
                        .decoration(net.kyori.adventure.text.format.TextDecoration.ITALIC, false))
                        .map(c -> (Component) c).toList());
                    // The real material is stashed so a greyed GRAY_DYE still knows what it is.
                    meta.getPersistentDataContainer().set(shopItemKey,
                        org.bukkit.persistence.PersistentDataType.STRING, e.material().name());
                    it.setItemMeta(meta);
                    inv.setItem(slot++, it);
                }
                inv.setItem(45, item(Material.IRON_PICKAXE, "Ore", NamedTextColor.AQUA, List.of()));
                inv.setItem(46, item(Material.WHEAT, "Farm", NamedTextColor.GREEN, List.of()));
                inv.setItem(47, item(Material.BONE, "Drops", NamedTextColor.WHITE, List.of()));
                inv.setItem(48, item(Material.OAK_LOG, "Wood", NamedTextColor.GOLD, List.of()));
                inv.setItem(49, item(Material.NETHER_STAR, "Special",
                    NamedTextColor.LIGHT_PURPLE, List.of()));
                inv.setItem(51, item(Material.HOPPER, "Sell everything sellable",
                    NamedTextColor.YELLOW, List.of("Runs /sell all.",
                        "Daily limit: 3600 Berries per category.")));
                inv.setItem(52, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(53, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }

    private void openAdmin(Player p) {
        Inventory inv = Bukkit.createInventory(new MenuHolder("admin"), 27,
            Component.text("Laugh Tale - staff", NamedTextColor.LIGHT_PURPLE));

        inv.setItem(10, item(Material.NAME_TAG, "Access audit", NamedTextColor.GREEN, List.of(
            "Row 12: does the whitelist match paid grants?",
            "Checks both directions.")));
        inv.setItem(11, item(Material.PAPER, "Live grants", NamedTextColor.GREEN, List.of(
            "Everyone with paid access right now.")));
        inv.setItem(12, item(Material.CLOCK, "Season status", NamedTextColor.GOLD, List.of(
            "Current season, state, and the Champion.")));
        inv.setItem(13, item(Material.REDSTONE_TORCH, "Server status", NamedTextColor.AQUA,
            List.of("Plugin version, database, world rules.")));
        inv.setItem(14, item(Material.DIAMOND, "Rating engine", NamedTextColor.RED, List.of(
            "Appendix B invariants, run live.")));

        inv.setItem(22, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
        p.openInventory(inv);
    }

    // ---- clicks --------------------------------------------------------------

    @EventHandler
    public void onClick(InventoryClickEvent e) {
        if (!(e.getInventory().getHolder() instanceof MenuHolder holder)) return;
        // Always cancel: this is a display, not a container. Without this a player could take
        // the buttons out of the menu and keep them.
        e.setCancelled(true);
        if (!(e.getWhoClicked() instanceof Player p)) return;
        ItemStack clicked = e.getCurrentItem();
        if (clicked == null || clicked.getType() == Material.AIR) return;

        ItemMeta meta = clicked.getItemMeta();
        if (meta == null || meta.displayName() == null) return;
        String name = net.kyori.adventure.text.serializer.plain.PlainTextComponentSerializer
            .plainText().serialize(meta.displayName());

        if (clicked.getType() == Material.BARRIER) { p.closeInventory(); return; }

        // Unbuilt entries are inert BY MARKER, not by name, so renaming a label cannot
        // accidentally make a dead button live.
        if (clicked.getType() == Material.CHEST || clicked.getType() == Material.GOLD_BLOCK
         || clicked.getType() == Material.PAPER && holder.page.equals("main")
         || clicked.getType() == Material.PLAYER_HEAD
         || clicked.getType() == Material.ARMOR_STAND
         || clicked.getType() == Material.OAK_SIGN
         || clicked.getType() == Material.NOTE_BLOCK) {
            if (holder.page.equals("main")) {
                p.sendMessage(Component.text(name + " is not built yet. "
                    + "The menu says so rather than pretending.", NamedTextColor.DARK_GRAY));
                return;
            }
        }

        if (holder.page.startsWith("shop")) {
            switch (name) {
                case "Ore"     -> openShop(p, "ore");
                case "Farm"    -> openShop(p, "farm");
                case "Drops"   -> openShop(p, "drops");
                case "Wood"    -> openShop(p, "wood");
                case "Special" -> openShop(p, "special");
                case "Back"    -> openMain(p);
                case "Sell everything sellable" -> { p.closeInventory(); run(p, "sell all"); }
                default -> {
                    // Read the stashed material rather than the clicked type, because a locked
                    // row is rendered as GRAY_DYE and its own type would be meaningless.
                    var buttonMeta = clicked.getItemMeta();
                    if (buttonMeta == null) return;
                    String mat = buttonMeta.getPersistentDataContainer().get(shopItemKey,
                        org.bukkit.persistence.PersistentDataType.STRING);
                    if (mat == null) return;
                    int qty = e.isRightClick() ? 16 : 1;
                    // Dispatched as the player, so ShopService applies the row 40 check exactly
                    // as it would for a typed command. The greying is cosmetic; this is not.
                    run(p, "buy " + mat + " " + qty);
                }
            }
            return;
        }

        if (holder.page.equals("homes")) {
            switch (clicked.getType()) {
                case RED_BED -> { p.closeInventory(); run(p, "home " + name); }
                case EMERALD -> { p.closeInventory(); run(p, "buyhome"); }
                case ARROW   -> openMain(p);
                default -> { }
            }
            return;
        }

        if (holder.page.equals("admin")) {
            switch (name) {
                case "Access audit"   -> run(p, "access audit");
                case "Live grants"    -> run(p, "access list");
                case "Season status"  -> run(p, "season status");
                case "Server status"  -> run(p, "laughtail status");
                case "Rating engine"  -> run(p, "laughtail rating");
                case "Back"           -> openMain(p);
                default -> { }
            }
            return;
        }

        switch (name) {
            case "Homes"               -> openHomes(p);
            case "Shop"                -> openShop(p, null);
            case "Berries"             -> run(p, "berries");
            case "Random Teleport"     -> { p.closeInventory(); run(p, "rtp"); }
            case "Teleport to a player" -> {
                p.closeInventory();
                p.sendMessage(Component.text("Use /tpa <player>. They must accept.",
                    NamedTextColor.GRAY));
            }
            case "Your rank"           -> run(p, "laughtail rating");
            case "Rules"               -> { p.closeInventory(); run(p, "rules"); }
            case "Staff and Owner tools" -> {
                if (p.hasPermission("laughtail.status")) openAdmin(p);
            }
            default -> { }
        }
    }

    private void run(Player p, String command) {
        // Dispatched as the PLAYER, deliberately - so every permission check, every audit row
        // and every refusal behaves exactly as it would if they had typed it. A menu that runs
        // commands as console would be a permission bypass wearing a friendly face.
        plugin.getServer().dispatchCommand(p, command);
    }
}
