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
    /**
     * Marks a button as not-yet-built.
     *
     * This used to be inferred from the MATERIAL - a list of types treated as inert. That was
     * fragile and had already broken: the Shop button became a real feature while still being a
     * CHEST, so it landed in the inert list and the working button reported itself unbuilt. A
     * marker written into the item is the thing the comment always claimed it was.
     */
    private final org.bukkit.NamespacedKey notBuiltKey;
    private final LaughTailPlugin plugin;
    /**
     * Players who clicked Search and are expected to type next.
     *
     * A CHAT PROMPT rather than an anvil rename box. An anvil GUI is the usual trick for text
     * input, but it needs a real anvil inventory whose behaviour differs between versions, it
     * shows a nonsense repair cost, and it does not work reliably for Bedrock players through
     * Geyser - which 4.4 puts in scope. A chat prompt works identically for everyone.
     */
    /**
     * Players the GUI is waiting on for typed input, and what it will do with it.
     *
     * A CHAT PROMPT rather than an anvil rename box. An anvil GUI is the usual trick for text input,
     * but it needs a real anvil inventory whose behaviour differs between versions, it shows a
     * nonsense repair cost, and it is unreliable for Bedrock players through Geyser - which 4.4 puts
     * in scope. A chat prompt behaves identically for everyone.
     *
     * The value is a command TEMPLATE containing {0}, so one handler serves every prompt. Adding a
     * new one that needs typing costs a template rather than another branch here - and a branch per
     * prompt is how the fifth one ends up subtly different from the first four.
     */
    private final java.util.Map<java.util.UUID, String> pendingInput =
        new java.util.concurrent.ConcurrentHashMap<>();

    Menu(LaughTailPlugin plugin) {
        this.plugin = plugin;
        this.shopItemKey = new org.bukkit.NamespacedKey(plugin, "shop_item");
        this.notBuiltKey = new org.bukkit.NamespacedKey(plugin, "not_built");
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
        ItemStack it = item(m, name, NamedTextColor.DARK_GRAY, List.of(
            whatItWillDo, "", "NOT BUILT YET", blockedBy));
        ItemMeta meta = it.getItemMeta();
        meta.getPersistentDataContainer().set(notBuiltKey,
            org.bukkit.persistence.PersistentDataType.BYTE, (byte) 1);
        it.setItemMeta(meta);
        return it;
    }

    private boolean isNotBuilt(ItemStack it) {
        ItemMeta m = it.getItemMeta();
        return m != null && m.getPersistentDataContainer().has(notBuiltKey,
            org.bukkit.persistence.PersistentDataType.BYTE);
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
        inv.setItem(21, item(Material.PAPER, "Orders / Bazaar", NamedTextColor.AQUA, List.of(
            "Buy and sell orders between players.",
            "They fill even when you are offline.",
            "The order that waited sets the price.")));
        inv.setItem(22, item(Material.PLAYER_HEAD, "Friends", NamedTextColor.AQUA, List.of(
            "Both sides must agree.",
            "Grants no advantage - Law 1.",
            "/friend add, accept, remove, requests")));
        inv.setItem(23, item(Material.WRITTEN_BOOK, "Paths and Story", NamedTextColor.LIGHT_PURPLE,
            List.of("Six Paths, four Houses, and the",
                    "season Chronicle.",
                    "Titles and recognition only -",
                    "never an advantage in a fight.")));
        inv.setItem(24, item(Material.OAK_SIGN, "Leaderboards", NamedTextColor.YELLOW, List.of(
            "Rank, kills, streak, playtime.",
            "No richest list, deliberately.")));
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
                inv.setItem(20, item(Material.OAK_SIGN, "Set a home here", NamedTextColor.AQUA,
                    List.of("Type a name in chat.", "Uses one of your slots.")));
                inv.setItem(24, item(Material.SHEARS, "Delete a home", NamedTextColor.RED,
                    List.of("Type its name in chat.", "The slot stays yours.")));
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
    void openShop(Player p, String category) { openShop(p, category, null); }

    /**
     * The shop page, optionally filtered.
     *
     * `query` matches anywhere in the material name, case-insensitively, so "diamond" finds
     * DIAMOND and "gold" finds both GOLD_INGOT and RAW_GOLD. Substring rather than prefix because
     * players think in nouns, not in Bukkit enum order.
     */
    void openShop(Player p, String category, String query) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final int tier;
            final java.util.Map<Material, Long> prices = new java.util.LinkedHashMap<>();
            try {
                int season = plugin.database().activeSeason();
                tier = Shop.tierForRp(plugin.database().currentRp(p.getUniqueId(), season));
                for (var en : Shop.catalogue().values()) {
                    if (matches(en, category, query)) {
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
                String heading = query != null ? "Shop - search: " + query
                    : category == null ? "Shop" : "Shop - " + category;
                Inventory inv = Bukkit.createInventory(
                    new MenuHolder("shop"), 54,
                    Component.text(heading + "  (your tier " + tier + "/8)",
                        NamedTextColor.GOLD));
                int slot = 0;
                for (var e : Shop.catalogue().values()) {
                    if (!matches(e, category, query)) continue;
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
                inv.setItem(50, item(Material.COMPASS, "Search", NamedTextColor.AQUA, List.of(
                    "Type a name in chat, such as diamond.",
                    "Matches any part of the name.")));
                inv.setItem(51, item(Material.HOPPER, "Sell box",
                    NamedTextColor.YELLOW, List.of("Put items in, see the value, click Sell.",
                        "Daily limit: 3600 Berries per category.")));
                inv.setItem(52, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(53, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }

    /**
     * Asks for a line of text, then runs a command template with it.
     *
     * One helper rather than the same four lines at every call site - a prompt that forgets to close
     * the inventory leaves the player typing into a menu they cannot see.
     */
    private void prompt(Player p, String template, String question) {
        p.closeInventory();
        pendingInput.put(p.getUniqueId(), template);
        p.sendMessage(Component.text(question + ", or type cancel.", NamedTextColor.AQUA));
    }

    private boolean matches(Shop.Entry e, String category, String query) {
        if (query != null) {
            return e.material().name().toLowerCase().contains(query.toLowerCase());
        }
        return category == null || e.category().equals(category);
    }

    /**
     * The stats page. Everything the server knows about you, in one place.
     *
     * Shows what is TRACKED rather than what flatters - deaths next to kills, and the K/D derived
     * rather than stored, so it cannot disagree with its own inputs.
     */
    void openStats(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final int[] kd;
            final int rp, season, champs;
            final long berries;
            try {
                season = plugin.database().activeSeason();
                rp = plugin.database().currentRp(p.getUniqueId(), season);
                kd = plugin.database().killsAndDeaths(p.getUniqueId());
                berries = plugin.database().balance(p.getUniqueId());
                champs = plugin.database().championSeasons(p.getUniqueId()).size();
            } catch (java.sql.SQLException e) {
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    p.sendMessage(Component.text("Could not read your stats.",
                        NamedTextColor.RED)));
                return;
            }
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                Inventory inv = Bukkit.createInventory(new MenuHolder("stats"), 27,
                    Component.text("Your stats", NamedTextColor.AQUA));
                String ratio = kd[1] == 0
                    ? (kd[0] == 0 ? "no fights yet" : kd[0] + ".00 (no deaths)")
                    : String.format("%.2f", (double) kd[0] / kd[1]);
                inv.setItem(10, item(Material.IRON_SWORD, "Rank: " + Rating.tierName(rp),
                    NamedTextColor.RED, List.of(rp + " RP",
                        "Rank comes from PvP and nothing else.",
                        "Mining and building change it by zero.")));
                inv.setItem(11, item(Material.SKELETON_SKULL, "Kills " + kd[0]
                    + " / Deaths " + kd[1], NamedTextColor.WHITE, List.of("K/D " + ratio,
                        "Derived, not stored - it cannot",
                        "disagree with its own inputs.")));
                inv.setItem(12, item(Material.GOLD_NUGGET, "Berries: " + berries,
                    NamedTextColor.GOLD, List.of("There is no richest leaderboard.",
                        "It would reward hoarding and tell",
                        "thieves who to target.")));
                inv.setItem(13, item(Material.CLOCK, season > 0 ? "Season " + season
                    : "No active season", NamedTextColor.LIGHT_PURPLE, List.of(
                        "Seasons are monthly.",
                        "Berries, stats and homes survive a reset.")));
                if (champs > 0) {
                    inv.setItem(14, item(Material.GOLDEN_HELMET, "Champion x" + champs,
                        NamedTextColor.GOLD, List.of("Kept forever.",
                            "Worth nothing in gameplay, deliberately -",
                            "a Champion with an edge would make the",
                            "next season unfair by construction.")));
                }
                inv.setItem(16, item(Material.PAPER, "Leaderboards", NamedTextColor.YELLOW,
                    List.of("Rank, kills, streak and playtime.", "Runs /top.")));
                inv.setItem(20, item(Material.OAK_SIGN, "Set a home here", NamedTextColor.AQUA,
                    List.of("Type a name in chat.", "Uses one of your slots.")));
                inv.setItem(24, item(Material.SHEARS, "Delete a home", NamedTextColor.RED,
                    List.of("Type its name in chat.", "The slot stays yours.")));
                inv.setItem(18, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(26, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }

    /**
     * The bazaar page. Your orders, and how to make one.
     *
     * Deliberately does NOT place an order by clicking. An order needs a quantity AND a price, and a
     * chest GUI has no way to ask for a number - every plugin that tries ends up with a
     * click-to-increment mess where setting 347 takes forty clicks. The page shows what exists, lets
     * you collect winnings, and names the one command that creates an order. That is honest about
     * where a chest interface stops being the right tool.
     */
    void openBazaar(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final List<String> mine;
            try {
                mine = plugin.database().myOrders(p.getUniqueId());
            } catch (java.sql.SQLException e) {
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    p.sendMessage(Component.text("Could not read your orders.",
                        NamedTextColor.RED)));
                return;
            }
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                Inventory inv = Bukkit.createInventory(new MenuHolder("bazaar"), 54,
                    Component.text("Bazaar - " + mine.size() + " of your orders",
                        NamedTextColor.GOLD));
                int slot = 0;
                for (String line : mine) {
                    if (slot >= 45) break;
                    boolean collectable = line.contains("to collect");
                    inv.setItem(slot++, item(
                        collectable ? Material.GOLD_INGOT : Material.PAPER,
                        line.length() > 32 ? line.substring(0, 32) : line,
                        collectable ? NamedTextColor.GOLD : NamedTextColor.WHITE,
                        List.of(line, "", collectable
                            ? "Click Collect below to take this."
                            : "Cancel with /order cancel <id>.")));
                }
                if (mine.isEmpty()) {
                    inv.setItem(22, item(Material.BARRIER, "You have no orders",
                        NamedTextColor.GRAY, List.of(
                            "An order needs a quantity and a price,",
                            "which a chest cannot ask for. Use:",
                            "/order buy <item> <qty> <price>",
                            "/order sell <item> <qty> <price>")));
                }
                inv.setItem(48, item(Material.HOPPER, "Collect everything",
                    NamedTextColor.GREEN, List.of("Takes the Berries and items",
                        "your filled orders earned.")));
                inv.setItem(49, item(Material.COMPASS, "How the bazaar works",
                    NamedTextColor.AQUA, List.of(
                        "Orders fill even when you are offline.",
                        "The order that waited sets the price,",
                        "so patience is rewarded, not punished.",
                        "You cannot trade with yourself.")));
                inv.setItem(50, item(Material.CHEST, "Shop instead", NamedTextColor.YELLOW,
                    List.of("Instant, at the server price.",
                        "The bazaar is player to player.")));
                inv.setItem(52, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(53, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }
    /**
     * The roleplay page: Paths, House, titles and the Chronicle.
     *
     * The six Path buttons show level and progress, and clicking one focuses it on the HUD - which is
     * the only action on this page that changes anything, and it changes a display. That is the whole
     * system in miniature: everything here is identity, nothing is power.
     */
    void openRoleplay(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final java.util.Map<Path, long[]> paths;
            final String house;
            final int titleCount;
            final Database.ChapterView chapter;
            try {
                paths = plugin.database().allPaths(p.getUniqueId());
                house = plugin.database().myHouse(p.getUniqueId());
                titleCount = plugin.database().ownedTitles(p.getUniqueId()).size();
                chapter = plugin.database().currentChapter();
            } catch (java.sql.SQLException e) {
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    p.sendMessage(Component.text("Could not read your roleplay progress.",
                        NamedTextColor.RED)));
                return;
            }
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                Inventory inv = Bukkit.createInventory(new MenuHolder("roleplay"), 45,
                    Component.text("Paths, House and Story", NamedTextColor.LIGHT_PURPLE));
                Material[] icons = {
                    Material.IRON_PICKAXE, Material.WHEAT, Material.BOW,
                    Material.COMPASS, Material.CRAFTING_TABLE, Material.EMERALD
                };
                int i = 0;
                for (Path path : Path.values()) {
                    long[] v = paths.getOrDefault(path, new long[] { 0, 0 });
                    long xp = v[0];
                    int level = (int) v[1];
                    inv.setItem(10 + i, item(icons[i], path.display() + "  level " + level,
                        NamedTextColor.WHITE, List.of(
                            path.blurb(),
                            "",
                            Path.bar(xp) + "  " + xp + " xp",
                            level >= Path.MAX_LEVEL ? "Mastered."
                                : "Next level at " + Path.xpForLevel(level + 1) + " xp",
                            "",
                            "Click to show this on your HUD.",
                            "Grants titles only - never an advantage.")));
                    i++;
                }
                inv.setItem(29, item(Material.WHITE_BANNER,
                    house == null ? "No House" : house,
                    NamedTextColor.GOLD, house == null
                        ? List.of("Four Houses: Ember, Tide,", "Verdant, Ashen.",
                                  "/house join <name>")
                        : List.of("Standing comes from everything",
                                  "members do, not only fighting.",
                                  "/house to see the standings")));
                inv.setItem(31, item(Material.NAME_TAG, "Titles: " + titleCount,
                    NamedTextColor.AQUA, List.of("Earned from Paths, Chronicles",
                        "and Champion wins.", "/title to choose one")));
                inv.setItem(33, item(Material.WRITTEN_BOOK,
                    chapter == null ? "The Chronicle has not begun"
                        : "Chapter " + chapter.chapter() + " - " + chapter.title(),
                    NamedTextColor.LIGHT_PURPLE, List.of(
                        "The season story. Everyone's",
                        "work counts toward it.",
                        "Click to read.")));
                // The three chat commands are reachable here too. A chest cannot hold a sentence, so
                // these prompt for one - which is the same pattern the shop search and the pay amount
                // use. Without them a player who never reads a command list never finds /me at all.
                inv.setItem(38, item(Material.FEATHER, "Describe an action", NamedTextColor.LIGHT_PURPLE,
                    List.of("Runs /me. Seen within 100 blocks.", "Type it in chat when asked.")));
                inv.setItem(40, item(Material.PAPER, "Speak locally", NamedTextColor.DARK_AQUA,
                    List.of("Runs /local. Only people who can", "see you will hear it.")));
                inv.setItem(42, item(Material.BELL, "Speak to your House", NamedTextColor.GOLD,
                    List.of("Runs /hc. Reaches members", "wherever they are.")));
                inv.setItem(36, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(44, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }
    /**
     * A player picker. One head per online player, and a click runs an action against them.
     *
     * ONE PAGE SERVES PAY, TELEPORT AND FRIEND REQUESTS, because they are the same interaction -
     * choose a person, then do a thing. Three near-identical pages would drift apart, and the third
     * one would be the one missing the confirmation.
     *
     * ONLY ONLINE PLAYERS ARE LISTED. An offline list would need every player who ever joined, which
     * grows without limit and cannot be paged usefully in a chest. Paying or friending someone offline
     * still works by typing their name, and the page says so.
     */
    void openPlayers(Player p, String action) {
        Inventory inv = Bukkit.createInventory(new MenuHolder("players:" + action), 54,
            Component.text(switch (action) {
                case "pay" -> "Pay whom?";
                case "tpa" -> "Teleport to whom?";
                case "tpahere" -> "Ask whom to come here?";
                default -> "Add whom as a friend?";
            }, NamedTextColor.AQUA));
        int slot = 0;
        for (Player other : plugin.getServer().getOnlinePlayers()) {
            if (other.equals(p) || slot >= 45) continue;
            ItemStack head = new ItemStack(Material.PLAYER_HEAD);
            org.bukkit.inventory.meta.SkullMeta sm =
                (org.bukkit.inventory.meta.SkullMeta) head.getItemMeta();
            sm.setOwningPlayer(other);
            sm.displayName(Component.text(other.getName(), NamedTextColor.WHITE)
                .decoration(TextDecoration.ITALIC, false));
            sm.lore(java.util.List.of(
                Component.text("Click to " + switch (action) {
                    case "pay" -> "pay them Berries";
                    case "tpa" -> "ask to teleport to them";
                    case "tpahere" -> "ask them to come to you";
                    default -> "send a friend request";
                }, NamedTextColor.GRAY).decoration(TextDecoration.ITALIC, false)));
            head.setItemMeta(sm);
            inv.setItem(slot++, head);
        }
        if (slot == 0) {
            inv.setItem(22, item(Material.BARRIER, "Nobody else is online",
                NamedTextColor.GRAY, List.of("This list shows online players only.",
                    "For someone offline, type their name:",
                    action.equals("pay") ? "/pay <name> <amount>"
                        : action.equals("friend") ? "/friend add <name>" : "/tpa <name>")));
        }
        inv.setItem(49, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
        inv.setItem(53, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
        p.openInventory(inv);
    }

    /**
     * Amount presets for a payment.
     *
     * Presets plus a typed option, rather than click-to-increment. Incrementing is the usual chest-GUI
     * answer to numbers and it is miserable: paying 3,470 would take dozens of clicks. Four common
     * amounts cover most payments and the typed option covers the rest honestly.
     */
    void openPayAmount(Player p, String target) {
        Inventory inv = Bukkit.createInventory(new MenuHolder("pay:" + target), 27,
            Component.text("Pay " + target, NamedTextColor.GOLD));
        int[] amounts = { 100, 500, 1000, 5000 };
        Material[] icons = { Material.IRON_NUGGET, Material.GOLD_NUGGET,
                             Material.GOLD_INGOT, Material.GOLD_BLOCK };
        for (int i = 0; i < amounts.length; i++) {
            inv.setItem(10 + i, item(icons[i], String.valueOf(amounts[i]),
                NamedTextColor.YELLOW, List.of("Send " + amounts[i] + " Berries to " + target,
                    amounts[i] > 5000 ? "A 5% tax applies above 5000." : "No tax at or below 5000.")));
        }
        inv.setItem(15, item(Material.WRITABLE_BOOK, "Another amount", NamedTextColor.AQUA,
            List.of("Type the amount in chat.", "Anything over 5000 carries a 5% tax.")));
        inv.setItem(18, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
        inv.setItem(26, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
        p.openInventory(inv);
    }

    /** Berries: balance, the rich list, and where money comes from. */
    void openEconomy(Player p) {
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            final long bal;
            final java.util.List<String> top;
            try {
                bal = plugin.database().balance(p.getUniqueId());
                top = plugin.database().topBalances(8);
            } catch (java.sql.SQLException e) {
                plugin.getServer().getScheduler().runTask(plugin, () ->
                    p.sendMessage(Component.text("Could not read your balance.",
                        NamedTextColor.RED)));
                return;
            }
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                Inventory inv = Bukkit.createInventory(new MenuHolder("economy"), 45,
                    Component.text("Berries", NamedTextColor.GOLD));
                inv.setItem(4, item(Material.GOLD_INGOT, "You have " + bal + " Berries",
                    NamedTextColor.GOLD, List.of("One currency, server-wide.",
                        "There is no second currency and",
                        "there never will be - that is how",
                        "servers hyperinflate.")));
                inv.setItem(20, item(Material.PLAYER_HEAD, "Pay someone", NamedTextColor.GREEN,
                    List.of("Send Berries to another player.",
                        "Over 5000 carries a 5% tax.")));
                inv.setItem(22, item(Material.CHEST, "Shop", NamedTextColor.YELLOW,
                    List.of("Buy and sell at server prices.")));
                inv.setItem(24, item(Material.PAPER, "Bazaar", NamedTextColor.AQUA,
                    List.of("Trade with other players.")));
                int slot = 28;
                inv.setItem(slot++, item(Material.DIAMOND, "Richest players",
                    NamedTextColor.LIGHT_PURPLE, top.isEmpty()
                        ? List.of("Nobody has any Berries yet.")
                        : top));
                // The three chat commands are reachable here too. A chest cannot hold a sentence, so
                // these prompt for one - which is the same pattern the shop search and the pay amount
                // use. Without them a player who never reads a command list never finds /me at all.
                inv.setItem(38, item(Material.FEATHER, "Describe an action", NamedTextColor.LIGHT_PURPLE,
                    List.of("Runs /me. Seen within 100 blocks.", "Type it in chat when asked.")));
                inv.setItem(40, item(Material.PAPER, "Speak locally", NamedTextColor.DARK_AQUA,
                    List.of("Runs /local. Only people who can", "see you will hear it.")));
                inv.setItem(42, item(Material.BELL, "Speak to your House", NamedTextColor.GOLD,
                    List.of("Runs /hc. Reaches members", "wherever they are.")));
                inv.setItem(36, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
                inv.setItem(44, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
                p.openInventory(inv);
            });
        });
    }

    /**
     * Pending teleport requests, with accept and deny.
     *
     * This page exists because /tpaccept was previously reachable only by typing, which means a player
     * who does not read chat closely never discovers it - and a teleport request that is never answered
     * looks like a broken feature to whoever sent it.
     */
    void openRequests(Player p) {
        Inventory inv = Bukkit.createInventory(new MenuHolder("requests"), 27,
            Component.text("Teleport requests", NamedTextColor.AQUA));
        inv.setItem(11, item(Material.LIME_DYE, "Accept", NamedTextColor.GREEN,
            List.of("Accept the request waiting for you.",
                    "Refused while you are in combat -",
                    "accepting is what moves you.")));
        inv.setItem(15, item(Material.RED_DYE, "Deny", NamedTextColor.RED,
            List.of("Refuse it. They are told.")));
        inv.setItem(13, item(Material.ENDER_PEARL, "Send a request", NamedTextColor.AQUA,
            List.of("Choose someone to teleport to.")));
        inv.setItem(18, item(Material.ARROW, "Back", NamedTextColor.GRAY, List.of()));
        inv.setItem(26, item(Material.BARRIER, "Close", NamedTextColor.RED, List.of()));
        p.openInventory(inv);
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
        if (isNotBuilt(clicked)) {
            p.sendMessage(Component.text(name + " is not built yet. "
                + "The menu says so rather than pretending.", NamedTextColor.DARK_GRAY));
            return;
        }

        if (holder.page.startsWith("shop")) {
            switch (name) {
                case "Ore"     -> openShop(p, "ore");
                case "Farm"    -> openShop(p, "farm");
                case "Drops"   -> openShop(p, "drops");
                case "Wood"    -> openShop(p, "wood");
                case "Special" -> openShop(p, "special");
                case "Back"    -> openMain(p);
                case "Sell box" -> { p.closeInventory(); plugin.sellBox().open(p); }
                case "Search" -> {
                    p.closeInventory();
                    pendingInput.put(p.getUniqueId(), "\u0000search");
                    p.sendMessage(Component.text("Type what you are looking for, or cancel.",
                        NamedTextColor.AQUA));
                }
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

        if (holder.page.equals("roleplay")) {
            switch (clicked.getType()) {
                case ARROW -> openMain(p);
                case WRITTEN_BOOK -> { p.closeInventory(); run(p, "chronicle"); }
                case WHITE_BANNER -> { p.closeInventory(); run(p, "house"); }
                case FEATHER -> prompt(p, "me {0}", "Describe what you are doing");
                case BELL -> prompt(p, "hc {0}", "What do you want to tell your House");
                case NAME_TAG -> { p.closeInventory(); run(p, "title"); }
                case PAPER -> prompt(p, "local {0}", "What do you want to say");
                default -> {
                    // A Path button. The display name starts with the Path name, so it is matched by
                    // prefix rather than by exact text - the label carries a level that changes.
                    for (Path path : Path.values()) {
                        if (name.startsWith(path.display())) {
                            p.closeInventory();
                            run(p, "path focus " + path.key());
                            return;
                        }
                    }
                }
            }
            return;
        }

        if (holder.page.startsWith("players:")) {
            String action = holder.page.substring("players:".length());
            if (clicked.getType() == Material.ARROW) { openMain(p); return; }
            if (clicked.getType() != Material.PLAYER_HEAD) return;
            // The head's display name is the target. Read from the item rather than from a map, so a
            // stale server-side map cannot send Berries to the wrong person.
            switch (action) {
                case "pay" -> openPayAmount(p, name);
                case "tpa" -> { p.closeInventory(); run(p, "tpa " + name); }
                case "tpahere" -> { p.closeInventory(); run(p, "tpahere " + name); }
                default -> { p.closeInventory(); run(p, "friend add " + name); }
            }
            return;
        }

        if (holder.page.startsWith("pay:")) {
            String target = holder.page.substring("pay:".length());
            if (clicked.getType() == Material.ARROW) { openPlayers(p, "pay"); return; }
            if (clicked.getType() == Material.WRITABLE_BOOK) {
                p.closeInventory();
                pendingInput.put(p.getUniqueId(), "pay " + target + " {0}");
                p.sendMessage(Component.text("Type the amount to send " + target
                    + ", or cancel.", NamedTextColor.AQUA));
                return;
            }
            if (name.matches("\\d+")) {
                p.closeInventory();
                run(p, "pay " + target + " " + name);
            }
            return;
        }

        if (holder.page.equals("economy")) {
            switch (name) {
                case "Back" -> openMain(p);
                case "Pay someone" -> openPlayers(p, "pay");
                case "Shop" -> openShop(p, null);
                case "Bazaar" -> openBazaar(p);
                default -> { }
            }
            return;
        }

        if (holder.page.equals("requests")) {
            switch (name) {
                case "Back" -> openMain(p);
                case "Accept" -> { p.closeInventory(); run(p, "tpaccept"); }
                case "Deny" -> { p.closeInventory(); run(p, "tpdeny"); }
                case "Send a request" -> openPlayers(p, "tpa");
                default -> { }
            }
            return;
        }
        if (holder.page.equals("bazaar")) {
            switch (name) {
                case "Back" -> openMain(p);
                case "Collect everything" -> { p.closeInventory(); run(p, "order claim"); }
                case "Shop instead" -> openShop(p, null);
                default -> { }
            }
            return;
        }

        if (holder.page.equals("stats")) {
            switch (name) {
                case "Back" -> openMain(p);
                case "Leaderboards" -> { p.closeInventory(); run(p, "top rank"); }
                default -> { }
            }
            return;
        }

        if (holder.page.equals("homes")) {
            switch (clicked.getType()) {
                case RED_BED -> { p.closeInventory(); run(p, "home " + name); }
                case OAK_SIGN -> {
                    p.closeInventory();
                    pendingInput.put(p.getUniqueId(), "sethome {0}");
                    p.sendMessage(Component.text("Type a name for this home, or cancel.",
                        NamedTextColor.AQUA));
                }
                case SHEARS -> {
                    p.closeInventory();
                    pendingInput.put(p.getUniqueId(), "delhome {0}");
                    p.sendMessage(Component.text("Type the name of the home to delete, or cancel.",
                        NamedTextColor.AQUA));
                }
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
            case "Your rank", "Your stats" -> openStats(p);
            case "Shop"                -> openShop(p, null);
            case "Orders / Bazaar"     -> openBazaar(p);
            case "Paths and Story"     -> openRoleplay(p);
            case "Friends"             -> { p.closeInventory(); run(p, "friend list"); }
            case "Leaderboards"        -> { p.closeInventory(); run(p, "top rank"); }
            case "Berries"             -> openEconomy(p);
            case "Random Teleport"     -> { p.closeInventory(); run(p, "rtp"); }
            case "Teleport to a player" -> openRequests(p);
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

    /**
     * Catches the typed search term.
     *
     * Handled at MONITOR with ignoreCancelled so a search term is never broadcast to chat - a
     * player typing "diamond" to search should not appear to be announcing it. Runs on the async
     * chat thread, so the menu is opened back on the main thread.
     */
    @EventHandler(priority = org.bukkit.event.EventPriority.LOWEST)
    public void onChat(io.papermc.paper.event.player.AsyncChatEvent e) {
        Player p = e.getPlayer();
        String template = pendingInput.remove(p.getUniqueId());
        if (template == null) return;
        // Cancelled so a typed answer is never broadcast. Somebody typing an amount to pay a friend
        // should not appear to be announcing it to the server.
        e.setCancelled(true);
        String typed = net.kyori.adventure.text.serializer.plain.PlainTextComponentSerializer
            .plainText().serialize(e.message()).trim();
        if (typed.isEmpty() || typed.equalsIgnoreCase("cancel")) {
            plugin.getServer().getScheduler().runTask(plugin, () -> {
                p.sendMessage(Component.text("Cancelled.", NamedTextColor.GRAY));
                openMain(p);
            });
            return;
        }
        // Bounded. An unbounded string can end up in an inventory title, and a very long title is a
        // client-side crash on some versions.
        final String answer = typed.length() > 32 ? typed.substring(0, 32) : typed;

        if (template.equals("\u0000search")) {
            plugin.getServer().getScheduler().runTask(plugin, () -> openShop(p, null, answer));
            return;
        }
        // Anything else is a command template. Dispatched AS THE PLAYER, so permissions, audit rows
        // and refusals behave exactly as if they had typed the whole thing.
        final String command = template.replace("{0}", answer);
        plugin.getServer().getScheduler().runTask(plugin, () -> run(p, command));
    }

    @EventHandler
    public void onSearchQuit(org.bukkit.event.player.PlayerQuitEvent e) {
        // Otherwise a player who quits mid-prompt would have their next message eaten on rejoin.
        pendingInput.remove(e.getPlayer().getUniqueId());
    }}
