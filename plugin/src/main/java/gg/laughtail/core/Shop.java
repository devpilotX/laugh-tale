package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The shop catalogue: what can be traded, at what price, and from what rank.
 *
 * THE SPREAD IS 50%. The shop sells at the listed price and buys back at half of it, so an item listed
 * at 200 pays 100 when sold. The owner asked for exactly this, and it is a much safer shop than the 12%
 * it replaced - buying something and selling it straight back now costs half its value rather than an
 * eighth.
 *
 * THE WIDE SPREAD IS WHAT PAYS FOR THE BIG CATALOGUE. With a thin spread, two items linked by a recipe
 * could always be exploited: buy raw iron at the bottom of its price band, smelt it, sell the ingot at
 * the top of its band. That is why the old catalogue had to leave OUT the smelted form of every ore
 * (D-0036). At a 50% spread against the +/-20% band from V7, the worst case is a 25% LOSS, so ingots,
 * blocks and raw ore can all be listed together - which is what makes "sell everything" possible.
 *
 * PRICES COME FROM RARITY, NOT FROM TASTE. Every item is placed in one of eight bands, and the band sets
 * the price. That is deliberate: with several hundred items, hand-picking each price guarantees that
 * some pair ends up inconsistent, and an inconsistent pair is a money printer. A band is a decision made
 * once and applied uniformly.
 *
 * The anchor is P2's 1,200 Berries an hour. JUNK is what you get thousands of and is priced accordingly;
 * MYTHIC is a full day's play for one item.
 *
 * WHAT IS DELIBERATELY NOT SELLABLE: anything a player cannot legitimately obtain (command blocks,
 * spawners, bedrock, structure voids, debug items). Listing an unobtainable item means the only way to
 * have one is a bug or an admin, and either way the shop should not put a price on it.
 */
final class Shop {

    /** An hour of deliberate play, from P2. */
    static final long HOUR = 1_200L;

    /**
     * The spread. Sell price is buy price times (1 - SPREAD).
     *
     * At 0.50 the sell price is exactly half the buy price, which is what the owner asked for and is
     * what lets the whole catalogue exist. See the class note.
     */
    static final double SPREAD = 0.50;

    /**
     * The P4 price band, as a single source of truth.
     *
     * These were previously written out as 0.6 and 1.4 in Arbitrage and again in Database, and when V7
     * narrowed the band the audit was left testing a band that no longer existed - so it reported 75
     * cycles the repair pass could not see, and the shop stayed closed for a reason that was not real.
     * That is the same class of bug as the spread being computed in two places, which cost a diamond a
     * Berry per sale. One constant, used everywhere.
     */
    static final double BAND_FLOOR = 0.8;
    static final double BAND_CEIL  = 1.2;

    /** The cheapest an item can ever be bought for. */
    static long minBuy(long base) { return Math.max(1L, Math.round(base * BAND_FLOOR)); }

    /** The most an item can ever be sold for. */
    static long maxSell(long base) { return sellPrice(Math.round(base * BAND_CEIL)); }

    /**
     * The eight price bands.
     *
     * The gap between bands widens deliberately as they climb. Rare things should feel rare when you sell
     * one, and if the ladder were linear a diamond would be worth about the same as a few stacks of coal,
     * which is the complaint that started this rewrite.
     */
    private enum Rarity {
        JUNK(1, 1),        // thousands per hour: dirt, cobblestone, gravel
        COMMON(4, 1),      // hundreds per hour: logs, wheat, coal
        PLENTIFUL(12, 1),  // steady income: copper, redstone, kelp blocks
        USEFUL(30, 2),     // iron, gold, quartz - the middle of the game
        VALUABLE(90, 3),   // diamond, emerald, obsidian
        RARE(300, 4),      // shulker shells, heart of the sea, echo shards
        EPIC(1200, 6),     // elytra, netherite, beacons - a full hour each
        MYTHIC(9000, 8);   // dragon egg, nether star - a day of play

        final long price;
        final int tier;
        Rarity(long price, int tier) { this.price = price; this.tier = tier; }
    }

    record Entry(Material material, String category, int tier, long basePrice) { }

    private static final Map<Material, Entry> CATALOGUE = new LinkedHashMap<>();

