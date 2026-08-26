package gg.laughtail.core;

/**
 * The six Paths and their level curve. See docs/roleplay-design.md.
 *
 * THE ONE RULE: a Path level grants STATUS, never POWER. There is no method on this class that returns
 * a damage multiplier, a health bonus, a speed modifier, a drop rate or a discount, and that is the
 * design rather than an oversight. Such a method would break Law 1's total equality and violate
 * acceptance row 30, which requires two hours of mining to change combat rating by EXACTLY ZERO.
 *
 * WHY THIS SYSTEM EXISTS AT ALL. Row 30 guarantees that non-combat play cannot move rank - correctly,
 * because that is what makes the ladder honest. But it leaves a hole: a player who loses fights has
 * nothing to climb. They mine, build and trade and no visible number moves. Most players are not
 * top-decile fighters, so a server where they have no progress loses them. Paths are the second
 * ladder, built so it can never leak into the first.
 *
 * THE CURVE IS QUADRATIC, not exponential. Exponential curves are the standard choice and they are
 * wrong for a server this size: level 30 becomes unreachable, so the ladder stops moving and stops
 * working. Quadratic keeps early levels quick and late levels meaningful without ever becoming
 * hopeless. Level 1 costs 100, level 10 costs 10,000, level 50 costs 250,000 - reachable by a
 * dedicated player in a season, which is the horizon that matters here.
 */
enum Path {

    DELVER("delver", "Delver", "Mining, depth, and what is buried"),
    CULTIVATOR("cultivator", "Cultivator", "Farming, breeding, and growing things"),
    HUNTER("hunter", "Hunter", "Mobs, danger, and bosses"),
    WAYFINDER("wayfinder", "Wayfinder", "Distance, biomes, and discovery"),
    ARTIFICER("artificer", "Artificer", "Crafting, enchanting, and building"),
    BROKER("broker", "Broker", "Trades, orders, and market volume");

    /** Highest level. Beyond this the Path is mastered and stops accruing titles. */
    static final int MAX_LEVEL = 50;

    private final String key;
    private final String display;
    private final String blurb;

    Path(String key, String display, String blurb) {
        this.key = key;
        this.display = display;
        this.blurb = blurb;
    }

    String key() { return key; }
    String display() { return display; }
    String blurb() { return blurb; }

    static Path fromKey(String k) {
        for (Path p : values()) {
            if (p.key.equalsIgnoreCase(k)) return p;
        }
        return null;
    }

    /**
     * Total XP required to have reached a level.
     *
     * Quadratic: 100 * level^2. See the class note on why not exponential.
     */
    static long xpForLevel(int level) {
        if (level <= 0) return 0;
        return 100L * level * level;
    }

    /** The level a given lifetime XP total corresponds to. */
    static int levelForXp(long xp) {
        if (xp < 100) return 0;
        // Inverting 100*L^2 <= xp gives L = floor(sqrt(xp/100)). Computed rather than looped, so the
        // cost does not grow with the level.
        int level = (int) Math.floor(Math.sqrt(xp / 100.0));
        return Math.min(level, MAX_LEVEL);
    }

    /** Progress through the current level, 0.0 to 1.0, for the HUD bar. */
    static double progress(long xp) {
        int level = levelForXp(xp);
        if (level >= MAX_LEVEL) return 1.0;
        long floor = xpForLevel(level);
        long ceil = xpForLevel(level + 1);
        if (ceil <= floor) return 1.0;
        return Math.max(0.0, Math.min(1.0, (double) (xp - floor) / (ceil - floor)));
    }

    /**
     * The title awarded at a level, or null if that level awards none.
     *
     * Titles land at 5, 10, 20, 30, 40 and 50 rather than every level. A reward at every level becomes
     * wallpaper - nobody remembers their 14th title. Six milestones across a Path stay memorable, and
     * the gaps are what make the next one worth reaching.
     */
    String titleAt(int level) {
        return switch (level) {
            case 5  -> "Apprentice " + display;
            case 10 -> "Journeyman " + display;
            case 20 -> "Adept " + display;
            case 30 -> "Master " + display;
            case 40 -> "Grandmaster " + display;
            case 50 -> display + " Eternal";
            default -> null;
        };
    }

    /** Colour for a level's title. Recognition is the entire reward, so it should look earned. */
    static String colourAt(int level) {
        if (level >= 50) return "#FFD447";
        if (level >= 40) return "#C77DFF";
        if (level >= 30) return "#4CC9F0";
        if (level >= 20) return "#52B788";
        if (level >= 10) return "#F4A261";
        return "#ADB5BD";
    }

    /**
     * A short bar for the HUD. Ten segments, because a sidebar line is narrow and a 20-segment bar
     * wraps on smaller GUI scales.
     */
    static String bar(long xp) {
        int filled = (int) Math.round(progress(xp) * 10);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10; i++) {
            sb.append(i < filled ? '\u25AC' : '\u00B7');
        }
        return sb.toString();
    }
}
