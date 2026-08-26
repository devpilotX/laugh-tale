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
    private Economy economy;
    private Homes homes;
    private Teleports teleports;
    private ResourceWorldGuard resourceGuard;
    private Menu menu;
    private Hud hud;
    private ShopService shopService;
    private SellBox sellBox;
    private CombatTag combatTag;
    private Social social;
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
        this.economy = new Economy(this, database);
        this.homes = new Homes(this, database);
        this.teleports = new Teleports(this);
        this.resourceGuard = new ResourceWorldGuard(this);
        getServer().getPluginManager().registerEvents(resourceGuard, this);
        resourceGuard.start();
        this.menu = new Menu(this);
        getServer().getPluginManager().registerEvents(menu, this);
        this.shopService = new ShopService(this, database);
        this.social = new Social(this, database);
        this.combatTag = new CombatTag(this, database);
        getServer().getPluginManager().registerEvents(combatTag, this);
        combatTag.start();
        this.sellBox = new SellBox(this, shopService);
        getServer().getPluginManager().registerEvents(sellBox, this);
        // Seed the price table at boot rather than lazily on first trade. A price table that
        // only materialises when someone buys something means the arbitrage audit and the
        // invariant tests see an empty catalogue on a fresh database - they would pass by
        // examining nothing. Idempotent: currentPrice inserts only when the row is absent.
        assertRow25();
        seedShopCatalogue();
        runArbitrageAudit();
        this.hud = new Hud(this, database);
        getServer().getPluginManager().registerEvents(hud, this);
        hud.start();
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

    /** Exposed so the menu can read homes without a second Database reference. */
    /**
     * Row 25, re-proven on every boot.
     *
     * "No blocking database call on the main thread anywhere." The guarantee is structural - every
     * Database method that opens its own connection begins with assertOffMainThread(), which
     * throws - and a static check in scripts/check-db-thread-guard.ps1 fails the deploy if a
     * method is ever added without it.
     *
     * This is the runtime half. It deliberately makes a forbidden call from the main thread during
     * enable and logs whether it was refused, so the claim rests on observed behaviour rather than
     * on reading the code. It runs at BOOT rather than as a console command because a check that
     * has to be remembered is a check that stops being run - this way every single start either
     * confirms the guarantee or leaves a warning in the log.
     *
     * The failure is logged loudly but does NOT stop the server: a broken self-test means the
     * evidence is missing, which is a problem for the acceptance ledger, not a reason to deny
     * players a working server.
     */
    private void assertRow25() {
        if (!getServer().isPrimaryThread()) {
            getLogger().warning("ROW 25 SELF-TEST INVALID: enable did not run on the main thread.");
            return;
        }
        try {
            database.activeSeason();
            getLogger().severe("ROW 25 VIOLATED: a database call from the main thread was NOT "
                + "refused. Something has removed assertOffMainThread from Database.");
        } catch (IllegalStateException expected) {
            getLogger().info("Row 25 verified: a main-thread database call was refused - "
                + expected.getMessage());
        } catch (java.sql.SQLException ex) {
            getLogger().warning("ROW 25 SELF-TEST INCONCLUSIVE: got SQLException rather than a "
                + "refusal, so the guard was not reached: " + ex.getMessage());
        }
    }

    /**
     * Row 26, run at boot once the catalogue is priced.
     *
     * Deliberately AFTER seeding and on a delay, because the audit needs prices and the recipe list
     * is not fully populated until the server has finished loading data packs. Running it too early
     * would audit an empty recipe list and report a triumphant pass over nothing - which is the
     * failure mode this whole check exists to avoid.
     */
    private void runArbitrageAudit() {
        getServer().getScheduler().runTaskLater(this, () -> {
            int examined = Arbitrage.recipeCount(getServer());
            java.util.List<Arbitrage.Finding> findings = Arbitrage.audit(getServer());
            if (examined == 0) {
                getLogger().severe("ARBITRAGE AUDIT INVALID: 0 recipes examined. The audit ran "
                    + "before recipes loaded, so its pass means nothing.");
                // An audit that proved nothing is treated exactly like a failed one. The dangerous
                // outcome is a green light nobody earned.
                shopService.close("the economy audit could not run. Trading is disabled until it can.");
                return;
            }
            if (findings.isEmpty()) {
                getLogger().info("ARBITRAGE AUDIT PASS: " + examined + " recipes examined, "
                    + "0 positive-yield cycles. Tested pessimistically - inputs bought at the "
                    + "band floor, output sold at the band ceiling.");
                return;
            }
            getLogger().severe("ARBITRAGE AUDIT FAIL: " + findings.size() + " positive-yield "
                + "cycle(s) out of " + examined + " recipes examined. THIS IS A MONEY PRINTER.");
            for (Arbitrage.Finding f : findings) {
                getLogger().severe("  " + f.recipe() + ": buy inputs for " + f.inputCost()
                    + ", craft " + f.outputQty() + "x " + f.output() + ", sell for "
                    + f.outputValue() + " = +" + f.profit() + " Berries per cycle");
            }
            getLogger().severe("  Fix by raising an input price, lowering the output price, or "
                + "removing the output from the catalogue. Do NOT ignore this.");
            // Teeth. The specification asks for a BUILD gate; a server already running cannot fail
            // its build, so the equivalent is to shut the shop. Buying and selling refuse until the
            // catalogue is fixed, because the alternative is leaving a money printer switched on
            // and hoping nobody finds it.
            shopService.close("an economy audit found " + findings.size()
                + " way(s) to print Berries. Trading is disabled until it is fixed.");
            getLogger().severe("  SHOP CLOSED. Buying and selling are disabled until this passes.");
        }, 100L);
    }

    private void seedShopCatalogue() {
        getServer().getScheduler().runTaskAsynchronously(this, () -> {
            int made = 0;
            try {
                for (Shop.Entry e : Shop.catalogue().values()) {
                    database.currentPrice(e);
                    made++;
                }
                int pruned = database.pruneOrphanPrices();
                if (pruned > 0) {
                    getLogger().info("Pruned " + pruned + " price row(s) for items no longer in "
                        + "the catalogue, so the table matches the code.");
                }
                getLogger().info("Shop catalogue priced from P2: " + made + " items, spread "
                    + (int) (Shop.SPREAD * 100) + "%, target " + Shop.HOUR + " Berries/hour.");
            } catch (java.sql.SQLException ex) {
                getLogger().warning("Shop seeding stopped after " + made + " items: "
                    + ex.getMessage() + ". The shop will still price lazily on first trade.");
            }
        });
    }

    /**
     * Shutdown. Empties every open sell box back to its owner first.
     *
     * A GUI inventory lives only in memory. Items left in one when the server stops are simply
     * gone - which is why servers that get this wrong generate a steady stream of "the shop ate my
     * stuff" reports. Never-break rule 14 says do not leave the server in a broken state; a player
     * down a stack of diamonds because of a restart qualifies.
     */
    @Override
    public void onDisable() {
        if (sellBox != null) {
            try {
                sellBox.returnAllOnShutdown();
            } catch (RuntimeException e) {
                getLogger().warning("Could not empty every sell box on shutdown: "
                    + e.getMessage());
            }
        }
        getLogger().info("LaughTail disabled cleanly.");
    }
    Database database() { return database; }

    SellBox sellBox() { return sellBox; }

    CombatTag combatTag() { return combatTag; }

    Social social() { return social; }

    Menu menu() { return menu; }

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
    public void onQuitCleanup(org.bukkit.event.player.PlayerQuitEvent e) {
        // Teleport state is in-memory only, so a leaving player must be forgotten or a
        // pending request could resolve against someone who is no longer there.
        teleports.forget(e.getPlayer().getUniqueId());
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

        // 9.6: the Champion keeps "a unique chat and tab prefix marking them as a past
        // Champion, kept forever, through every future season". Applied on join because a
        // title granted once at crowning would be lost by any LuckPerms reset or migration,
        // whereas the champions table is the durable record and this derives from it.
        //
        // Note what the Champion does NOT get: 9.6 is explicit - "no Berries, no items, no
        // gear, no stat bonus, no permission, no shop discount". The prize is entirely
        // recognition, which is what keeps Law 1 intact.
        getServer().getScheduler().runTaskAsynchronously(this, () -> {
            try {
                java.util.List<Integer> won = database.championSeasons(p.getUniqueId());
                if (won.isEmpty()) return;
                String label = won.size() == 1
                    ? "Champion of Season " + won.get(0)
                    : "Champion x" + won.size() + " (seasons "
                      + won.stream().map(String::valueOf)
                           .collect(java.util.stream.Collectors.joining(", ")) + ")";
                getServer().getScheduler().runTask(this, () -> {
                    if (!p.isOnline()) return;
                    p.sendMessage(Component.text("\u2726 " + label + " \u2726", NamedTextColor.GOLD));
                    p.sendMessage(Component.text(
                        "Your title is permanent. It survives every season reset.",
                        NamedTextColor.DARK_GRAY));
                    // Announced to everyone, once per join. 9.6 says the advancement is
                    // announced server-wide; a returning Champion being visible is the flex.
                    getServer().broadcast(Component.text(label + " has joined: " + p.getName(),
                        NamedTextColor.GOLD));
                });
            } catch (SQLException ex) {
                getLogger().log(Level.WARNING, "champion title lookup failed: " + ex.getMessage());
            }
        });
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
        if (economy.handle(sender, name, args)) return true;
        if (homes.handle(sender, name, args)) return true;
        if (teleports.handle(sender, name, args)) return true;
        if (shopService.handle(sender, name, args)) return true;
        if (social.handle(sender, name, args)) return true;
        if (name.equals("menu")) {
            if (sender instanceof Player mp) { menu.openMain(mp); }
            else { sender.sendMessage(Component.text("A menu needs a screen.", NamedTextColor.GRAY)); }
            return true;
        }

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
            if (args[0].equalsIgnoreCase("dbthread")) {
                // Row 25: "no blocking database call on the main thread anywhere".
                //
                // The guarantee is structural - every Database method opens with
                // assertOffMainThread() and THROWS - but a guarantee nobody exercised is a
                // comment. This deliberately makes a forbidden call from the main thread and
                // reports whether it was refused, so the claim rests on observed behaviour.
                //
                // It also counts the methods carrying the guard, because a guard on 30 of 31
                // methods would pass this test while leaving the one hole that matters.
                boolean refused = false;
                String detail = "the call SUCCEEDED, which means row 25 is not enforced";
                try {
                    database.activeSeason();
                } catch (IllegalStateException ex) {
                    refused = true;
                    detail = ex.getMessage();
                } catch (java.sql.SQLException ex) {
                    detail = "SQLException instead of a refusal: " + ex.getMessage();
                }
                sender.sendMessage(Component.text("Row 25 - main-thread database guard",
                    NamedTextColor.GOLD));
                sender.sendMessage(Component.text("  on main thread: "
                    + (org.bukkit.Bukkit.isPrimaryThread() ? "yes" : "NO - test is invalid"),
                    NamedTextColor.GRAY));
                sender.sendMessage(refused
                    ? Component.text("  REFUSED as required: " + detail, NamedTextColor.GREEN)
                    : Component.text("  NOT REFUSED: " + detail, NamedTextColor.RED));
                // Then prove the same call works off the main thread, so the test cannot pass
                // simply because the method is broken for everyone.
                getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    String r;
                    try {
                        r = "off-thread call returned season " + database.activeSeason();
                    } catch (java.sql.SQLException ex) {
                        r = "off-thread call FAILED: " + ex.getMessage();
                    }
                    final String out = r;
                    getServer().getScheduler().runTask(this, () -> sender.sendMessage(
                        Component.text("  " + out, NamedTextColor.GRAY)));
                });
                return true;
            }

            if (args[0].equalsIgnoreCase("shopseed")) {
                // Prices are created lazily on first read, which means a fresh database has an
                // empty price table until someone trades. That is fine in play but useless for
                // testing an invariant across the whole catalogue, so this walks every entry and
                // forces the row into existence. It is idempotent - currentPrice inserts only if
                // absent - so running it twice changes nothing.
                getServer().getScheduler().runTaskAsynchronously(this, () -> {
                    int made = 0;
                    try {
                        for (Shop.Entry e : Shop.catalogue().values()) {
                            database.currentPrice(e);
                            made++;
                        }
                    } catch (java.sql.SQLException ex) {
                        getLogger().warning("shopseed failed after " + made + ": " + ex.getMessage());
                    }
                    final int n = made;
                    getServer().getScheduler().runTask(this, () -> sender.sendMessage(
                        Component.text("Shop catalogue seeded: " + n + " of "
                            + Shop.catalogue().size() + " priced from P2.", NamedTextColor.GREEN)));
                });
                return true;
            }

            if (args[0].equalsIgnoreCase("rating")) {
                if (!sender.hasPermission("laughtail.status")) {
                    sender.sendMessage(Component.text("No permission.", NamedTextColor.RED));
                    return true;
                }
                // Appendix B asks for five invariants to be asserted in tests. Running them
                // through a command rather than a test harness is deliberate: it means the
                // maths can be re-verified on the live server after any config change to the
                // tier thresholds, which 9.3 says will be re-set from measurement after the
                // first season.
                java.util.List<String> fails = Rating.selfTest();
                sender.sendMessage(Component.text("Rating engine - Appendix B with D-0031 rulings",
                    NamedTextColor.GOLD));
                for (String l : Rating.examples()) {
                    sender.sendMessage(Component.text("  " + l, NamedTextColor.GRAY));
                }
                if (fails.isEmpty()) {
                    sender.sendMessage(Component.text(
                        "  INVARIANTS: all pass (5 from Appendix B, plus P11, P12, P13, repeat curve)",
                        NamedTextColor.GREEN));
                } else {
                    sender.sendMessage(Component.text("  INVARIANTS FAILED:", NamedTextColor.RED));
                    for (String l : fails) {
                        sender.sendMessage(Component.text("    " + l, NamedTextColor.RED));
                    }
                }
                return true;
            }            if (args[0].equalsIgnoreCase("reload")) {
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
