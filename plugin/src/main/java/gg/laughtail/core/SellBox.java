package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import net.kyori.adventure.text.format.TextDecoration;
import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryCloseEvent;
import org.bukkit.event.inventory.InventoryDragEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.InventoryHolder;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;

import java.util.ArrayList;
import java.util.List;

/**
 * The sell box. Drop items in, see what they are worth, click once to sell.
 *
 * THIS IS THE ONE MENU THAT IS A REAL CONTAINER. Every other page cancels every click, because a
 * display that lets you take the buttons out is broken. Here the opposite is required: the deposit
 * area must accept items, so clicks in slots 0-44 are deliberately NOT cancelled while clicks on
 * the control row still are.
 *
 * WHICH CREATES THE ONLY WAY TO LOSE ITEMS IN THIS PLUGIN, so it is handled three times over:
 *
 *   1. On close, everything still in the box is returned to the player's inventory, and anything
 *      that will not fit is dropped at their feet rather than deleted.
 *   2. On quit - which does NOT always fire a close event first - the same return runs, and items
 *      that cannot fit are dropped in the world where they can be picked back up.
 *   3. On disable, every open sell box is emptied back to its owner, so a restart mid-session
 *      cannot swallow a stack.
 *
 * A GUI inventory is not saved anywhere. Items left in one at shutdown are simply gone, which is
 * why servers that get this wrong generate constant "the shop ate my stuff" reports. The box is
 * treated as a loan, never as storage.
 *
 * SHIFT-CLICK IS INTERCEPTED rather than allowed. Bukkit's own shift-click moves a stack to the
 * first free slot, which can be a control slot - so a shift-clicked stack could land on top of the
 * Sell button. Placement is done by hand into the deposit area only.
 */
final class SellBox implements Listener {

    /** Marks an inventory as a sell box. A client cannot fabricate a holder. */
    static final class SellHolder implements InventoryHolder {
        private final java.util.UUID owner;
        private SellHolder(java.util.UUID owner) { this.owner = owner; }
        @Override public Inventory getInventory() { return null; }
    }

    /** Slots 0-44 accept items. 45-53 are controls. */
    private static final int DEPOSIT_END = 45;
    private static final int SLOT_INFO = 49;
    private static final int SLOT_SELL = 48;
    private static final int SLOT_BACK = 45;
    private static final int SLOT_CLOSE = 53;

    private final LaughTailPlugin plugin;
    private final ShopService shop;

    SellBox(LaughTailPlugin plugin, ShopService shop) {
        this.plugin = plugin;
        this.shop = shop;
    }

    void open(Player p) {
        Inventory inv = Bukkit.createInventory(new SellHolder(p.getUniqueId()), 54,
            Component.text("Sell - put items in, then click Sell", NamedTextColor.GREEN));
        decorate(inv, 0L, 0);
        p.openInventory(inv);
    }

    /** Draws the control row and the running total. */
    private void decorate(Inventory inv, long value, int count) {
        inv.setItem(SLOT_BACK, button(Material.ARROW, "Back to menu", NamedTextColor.GRAY,
            List.of("Your items come back with you.")));
        inv.setItem(SLOT_SELL, button(Material.HOPPER,
            count == 0 ? "Sell - the box is empty" : "Sell " + count + " item(s)",
            count == 0 ? NamedTextColor.DARK_GRAY : NamedTextColor.GREEN,
            count == 0
                ? List.of("Drag items in from your inventory.",
                          "Anything the shop does not buy stays put.")
                : List.of("You receive " + value + " Berries.",
                          "Daily limit is 3600 per category;",
                          "anything over it is left in the box.")));
        inv.setItem(SLOT_INFO, button(Material.PAPER, "Value: " + value + " Berries",
            NamedTextColor.GOLD, List.of(
                "Prices move with trade, so this is",
                "what the shop pays right now.",
                "Selling is never rank-gated.")));
        inv.setItem(SLOT_CLOSE, button(Material.BARRIER, "Close", NamedTextColor.RED,
            List.of("Your items come back with you.")));
        // Fill the rest of the control row so the boundary is visible rather than implied.
        for (int i = DEPOSIT_END; i < 54; i++) {
            if (inv.getItem(i) == null) {
                inv.setItem(i, button(Material.GRAY_STAINED_GLASS_PANE, " ",
                    NamedTextColor.DARK_GRAY, List.of()));
            }
        }
    }

