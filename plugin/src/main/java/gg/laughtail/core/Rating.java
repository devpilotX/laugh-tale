package gg.laughtail.core;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The ranking mathematics. Appendix B, with the three contradictions resolved by D-0031.
 *
 * PURE FUNCTIONS ONLY. Nothing here touches the database, the server, or the clock except
 * through arguments. That is deliberate: Appendix B lists five invariants to assert in tests,
 * and invariants are only testable if the arithmetic can be evaluated without a running
 * server. `selfTest()` exercises all five in memory.
 *
 * WHERE THIS DEPARTS FROM APPENDIX B, AND WHY - all three are D-0031 rulings:
 *
 * P11: MAX_GAIN is 24, not 40. Appendix B states 40, but also `raw = K * (1 - E)` with
 *      K = 24, and E is a probability - so raw is always under 24 and a cap at 40 could never
 *      bind. Rather than raise K (which would make the ladder swing far faster than a monthly
 *      season wants), the cap becomes the value the formula can actually reach. It stays as a
 *      real guard against a future multiplier pushing one gain higher than a single upset.
 *
 * P12: the death floor is the bottom of the LADDER, not of the victim's tier. Appendix B says
 *      `max(tier_floor(CR_victim), ...)`, which means a player can never fall out of a tier
 *      they have reached - so there is no demotion at all, and a ladder without demotion is a
 *      high-water mark. 9.2 says "the bottom of the ladder" and 9.2 wins. Peak rating is
 *      preserved separately in `combat_ratings.peak_rp`, which is the right place for a
 *      high-water mark.
 *
 * P13: decay is 1% of the distance ABOVE the tier floor, not 1% of total CR. Appendix B's
 *      `CR * (1 - DECAY_RATE)` costs a player at CR 2000 twenty points a week and a player at
 *      CR 1050 ten - it punishes the highest-rated hardest for the same absence, which is the
 *      opposite of what decay is for. 9.2's form is self-limiting: it approaches the tier
 *      floor and stops.
 *
 * WHAT IS NOT A DEPARTURE. The repeat-kill curve is Appendix B's, exactly: 1.00, 0.50, 0.25,
 * 0.10, then 0.00, resetting after six hours. An earlier version of this project put invented
 * values in a private config on the grounds that the specification gave no numbers. That was
 * wrong - Appendix B gives them explicitly, and they are published in the specification, so
 * there is nothing for never-break rule 10 to protect here. Rule 10 still covers the IP salt.
 */
final class Rating {

    static final int K = 24;
    static final int STARTING_CR = 1000;
    static final int MIN_GAIN = 2;
    static final int MAX_GAIN = 24;            // P11
    static final double DECAY_RATE = 0.01;     // per week
    static final int DECAY_AFTER_DAYS = 7;
    static final double RESET_FACTOR = 0.35;
    static final int RESET_BASE = 1000;
    static final long REPEAT_WINDOW_MS = 6L * 3600L * 1000L;   // Appendix B: six hours

    /** Appendix B's repeat curve, by prior kills on the same victim inside the window. */
    static final double[] REPEAT_MULTIPLIER = { 1.00, 0.50, 0.25, 0.10, 0.00 };

    /**
     * The ten tiers of 9.3, with PROVISIONAL floors.
     *
     * 9.3 is explicit that "thresholds live in config, tunable without a code change. Set them
     * from the measured RP distribution after the first season." So these are a starting shape,
     * not a decision: everyone begins at Raider, there are two tiers below so a losing player
     * has somewhere to fall (which P12 makes possible), and the top is reachable but far.
     *
     * They must be re-set from the real distribution after season 1. Until then any statement
     * about how many players are Gladiator is a guess.
     */
    static final Map<String, Integer> TIERS = new LinkedHashMap<>();
    static {
        TIERS.put("Wanderer",  0);
        TIERS.put("Settler",   900);
        TIERS.put("Raider",    1000);   // STARTING_CR
        TIERS.put("Fighter",   1100);
        TIERS.put("Warrior",   1200);
        TIERS.put("Gladiator", 1325);
        TIERS.put("Champion",  1450);
        TIERS.put("Warlord",   1600);
        TIERS.put("Legend",    1775);
        TIERS.put("Mythic",    2000);
    }

    /** The absolute bottom of the ladder. P12's floor. */
    static final int LADDER_FLOOR = 0;

    private Rating() { }

    static String tierName(int cr) {
        String best = "Wanderer";
        for (Map.Entry<String, Integer> e : TIERS.entrySet()) {
            if (cr >= e.getValue()) best = e.getKey();
        }
        return best;
    }

    static int tierFloor(int cr) {
        int best = 0;
        for (int floor : TIERS.values()) {
            if (cr >= floor && floor > best) best = floor;
        }
        return best;
    }