    /** Registers one material. Later calls win, so overrides can follow bulk additions. */
    private static void put(Material m, String category, Rarity r) {
        if (m == null || m.isAir() || !m.isItem()) return;
        CATALOGUE.put(m, new Entry(m, category, r.tier, r.price));
    }

    /** Registers by name so a material missing from this Minecraft version is skipped, not fatal. */
    private static void put(String name, String category, Rarity r) {
        Material m = Material.getMaterial(name);
        if (m != null) put(m, category, r);
    }

    /** Registers every material whose name contains a fragment - the bulk of the catalogue. */
    private static void putMatching(String fragment, String category, Rarity r) {
        for (Material m : Material.values()) {
            if (!m.isItem() || m.isAir() || m.isLegacy()) continue;
            if (m.name().contains(fragment)) put(m, category, r);
        }
    }

    /**
     * Registers a material at an exact price rather than a band.
     *
     * Used for storage blocks, and the reason is worth stating: a block is not a separate item with its
     * own rarity, it is nine of something. Pricing it by band made a diamond block worth 300 while nine
     * diamonds were worth 810, so the repair pass correctly concluded that a diamond must be worth at
     * most 43 and crushed the price of the most recognisable item in the game.
     *
     * Priced at exactly nine times its contents, the relationship is safe in both directions and the
     * item keeps the value its rarity says it should have. The lesson generalises: a derived item needs a
     * derived price, and a band is only right for something whose value stands on its own.
     */
    private static void putExact(String name, String category, int tier, long price) {
        Material m = Material.getMaterial(name);
        if (m == null || !m.isItem()) return;
        CATALOGUE.put(m, new Entry(m, category, tier, Math.max(1L, price)));
    }
    static {
        // ---- stone and earth: the floor of the economy ------------------------
        for (String s : new String[] { "DIRT", "COARSE_DIRT", "ROOTED_DIRT", "GRASS_BLOCK", "PODZOL",
                "MYCELIUM", "SAND", "RED_SAND", "GRAVEL", "CLAY", "COBBLESTONE", "STONE",
                "COBBLED_DEEPSLATE", "DEEPSLATE", "NETHERRACK", "SOUL_SAND", "SOUL_SOIL",
                "ANDESITE", "DIORITE", "GRANITE", "TUFF", "CALCITE", "BASALT", "SMOOTH_BASALT",
                "BLACKSTONE", "MAGMA_BLOCK", "SNOW_BLOCK", "ICE", "PACKED_ICE", "MOSS_BLOCK",
                "SANDSTONE", "RED_SANDSTONE", "END_STONE", "DRIPSTONE_BLOCK", "POINTED_DRIPSTONE" }) {
            put(s, "stone", Rarity.JUNK);
        }
        putMatching("_STAIRS", "stone", Rarity.JUNK);
        putMatching("_SLAB", "stone", Rarity.JUNK);
        putMatching("_WALL", "stone", Rarity.JUNK);
        putMatching("BRICKS", "stone", Rarity.COMMON);
        putMatching("_CONCRETE", "stone", Rarity.COMMON);
        putMatching("TERRACOTTA", "stone", Rarity.COMMON);
        put("BLUE_ICE", "stone", Rarity.PLENTIFUL);
        put("OBSIDIAN", "stone", Rarity.VALUABLE);
        put("CRYING_OBSIDIAN", "stone", Rarity.RARE);

        // ---- wood ------------------------------------------------------------
        putMatching("_LOG", "wood", Rarity.COMMON);
        putMatching("_WOOD", "wood", Rarity.COMMON);
        putMatching("_PLANKS", "wood", Rarity.COMMON);
        putMatching("_SAPLING", "wood", Rarity.COMMON);
        putMatching("_LEAVES", "wood", Rarity.JUNK);
        putMatching("_FENCE", "wood", Rarity.COMMON);
        putMatching("_DOOR", "wood", Rarity.COMMON);
        put("BAMBOO", "wood", Rarity.JUNK);
        put("STICK", "wood", Rarity.JUNK);

        // ---- ore, ingots and blocks, all three, now that the spread allows it --
        put("COAL", "ore", Rarity.COMMON);
        put("CHARCOAL", "ore", Rarity.COMMON);
        put("RAW_COPPER", "ore", Rarity.PLENTIFUL);
        put("COPPER_INGOT", "ore", Rarity.PLENTIFUL);
        put("REDSTONE", "ore", Rarity.PLENTIFUL);
        put("LAPIS_LAZULI", "ore", Rarity.PLENTIFUL);
        put("RAW_IRON", "ore", Rarity.USEFUL);
        put("IRON_INGOT", "ore", Rarity.USEFUL);
        put("IRON_NUGGET", "ore", Rarity.COMMON);
        put("RAW_GOLD", "ore", Rarity.USEFUL);
        put("GOLD_INGOT", "ore", Rarity.USEFUL);
        put("GOLD_NUGGET", "ore", Rarity.COMMON);
        put("QUARTZ", "ore", Rarity.USEFUL);
        put("AMETHYST_SHARD", "ore", Rarity.USEFUL);
        put("DIAMOND", "ore", Rarity.VALUABLE);
        put("EMERALD", "ore", Rarity.VALUABLE);
        put("ANCIENT_DEBRIS", "ore", Rarity.EPIC);
        put("NETHERITE_SCRAP", "ore", Rarity.EPIC);
        put("NETHERITE_INGOT", "ore", Rarity.EPIC);
        // Storage blocks. Priced by band rather than exactly nine times the item on purpose - see the
        // note at the bottom about why exact multiples are not required at a 50% spread.
        // Storage blocks are priced as NINE of their contents, not by rarity band. See putExact.
        putExact("COAL_BLOCK",      "ore", 1, 9 * Rarity.COMMON.price);
        putExact("COPPER_BLOCK",    "ore", 1, 9 * Rarity.PLENTIFUL.price);
        putExact("REDSTONE_BLOCK",  "ore", 2, 9 * Rarity.PLENTIFUL.price);
        putExact("LAPIS_BLOCK",     "ore", 2, 9 * Rarity.PLENTIFUL.price);
        putExact("IRON_BLOCK",      "ore", 2, 9 * Rarity.USEFUL.price);
        putExact("GOLD_BLOCK",      "ore", 2, 9 * Rarity.USEFUL.price);
        putExact("DIAMOND_BLOCK",   "ore", 3, 9 * Rarity.VALUABLE.price);
        putExact("EMERALD_BLOCK",   "ore", 3, 9 * Rarity.VALUABLE.price);
        putExact("NETHERITE_BLOCK", "ore", 8, 9 * Rarity.EPIC.price);
        // Four shards, not nine.
        putExact("AMETHYST_BLOCK",  "ore", 2, 4 * Rarity.USEFUL.price);
        putExact("QUARTZ_BLOCK",    "ore", 2, 4 * Rarity.USEFUL.price);

        // ---- farming ---------------------------------------------------------
        for (String s : new String[] { "WHEAT", "WHEAT_SEEDS", "CARROT", "POTATO", "BEETROOT",
                "BEETROOT_SEEDS", "MELON_SLICE", "MELON", "PUMPKIN", "SUGAR_CANE", "COCOA_BEANS",
                "SWEET_BERRIES", "GLOW_BERRIES", "KELP", "DRIED_KELP", "SEAGRASS", "CACTUS",
                "VINE", "LILY_PAD", "BROWN_MUSHROOM", "RED_MUSHROOM", "NETHER_WART",
                "TORCHFLOWER_SEEDS", "PITCHER_POD", "HANGING_ROOTS", "GLOW_LICHEN" }) {
            put(s, "farm", Rarity.COMMON);
        }
        putMatching("_FLOWER", "farm", Rarity.COMMON);
        putMatching("SAPLING", "farm", Rarity.COMMON);
        put("HONEYCOMB", "farm", Rarity.PLENTIFUL);
        put("HONEY_BOTTLE", "farm", Rarity.PLENTIFUL);
        put("BEE_NEST", "farm", Rarity.VALUABLE);

        // ---- food ------------------------------------------------------------
        for (String s : new String[] { "BREAD", "COOKED_BEEF", "COOKED_PORKCHOP", "COOKED_CHICKEN",
                "COOKED_MUTTON", "COOKED_RABBIT", "COOKED_COD", "COOKED_SALMON", "BEEF", "PORKCHOP",
                "CHICKEN", "MUTTON", "RABBIT", "COD", "SALMON", "TROPICAL_FISH", "PUFFERFISH",
                "BAKED_POTATO", "PUMPKIN_PIE", "COOKIE", "CAKE", "MUSHROOM_STEW", "RABBIT_STEW",
                "BEETROOT_SOUP", "SUSPICIOUS_STEW", "APPLE", "MILK_BUCKET", "EGG" }) {
            put(s, "food", Rarity.COMMON);
        }
        put("GOLDEN_CARROT", "food", Rarity.PLENTIFUL);
        put("GOLDEN_APPLE", "food", Rarity.USEFUL);
        put("ENCHANTED_GOLDEN_APPLE", "food", Rarity.EPIC);

        // ---- mob drops -------------------------------------------------------
        for (String s : new String[] { "ROTTEN_FLESH", "BONE", "BONE_MEAL", "STRING", "SPIDER_EYE",
                "FEATHER", "LEATHER", "RABBIT_HIDE", "INK_SAC", "GLOW_INK_SAC", "SLIME_BALL",
                "GUNPOWDER", "PHANTOM_MEMBRANE", "SCUTE", "TURTLE_SCUTE" }) {
            put(s, "drops", Rarity.COMMON);
        }
        put("ENDER_PEARL", "drops", Rarity.PLENTIFUL);
        put("BLAZE_ROD", "drops", Rarity.USEFUL);
        put("MAGMA_CREAM", "drops", Rarity.USEFUL);
        put("GHAST_TEAR", "drops", Rarity.VALUABLE);
        put("PRISMARINE_SHARD", "drops", Rarity.PLENTIFUL);
        put("PRISMARINE_CRYSTALS", "drops", Rarity.USEFUL);
        put("NAUTILUS_SHELL", "drops", Rarity.RARE);
        put("HEART_OF_THE_SEA", "drops", Rarity.EPIC);
        put("SHULKER_SHELL", "drops", Rarity.RARE);
        put("ECHO_SHARD", "drops", Rarity.RARE);
        put("TOTEM_OF_UNDYING", "drops", Rarity.EPIC);
        put("DRAGON_BREATH", "drops", Rarity.RARE);
        put("NETHER_STAR", "drops", Rarity.MYTHIC);
        put("WITHER_SKELETON_SKULL", "drops", Rarity.EPIC);
        put("ELYTRA", "drops", Rarity.EPIC);
        put("TRIDENT", "drops", Rarity.EPIC);

        // ---- utility and redstone --------------------------------------------
        for (String s : new String[] { "TORCH", "SOUL_TORCH", "LANTERN", "SOUL_LANTERN", "LADDER",
                "CHEST", "BARREL", "FURNACE", "BLAST_FURNACE", "SMOKER", "CRAFTING_TABLE",
                "SMITHING_TABLE", "STONECUTTER", "GRINDSTONE", "LOOM", "CARTOGRAPHY_TABLE",
                "FLETCHING_TABLE", "COMPOSTER", "SCAFFOLDING", "BUCKET", "GLASS", "GLASS_PANE",
                "GLOWSTONE", "REDSTONE_TORCH", "REPEATER", "COMPARATOR", "PISTON", "STICKY_PISTON",
                "OBSERVER", "DISPENSER", "DROPPER", "HOPPER", "RAIL", "POWERED_RAIL",
                "DETECTOR_RAIL", "ACTIVATOR_RAIL", "MINECART", "TNT", "LEVER", "TRIPWIRE_HOOK",
                "DAYLIGHT_DETECTOR", "TARGET", "NOTE_BLOCK", "JUKEBOX", "BOOKSHELF", "PAPER",
                "BOOK", "STRING", "FLINT", "BRICK", "NETHER_BRICK", "ITEM_FRAME", "ARMOR_STAND",
                "SHIELD", "BOW", "ARROW", "CROSSBOW", "FISHING_ROD", "SHEARS", "FLINT_AND_STEEL",
                "COMPASS", "CLOCK", "SPYGLASS", "LEAD", "NAME_TAG", "SADDLE" }) {
            put(s, "utility", Rarity.PLENTIFUL);
        }
        put("ENDER_CHEST", "utility", Rarity.VALUABLE);
        put("ANVIL", "utility", Rarity.USEFUL);
        put("ENCHANTING_TABLE", "utility", Rarity.VALUABLE);
        put("EXPERIENCE_BOTTLE", "utility", Rarity.USEFUL);
        put("SHULKER_BOX", "utility", Rarity.RARE);
        put("BEACON", "utility", Rarity.EPIC);
        put("CONDUIT", "utility", Rarity.EPIC);
        put("RESPAWN_ANCHOR", "utility", Rarity.RARE);
        put("LODESTONE", "utility", Rarity.RARE);
        put("DRAGON_EGG", "utility", Rarity.MYTHIC);
        put("ELYTRA", "utility", Rarity.EPIC);

        // ---- decoration ------------------------------------------------------
        putMatching("_WOOL", "decor", Rarity.COMMON);
        putMatching("_CARPET", "decor", Rarity.COMMON);
        putMatching("_DYE", "decor", Rarity.COMMON);
        putMatching("_BED", "decor", Rarity.COMMON);
        putMatching("_BANNER", "decor", Rarity.COMMON);
        putMatching("_STAINED_GLASS", "decor", Rarity.COMMON);
        putMatching("CANDLE", "decor", Rarity.COMMON);
        putMatching("GLAZED_TERRACOTTA", "decor", Rarity.PLENTIFUL);
        putMatching("_HEAD", "decor", Rarity.RARE);
        putMatching("MUSIC_DISC", "decor", Rarity.RARE);
        put("PAINTING", "decor", Rarity.COMMON);
        put("FLOWER_POT", "decor", Rarity.COMMON);
        put("SPONGE", "decor", Rarity.RARE);
        put("WET_SPONGE", "decor", Rarity.RARE);

        // ---- brewing ---------------------------------------------------------
        for (String s : new String[] { "GLASS_BOTTLE", "BREWING_STAND", "CAULDRON", "FERMENTED_SPIDER_EYE",
                "GLISTERING_MELON_SLICE", "GOLDEN_CARROT", "RABBIT_FOOT", "SUGAR", "REDSTONE",
                "GLOWSTONE_DUST", "BLAZE_POWDER" }) {
            put(s, "brew", Rarity.PLENTIFUL);
        }

        // ---- WHAT IS REMOVED, and why ----------------------------------------
        // Items a player cannot legitimately obtain. Putting a price on one means the only way to have
        // it is a bug or an admin hand-out, and in either case the shop should not be the thing that
        // turns it into Berries.
        for (String s : new String[] { "BEDROCK", "COMMAND_BLOCK", "CHAIN_COMMAND_BLOCK",
                "REPEATING_COMMAND_BLOCK", "COMMAND_BLOCK_MINECART", "STRUCTURE_BLOCK",
                "STRUCTURE_VOID", "JIGSAW", "BARRIER", "LIGHT", "DEBUG_STICK", "KNOWLEDGE_BOOK",
                "SPAWNER", "TRIAL_SPAWNER", "VAULT", "END_PORTAL_FRAME", "PETRIFIED_OAK_SLAB",
                "FARMLAND", "DIRT_PATH", "BUDDING_AMETHYST", "REINFORCED_DEEPSLATE",
                "INFESTED_STONE", "PLAYER_HEAD" }) {
            Material m = Material.getMaterial(s);
            if (m != null) CATALOGUE.remove(m);
        }
        // Spawn eggs are creative-only.
        CATALOGUE.keySet().removeIf(m -> m.name().endsWith("_SPAWN_EGG"));
        // Anything with durability is excluded: a shop that buys tools has to decide what a
        // half-broken pickaxe is worth, and every answer to that is exploitable.
        CATALOGUE.keySet().removeIf(m -> m.getMaxDurability() > 0
            && m != Material.SHIELD && m != Material.BOW && m != Material.CROSSBOW
            && m != Material.FISHING_ROD && m != Material.SHEARS && m != Material.FLINT_AND_STEEL
            && m != Material.ELYTRA && m != Material.TRIDENT);
        // Those exceptions are then removed too - they are all repairable, so they carry damage.
        for (Material m : new Material[] { Material.SHIELD, Material.BOW, Material.CROSSBOW,
                Material.FISHING_ROD, Material.SHEARS, Material.FLINT_AND_STEEL,
                Material.ELYTRA, Material.TRIDENT }) {
            CATALOGUE.remove(m);
        }
    }

