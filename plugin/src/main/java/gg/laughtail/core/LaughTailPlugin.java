package gg.laughtail.core;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.plugin.java.JavaPlugin;

import java.sql.SQLException;
import java.util.List;
import java.util.logging.Level;

/**
 * LaughTail core.
 *
 * Scope at 0.1.0, deliberately small and complete rather than broad and half-done
 * (standing bias: fewer features working perfectly):
 *
 *   - registers every joining player in the database, keyed on UUID
 *   - enforces the rules gate (acceptance row 17) with the accepted VERSION stored
 *   - /laughtail status, so the server can be asked whether it is actually healthy
 *   - /laughtail reload, which is what never-break rule 7 says to use instead of
 *     vanilla /reload
 *
 * NOT here yet, and not pretended: Berries, rank, seasons, shop, cosmetics, the 6.6
 * watchdog. Those are Phases 3 to 7 and several are blocked on owner decisions
 * (Q-10 economy numbers, OA-12 price).
 */
public final class LaughTailPlugin extends JavaPlugin implements Listener {

    private Database database;
    private RulesGate rulesGate;
    private String rulesVersion;
    private List<String> rulesText;

    @Override
    public void onEnable() {
        saveDefaultConfig();
        loadSettings();

        this.rulesGate = new RulesGate(this);
        getServer().getPluginManager().registerEvents(this, this);
        getServer().getPluginManager().registerEvents(rulesGate, this);

        // Connectivity is checked ASYNCHRONOUSLY. Doing it here on the main thread
        // would block startup on a network timeout, and acceptance row 25 forbids
        // main-thread database work regardless of how convenient it is.
        getServer().getScheduler().runTaskAsynchronously(this, () -> {
            boolean ok = database.checkConnectivity();
            if (ok) {
                getLogger().info("Database reachable, migration V1 present.");
            } else {
                getLogger().severe("STARTING WITHOUT A WORKING DATABASE. "
                    + "Players will be gated and cannot be recorded. Fix the database, "
                    + "then /laughtail reload.");
            }
        });

        getLogger().info("LaughTail " + getPluginMeta().getVersion() + " enabled. Rules version "
            + rulesVersion + ".");
    }

    private void loadSettings() {
        FileConfiguration c = getConfig();
        this.rulesVersion = c.getString("rules.version", "0-draft");
        this.rulesText = c.getStringList("rules.text");
        if (rulesText.isEmpty()) {
            rulesText = List.of("The rules have not been written yet (owner action OA-13).");
        }
        this.database = new Database(
            this,
            c.getString("database.host", "127.0.0.1"),
            c.getInt("database.port", 3306),
            c.getString("database.schema", "laughtail"),
            c.getString("database.user", "laughtail"),
            c.getString("database.password", "")
        );
    }

    String rulesVersion() { return rulesVersion; }
    List<String> rulesText() { return rulesText; }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        Player p = e.getPlayer();

        // Gate FIRST, release later if the database says they have accepted. The
        // safe default is gated: if the database is down, a player who has already
        // accepted is inconvenienced, whereas the opposite default would let an
        // unaccepted player straight in and quietly break row 17.
        if (!p.hasPermission("laughtail.rules.bypass")) {
            rulesGate.gate(p);
        }

