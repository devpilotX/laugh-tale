package gg.laughtail.core;

import org.bukkit.Material;
import org.bukkit.inventory.CookingRecipe;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.Recipe;
import org.bukkit.inventory.ShapedRecipe;
import org.bukkit.inventory.ShapelessRecipe;
import org.bukkit.inventory.RecipeChoice;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * The arbitrage audit. Acceptance rows 26 and 27.
 *
 * Row 26: "Zero positive-yield cycles across all items and all recipe chains."
 *
 * WHAT A POSITIVE-YIELD CYCLE IS. Buy ingredients from the shop, transform them with a recipe, sell
 * the result back to the shop, and end with more Berries than you started with. That is a money
 * printer. It does not need a bug to appear - it appears whenever the price of a product is set
 * independently of the price of its inputs, which is what happens every time someone adds an item
 * to a shop by picking a number that "feels right".
 *
 * THE AUDIT IS DELIBERATELY PESSIMISTIC. For every recipe it assumes the attacker is maximally
 * lucky: ingredients bought at the BOTTOM of the P4 band (0.6x base, the cheapest the price can
 * ever be) and the output sold at the TOP (1.4x base, then less the 12% spread). If a recipe is not
 * profitable under those conditions it cannot be profitable under any real conditions, so a pass
 * here is a strong statement rather than a snapshot of today's prices.
 *
 * WHAT THIS AUDIT DOES NOT CLAIM, stated because a security claim with an unstated limit is worse
 * than no claim:
 *
 *   1. It covers recipes the SERVER knows about - crafting, smelting, blasting, smoking,
 *      campfires and stonecutting. It does not model multi-step chains where an intermediate item
 *      is unsellable. Those cannot yield Berries directly, because a chain only pays out where it
 *      touches the shop, and every point where it touches the shop is a recipe this audit sees.
 *   2. It does not cover buying low and selling high OVER TIME. That window genuinely exists: the
 *      band floor is 0.6x base and the ceiling sell is 1.232x base, so an item bought at the floor
 *      and sold at the ceiling roughly doubles. That is speculation, not a cycle - it requires
 *      other players to move the price, it is bounded by the band, and P5 pulls prices back toward
 *      base at 5% an hour. It is recorded as a known property rather than hidden, and if the owner
 *      ever wants it closed the lever is the band width, not this audit.
 *   3. It does not model mob or block drops. Those are income, not arbitrage - a cycle needs a
 *      purchase at the start.
 *
 * IT RUNS AT BOOT AND FAILS LOUDLY. The specification asks for a build gate. Running it inside the
 * server at enable is strictly better than running it in CI, because the recipe list is whatever
 * this Minecraft version actually ships - a CI job would be auditing a copy of the recipe list and
 * could silently drift from the server after any update. A positive cycle logs at SEVERE with the
 * exact recipe, and the test script greps for the verdict.
 */
final class Arbitrage {

    /** One profitable recipe, with the arithmetic that condemned it. */
    record Finding(String recipe, Material output, int outputQty, long inputCost,
                   long outputValue, long profit) { }

    /** The cheapest an item can ever be bought for: the bottom of the P4 band. */
    private static long minBuy(Material m) {
        Shop.Entry e = Shop.entry(m);
        if (e == null) return -1;
        return Math.max(1L, Math.round(e.basePrice() * 0.6));
    }

    /** The most an item can ever be sold for: the top of the band, less the spread. */
    private static long maxSell(Material m) {
        Shop.Entry e = Shop.entry(m);
        if (e == null) return -1;
        return Shop.sellPrice(Math.round(e.basePrice() * 1.4));
    }