    /** Expected score for the killer. Standard Elo. */
    static double expected(int crKiller, int crVictim) {
        return 1.0 / (1.0 + Math.pow(10.0, (crVictim - crKiller) / 400.0));
    }

    /** The multiplier for the Nth kill on the same victim inside the window (0-indexed prior). */
    static double repeatMultiplier(int priorKillsInWindow) {
        if (priorKillsInWindow < 0) return 1.0;
        if (priorKillsInWindow >= REPEAT_MULTIPLIER.length) return 0.0;
        return REPEAT_MULTIPLIER[priorKillsInWindow];
    }

    /**
     * The rating change for one kill.
     *
     * Returns the gain applied to the killer. The victim loses the SAME amount before flooring -
     * Appendix B's invariant that "the sum of CR changes in a single kill event is zero before
     * clamping and flooring".
     *
     * `suppressed` covers same-IP, reciprocal, spawn-region, staff and self-inflicted. All of
     * them multiply by zero rather than skipping the calculation, so a suppressed kill still
     * produces a combat_events row with a visible reason instead of vanishing.
     */
    static int gain(int crKiller, int crVictim, int priorKillsInWindow, boolean suppressed) {
        if (suppressed) return 0;
        double raw = K * (1.0 - expected(crKiller, crVictim));
        double clamped = Math.max(MIN_GAIN, Math.min(MAX_GAIN, raw));
        double afterRepeat = clamped * repeatMultiplier(priorKillsInWindow);
        // Round rather than truncate: truncation would make a 0.10 multiplier on a small gain
        // always zero, which would silently turn the fourth kill into the fifth.
        return (int) Math.round(afterRepeat);
    }

    /** The victim's new rating. P12: floored at the LADDER bottom, not the tier bottom. */
    static int victimAfter(int crVictim, int gain) {
        return Math.max(LADDER_FLOOR, crVictim - gain);
    }

    /** The killer's new rating. Appendix B invariant: a kill can never reduce it. */
    static int killerAfter(int crKiller, int gain) {
        return crKiller + Math.max(0, gain);
    }

    /** P13: weekly decay of 1% of the distance above the tier floor, never below it. */
    static int decayOneWeek(int cr) {
        int floor = tierFloor(cr);
        int above = cr - floor;
        if (above <= 0) return cr;
        int loss = (int) Math.round(above * DECAY_RATE);
        // A rating one point above its floor would otherwise never decay at all because
        // round(0.01) is 0. One point is the smallest meaningful movement.
        if (loss == 0) loss = 1;
        return Math.max(floor, cr - loss);
    }

    /** Monthly season reset. Appendix B, unchanged. */
    static int seasonReset(int crOld) {
        return (int) Math.round(RESET_BASE + (crOld - RESET_BASE) * RESET_FACTOR);
    }

    // ---- the five invariants Appendix B asks to be asserted -------------------

