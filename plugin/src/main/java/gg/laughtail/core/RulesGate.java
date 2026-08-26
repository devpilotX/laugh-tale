package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.inventory.InventoryOpenEvent;
import org.bukkit.event.player.AsyncPlayerChatEvent;
import org.bukkit.event.player.PlayerCommandPreprocessEvent;
import org.bukkit.event.player.PlayerDropItemEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.player.PlayerMoveEvent;
import org.bukkit.event.player.PlayerQuitEvent;

import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * The rules gate. Acceptance row 17: "A new player cannot move, build or chat
 * before accepting; acceptance is stored with a version."
 *
 * WHY EACH EVENT IS BLOCKED. Row 17 names move, build and chat. Blocking only those
 * three would leave a gated player able to open chests, drop items, hit other
 * players and run commands - so the gate would be theatre. What is blocked here is
 * everything that changes the world or interacts with anyone, and nothing else.
 *
 * WHAT IS DELIBERATELY NOT BLOCKED: looking around. PlayerMoveEvent fires for
 * head rotation as well as position, so cancelling every move would freeze the
 * camera and feel like a crash rather than a gate. Only actual position changes are
 * cancelled - the player can look around and read, which is the point.
 *
 * The allowed command list is minimal and explicit. A gated player must be able to
 * accept the rules and read them; everything else waits.
 */
public final class RulesGate implements Listener {

    private final LaughTailPlugin plugin;
    private final Set<UUID> gated = ConcurrentHashMap.newKeySet();

    private static final Set<String> ALLOWED_COMMANDS = Set.of(
        "/rules", "/rules accept", "/help"
    );

    RulesGate(LaughTailPlugin plugin) {
        this.plugin = plugin;
    }

    void gate(Player p) {
        gated.add(p.getUniqueId());
        showRules(p);
    }

    void release(Player p) {
        gated.remove(p.getUniqueId());
    }

    boolean isGated(Player p) {
        return gated.contains(p.getUniqueId());
    }

    void showRules(Player p) {
        p.sendMessage(Component.text("─────────────────────────────", NamedTextColor.DARK_GRAY));
        p.sendMessage(Component.text("LAUGH TALE — the rules", NamedTextColor.GOLD));
        p.sendMessage(Component.empty());
        for (String line : plugin.rulesText()) {
            p.sendMessage(Component.text("  " + line, NamedTextColor.GRAY));
        }
        p.sendMessage(Component.empty());
        p.sendMessage(Component.text("  Type ", NamedTextColor.YELLOW)
            .append(Component.text("/rules accept", NamedTextColor.GREEN))
            .append(Component.text(" to continue.", NamedTextColor.YELLOW)));
        p.sendMessage(Component.text("  You cannot move, build or chat until you do.", NamedTextColor.DARK_GRAY));
        p.sendMessage(Component.text("─────────────────────────────", NamedTextColor.DARK_GRAY));
    }

    private void deny(Player p) {
        p.sendActionBar(Component.text("Accept the rules first: /rules accept", NamedTextColor.RED));
    }

    // Position changes only. Head rotation is allowed on purpose - see the class note.
    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onMove(PlayerMoveEvent e) {
        if (!isGated(e.getPlayer())) return;
        if (e.getFrom().getX() == e.getTo().getX()
         && e.getFrom().getY() == e.getTo().getY()
         && e.getFrom().getZ() == e.getTo().getZ()) {
            return;
        }
        e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        if (isGated(e.getPlayer())) { e.setCancelled(true); deny(e.getPlayer()); }
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        if (isGated(e.getPlayer())) { e.setCancelled(true); deny(e.getPlayer()); }
    }

    @SuppressWarnings("deprecation") // AsyncPlayerChatEvent: Paper's replacement is not on the 1.21 API surface uniformly
    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onChat(AsyncPlayerChatEvent e) {
        if (isGated(e.getPlayer())) { e.setCancelled(true); deny(e.getPlayer()); }
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onInteract(PlayerInteractEvent e) {
        if (isGated(e.getPlayer())) { e.setCancelled(true); }
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onInventory(InventoryOpenEvent e) {
        if (e.getPlayer() instanceof Player p && isGated(p)) { e.setCancelled(true); deny(p); }
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onDrop(PlayerDropItemEvent e) {
        if (isGated(e.getPlayer())) { e.setCancelled(true); }
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onDamage(EntityDamageByEntityEvent e) {
        if (e.getDamager() instanceof Player p && isGated(p)) { e.setCancelled(true); deny(p); }
    }

    @EventHandler(priority = EventPriority.LOWEST, ignoreCancelled = true)
    public void onCommand(PlayerCommandPreprocessEvent e) {
        if (!isGated(e.getPlayer())) return;
        String msg = e.getMessage().toLowerCase().trim();
        for (String allowed : ALLOWED_COMMANDS) {
            if (msg.equals(allowed) || msg.startsWith(allowed + " ")) return;
        }
        e.setCancelled(true);
        deny(e.getPlayer());
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        // Do not leak UUIDs for players who left mid-gate.
        gated.remove(e.getPlayer().getUniqueId());
    }
}