    private ItemStack button(Material m, String name, NamedTextColor c, List<String> lore) {
        ItemStack it = new ItemStack(m);
        ItemMeta meta = it.getItemMeta();
        meta.displayName(Component.text(name, c).decoration(TextDecoration.ITALIC, false));
        if (!lore.isEmpty()) {
            meta.lore(lore.stream()
                .map(s -> (Component) Component.text(s, NamedTextColor.GRAY)
                    .decoration(TextDecoration.ITALIC, false))
                .toList());
        }
        it.setItemMeta(meta);
        return it;
    }

    /** What the deposit area is currently worth, and how many units it holds. */
    private long[] valueOf(Inventory inv) {
        long value = 0;
        int count = 0;
        for (int i = 0; i < DEPOSIT_END; i++) {
            ItemStack it = inv.getItem(i);
            if (it == null || it.getType() == Material.AIR) continue;
            Shop.Entry e = Shop.entry(it.getType());
            if (e == null) continue;
            long unit = Shop.sellPrice(Shop.displayPrice(it.getType()));
            value += unit * it.getAmount();
            count += it.getAmount();
        }
        return new long[] { value, count };
    }

    private void refresh(Inventory inv) {
        long[] v = valueOf(inv);
        decorate(inv, v[0], (int) v[1]);
    }

    // ---- events --------------------------------------------------------------

    @EventHandler
    public void onClick(InventoryClickEvent e) {
        if (!(e.getInventory().getHolder() instanceof SellHolder)) return;
        if (!(e.getWhoClicked() instanceof Player p)) return;
        Inventory box = e.getInventory();
        int raw = e.getRawSlot();

        // A click in the player's own inventory. Shift-click is intercepted because Bukkit would
        // move the stack to the first free slot, which could be a control slot.
        if (raw >= box.getSize()) {
            if (e.isShiftClick()) {
                e.setCancelled(true);
                ItemStack moving = e.getCurrentItem();
                if (moving == null || moving.getType() == Material.AIR) return;
                if (Shop.entry(moving.getType()) == null) {
                    p.sendMessage(Component.text("The shop does not buy "
                        + moving.getType().name() + ".", NamedTextColor.GRAY));
                    return;
                }
                int placed = placeInDeposit(box, moving.clone());
                if (placed <= 0) {
                    p.sendMessage(Component.text("The sell box is full.", NamedTextColor.YELLOW));
                    return;
                }
                moving.setAmount(moving.getAmount() - placed);
                if (moving.getAmount() <= 0) e.setCurrentItem(null);
                refresh(box);
            } else {
                // A normal click in your own inventory is left alone, then the total is redrawn
                // a tick later once Bukkit has finished moving the item.
                plugin.getServer().getScheduler().runTask(plugin, () -> refresh(box));
            }
            return;
        }

        if (raw >= DEPOSIT_END) {
            e.setCancelled(true);
            ItemStack clicked = e.getCurrentItem();
            if (clicked == null) return;
            switch (clicked.getType()) {
                case BARRIER -> p.closeInventory();
                case ARROW -> {
                    returnItems(p, box);
                    plugin.getServer().getScheduler().runTask(plugin,
                        () -> plugin.menu().openMain(p));
                }
                case HOPPER -> sellContents(p, box);
                default -> { }
            }
            return;
        }

        // Slots 0-44: a real container. Not cancelled, so items can be put in and taken back out.
        // Non-sellable items are refused at the point of placement, because discovering it only
        // at checkout is worse feedback.
        ItemStack placing = e.getCursor();
        if (placing != null && placing.getType() != Material.AIR
                && Shop.entry(placing.getType()) == null) {
            e.setCancelled(true);
            p.sendMessage(Component.text("The shop does not buy " + placing.getType().name()
                + ". Nothing was taken.", NamedTextColor.GRAY));
            return;
        }
        plugin.getServer().getScheduler().runTask(plugin, () -> refresh(box));
    }