        getServer().getScheduler().runTaskAsynchronously(this, () -> {
            try {
                String accepted = database.registerAndGetAcceptedRules(
                    p.getUniqueId(), p.getName());
                if (rulesVersion.equals(accepted)) {
                    getServer().getScheduler().runTask(this, () -> {
                        if (p.isOnline()) {
                            rulesGate.release(p);
                            p.sendMessage(Component.text("Welcome back to Laugh Tale.", NamedTextColor.GOLD));
                        }
                    });
                } else if (accepted != null) {
                    // Accepted an OLDER version. This is precisely why row 17 wants
                    // the version stored rather than a boolean.
                    getServer().getScheduler().runTask(this, () -> {
                        if (p.isOnline()) {
                            p.sendMessage(Component.text(
                                "The rules have changed since you last accepted them.",
                                NamedTextColor.YELLOW));
                        }
                    });
                }
            } catch (SQLException ex) {
                getLogger().log(Level.SEVERE,
                    "Could not record player " + p.getUniqueId() + ": " + ex.getMessage());
                getServer().getScheduler().runTask(this, () -> {
                    if (p.isOnline()) {
                        p.sendMessage(Component.text(
                            "The server could not reach its database. Staff have been notified.",
                            NamedTextColor.RED));
                    }
                });
            }
        });
    }

    @Override
    public boolean onCommand(CommandSender sender, Command cmd, String label, String[] args) {
        String name = cmd.getName().toLowerCase();

        if (name.equals("rules")) {
            if (!(sender instanceof Player p)) {
                sender.sendMessage("Rules version " + rulesVersion);
                return true;
            }
            if (args.length == 0) {
                rulesGate.showRules(p);
                return true;
            }
            if (args[0].equalsIgnoreCase("accept")) {
                if (!p.hasPermission("laughtail.rules.accept")) {
                    p.sendMessage(Component.text("You cannot accept the rules.", NamedTextColor.RED));
                    return true;
                }
                if (!rulesGate.isGated(p)) {
                    p.sendMessage(Component.text("You have already accepted the current rules.",
                        NamedTextColor.GRAY));
                    return true;
                }
                final String version = rulesVersion;
                getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    try {
                        database.recordRulesAcceptance(p.getUniqueId(), version);
                        getServer().getScheduler().runTask(this, () -> {
                            if (p.isOnline()) {
                                rulesGate.release(p);
                                p.sendMessage(Component.text(
                                    "Rules accepted (version " + version + "). Welcome to Laugh Tale.",
                                    NamedTextColor.GREEN));
                            }
                        });
                    } catch (SQLException ex) {
                        getLogger().log(Level.SEVERE, "Could not store rules acceptance: " + ex.getMessage());
                        getServer().getScheduler().runTask(this, () -> {
                            if (p.isOnline()) {
                                // NOT released. An acceptance that was not stored did
                                // not happen - releasing anyway would make row 17 a lie.
                                p.sendMessage(Component.text(
                                    "Could not save your acceptance. Please try again.",
                                    NamedTextColor.RED));
                            }
                        });
                    }
                });
                return true;
            }
            p.sendMessage(Component.text("Usage: /rules [accept]", NamedTextColor.GRAY));
            return true;
        }

        if (name.equals("laughtail")) {
            if (args.length == 0 || args[0].equalsIgnoreCase("status")) {
                if (!sender.hasPermission("laughtail.status")) {
                    sender.sendMessage(Component.text("No permission.", NamedTextColor.RED));
                    return true;
                }
                sender.sendMessage(Component.text("LaughTail " + getPluginMeta().getVersion(),
                    NamedTextColor.GOLD));
                sender.sendMessage(Component.text("  rules version: " + rulesVersion, NamedTextColor.GRAY));
                sender.sendMessage(Component.text("  database: "
                    + (database.isHealthy() ? "reachable" : "NOT REACHABLE"),
                    database.isHealthy() ? NamedTextColor.GREEN : NamedTextColor.RED));
                getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    String line;
                    try {
                        line = "  players recorded: " + database.countPlayers();
                    } catch (SQLException ex) {
                        line = "  players recorded: query failed - " + ex.getMessage();
                    }
                    final String out = line;
                    getServer().getScheduler().runTask(this, () ->
                        sender.sendMessage(Component.text(out, NamedTextColor.GRAY)));
                });
                return true;
            }
            if (args[0].equalsIgnoreCase("reload")) {
                if (!sender.hasPermission("laughtail.reload")) {
                    sender.sendMessage(Component.text("No permission.", NamedTextColor.RED));
                    return true;
                }
                reloadConfig();
                loadSettings();
                getServer().getScheduler().runTaskAsynchronously(this, () -> database.checkConnectivity());
                sender.sendMessage(Component.text(
                    "LaughTail config reloaded. Rules version " + rulesVersion + ".",
                    NamedTextColor.GREEN));
                sender.sendMessage(Component.text(
                    "This is the reload to use - never vanilla /reload (never-break rule 7).",
                    NamedTextColor.DARK_GRAY));
                return true;
            }
            sender.sendMessage(Component.text("Usage: /laughtail <status|reload>", NamedTextColor.GRAY));
            return true;
        }
        return false;
    }
}
