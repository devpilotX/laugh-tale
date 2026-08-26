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
    private WorldRules worldRules;
    private StatsTracker statsTracker;
    private CombatTracker combatTracker;
    private Moderation moderation;
    private AccessGrants accessGrants;
    private String rulesVersion;
    private List<String> rulesText;

    @Override
    public void onEnable() {
        saveDefaultConfig();
        loadSettings();

        this.rulesGate = new RulesGate(this);
        this.worldRules = new WorldRules(this);
        getServer().getPluginManager().registerEvents(this, this);
        getServer().getPluginManager().registerEvents(rulesGate, this);
        getServer().getPluginManager().registerEvents(worldRules, this);

        // Section 7.2. Applied here rather than over RCON because a console /gamerule
        // reaches only the default world and `execute in <dim> run gamerule` is rejected
        // by the 26.2 parser. Also re-applied on WorldLoadEvent, so the resource world
        // (7.4) and arena (7.1) inherit these rules when they are eventually created.
        worldRules.applyToAll();

        // Stats and combat. Both write only through Database, which refuses main-thread
        // calls, so acceptance row 25 is enforced by the layer below rather than by these
        // classes remembering to be careful.
        this.statsTracker = new StatsTracker(this, database);
        this.combatTracker = new CombatTracker(this, database, statsTracker);
        loadPrivateThresholds();
        getServer().getPluginManager().registerEvents(statsTracker, this);
        getServer().getPluginManager().registerEvents(combatTracker, this);
        statsTracker.start();

        // Moderation. Every command path writes a staff_audit row, including the ones that
        // fail validation - an audit that records only successes is a record of intentions.
        this.moderation = new Moderation(this, database);
        this.accessGrants = new AccessGrants(this, database);
        getServer().getPluginManager().registerEvents(moderation, this);

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

    /**
     * Loads the anti-farm thresholds from a PRIVATE file that is deliberately not part of
     * the plugin's committed config.
     *
     * Never-break rule 10: "Never publish detector thresholds for anti-cheat, wagering, or
     * market manipulation. Publishing them teaches evasion." A player who knows the
     * repeat-kill window is one hour and the limit is three knows exactly how to farm an
     * alt without ever being flagged.
     *
     * So `config.yml` - which is in git - contains none of these numbers, and
     * `private.yml` alongside it is created on the host, listed in .gitignore, and read
     * here. If it is absent the plugin still runs on conservative placeholders and says so
     * loudly, because silently running with unknown thresholds would be worse than either
     * alternative.
     */
    private void loadPrivateThresholds() {
        java.io.File f = new java.io.File(getDataFolder(), "private.yml");
        if (!f.isFile()) {
            combatTracker.configure(3_600_000L, 3, "", false);
            return;
        }
        org.bukkit.configuration.file.YamlConfiguration p =
            org.bukkit.configuration.file.YamlConfiguration.loadConfiguration(f);
        long window = p.getLong("anti-farm.repeat-kill-window-seconds", 3600L) * 1000L;
        int limit = p.getInt("anti-farm.repeat-kills-before-zero", 3);
        String salt = p.getString("anti-farm.ip-hash-salt", "");
        if (salt == null || salt.isBlank()) {
            getLogger().warning("private.yml has no ip-hash-salt. Same-IP detection still "
                + "works, but unsalted hashes of the IPv4 space are reversible by brute force.");
        }
        combatTracker.configure(window, limit, salt, true);
        // The VALUES are never logged - only that they were loaded. Logging them would put
        // them in a file that gets pasted into support threads.
        getLogger().info("Anti-farm thresholds loaded from private.yml (values not logged).");
    }

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

        if (moderation.handle(sender, name, args)) return true;
        if (name.equals("access")) return accessGrants.handle(sender, args);

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

        if (name.equals("season")) {
            // Season control is OWNER-ONLY by permission, and that is not a convenience:
            // 17.3 puts "season management, manual reset or manual Champion assignment" on
            // the never-grant-to-Admin list because "the integrity of the competition
            // depends on this being untouchable by staff".
            if (!sender.hasPermission("laughtail.season.reset")) {
                sender.sendMessage(Component.text(
                    "Season management is Owner and Console only (17.3).", NamedTextColor.RED));
                return true;
            }
            String sub = args.length > 0 ? args[0].toLowerCase() : "status";
            switch (sub) {
                case "status" -> getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    try {
                        java.util.List<String> lines = database.seasonSummary();
                        int active = database.activeSeason();
                        getServer().getScheduler().runTask(this, () -> {
                            sender.sendMessage(Component.text("Seasons (active: "
                                + (active < 0 ? "none" : active) + ")", NamedTextColor.GOLD));
                            if (lines.isEmpty()) {
                                sender.sendMessage(Component.text("  no seasons yet - /season start",
                                    NamedTextColor.GRAY));
                            }
                            for (String l : lines) {
                                sender.sendMessage(Component.text("  " + l, NamedTextColor.GRAY));
                            }
                        });
                    } catch (SQLException e) {
                        getLogger().log(Level.SEVERE, "season status failed: " + e.getMessage());
                    }
                });
                case "start" -> {
                    // 31.1 makes seasons monthly. 30 days rather than a calendar month so
                    // every season is the same length - a February champion should not have
                    // had three fewer days than a March one.
                    final int days = 30;
                    getServer().getScheduler().runTaskAsynchronously(this, () -> {
                        try {
                            int n = database.startSeason(days);
                            database.audit(null, sender.getName(), "season.start", null, null,
                                n < 0 ? "refused - a season is already running" : "season " + n, null);
                            getServer().getScheduler().runTask(this, () -> sender.sendMessage(
                                Component.text(n < 0
                                    ? "Refused: a season is already active, in finale or resetting."
                                    : "Season " + n + " started, ending in " + days + " days.",
                                    n < 0 ? NamedTextColor.RED : NamedTextColor.GREEN)));
                        } catch (SQLException e) {
                            getLogger().log(Level.SEVERE, "season start failed: " + e.getMessage());
                        }
                    });
                }
                case "end" -> getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    try {
                        int active = database.activeSeason();
                        if (active < 0) {
                            getServer().getScheduler().runTask(this, () -> sender.sendMessage(
                                Component.text("No active season.", NamedTextColor.RED)));
                            return;
                        }
                        String result = database.endSeason(active);
                        database.audit(null, sender.getName(), "season.end", null, null,
                            "season " + active + ": " + result, null);
                        getServer().getScheduler().runTask(this, () -> sender.sendMessage(
                            Component.text("Season " + active + ": " + result,
                                result.startsWith("REFUSED") ? NamedTextColor.RED : NamedTextColor.GREEN)));
                    } catch (SQLException e) {
                        getLogger().log(Level.SEVERE, "season end failed: " + e.getMessage());
                    }
                });
                default -> sender.sendMessage(Component.text(
                    "Usage: /season <status|start|end>", NamedTextColor.GRAY));
            }
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
                sender.sendMessage(Component.text("  worlds and Section 7.2 rules:", NamedTextColor.GRAY));
                for (String line : worldRules.describe().split("\n")) {
                    if (!line.isBlank()) sender.sendMessage(Component.text(line, NamedTextColor.DARK_GRAY));
                }
                sender.sendMessage(Component.text("  database: "
                    + (database.isHealthy() ? "reachable" : "NOT REACHABLE"),
                    database.isHealthy() ? NamedTextColor.GREEN : NamedTextColor.RED));
                getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    String line;
                    try {
                        line = "  players recorded: " + database.countPlayers()
                             + "   combat events: " + database.countCombatEvents()
                             + "   anti-farm config: "
                             + (combatTracker.isPrivateConfigLoaded() ? "private.yml" : "PLACEHOLDERS")
                             + "   stat flushes pending: " + statsTracker.pendingCount();
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
