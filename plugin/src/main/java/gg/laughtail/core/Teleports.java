package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.World;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Player-to-player teleport requests, and random teleport.
 *
 * RTP SENDS PLAYERS TO THE RESOURCE WORLD, not the overworld. That is the whole point of 7.4:
 * "all serious mining and bulk farming happens in the resource world, which is regenerated with
 * the monthly season reset. The main world keeps its landscape permanently." An /rtp that drops
 * people into the overworld would spread exactly the strip-mined moonscape 7.4 exists to
 * prevent - it would be a feature actively working against the design.
 *
 * REQUESTS EXPIRE. A tpa request that waits forever becomes a trap: a player accepts one from
 * twenty minutes ago and is pulled somewhere unexpected, possibly into an ambush. Sixty seconds
 * is long enough to notice and short enough to be about the moment it was sent.
 *
 * TPA IS OPT-IN BY ACCEPTANCE, always. There is no /tpaall, no auto-accept and no staff
 * override for pulling a player - being teleported without consent is how a PvP server becomes
 * a trapping game. Staff who need to reach someone use /tp to coordinates, which is a separate
 * permission (laughtail.tp.player) and is audited.
 *
 * SAFETY SEARCH FOR RTP. A random x,z is usually not a safe place to stand: it can be inside
 * stone, over lava, or in the void above the nether roof. The search checks the highest solid
 * block, refuses lava and water, refuses a spot with no air above it, and retries. It gives up
 * after a bounded number of attempts rather than looping - an unbounded search on a 2 vCPU box
 * generating fresh chunks is how a single command stalls a server.
 */
final class Teleports {

    private static final long REQUEST_TTL_MILLIS = 60_000L;
    private static final long RTP_COOLDOWN_MILLIS = 60_000L;
    private static final long WARMUP_MILLIS = 3_000L;
    private static final int RTP_ATTEMPTS = 12;
    /** Kept inside the resource world's 3000 border with a margin, so RTP never lands on it. */
    private static final int RTP_RADIUS = 1_400;

    private record Request(UUID from, boolean here, long at) { }

    private final LaughTailPlugin plugin;
    /** target -> pending request. One at a time: a queue of requests is a queue of surprises. */
    private final Map<UUID, Request> pending = new ConcurrentHashMap<>();
    private final Map<UUID, Long> lastRtp = new ConcurrentHashMap<>();
    private final Random random = new Random();

    Teleports(LaughTailPlugin plugin) {
        this.plugin = plugin;
    }

    boolean handle(CommandSender sender, String cmd, String[] args) {
        if (!(sender instanceof Player p)) return false;
        switch (cmd) {
            case "tpa":      return request(p, args, false);
            case "tpahere":  return request(p, args, true);
            case "tpaccept": return accept(p);
            case "tpdeny":   return deny(p);
            case "rtp":
            case "wild":     return rtp(p);
            default:         return false;
        }
    }

    private boolean request(Player from, String[] args, boolean here) {
        if (args.length < 1) {
            from.sendMessage(Component.text("Usage: /" + (here ? "tpahere" : "tpa") + " <player>",
                NamedTextColor.GRAY));
            return true;
        }
        Player target = plugin.getServer().getPlayerExact(args[0]);
        if (target == null || !target.isOnline()) {
            from.sendMessage(Component.text("That player is not online.", NamedTextColor.RED));
            return true;
        }
        if (target.getUniqueId().equals(from.getUniqueId())) {
            from.sendMessage(Component.text("You are already there.", NamedTextColor.GRAY));
            return true;
        }
        pending.put(target.getUniqueId(),
            new Request(from.getUniqueId(), here, System.currentTimeMillis()));
        from.sendMessage(Component.text("Request sent to " + target.getName()
            + ". It expires in 60 seconds.", NamedTextColor.GREEN));
        target.sendMessage(Component.text(from.getName()
            + (here ? " wants you to teleport to them." : " wants to teleport to you."),
            NamedTextColor.GOLD));
        target.sendMessage(Component.text("  /tpaccept  or  /tpdeny", NamedTextColor.GRAY));
        return true;
    }

    private boolean accept(Player target) {
        Request r = pending.remove(target.getUniqueId());
        if (r == null) {
            target.sendMessage(Component.text("You have no pending request.", NamedTextColor.RED));
            return true;
        }
        if (System.currentTimeMillis() - r.at() > REQUEST_TTL_MILLIS) {
            target.sendMessage(Component.text(
                "That request expired. Ask them to send it again.", NamedTextColor.YELLOW));
            return true;
        }
        Player from = plugin.getServer().getPlayer(r.from());
        if (from == null || !from.isOnline()) {
            target.sendMessage(Component.text("They are no longer online.", NamedTextColor.RED));
            return true;
        }
        // `here` reverses who moves. Naming it explicitly avoids the classic bug where
        // /tpahere teleports the wrong person.
        final Player mover = r.here() ? target : from;
        final Player anchor = r.here() ? from : target;
        mover.sendMessage(Component.text("Teleporting in " + (WARMUP_MILLIS / 1000)
            + "s - do not move.", NamedTextColor.GRAY));
        final Location startedAt = mover.getLocation();
        plugin.getServer().getScheduler().runTaskLater(plugin, () -> {
            if (!mover.isOnline() || !anchor.isOnline()) return;
            if (startedAt.distanceSquared(mover.getLocation()) > 1.0) {
                mover.sendMessage(Component.text("Teleport cancelled - you moved.",
                    NamedTextColor.RED));
                return;
            }
            mover.teleportAsync(anchor.getLocation());
        }, WARMUP_MILLIS / 50);
        return true;
    }