    @EventHandler
    public void onDrag(InventoryDragEvent e) {
        if (!(e.getInventory().getHolder() instanceof SellHolder)) return;
        // A drag that touches the control row is refused entirely rather than partially applied -
        // a half-applied drag is how items end up on top of buttons.
        for (int raw : e.getRawSlots()) {
            if (raw < e.getInventory().getSize() && raw >= DEPOSIT_END) {
                e.setCancelled(true);
                return;
            }
        }
        if (e.getOldCursor() != null && Shop.entry(e.getOldCursor().getType()) == null) {
            e.setCancelled(true);
            if (e.getWhoClicked() instanceof Player p) {
                p.sendMessage(Component.text("The shop does not buy "
                    + e.getOldCursor().getType().name() + ".", NamedTextColor.GRAY));
            }
            return;
        }
        Inventory box = e.getInventory();
        plugin.getServer().getScheduler().runTask(plugin, () -> refresh(box));
    }

    @EventHandler
    public void onClose(InventoryCloseEvent e) {
        if (!(e.getInventory().getHolder() instanceof SellHolder)) return;
        if (e.getPlayer() instanceof Player p) returnItems(p, e.getInventory());
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        // A quit does not reliably fire a close first. Without this, logging out with a full box
        // would delete the contents.
        Inventory top = e.getPlayer().getOpenInventory().getTopInventory();
        if (top.getHolder() instanceof SellHolder) returnItems(e.getPlayer(), top);
    }

    /** Empties every open sell box back to its owner. Called from onDisable. */
    void returnAllOnShutdown() {
        for (Player p : plugin.getServer().getOnlinePlayers()) {
            Inventory top = p.getOpenInventory().getTopInventory();
            if (top.getHolder() instanceof SellHolder) {
                returnItems(p, top);
                p.closeInventory();
            }
        }
    }

    /** Puts everything in the deposit area back, dropping what will not fit. Never deletes. */
    private void returnItems(Player p, Inventory box) {
        for (int i = 0; i < DEPOSIT_END; i++) {
            ItemStack it = box.getItem(i);
            if (it == null || it.getType() == Material.AIR) continue;
            box.setItem(i, null);
            for (ItemStack leftover : p.getInventory().addItem(it).values()) {
                // Dropped rather than discarded. A dropped item can be picked up; a deleted one
                // is a support ticket.
                p.getWorld().dropItemNaturally(p.getLocation(), leftover);
            }
        }
    }

    private int placeInDeposit(Inventory box, ItemStack stack) {
        int remaining = stack.getAmount();
        int max = stack.getMaxStackSize();
        for (int i = 0; i < DEPOSIT_END && remaining > 0; i++) {
            ItemStack slot = box.getItem(i);
            if (slot == null || slot.getType() == Material.AIR) {
                ItemStack put = stack.clone();
                put.setAmount(Math.min(remaining, max));
                box.setItem(i, put);
                remaining -= put.getAmount();
            } else if (slot.isSimilar(stack) && slot.getAmount() < max) {
                int room = Math.min(max - slot.getAmount(), remaining);
                slot.setAmount(slot.getAmount() + room);
                remaining -= room;
            }
        }
        return stack.getAmount() - remaining;
    }

    /**
     * Sells the box.
     *
     * Items are taken out of the box FIRST and held, then sold; anything the sale could not take -
     * a daily cap, a worthless item - is put back. Selling straight from the box would leave a
     * window where a second click could sell the same stack twice.
     */
    private void sellContents(Player p, Inventory box) {
        List<ItemStack> held = new ArrayList<>();
        for (int i = 0; i < DEPOSIT_END; i++) {
            ItemStack it = box.getItem(i);
            if (it == null || it.getType() == Material.AIR) continue;
            held.add(it.clone());
            box.setItem(i, null);
        }
        if (held.isEmpty()) {
            p.sendMessage(Component.text("The box is empty. Put items in first.",
                NamedTextColor.GRAY));
            return;
        }
        refresh(box);
        shop.sellStacks(p, held, box, this);
    }

    /** Puts a stack back into the box, or into the player if the box is gone. */
    void putBack(Player p, Inventory box, ItemStack stack) {
        int placed = placeInDeposit(box, stack);
        if (placed < stack.getAmount()) {
            ItemStack rest = stack.clone();
            rest.setAmount(stack.getAmount() - placed);
            for (ItemStack leftover : p.getInventory().addItem(rest).values()) {
                p.getWorld().dropItemNaturally(p.getLocation(), leftover);
            }
        }
        refresh(box);
    }
}