    private Shop() { }

    static Entry entry(Material m) { return CATALOGUE.get(m); }
    static Map<Material, Entry> catalogue() { return CATALOGUE; }
    static int size() { return CATALOGUE.size(); }

    /** Every category present, in a stable order for the GUI. */
    static java.util.List<String> categories() {
        java.util.LinkedHashSet<String> out = new java.util.LinkedHashSet<>();
        for (Entry e : CATALOGUE.values()) out.add(e.category());
        return new java.util.ArrayList<>(out);
    }

    private static final java.util.concurrent.ConcurrentHashMap<Material, Long> PRICE_CACHE =
        new java.util.concurrent.ConcurrentHashMap<>();

    static void cachePrice(Material m, long price) { PRICE_CACHE.put(m, price); }

    /** Display price. Falls back to base, which is the right answer before the first read. */
    static long displayPrice(Material m) {
        Entry e = CATALOGUE.get(m);
        if (e == null) return 0L;
        return PRICE_CACHE.getOrDefault(m, e.basePrice());
    }

    /**
     * Sell price from a buy price. Half, rounded down.
     *
     * FLOOR, NOT ROUND, so the spread can never come out below 50%. Rounding half-up on an odd price
     * would give back one Berry too many - invisible per trade and compounding over millions of them.
     */
    static long sellPrice(long buyPrice) {
        long sell = (long) Math.floor(buyPrice * (1.0 - SPREAD));
        return Math.min(sell, buyPrice - 1);
    }