    private boolean deny(Player target) {
        Request r = pending.remove(target.getUniqueId());
        target.sendMessage(Component.text(r == null ? "No pending request." : "Request denied.",
            NamedTextColor.GRAY));
        if (r != null) {
            Player from = plugin.getServer().getPlayer(r.from());
            if (from != null) {
                from.sendMessage(Component.text(target.getName() + " denied your request.",
                    NamedTextColor.YELLOW));
            }
        }
        return true;
    }

    private boolean rtp(Player p) {
        long since = System.currentTimeMillis() - lastRtp.getOrDefault(p.getUniqueId(), 0L);
        if (since < RTP_COOLDOWN_MILLIS) {
            p.sendMessage(Component.text("Wait " + ((RTP_COOLDOWN_MILLIS - since) / 1000 + 1)
                + "s before using /rtp again.", NamedTextColor.YELLOW));
            return true;
        }

        World resource = null;
        for (World w : plugin.getServer().getWorlds()) {
            if (w.getName().contains("resource")) { resource = w; break; }
        }
        if (resource == null) {
            p.sendMessage(Component.text(
                "The resource world is not available right now.", NamedTextColor.RED));
            return true;
        }
        final World target = resource;
        p.sendMessage(Component.text(
            "Searching the resource world for safe ground. This can take a few seconds - the "
          + "server may have to generate that part of the map first.", NamedTextColor.GRAY));

        attemptRtp(p, target, 0);
        return true;
    }

    /**
     * Tries one candidate per call, chaining through the scheduler rather than looping.
     *
     * Looping would block the main thread while chunks generate - on this box that is the
     * difference between a command and a freeze. Chaining lets each attempt load its chunk
     * asynchronously and yields between tries.
     */
    private void attemptRtp(Player p, World world, int attempt) {
        if (!p.isOnline()) return;
        if (attempt >= RTP_ATTEMPTS) {
            p.sendMessage(Component.text(
                "Could not find a safe spot after " + RTP_ATTEMPTS + " tries. Try again.",
                NamedTextColor.RED));
            return;
        }
        int x = random.nextInt(RTP_RADIUS * 2) - RTP_RADIUS;
        int z = random.nextInt(RTP_RADIUS * 2) - RTP_RADIUS;

        world.getChunkAtAsync(x >> 4, z >> 4).thenAccept(chunk -> {
            if (!p.isOnline()) return;
            int y = world.getHighestBlockYAt(x, z);
            Location candidate = new Location(world, x + 0.5, y + 1, z + 0.5);
            Material under = world.getBlockAt(x, y, z).getType();
            Material at = world.getBlockAt(x, y + 1, z).getType();
            Material above = world.getBlockAt(x, y + 2, z).getType();

            boolean safe = under.isSolid()
                && under != Material.LAVA && under != Material.WATER
                && under != Material.MAGMA_BLOCK && under != Material.CACTUS
                && at.isAir() && above.isAir()
                && y > world.getMinHeight() + 2 && y < world.getMaxHeight() - 3;

            if (!safe) {
                attemptRtp(p, world, attempt + 1);
                return;
            }
            final Location startedAt = p.getLocation();
            p.sendMessage(Component.text("Found safe ground after "
                + (attempt + 1) + (attempt == 0 ? " try" : " tries") + ". Teleporting in "
                + (WARMUP_MILLIS / 1000) + "s - do not move.", NamedTextColor.GRAY));
            plugin.getServer().getScheduler().runTaskLater(plugin, () -> {
                if (!p.isOnline()) return;
                if (startedAt.distanceSquared(p.getLocation()) > 1.0) {
                    p.sendMessage(Component.text("Teleport cancelled - you moved.",
                        NamedTextColor.RED));
                    return;
                }
                lastRtp.put(p.getUniqueId(), System.currentTimeMillis());
                p.teleportAsync(candidate).thenAccept(ok -> {
                    if (ok) {
                        p.sendMessage(Component.text(
                            "Welcome to the resource world. Everything here resets monthly - "
                          + "mine freely, but do not build anything you want to keep.",
                            NamedTextColor.GOLD));
                    }
                });
            }, WARMUP_MILLIS / 50);
        });
    }

    /** Clears state for a leaving player so nothing leaks. */
    void forget(UUID uuid) {
        pending.remove(uuid);
        lastRtp.remove(uuid);
        pending.entrySet().removeIf(e -> e.getValue().from().equals(uuid));
    }
}
