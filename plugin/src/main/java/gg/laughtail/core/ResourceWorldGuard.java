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
        // Every 5 seconds is often enough to be present and rare enough to cost nothing. The
        // action bar is used rather than chat precisely because it does not scroll away and does
        // not spam the log.
        plugin.getServer().getScheduler().runTaskTimer(plugin, () -> {
            for (UUID id : inside) {
                Player p = plugin.getServer().getPlayer(id);
                if (p == null || !p.isOnline()) continue;
                if (!isResourceWorld(p.getWorld().getName())) continue;
                p.sendActionBar(Component.text(
                    "RESOURCE WORLD - everything here is deleted every month",
                    NamedTextColor.RED));
            }
        }, 100L, 100L);
    }

    @EventHandler
    public void onWorldChange(PlayerChangedWorldEvent e) {
        update(e.getPlayer());
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        // A player who logged out in the resource world logs back into it, so the reminder must
        // be re-established on join and not only on a world change.
        update(e.getPlayer());
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
        p.showTitle(Title.title(
            Component.text("RESOURCE WORLD", NamedTextColor.RED),
            Component.text("Everything here is deleted every month", NamedTextColor.YELLOW),
            Title.Times.times(Duration.ofMillis(300), Duration.ofSeconds(4),
                Duration.ofMillis(600))));
        p.sendMessage(Component.text("─────────────────────────────", NamedTextColor.DARK_GRAY));
        p.sendMessage(Component.text("You are in the RESOURCE WORLD.", NamedTextColor.RED));
        p.sendMessage(Component.text("  Mine and farm here freely - that is what it is for.",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("  This whole world is DELETED and regenerated every month.",
            NamedTextColor.YELLOW));
        p.sendMessage(Component.text("  Do not build a base or store anything you want to keep.",
            NamedTextColor.YELLOW));
        p.sendMessage(Component.text("  Your permanent base belongs in the main world - /home.",
            NamedTextColor.GRAY));
        p.sendMessage(Component.text("─────────────────────────────", NamedTextColor.DARK_GRAY));
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
