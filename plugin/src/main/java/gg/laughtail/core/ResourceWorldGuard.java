package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.title.Title;
import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.player.PlayerChangedWorldEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;

import java.time.Duration;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Makes the resource world impossible to mistake for a permanent one.
 *
 * WHY THIS EXISTS. 7.4 says the resource world regenerates monthly and that nothing there is
 * claimable - "no bases, no claims, no permanent storage". But the world LOOKS exactly like the
 * overworld, because it is generated the same way. A player who arrives via /rtp, finds a nice
 * valley and builds there will lose everything at the reset, and will be entirely right to call
 * that a broken server rather than a documented feature.
 *
 * A single line of chat on arrival is not enough. Chat scrolls, and the consequence is a month
 * of someone's work. So the warning is repeated at the three moments a player could be about to
 * make that mistake:
 *
 *   1. Entering the world - a full-screen title, which cannot be scrolled past.
 *   2. Placing a CONTAINER - the specific act that means "I am storing things here". Chests,
 *      barrels, shulkers, furnaces. Warned every time, not once, because the cost of being
 *      slightly annoying is nothing next to the cost of losing a base.
 *   3. Being in the world at all - a persistent action-bar reminder while they are there.
 *
 * NOTHING IS BLOCKED. Building in the resource world is allowed - temporary shelters and mining
 * outposts are the normal way to use it, and blocking placement would make it unusable. The goal
 * is that nobody can be SURPRISED, not that nobody can build.
 */
final class ResourceWorldGuard implements Listener {

    private static final Set<Material> CONTAINERS = Set.of(
        Material.CHEST, Material.TRAPPED_CHEST, Material.BARREL, Material.ENDER_CHEST,
        Material.FURNACE, Material.BLAST_FURNACE, Material.SMOKER, Material.HOPPER,
        Material.SHULKER_BOX, Material.DISPENSER, Material.DROPPER, Material.BREWING_STAND
    );

    private final LaughTailPlugin plugin;
    /** Players currently inside the resource world, for the action-bar reminder. */
    private final Set<UUID> inside = ConcurrentHashMap.newKeySet();

    ResourceWorldGuard(LaughTailPlugin plugin) {
        this.plugin = plugin;
    }

    static boolean isResourceWorld(String worldName) {
        return worldName != null && worldName.contains("resource");
    }

    void start() {
        // The repeating action-bar reminder was removed. It fired every 5 seconds and the owner
        // was right that it was spam: a warning shown constantly stops being read, which makes it
        // worse than a warning shown once at the moment it matters. What remains is one concise
        // line on entering the world and a warning when placing a container - both tied to an
        // ACTION rather than to merely existing.
    }

    @EventHandler
    public void onWorldChange(PlayerChangedWorldEvent e) {
        update(e.getPlayer());
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        // Tracked but NOT announced. A player who logged out here already knows where they are,
        // and a red banner every login is exactly the noise the owner asked to remove.
        if (isResourceWorld(e.getPlayer().getWorld().getName())) {
            inside.add(e.getPlayer().getUniqueId());
        }
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        inside.remove(e.getPlayer().getUniqueId());
    }

    private void update(Player p) {
        if (isResourceWorld(p.getWorld().getName())) {
            inside.add(p.getUniqueId());
            announce(p);
        } else {
            inside.remove(p.getUniqueId());
        }
    }

    private void announce(Player p) {
        // One subtitle, no big red headline. The owner asked for clean, and a full-screen red
        // banner on every entry reads as an error rather than as information.
        p.showTitle(Title.title(
            Component.empty(),
            Component.text("Resource world - resets monthly, do not build here",
                NamedTextColor.YELLOW),
            Title.Times.times(Duration.ofMillis(200), Duration.ofSeconds(3),
                Duration.ofMillis(400))));
        p.sendMessage(Component.text("Resource world: mine freely. ", NamedTextColor.YELLOW)
            .append(Component.text("Everything here is deleted monthly - build at /home.",
                NamedTextColor.GRAY)));
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        if (!isResourceWorld(e.getBlock().getWorld().getName())) return;
        if (!CONTAINERS.contains(e.getBlock().getType())) return;
        // Placing a container is the moment a player decides to STORE something here, which is
        // the single most expensive mistake available in this world. Warned every time - the
        // cost of being slightly annoying is nothing next to losing a month of storage.
        e.getPlayer().sendMessage(Component.text(
            "Careful: containers in the resource world are DELETED with the world every month. "
          + "Anything left inside is gone.", NamedTextColor.RED));
    }
}
