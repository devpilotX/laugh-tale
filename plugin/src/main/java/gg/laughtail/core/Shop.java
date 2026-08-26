package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The shop catalogue and the price derivation.
 *
 * BASE PRICES ARE DERIVED FROM P2, not invented per item. `target_berries_per_hour` is 1,200, so
 * every base price is an answer to "how much of this does an hour of deliberate play produce?".
 * Iron at 20 means roughly 60 ingots an hour is a full hour's income, which is about right for
 * someone mining with purpose. Cobblestone at 1 means you would need 1,200 an hour, which is also
 * about right - it is nearly worthless because it nearly is.
 *
 * Deriving rather than hand-picking matters because P2 is the single anchor the whole economy
 * hangs from. If the owner later changes 1,200, every price should move with it - and it will,
 * because the numbers below are multipliers of an hour rather than absolute figures someone chose.
 *
 * THE SELL PRICE IS ALWAYS `buy * (1 - 0.12)` (P3's 12% spread). That is the server's cut and the
 * anti-arbitrage margin in one, and it is why the Phase 3 audit can never find a buy-then-sell
 * loop that yields a profit: selling back always loses 12%.
 *
 * TIERS GATE BUYING, NEVER SELLING. 10.3 is explicit that selling is never gated - a new player
 * must be able to convert what they mine into Berries from the first minute, or the economy has no
 * entry point. Tiers only restrict what you may BUY, which is what makes rank worth having without
 * making poverty a trap.
 */
final class Shop {

    /** An hour of deliberate play, from P2. Every base price is a fraction of this. */
    static final long HOUR = 1_200L;
    /** P3: the minimum spread. Sell price is buy price less this. */
    static final double SPREAD = 0.12;

    record Entry(Material material, String category, int tier, long basePrice) { }

    /**
     * The catalogue. `unitsPerHour` is the honest question behind each price: how many of these
     * does an hour of focused play yield? Base price is HOUR divided by that.
     *
     * Tier is what rank a player must have REACHED to buy it (10.2's eight tiers). Everything at
     * tier 1 is available immediately, which keeps the shop useful to a brand new player.
     */
    private static final Map<Material, Entry> CATALOGUE = new LinkedHashMap<>();

    private static void add(Material m, String category, int tier, long unitsPerHour) {
        CATALOGUE.put(m, new Entry(m, category, tier, Math.max(1L, HOUR / unitsPerHour)));
    }

    static {
        // NOTE ON WHAT IS DELIBERATELY ABSENT: IRON_INGOT, GOLD_INGOT, NETHERITE_SCRAP and STONE.
        //
        // Each is the OUTPUT of a smelting recipe whose INPUT is also in this catalogue, and the
        // arbitrage audit caught all four as money printers on its first run: buy raw iron at the
        // bottom of its band for 12, smelt it, sell the ingot at the top of its band for 24.
        //
        // The root cause is structural, not a wrong number. Two items linked by a recipe hold
        // INDEPENDENT prices, and the P4 band lets them drift apart by 1.4/0.6 = 2.33x, which
        // swamps the 12% spread entirely. No choice of base prices fixes it while both sides are
        // priced independently - to be safe the ingot would have to be worth under half the ore,
        // which is absurd and would confuse every player who saw it.
        //
        // So only ONE side of each transformation is priced. Players sell what they mine, which is
        // the raw form; ingots stay for crafting. The alternative considered was linked price groups
        // that move together - more elegant, more machinery - recorded in decisions.md as the option
        // to reach for if the catalogue ever needs both sides sellable.
        // --- ore and mining. The bulk of early income. -------------------------
        add(Material.COBBLESTONE,     "ore",     1, 1200);   // 1
        add(Material.COAL,            "ore",     1, 150);    // 8
        add(Material.RAW_COPPER,      "ore",     1, 100);    // 12
        add(Material.RAW_IRON,        "ore",     1, 60);     // 20
        add(Material.REDSTONE,        "ore",     2, 120);    // 10
        add(Material.LAPIS_LAZULI,    "ore",     2, 100);    // 12
        add(Material.RAW_GOLD,        "ore",     2, 34);     // 35
        add(Material.QUARTZ,          "ore",     3, 60);     // 20
        add(Material.AMETHYST_SHARD,  "ore",     3, 40);     // 30
        add(Material.DIAMOND,         "ore",     4, 10);     // 120
        add(Material.EMERALD,         "ore",     4, 12);     // 100
        add(Material.ANCIENT_DEBRIS,  "ore",     6, 2);      // 600

        // --- farming. Lower value per unit, far higher throughput. -------------
        add(Material.WHEAT,           "farm",    1, 200);
        add(Material.CARROT,          "farm",    1, 200);
        add(Material.POTATO,          "farm",    1, 200);
        add(Material.SUGAR_CANE,      "farm",    1, 240);
        add(Material.MELON_SLICE,     "farm",    1, 300);
        add(Material.PUMPKIN,         "farm",    1, 120);
        add(Material.BAMBOO,          "farm",    1, 600);
        add(Material.NETHER_WART,     "farm",    2, 150);
        add(Material.HONEYCOMB,       "farm",    3, 60);

        // --- mob drops. Rewards combat with the world, not with players. -------
        add(Material.ROTTEN_FLESH,    "drops",   1, 400);
        add(Material.BONE,            "drops",   1, 200);
        add(Material.STRING,          "drops",   1, 200);
        add(Material.GUNPOWDER,       "drops",   2, 80);
        add(Material.ENDER_PEARL,     "drops",   3, 24);
        add(Material.BLAZE_ROD,       "drops",   4, 20);
        add(Material.GHAST_TEAR,      "drops",   5, 8);
        add(Material.NETHER_STAR,     "drops",   8, 1);      // 1200 - a full hour

        // --- wood and building ------------------------------------------------
        add(Material.OAK_LOG,         "wood",    1, 300);
        add(Material.SPRUCE_LOG,      "wood",    1, 300);
        add(Material.BIRCH_LOG,       "wood",    1, 300);
        add(Material.DARK_OAK_LOG,    "wood",    1, 300);

        // --- higher tiers. What rank actually unlocks. --------------------------
        add(Material.OBSIDIAN,        "special", 3, 30);
        add(Material.EXPERIENCE_BOTTLE, "special", 4, 40);
        add(Material.SHULKER_SHELL,   "special", 5, 6);
        add(Material.ELYTRA,          "special", 7, 1);
        add(Material.BEACON,          "special", 7, 1);
        add(Material.ENCHANTED_GOLDEN_APPLE, "special", 8, 2);
        add(Material.DRAGON_EGG,      "special", 8, 1);
    }

    /**
     * Last known price per item, for rendering only.
     *
     * A GUI must be built on the main thread, but prices live in the database and row 25 forbids
     * querying there. Without a cache every menu render would either block the server or show
     * nothing. Database.currentPrice writes through to this on every read, and the shop is seeded
     * at boot, so the cache is populated before any player can open a menu. It is deliberately
     * NEVER the source of truth for a transaction - buy and sell re-read the price under the
     * transaction lock, because a stale cache used for a charge would let a player pay yesterday's
     * price for today's item.
     */
    private static final java.util.concurrent.ConcurrentHashMap<Material, Long> PRICE_CACHE =
        new java.util.concurrent.ConcurrentHashMap<>();

    static void cachePrice(Material m, long price) { PRICE_CACHE.put(m, price); }

    /** Display price. Falls back to base, which is the right answer before the first read. */
    static long displayPrice(Material m) {
        Entry e = CATALOGUE.get(m);
        if (e == null) return 0L;
        return PRICE_CACHE.getOrDefault(m, e.basePrice());
    }

    private Shop() { }

    static Entry entry(Material m) {
        return CATALOGUE.get(m);
    }

    static Map<Material, Entry> catalogue() {
        return CATALOGUE;
    }

    /**
     * Sell price from a buy price. P3's spread, always applied, never negotiable.
     *
     * FLOOR, NOT ROUND. Rounding half-up can push the sell price a fraction ABOVE the 12% floor -
     * a diamond at 120 rounds to 106, which is a 11.7% spread, under the minimum P3 sets. The
     * error is under one Berry per unit and would never be noticed by a player, which is exactly
     * why it is worth fixing: it is invisible per trade and compounds over millions of them, and
     * "minimum 12%" has to actually be a minimum or it is not a floor at all. The shop invariant
     * test asserts this with no tolerance.
     */
    static long sellPrice(long buyPrice) {
        long sell = (long) Math.floor(buyPrice * (1.0 - SPREAD));
        // A 1-Berry item would round to 1 and the spread would vanish, which is exactly the
        // rounding hole a buy-then-sell loop exploits. Floor it to zero instead: cobblestone is
        // worth buying for 1 and worth nothing to sell back, which is honest.
        return Math.min(sell, buyPrice - 1);
    }

    /**
     * Row 40. Whether a player may BUY this entry.
     *
     * Checked against PEAK tier rather than current, because 10.x gates on what a player has
     * reached - a bad week should not revoke access to items they earned. Selling is never gated
     * (10.3), so there is deliberately no matching canSell.
     */
    static boolean canBuy(int peakTier, Entry e) {
        return peakTier >= e.tier();
    }

    /** The tier a rating corresponds to, 1-8. Maps the ten rank tiers onto eight shop tiers. */
    static int tierForRp(int rp) {
        String rank = Rating.tierName(rp);
        return switch (rank) {
            case "Wanderer", "Settler" -> 1;
            case "Raider"    -> 1;
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

    /** Counts how many of a material a player is carrying. */
    static int countIn(Player p, Material m) {
        int n = 0;
        for (ItemStack it : p.getInventory().getStorageContents()) {
            if (it != null && it.getType() == m) n += it.getAmount();
        }
        return n;
    }

    /** Removes exactly `amount`, returning how many were actually taken. */
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
        return Component.text(e.material().name(), allowed ? NamedTextColor.WHITE : NamedTextColor.DARK_GRAY)
            .append(Component.text("  buy " + buy + "  sell " + sellPrice(buy),
                NamedTextColor.GRAY));
    }
}
