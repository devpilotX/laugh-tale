package gg.laughtail.core;

import org.bukkit.GameRule;
import org.bukkit.World;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.world.WorldLoadEvent;
import org.bukkit.plugin.Plugin;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Enforces the Section 7.2 gameplay rules on every world.
 *
 * WHY THIS LIVES IN THE PLUGIN rather than in a deploy script. The obvious approach -
 * send `gamerule keepInventory false` over RCON - does not work, and fails in a way
 * that is easy to miss:
 *
 *   - A bare `/gamerule` from the console applies only to the DEFAULT world, so the
 *     Nether and End would silently keep fire spread and mob griefing.
 *   - `execute in minecraft:the_nether run gamerule ...` is rejected outright by the
 *     26.2 command parser: "Incorrect argument for command".
 *
 * Doing it here fixes both problems and adds a third property that matters more: it
 * runs on WorldLoadEvent, so any world created later - the resource world of 7.4, the
 * arena of 7.1 - gets the same rules automatically. A rule that has to be remembered
 * for each new world is a rule that will eventually be missed.
 *
 * Idempotent by construction: it reads the current value first and only writes when it
 * differs, so a restart logs "already correct" instead of pretending to have done work.
 */
final class WorldRules implements Listener {

    private final Plugin plugin;

    /**
     * The rules, each with the 7.2 line that decides it. Booleans only - every 7.2 rule
     * happens to be a boolean, and keeping the map typed avoids a cast per entry.
     */
    private static final Map<GameRule<Boolean>, Boolean> RULES = new LinkedHashMap<>();
    static {
        // "Death must cost something or PvP means nothing."
        RULES.put(GameRule.KEEP_INVENTORY, false);
        // "Removes the most common griefing vector at almost no gameplay cost."
        RULES.put(GameRule.DO_FIRE_TICK, false);
        // "Stops creeper and enderman damage to builds."
        RULES.put(GameRule.MOB_GRIEFING, false);
        // 7.2 lists natural regeneration as On, "standard".
        RULES.put(GameRule.NATURAL_REGENERATION, true);
    }

    WorldRules(Plugin plugin) {
        this.plugin = plugin;
    }

    /**
     * The 7.1 border table, as DIAMETERS - which is what the specification's table
     * states and what Minecraft's WorldBorder#setSize expects. Reading that table as a
     * radius would double every world; the overworld would become 12,000 blocks, which
     * this disk cannot hold and Chunky would spend days pregenerating.
     *
     * Keyed on world name. A world not listed here is left alone rather than given a
     * default: silently imposing a border on an unrecognised world is worse than having
     * none, because it would be invisible until a player walked into it.
     */
    private static final Map<String, Double> BORDERS = new LinkedHashMap<>();
    static {
        BORDERS.put("laughtail", 6000.0);            // Overworld. "Never reset."
        BORDERS.put("laughtail_nether", 2000.0);     // Nether
        BORDERS.put("laughtail_the_end", 3000.0);    // End, dragon, Season Finale
        BORDERS.put("laughtail_resource", 3000.0);   // Resets monthly (7.4)
        BORDERS.put("laughtail_arena", 512.0);       // 7.1 says "small, flat"; 512 is a
                                                     // deliberate reading of "small" and
                                                     // is a Phase 7 tuning candidate
                                                     // once the war format is built.
    }

    /** Applies to every already-loaded world. Called once on enable. */
    void applyToAll() {
        for (World w : plugin.getServer().getWorlds()) {
            apply(w);
        }
    }

    @EventHandler
    public void onWorldLoad(WorldLoadEvent e) {
        apply(e.getWorld());
    }

    private void apply(World w) {
        int changed = 0;
        StringBuilder detail = new StringBuilder();
        for (Map.Entry<GameRule<Boolean>, Boolean> r : RULES.entrySet()) {
            Boolean current = w.getGameRuleValue(r.getKey());
            Boolean want = r.getValue();
            if (!want.equals(current)) {
                w.setGameRule(r.getKey(), want);
                changed++;
                detail.append(' ').append(r.getKey().getName())
                      .append(':').append(current).append("->").append(want);
            }
        }
        if (changed > 0) {
            plugin.getLogger().info("World '" + w.getName() + "': set " + changed
                + " gamerule(s) from Section 7.2:" + detail);
        } else {
            plugin.getLogger().info("World '" + w.getName()
                + "': all Section 7.2 gamerules already correct");
        }

        // Border, from the 7.1 table. Compared before writing so a restart does not
        // re-announce work it did not do.
        Double want = BORDERS.get(w.getName());
        if (want == null) {
            plugin.getLogger().warning("World '" + w.getName()
                + "' has no border in the Section 7.1 table - leaving it alone rather than "
                + "guessing. Add it to WorldRules.BORDERS if it is meant to be bordered.");
            return;
        }
        double have = w.getWorldBorder().getSize();
        if (Math.abs(have - want) > 0.5) {
            w.getWorldBorder().setSize(want);
            plugin.getLogger().info("World '" + w.getName() + "': border "
                + (long) have + " -> " + want.longValue() + " (7.1)");
        } else {
            plugin.getLogger().info("World '" + w.getName() + "': border already "
                + want.longValue());
        }
    }

    /** For /laughtail status - reports the live values rather than what we intended. */
    String describe() {
        StringBuilder sb = new StringBuilder();
        for (World w : plugin.getServer().getWorlds()) {
            sb.append("  ").append(w.getName()).append(": ");
            for (GameRule<Boolean> g : RULES.keySet()) {
                sb.append(g.getName()).append('=').append(w.getGameRuleValue(g)).append(' ');
            }
            sb.append("border=").append((long) w.getWorldBorder().getSize());
            sb.append('\n');
        }
        return sb.toString();
    }
}