    /** Row 40. Whether a player may BUY. Selling is never gated (10.3). */
    static boolean canBuy(int peakTier, Entry e) {
        return peakTier >= e.tier();
    }

    static int tierForRp(int rp) {
        return switch (Rating.tierName(rp)) {
            case "Wanderer", "Settler", "Raider" -> 1;
            case "Fighter"   -> 2;
            case "Warrior"   -> 3;
            case "Gladiator" -> 4;
            case "Champion"  -> 5;
            case "Warlord"   -> 6;
            case "Legend"    -> 7;
            case "Mythic"    -> 8;
            default -> 1;
        };
    }

    static int countIn(Player p, Material m) {
        int n = 0;
        for (ItemStack it : p.getInventory().getStorageContents()) {
            if (it != null && it.getType() == m) n += it.getAmount();
        }
        return n;
    }

    static int removeFrom(Player p, Material m, int amount) {
        int remaining = amount;
        ItemStack[] contents = p.getInventory().getStorageContents();
        for (int i = 0; i < contents.length && remaining > 0; i++) {
            ItemStack it = contents[i];
            if (it == null || it.getType() != m) continue;
            int take = Math.min(remaining, it.getAmount());
            it.setAmount(it.getAmount() - take);
            if (it.getAmount() <= 0) contents[i] = null;
            remaining -= take;
        }
        p.getInventory().setStorageContents(contents);
        return amount - remaining;
    }

    static Component describe(Entry e, long buy, boolean allowed) {
        return Component.text(e.material().name(),
                allowed ? NamedTextColor.WHITE : NamedTextColor.DARK_GRAY)
            .append(Component.text("  buy " + buy + "  sell " + sellPrice(buy), NamedTextColor.GRAY));
    }

    /**
     * Lowers an entry's base price. Called only by the arbitrage repair pass.
     *
     * LOWER ONLY, enforced here rather than trusted to the caller. A method that could raise a price
     * would let a bug in the repair pass inflate the economy while claiming to protect it.
     */
    static boolean lowerPrice(Material m, long newBase) {
        Entry e = CATALOGUE.get(m);
        if (e == null || newBase >= e.basePrice() || newBase < 1) return false;
        CATALOGUE.put(m, new Entry(e.material(), e.category(), e.tier(), newBase));
        PRICE_CACHE.remove(m);
        return true;
    }}