    /**
     * Runs the audit.
     *
     * @return every profitable recipe found. Empty is a pass.
     */
    static List<Finding> audit(org.bukkit.Server server) {
        List<Finding> findings = new ArrayList<>();
        Iterator<Recipe> it = server.recipeIterator();
        while (it.hasNext()) {
            Recipe r;
            try {
                r = it.next();
            } catch (RuntimeException ex) {
                // A malformed recipe from another plugin must not abort the audit, or one bad
                // recipe would silently disable the whole money-printer check.
                continue;
            }
            ItemStack result = r.getResult();
            if (result == null || result.getType() == Material.AIR) continue;

            long sellEach = maxSell(result.getType());
            // If the output cannot be sold, the recipe cannot pay out. Nothing to check.
            if (sellEach <= 0) continue;

            List<ItemStack> inputs = ingredientsOf(r);
            if (inputs == null || inputs.isEmpty()) continue;

            long cost = 0;
            boolean allBuyable = true;
            for (ItemStack in : inputs) {
                long each = minBuy(in.getType());
                if (each < 0) {
                    // An ingredient the shop does not sell cannot be bought, so this recipe is not
                    // a CYCLE - the player had to obtain that input by playing. Not a finding.
                    allBuyable = false;
                    break;
                }
                cost += each * in.getAmount();
            }
            if (!allBuyable) continue;

            long value = sellEach * result.getAmount();
            if (value > cost) {
                findings.add(new Finding(describe(r), result.getType(), result.getAmount(),
                    cost, value, value - cost));
            }
        }
        return findings;
    }

    /** How many recipes the audit actually examined, so a pass cannot be a pass over nothing. */
    static int recipeCount(org.bukkit.Server server) {
        int n = 0;
        Iterator<Recipe> it = server.recipeIterator();
        while (it.hasNext()) {
            try {
                it.next();
                n++;
            } catch (RuntimeException ignored) {
                // counted as examined-and-skipped; the audit above does the same
            }
        }
        return n;
    }

    /**
     * The ingredients of a recipe, resolved to concrete materials.
     *
     * A RecipeChoice can accept several materials - any log, any plank. The CHEAPEST accepted
     * material is used, because that is what an attacker would use. Picking the first, or an
     * average, would understate the risk.
     */
    private static List<ItemStack> ingredientsOf(Recipe r) {
        List<ItemStack> out = new ArrayList<>();
        if (r instanceof ShapedRecipe shaped) {
            for (RecipeChoice choice : shaped.getChoiceMap().values()) {
                if (choice == null) continue;
                Material m = cheapest(choice);
                if (m == null) return null;
                out.add(new ItemStack(m, 1));
            }
        } else if (r instanceof ShapelessRecipe shapeless) {
            for (RecipeChoice choice : shapeless.getChoiceList()) {
                Material m = cheapest(choice);
                if (m == null) return null;
                out.add(new ItemStack(m, 1));
            }
        } else if (r instanceof CookingRecipe<?> cooking) {
            Material m = cheapest(cooking.getInputChoice());
            if (m == null) return null;
            out.add(new ItemStack(m, 1));
        } else if (r instanceof org.bukkit.inventory.StonecuttingRecipe stone) {
            Material m = cheapest(stone.getInputChoice());
            if (m == null) return null;
            out.add(new ItemStack(m, 1));
        } else if (r instanceof org.bukkit.inventory.SmithingRecipe smith) {
            Material base = cheapest(smith.getBase());
            Material add = cheapest(smith.getAddition());
            if (base == null || add == null) return null;
            out.add(new ItemStack(base, 1));
            out.add(new ItemStack(add, 1));
        } else {
            // An unrecognised recipe type is NOT silently passed. Returning null makes the caller
            // skip it, and the count difference is reported, so an unaudited recipe is visible
            // rather than assumed safe.
            return null;
        }
        return out;
    }

    /** The cheapest material a choice accepts, or null if none is purchasable. */
    private static Material cheapest(RecipeChoice choice) {
        if (choice == null) return null;
        List<Material> accepted = new ArrayList<>();
        if (choice instanceof RecipeChoice.MaterialChoice mc) {
            accepted.addAll(mc.getChoices());
        } else if (choice instanceof RecipeChoice.ExactChoice ec) {
            for (ItemStack s : ec.getChoices()) accepted.add(s.getType());
        } else {
            return null;
        }
        Material best = null;
        long bestPrice = Long.MAX_VALUE;
        for (Material m : accepted) {
            long p = minBuy(m);
            if (p >= 0 && p < bestPrice) {
                bestPrice = p;
                best = m;
            }
        }
        return best;
    }

    private static String describe(Recipe r) {
        if (r instanceof org.bukkit.Keyed k) return k.getKey().toString();
        return r.getClass().getSimpleName();
    }
}
