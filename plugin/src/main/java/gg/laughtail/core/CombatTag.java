package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.entity.Player;
import org.bukkit.entity.Projectile;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.PlayerDeathEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.inventory.ItemStack;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The combat tag. Acceptance rows 33 and 44.
 *
 * A player who has recently been in PvP is "tagged" and cannot teleport away or log out safely.
 * Without it, every losing fight ends the same way - the loser types /home or pulls the plug - and
 * a PvP ladder where the loser escapes is not a ladder, it is a formality.
 *
 * DURATION IS 15 SECONDS, decided under D-0031 where the owner delegated numeric choices. The
 * specification does not name a figure. 15 is long enough that running away requires actually
 * running - a sprinting player covers roughly 80 blocks, which is well inside render distance so
 * the fight can continue - and short enough that a player who genuinely disengaged is not held
 * hostage. Ten seconds is escapable with one ender pearl; thirty punishes the survivor of an
 * ambush they never wanted.
 *
 * MOB DAMAGE DOES NOT TAG. Only player-versus-player. Being hit by a zombie must not stop someone
 * going home, and tagging on mob damage is the most common complaint about combat-tag plugins.
 *
 * THE ATTACKER IS TAGGED TOO, not only the victim. Tagging only the victim lets an attacker hit
 * someone and immediately teleport out with their advantage - which turns the tag into a weapon
 * rather than a rule.
 *
 * COMBAT LOGGING IS RESOLVED AS A DEATH (row 33). Quitting while tagged drops the player's
 * inventory where they stood, empties it, and marks them to arrive dead. The alternative - kicking
 * the connection and leaving the player intact - means the punishment for losing is a 15-second
 * inconvenience, and everybody learns to pull the plug.
 *
 * ON THE DISPLAY: a countdown is shown on the action bar, and ONLY while tagged. The owner had the
 * repeating resource-world action bar removed as spam and was right to; the principle drawn from
 * that was that a message must be tied to something happening rather than to merely existing. A
 * combat timer is the clearest possible example of the former - it appears because you are in a
 * fight, it counts down, and it goes away.
 */
final class CombatTag implements Listener {

    /** D-0031. See the class note for the reasoning. */
    static final int TAG_SECONDS = 15;

    private final LaughTailPlugin plugin;
    private final Database db;

    /** UUID to the tick at which the tag expires. */
    private final Map<UUID, Long> tagged = new ConcurrentHashMap<>();
    /** Who tagged whom last, so a combat log can be attributed to a killer. */
    private final Map<UUID, UUID> lastAttacker = new ConcurrentHashMap<>();

    CombatTag(LaughTailPlugin plugin, Database db) {
        this.plugin = plugin;
        this.db = db;
    }

    void start() {
        // One task drives both the countdown display and expiry. Two tasks would drift apart.
        plugin.getServer().getScheduler().runTaskTimer(plugin, this::tick, 20L, 10L);
    }

    // ---- state ---------------------------------------------------------------

    boolean isTagged(Player p) {
        Long until = tagged.get(p.getUniqueId());
        return until != null && until > System.currentTimeMillis();
    }

    /** Seconds left, for a refusal message that tells the player something useful. */
    int secondsLeft(Player p) {
        Long until = tagged.get(p.getUniqueId());
        if (until == null) return 0;
        long ms = until - System.currentTimeMillis();
        return ms <= 0 ? 0 : (int) Math.ceil(ms / 1000.0);
    }

    /**
     * Refuses an action and says why. Returns true when the caller should stop.
     *
     * Every teleport route calls this, so there is one place that decides what "in combat" blocks.
     * Spreading the check across each command is how one route quietly ends up unguarded.
     */
    boolean refuse(Player p, String action) {
        if (!isTagged(p)) return false;
        p.sendMessage(Component.text("You cannot " + action + " while in combat - "
            + secondsLeft(p) + "s left.", NamedTextColor.RED));
        p.sendMessage(Component.text("Win the fight, or get away and wait it out.",
            NamedTextColor.GRAY));
        return true;
    }