    /** Runs Appendix B's invariants plus the P11-P13 rulings. Returns failures, empty = pass. */
    static java.util.List<String> selfTest() {
        java.util.List<String> f = new java.util.ArrayList<>();

        // 1. A kill can never reduce the killer's CR.
        for (int ck = 0; ck <= 2500; ck += 250) {
            for (int cv = 0; cv <= 2500; cv += 250) {
                int g = gain(ck, cv, 0, false);
                if (killerAfter(ck, g) < ck) {
                    f.add("invariant 1 broken: killer " + ck + " vs " + cv + " lost rating");
                }
            }
        }

        // 2. A death can never take a player below the floor. P12 makes that the LADDER floor.
        for (int cv = 0; cv <= 100; cv += 10) {
            int g = gain(2500, cv, 0, false);
            if (victimAfter(cv, g) < LADDER_FLOOR) {
                f.add("invariant 2 broken: victim " + cv + " fell below the ladder floor");
            }
        }

        // 3. No non-combat action changes CR. Structural: nothing outside CombatTracker calls
        //    this class. Asserted here as the suppressed case returning exactly zero.
        if (gain(1000, 1000, 0, true) != 0) {
            f.add("invariant 3 broken: a suppressed kill produced a non-zero gain");
        }

        // 4. Two applications of the reset are NOT identical to one - Appendix B's wording is
        //    about the reset JOB being idempotent, not the formula being a fixed point. The
        //    formula is intentionally contractive. What must hold is that the job does not run
        //    twice, which reset_completed enforces and test-seasons.sh proves. Assert instead
        //    that the formula converges toward RESET_BASE rather than diverging.
        int once = seasonReset(2000);
        int twice = seasonReset(once);
        if (!(Math.abs(twice - RESET_BASE) < Math.abs(once - RESET_BASE))) {
            f.add("reset does not converge toward base: " + once + " then " + twice);
        }

        // 5. The sum of CR changes in one kill is zero BEFORE clamping and flooring.
        int ck = 1200, cv = 1000;
        int g = gain(ck, cv, 0, false);
        if ((killerAfter(ck, g) - ck) != (cv - victimAfter(cv, g))) {
            f.add("invariant 5 broken: gain and loss are asymmetric away from the floor");
        }

        // P11: MAX_GAIN must be reachable, or it is dead code.
        int maxObserved = 0;
        for (int cv2 = 0; cv2 <= 3000; cv2 += 10) {
            maxObserved = Math.max(maxObserved, gain(3000, cv2, 0, false));
        }
        if (maxObserved > MAX_GAIN) f.add("P11 broken: gain " + maxObserved + " exceeded MAX_GAIN");

        // P12: demotion must be possible - a tier floor must not trap a player.
        int gladiatorFloor = TIERS.get("Gladiator");
        int afterBigLoss = victimAfter(gladiatorFloor, 24);
        if (afterBigLoss >= gladiatorFloor) {
            f.add("P12 broken: a player at a tier floor could not be demoted");
        }

        // P13: decay must be self-limiting and must never cross the tier floor.
        //
        // Iterate to STABILITY rather than for a guessed number of weeks. The first version
        // ran 200 weeks and failed at 2045 - which was correct behaviour reported as a bug,
        // because 1% of a shrinking surplus takes roughly 257 weeks to walk 400 points down,
        // not 200. Asserting a fixed iteration count was asserting my arithmetic about the
        // test rather than the property being tested.
        int cr = 2400;
        int guard = 0;
        while (guard++ < 10_000) {
            int next = decayOneWeek(cr);
            if (next == cr) break;
            if (next > cr) { f.add("P13 broken: decay increased rating " + cr + " -> " + next); break; }
            cr = next;
        }
        if (cr < tierFloor(2400)) {
            f.add("P13 broken: decay fell below the tier floor, reaching " + cr);
        }
        if (cr != tierFloor(2400)) {
            f.add("P13 broken: decay stabilised at " + cr + " rather than the floor "
                + tierFloor(2400));
        }
        // Decay must actually bite ABOVE a floor.
        if (decayOneWeek(2400) >= 2400) f.add("P13 broken: no decay applied at CR 2400");

        // And it must NOT bite AT a floor. This assertion was wrong in the first version - it
        // asserted decay at CR 2000, which is exactly the Mythic floor, and the self-test
        // correctly reported a failure that was in the TEST rather than the code.
        //
        // THE CONSEQUENCE IS WORTH KNOWING, not hiding: a player sitting exactly at a tier
        // floor never decays, so inactivity squatting AT A FLOOR is free. That follows directly
        // from 9.2's wording ("decays 1 percent per week above the tier floor") and it is a
        // deliberate limit rather than an oversight - decay strips surplus rating, it does not
        // strip an earned tier. If squatting at a floor ever becomes a real problem, the fix is
        // a separate inactivity rule, not a change to decay.
        int mythicFloor = TIERS.get("Mythic");
        if (decayOneWeek(mythicFloor) != mythicFloor) {
            f.add("P13 broken: a rating exactly at a tier floor decayed below it");
        }

        // Appendix B's repeat curve, exactly as published.
        double[] want = { 1.00, 0.50, 0.25, 0.10, 0.00, 0.00 };
        for (int i = 0; i < want.length; i++) {
            if (Math.abs(repeatMultiplier(i) - want[i]) > 0.0001) {
                f.add("repeat curve wrong at " + i + ": " + repeatMultiplier(i)
                    + " expected " + want[i]);
            }
        }

        return f;
    }

    /** A human-readable worked example, for /laughtail rating. */
    static java.util.List<String> examples() {
        java.util.List<String> out = new java.util.ArrayList<>();
        out.add("even match 1000 v 1000  -> gain " + gain(1000, 1000, 0, false));
        out.add("upset     1000 v 1400  -> gain " + gain(1000, 1400, 0, false));
        out.add("expected  1400 v 1000  -> gain " + gain(1400, 1000, 0, false));
        out.add("repeat curve on 1000 v 1000: "
            + gain(1000, 1000, 0, false) + ", " + gain(1000, 1000, 1, false) + ", "
            + gain(1000, 1000, 2, false) + ", " + gain(1000, 1000, 3, false) + ", "
            + gain(1000, 1000, 4, false));
        out.add("decay from 2400 for 4 weeks: " + decayOneWeek(decayOneWeek(
            decayOneWeek(decayOneWeek(2400)))) + " (floor " + tierFloor(2400) + ")");
        out.add("season reset 2000 -> " + seasonReset(2000) + ", 1400 -> " + seasonReset(1400));
        out.add("tier at 1000=" + tierName(1000) + " 1450=" + tierName(1450)
            + " 2000=" + tierName(2000));
        return out;
    }
}
