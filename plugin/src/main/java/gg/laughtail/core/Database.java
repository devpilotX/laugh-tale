package gg.laughtail.core;

import org.bukkit.plugin.Plugin;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.UUID;
import java.util.logging.Level;

/**
 * The database layer.
 *
 * ACCEPTANCE ROW 25 IS THE DESIGN CONSTRAINT: no database call on the main thread.
 * A query that takes 50 ms on the main thread is a 50 ms tick, and the whole tick
 * budget is 25 ms. So every method here refuses to run on the main thread and says
 * so loudly rather than quietly costing tick time - Law 8, fail loud not slow.
 *
 * Connections are opened per operation rather than pooled. That is a deliberate
 * choice for this stage: a pool is the right answer under load, but pooling adds a
 * dependency and configuration surface for a server with at most 24 players whose
 * writes are a handful per join. This will need revisiting before Phase 3's order
 * book, which is write-heavy and latency-sensitive - noted rather than pretended
 * away.
 */
public final class Database {

    private final Plugin plugin;
    private final String url;
    private final String user;
    private final String password;
    private volatile boolean healthy;

    Database(Plugin plugin, String host, int port, String schema, String user, String password) {
        this.plugin = plugin;
        // useServerPrepStmts: real prepared statements server-side. Every query in
        // this class is parameterised - string-concatenated SQL is how player data
        // gets stolen, and a player name is attacker-controlled input.
        this.url = "jdbc:mariadb://" + host + ":" + port + "/" + schema
                + "?useServerPrepStmts=true&connectTimeout=5000&socketTimeout=15000";
        this.user = user;
        this.password = password;
    }

    private void assertOffMainThread() {
        if (plugin.getServer().isPrimaryThread()) {
            throw new IllegalStateException(
                "LaughTail: refusing a database call on the main thread (acceptance row 25). "
              + "Wrap it in runTaskAsynchronously.");
        }
    }

    private Connection open() throws SQLException {
        // The driver is instantiated DIRECTLY rather than going through
        // DriverManager's ServiceLoader discovery.
        //
        // Why: this jar relocates org.mariadb.jdbc to gg.laughtail.libs.mariadb so it
        // cannot collide with a driver another plugin shades. Relocation rewrites the
        // classes but not, by default, the META-INF/services text file that names the
        // driver - so DriverManager looked up a class that no longer existed and
        // reported "No suitable driver found", which reads like a network fault and is
        // actually a packaging one. The build now also relocates the service file, but
        // referring to the type directly means correctness does not depend on that at
        // all: Maven Shade rewrites this reference at the bytecode level, so it is
        // right by construction.
        java.util.Properties props = new java.util.Properties();
        props.setProperty("user", user);
        props.setProperty("password", password);
        Connection c = new org.mariadb.jdbc.Driver().connect(url, props);
        if (c == null) {
            throw new SQLException("MariaDB driver declined the URL: " + url);
        }
        return c;
    }

    /** Verifies connectivity and that the migration the plugin expects has been applied. */
    boolean checkConnectivity() {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT COUNT(*) FROM schema_migrations WHERE version = ?")) {
            ps.setString(1, "V1");
            try (ResultSet rs = ps.executeQuery()) {
                boolean ok = rs.next() && rs.getInt(1) == 1;
                healthy = ok;
                if (!ok) {
                    plugin.getLogger().severe(
                        "Database reachable but migration V1 is NOT applied. Run db-migrate.sh. "
                      + "Refusing to pretend the schema is present.");
                }
                return ok;
            }
        } catch (SQLException e) {
            healthy = false;
            plugin.getLogger().log(Level.SEVERE, "Database unreachable: " + e.getMessage());
            return false;
        }
    }

    boolean isHealthy() {
        return healthy;
    }

    /**
     * Records a player on join and returns the rules version they have accepted,
     * or null if they have accepted nothing.
     *
     * Upsert on UUID, never on name: Appendix D's rule, and names are reusable -
     * the owner's own account was renamed from dipanshu03j to IgnisClaw (D-0017),
     * which is exactly the case that breaks name-keyed storage.
     */
    String registerAndGetAcceptedRules(UUID uuid, String name) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            try (PreparedStatement ps = c.prepareStatement(
                    "INSERT INTO players (uuid, current_name, first_join, last_seen, created_at, updated_at) "
                  + "VALUES (?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) "
                  + "ON DUPLICATE KEY UPDATE current_name = VALUES(current_name), "
                  + "last_seen = UTC_TIMESTAMP(3), updated_at = UTC_TIMESTAMP(3)")) {
                ps.setString(1, uuid.toString());
                ps.setString(2, name);
                ps.executeUpdate();
            }
            try (PreparedStatement ps = c.prepareStatement(
                    "SELECT rules_version_accepted FROM players WHERE uuid = ?")) {
                ps.setString(1, uuid.toString());
                try (ResultSet rs = ps.executeQuery()) {
                    return rs.next() ? rs.getString(1) : null;
                }
            }
        }
    }

    /**
     * Stores rules acceptance WITH THE VERSION, which is what acceptance row 17
     * requires - not a boolean. A boolean cannot re-gate everyone when the rules
     * change, and the rules will change.
     */
    void recordRulesAcceptance(UUID uuid, String version) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE players SET rules_version_accepted = ?, rules_accepted_at = UTC_TIMESTAMP(3), "
               + "updated_at = UTC_TIMESTAMP(3) WHERE uuid = ?")) {
            ps.setString(1, version);
            ps.setString(2, uuid.toString());
            ps.executeUpdate();
        }
    }

    /** Player count, for /laughtail status. */
    int countPlayers() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement("SELECT COUNT(*) FROM players");
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : -1;
        }
    }
}