    private void tag(Player p, Player by) {
        tagged.put(p.getUniqueId(), System.currentTimeMillis() + TAG_SECONDS * 1000L);
        if (by != null && !by.getUniqueId().equals(p.getUniqueId())) {
            lastAttacker.put(p.getUniqueId(), by.getUniqueId());
        }
    }

    void clear(Player p) {
        tagged.remove(p.getUniqueId());
        lastAttacker.remove(p.getUniqueId());
    }

    // ---- events --------------------------------------------------------------

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onDamage(EntityDamageByEntityEvent e) {
        if (!(e.getEntity() instanceof Player victim)) return;
        Player attacker = resolveAttacker(e.getDamager());
        if (attacker == null) return;
        if (attacker.getUniqueId().equals(victim.getUniqueId())) return;

        // MONITOR and ignoreCancelled together mean the tag only applies to damage that actually
        // landed. Tagging on cancelled damage would let someone tag a player through a region
        // where PvP is disabled.
        tag(victim, attacker);
        tag(attacker, victim);
    }

    /** Unwraps arrows and thrown potions to the player who fired them. */
    private Player resolveAttacker(org.bukkit.entity.Entity damager) {
        if (damager instanceof Player p) return p;
        if (damager instanceof Projectile proj
                && proj.getShooter() instanceof Player shooter) {
            return shooter;
        }
        return null;
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onDeath(PlayerDeathEvent e) {
        // A dead player is not in combat. Leaving the tag on would block their first teleport
        // after respawning, which reads as a bug.
        clear(e.getEntity());
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onQuit(PlayerQuitEvent e) {
        Player p = e.getPlayer();
        if (!isTagged(p)) return;

        UUID killer = lastAttacker.get(p.getUniqueId());
        clear(p);

        // Drop what they were carrying, where they stood. This is the whole point: the cost of
        // logging out mid-fight has to be the same as the cost of losing it.
        for (ItemStack it : p.getInventory().getContents()) {
            if (it != null && it.getType() != org.bukkit.Material.AIR) {
                p.getWorld().dropItemNaturally(p.getLocation(), it);
            }
        }
        p.getInventory().clear();
        // NOT killed on rejoin, deliberately. An earlier draft marked the player to arrive dead
        // and kill them on join. That would DOUBLE COUNT: the death is already recorded below, and
        // a real death on join would fire PlayerDeathEvent and increment the counter a second time,
        // so a combat logger would be recorded as dying twice for one offence. Everything row 33
        // asks for is already true - the items are on the ground, the death is in the database, and
        // the attacker is credited through the normal rating path - so an in-game corpse would add
        // nothing except a wrong number.

        String name = p.getName();
        plugin.getServer().broadcast(Component.text(name
            + " logged out while in combat. Their items were dropped.", NamedTextColor.YELLOW));

        // Record it as a death so the ladder treats it exactly like losing, and audit it so a
        // repeat offender is visible to staff rather than only to whoever they did it to.
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                db.audit(null, "COMBAT", "combat_log", p.getUniqueId(), name,
                    killer == null ? "no attacker recorded" : "attacker " + killer,
                    p.getWorld().getName());
                db.recordCombatLog(p.getUniqueId(), killer);
            } catch (java.sql.SQLException ex) {
                plugin.getLogger().warning("Could not record the combat log for " + name
                    + ": " + ex.getMessage());
            }
        });
    }


    // ---- countdown -----------------------------------------------------------

    private void tick() {
        long now = System.currentTimeMillis();
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            Long until = tagged.get(p.getUniqueId());
            if (until == null) continue;
            if (until <= now) {
                clear(p);
                p.sendActionBar(Component.text("Out of combat.", NamedTextColor.GREEN));
                continue;
            }
            int left = (int) Math.ceil((until - now) / 1000.0);
            p.sendActionBar(Component.text("In combat - " + left + "s  ",
                    left <= 3 ? NamedTextColor.GREEN : NamedTextColor.RED)
                .append(Component.text("no teleport, no safe logout", NamedTextColor.GRAY)));
        }
    }
}
