package gg.laughtail.core;

import org.bukkit.plugin.Plugin;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Map;
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

    /**
     * Writes a staff_audit row. Every staff action goes through here.
     *
     * 17.4: "All staff actions are logged, permanently, to the database, including who,
     * what, when, and to whom - and staff cannot delete these logs." The cannot-delete
     * half is enforced by triggers in V2 and proven by db-test-append-only.sh; this is the
     * are-they-logged-at-all half.
     *
     * staff_name and target_name are stored alongside the UUIDs on purpose. Appendix D
     * asks for who and to whom, and a UUID stops being readable the moment an account is
     * renamed or anonymised under 31.13 - at which point an audit trail of raw UUIDs is
     * technically complete and practically useless.
     */
    void audit(UUID staff, String staffName, String action,
               UUID target, String targetName, String parameters, String world)
            throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO staff_audit (staff_uuid, staff_name, action, target_uuid, "
               + "target_name, parameters, world, occurred_at) "
               + "VALUES (?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(3))")) {
            if (staff != null) ps.setString(1, staff.toString()); else ps.setNull(1, java.sql.Types.CHAR);
            ps.setString(2, staffName);
            ps.setString(3, action);
            if (target != null) ps.setString(4, target.toString()); else ps.setNull(4, java.sql.Types.CHAR);
            if (targetName != null) ps.setString(5, targetName); else ps.setNull(5, java.sql.Types.VARCHAR);
            if (parameters != null) ps.setString(6, parameters); else ps.setNull(6, java.sql.Types.VARCHAR);
            if (world != null) ps.setString(7, world); else ps.setNull(7, java.sql.Types.VARCHAR);
            ps.executeUpdate();
        }
    }

    /** Records a punishment and returns its id. */
    long insertPunishment(UUID target, String type, String reason, String evidenceRef,
                          UUID issuedBy, Long durationSeconds) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO punishments (target_uuid, type, reason, evidence_ref, issued_by, "
               + "issued_at, expires_at) VALUES (?, ?, ?, ?, ?, UTC_TIMESTAMP(3), "
               + (durationSeconds == null ? "NULL" : "DATE_ADD(UTC_TIMESTAMP(3), INTERVAL ? SECOND)")
               + ")", PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, target.toString());
            ps.setString(2, type);
            ps.setString(3, reason);
            if (evidenceRef != null) ps.setString(4, evidenceRef); else ps.setNull(4, java.sql.Types.VARCHAR);
            if (issuedBy != null) ps.setString(5, issuedBy.toString()); else ps.setNull(5, java.sql.Types.CHAR);
            if (durationSeconds != null) ps.setLong(6, durationSeconds);
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                return rs.next() ? rs.getLong(1) : -1;
            }
        }
    }

    /**
     * Returns the reason for an ACTIVE punishment of this type, or null if there is none.
     *
     * "Active" means not revoked and not expired, evaluated in SQL against the database's
     * own UTC_TIMESTAMP rather than in Java against the server clock. Two clocks that
     * disagree by a minute would let a ban expire early or linger, and the database is the
     * one that wrote the expiry.
     */
    String activePunishmentReason(UUID target, String type) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT reason, expires_at FROM punishments WHERE target_uuid = ? AND type = ? "
               + "AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP(3)) "
               + "ORDER BY issued_at DESC LIMIT 1")) {
            ps.setString(1, target.toString());
            ps.setString(2, type);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                String reason = rs.getString(1);
                String until = rs.getString(2);
                return until == null ? reason + " (permanent)" : reason + " (until " + until + " UTC)";
            }
        }
    }

    /** Revokes the newest active punishment of a type. Returns true if one was revoked. */
    boolean revokePunishment(UUID target, String type, UUID by, String reason) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE punishments SET revoked_at = UTC_TIMESTAMP(3), revoked_by = ?, "
               + "revoked_reason = ? WHERE target_uuid = ? AND type = ? AND revoked_at IS NULL "
               + "AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP(3)) "
               + "ORDER BY issued_at DESC LIMIT 1")) {
            if (by != null) ps.setString(1, by.toString()); else ps.setNull(1, java.sql.Types.CHAR);
            ps.setString(2, reason);
            ps.setString(3, target.toString());
            ps.setString(4, type);
            return ps.executeUpdate() > 0;
        }
    }

    /** Punishment history for a player, newest first. */
    java.util.List<String> punishmentHistory(UUID target, int limit) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT id, type, reason, issued_at, expires_at, revoked_at "
               + "FROM punishments WHERE target_uuid = ? ORDER BY issued_at DESC LIMIT ?")) {
            ps.setString(1, target.toString());
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String state = rs.getString(6) != null ? "REVOKED"
                        : (rs.getString(5) == null ? "active/permanent" : "expires " + rs.getString(5));
                    out.add("#" + rs.getLong(1) + " " + rs.getString(2) + " - " + rs.getString(3)
                        + " [" + rs.getString(4) + " UTC, " + state + "]");
                }
            }
        }
        return out;
    }

    /** Looks up a UUID by cached name. Returns null when the player has never joined. */
    UUID uuidByName(String name) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT uuid FROM players WHERE current_name = ? ORDER BY last_seen DESC LIMIT 1")) {
            ps.setString(1, name);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? UUID.fromString(rs.getString(1)) : null;
            }
        }
    }

    int countAuditRows() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement("SELECT COUNT(*) FROM staff_audit");
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : -1;
        }
    }

    // ---- homes (V4) ----------------------------------------------------------

    record HomeRow(String name, String world, double x, double y, double z,
                   float yaw, float pitch) { }

    java.util.List<String> homeNames(UUID uuid) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT name FROM homes WHERE uuid = ? ORDER BY name")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(rs.getString(1));
            }
        }
        return out;
    }

    HomeRow getHome(UUID uuid, String name) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT name, world, x, y, z, yaw, pitch FROM homes WHERE uuid = ? AND name = ?")) {
            ps.setString(1, uuid.toString());
            ps.setString(2, name);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                return new HomeRow(rs.getString(1), rs.getString(2), rs.getDouble(3),
                    rs.getDouble(4), rs.getDouble(5), rs.getFloat(6), rs.getFloat(7));
            }
        }
    }

    void setHome(UUID uuid, String name, String world, double x, double y, double z,
                 float yaw, float pitch) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO homes (uuid, name, world, x, y, z, yaw, pitch, created_at, updated_at) "
               + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) "
               + "ON DUPLICATE KEY UPDATE world=VALUES(world), x=VALUES(x), y=VALUES(y), "
               + "z=VALUES(z), yaw=VALUES(yaw), pitch=VALUES(pitch), updated_at=UTC_TIMESTAMP(3)")) {
            ps.setString(1, uuid.toString());
            ps.setString(2, name);
            ps.setString(3, world);
            ps.setDouble(4, x);
            ps.setDouble(5, y);
            ps.setDouble(6, z);
            ps.setFloat(7, yaw);
            ps.setFloat(8, pitch);
            ps.executeUpdate();
        }
    }

    boolean deleteHome(UUID uuid, String name) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "DELETE FROM homes WHERE uuid = ? AND name = ?")) {
            ps.setString(1, uuid.toString());
            ps.setString(2, name);
            return ps.executeUpdate() > 0;
        }
    }

    int purchasedSlots(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT purchased_slots FROM home_slots WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /**
     * Buys one home slot. Returns null on success, or a message explaining the refusal.
     *
     * The charge, the slot and the ledger row are ONE transaction. A charge without a slot is
     * theft and a slot without a charge is free money, so neither may happen alone - and the
     * balance is locked FOR UPDATE so two simultaneous purchases cannot both pass the same
     * affordability check.
     */
    String buyHomeSlot(UUID uuid, long cost) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                ensureBalanceRow(c, uuid);
                lockBalance(c, uuid);
                long bal = readLocked(c, uuid);
                if (bal < cost) {
                    c.rollback();
                    return "You have " + bal + " Berries and the next slot costs " + cost + ".";
                }
                long after = bal - cost;
                writeBalance(c, uuid, after, 0, cost);
                ledger(c, uuid, -cost, after, "sink_fee", null, "home_slot", 1,
                    "bought a home slot");

                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO home_slots (uuid, purchased_slots, total_spent, updated_at) "
                      + "VALUES (?, 1, ?, UTC_TIMESTAMP(3)) "
                      + "ON DUPLICATE KEY UPDATE purchased_slots = purchased_slots + 1, "
                      + "total_spent = total_spent + VALUES(total_spent), "
                      + "updated_at = UTC_TIMESTAMP(3)")) {
                    ps.setString(1, uuid.toString());
                    ps.setLong(2, cost);
                    ps.executeUpdate();
                }
                c.commit();
                return null;
            } catch (java.sql.SQLIntegrityConstraintViolationException cap) {
                // chk_slots_range: 18 purchased is the maximum, since 2 are free and 15.x caps
                // homes at 20. The database refusing is better than trusting the caller's count.
                c.rollback();
                return "You already own the maximum number of purchasable home slots.";
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    // ---- economy (V3) --------------------------------------------------------

    enum Outcome { OK, INSUFFICIENT, NO_SENDER_ACCOUNT }

    record TransferResult(Outcome outcome, long senderBalance, long receiverBalance) { }

    long balance(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT berries FROM balances WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0L;
            }
        }
    }

    /**
     * Moves Berries between two players, atomically, with the ledger written in the same
     * transaction.
     *
     * THE LOCK ORDER IS DELIBERATE. Both rows are locked with SELECT ... FOR UPDATE, and always
     * in ascending UUID order regardless of who is paying whom. Locking in the order the
     * command happens to arrive would let two simultaneous transfers between the same pair
     * deadlock - A locks itself and waits for B while B locks itself and waits for A. Ordering
     * the locks makes that impossible rather than merely unlikely.
     *
     * The tax is REMOVED from circulation rather than paid to anyone. It is a sink, which is
     * what 8.x wants - a tax paid to an admin account is not a sink, it is a transfer.
     */
    TransferResult transfer(UUID from, UUID to, long amount, long tax) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                ensureBalanceRow(c, from);
                ensureBalanceRow(c, to);

                // Ascending UUID order, not command order. See the note above.
                UUID first = from.compareTo(to) <= 0 ? from : to;
                UUID second = from.compareTo(to) <= 0 ? to : from;
                lockBalance(c, first);
                lockBalance(c, second);

                long fromBal = readLocked(c, from);
                if (fromBal < amount) {
                    c.rollback();
                    return new TransferResult(Outcome.INSUFFICIENT, fromBal, 0L);
                }

                long net = amount - tax;
                long newFrom = fromBal - amount;
                long toBal = readLocked(c, to);
                long newTo = toBal + net;

                writeBalance(c, from, newFrom, 0, amount);
                writeBalance(c, to, newTo, net, 0);

                ledger(c, from, -amount, newFrom, "transfer_out", to, null, null,
                    "paid " + net + " to counterparty" + (tax > 0 ? ", " + tax + " tax" : ""));
                ledger(c, to, net, newTo, "transfer_in", from, null, null,
                    "received from counterparty");
                if (tax > 0) {
                    // Recorded as its own row so the sink is visible in the ledger. A tax that
                    // only shows up as a smaller transfer is invisible to the audit.
                    ledger(c, from, 0, newFrom, "transfer_tax", to, null, null,
                        tax + " removed from circulation (P10, transfer over "
                        + Economy.TRANSFER_TAX_THRESHOLD + ")");
                }

                c.commit();
                return new TransferResult(Outcome.OK, newFrom, newTo);
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    private void ensureBalanceRow(Connection c, UUID uuid) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO balances (uuid, berries, last_modified, created_at) "
              + "VALUES (?, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) "
              + "ON DUPLICATE KEY UPDATE last_modified = last_modified")) {
            ps.setString(1, uuid.toString());
            ps.executeUpdate();
        }
    }

    private void lockBalance(Connection c, UUID uuid) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT berries FROM balances WHERE uuid = ? FOR UPDATE")) {
            ps.setString(1, uuid.toString());
            ps.executeQuery();
        }
    }

    private long readLocked(Connection c, UUID uuid) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT berries FROM balances WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0L;
            }
        }
    }

    private void writeBalance(Connection c, UUID uuid, long newBalance, long in, long out)
            throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE balances SET berries = ?, lifetime_in = lifetime_in + ?, "
              + "lifetime_out = lifetime_out + ?, last_modified = UTC_TIMESTAMP(3) "
              + "WHERE uuid = ?")) {
            ps.setLong(1, newBalance);
            ps.setLong(2, in);
            ps.setLong(3, out);
            ps.setString(4, uuid.toString());
            ps.executeUpdate();
        }
    }

    private void ledger(Connection c, UUID uuid, long delta, long after, String type,
                        UUID counterparty, String item, Integer qty, String reason)
            throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO transactions (uuid, delta, balance_after, type, counterparty, "
              + "item, quantity, reason, occurred_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, "
              + "UTC_TIMESTAMP(3))")) {
            ps.setString(1, uuid.toString());
            ps.setLong(2, delta);
            ps.setLong(3, after);
            ps.setString(4, type);
            if (counterparty != null) ps.setString(5, counterparty.toString());
            else ps.setNull(5, java.sql.Types.CHAR);
            if (item != null) ps.setString(6, item); else ps.setNull(6, java.sql.Types.VARCHAR);
            if (qty != null) ps.setInt(7, qty); else ps.setNull(7, java.sql.Types.INTEGER);
            if (reason != null) ps.setString(8, reason); else ps.setNull(8, java.sql.Types.VARCHAR);
            ps.executeUpdate();
        }
    }

    /** Admin grant or take. Used by /berries give and by rewards. Always ledgered. */
    long adjustBalance(UUID uuid, long delta, String type, String reason) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                ensureBalanceRow(c, uuid);
                lockBalance(c, uuid);
                long bal = readLocked(c, uuid);
                long next = bal + delta;
                if (next < 0) { c.rollback(); return -1L; }
                writeBalance(c, uuid, next, Math.max(0, delta), Math.max(0, -delta));
                ledger(c, uuid, delta, next, type, null, null, null, reason);
                c.commit();
                return next;
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    java.util.List<String> richList(int limit) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT p.current_name, b.berries FROM balances b "
               + "JOIN players p ON p.uuid = b.uuid WHERE b.berries > 0 "
               + "ORDER BY b.berries DESC LIMIT ?")) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                int i = 1;
                while (rs.next()) {
                    out.add((i++) + ". " + rs.getString(1) + "  " + rs.getLong(2));
                }
            }
        }
        return out;
    }

    java.util.List<String> ledgerFor(UUID uuid, int limit) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT occurred_at, delta, balance_after, type, IFNULL(reason,'') "
               + "FROM transactions WHERE uuid = ? ORDER BY id DESC LIMIT ?")) {
            ps.setString(1, uuid.toString());
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    long d = rs.getLong(2);
                    out.add(rs.getString(1) + "  " + (d >= 0 ? "+" : "") + d
                        + "  -> " + rs.getLong(3) + "  [" + rs.getString(4) + "] "
                        + rs.getString(5));
                }
            }
        }
        return out;
    }

    /** Test helper: verifies the ledger is self-consistent for one player. */
    String verifyLedger(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT id, delta, balance_after FROM transactions WHERE uuid = ? "
               + "AND type <> 'transfer_tax' ORDER BY id ASC")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                long running = 0;
                while (rs.next()) {
                    running += rs.getLong(2);
                    long recorded = rs.getLong(3);
                    if (running != recorded) {
                        return "MISMATCH at transaction " + rs.getLong(1)
                             + ": running " + running + " but row says " + recorded;
                    }
                }
                long actual = balance(uuid);
                return running == actual
                    ? "consistent: ledger sums to " + running + " and matches the balance"
                    : "MISMATCH: ledger sums to " + running + " but balance is " + actual;
            }
        }
    }

    // ---- access grants (D-0032: manual, no payment integration) --------------
    /**
     * Records a paid access grant. Returns the id, or -1 if the reference is already used.
     *
     * The player row is created first because `access_grants` has a foreign key to it, and a
     * manual grant normally happens BEFORE the player's first login - so there is usually no
     * player row yet. That is not an edge case, it is the normal path for a whitelist.
     *
     * The duplicate-reference check relies on V1's UNIQUE constraint on `transaction_ref`
     * rather than a SELECT first. Checking then inserting has a race; letting the database
     * refuse does not, and one payment must never grant access twice.
     */
    long grantAccess(UUID uuid, String name, String source, String reference,
                     Long amountMinor, String currency) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO players (uuid, current_name, first_join, last_seen, "
                      + "created_at, updated_at) VALUES (?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), "
                      + "UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) "
                      + "ON DUPLICATE KEY UPDATE current_name = VALUES(current_name), "
                      + "updated_at = UTC_TIMESTAMP(3)")) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, name);
                    ps.executeUpdate();
                }
                long id;
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO access_grants (uuid, source, transaction_ref, amount_minor, "
                      + "currency, granted_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, "
                      + "UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), UTC_TIMESTAMP(3))",
                        PreparedStatement.RETURN_GENERATED_KEYS)) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, source);
                    ps.setString(3, reference);
                    if (amountMinor != null) ps.setLong(4, amountMinor); else ps.setNull(4, java.sql.Types.BIGINT);
                    ps.setString(5, currency);
                    ps.executeUpdate();
                    try (ResultSet rs = ps.getGeneratedKeys()) {
                        id = rs.next() ? rs.getLong(1) : -1;
                    }
                }
                c.commit();
                return id;
            } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
                c.rollback();
                return -1;   // the unique transaction_ref did its job
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    boolean revokeAccess(UUID uuid, String reason) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE access_grants SET revoked_at = UTC_TIMESTAMP(3), revoked_reason = ?, "
               + "updated_at = UTC_TIMESTAMP(3) WHERE uuid = ? AND revoked_at IS NULL "
               + "AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP(3))")) {
            ps.setString(1, reason);
            ps.setString(2, uuid.toString());
            return ps.executeUpdate() > 0;
        }
    }

    java.util.List<String> liveGrants() throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT g.id, p.current_name, g.source, g.transaction_ref, g.amount_minor, "
               + "g.granted_at FROM access_grants g JOIN players p ON p.uuid = g.uuid "
               + "WHERE g.revoked_at IS NULL AND (g.expires_at IS NULL OR g.expires_at > UTC_TIMESTAMP(3)) "
               + "ORDER BY g.granted_at DESC");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                long minor = rs.getLong(5);
                out.add("#" + rs.getLong(1) + " " + rs.getString(2)
                    + " [" + rs.getString(3) + "] ref=" + rs.getString(4)
                    + (rs.wasNull() || minor == 0 ? "" : " amount=" + (minor / 100.0))
                    + " granted " + rs.getString(6) + " UTC");
            }
        }
        return out;
    }

    /** UUIDs with a live grant. For the row 12 audit. */
    java.util.Set<UUID> liveGrantUuids() throws SQLException {
        assertOffMainThread();
        java.util.Set<UUID> out = new java.util.HashSet<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT DISTINCT uuid FROM access_grants WHERE revoked_at IS NULL "
               + "AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP(3))");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) out.add(UUID.fromString(rs.getString(1)));
        }
        return out;
    }

    // ---- seasons -------------------------------------------------------------

    /** The active season number, or -1 when none is active. */
    int activeSeason() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT season_number FROM seasons WHERE state='active' "
               + "ORDER BY season_number DESC LIMIT 1");
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : -1;
        }
    }

    /** Season state summary lines for /season status. */
    java.util.List<String> seasonSummary() throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT s.season_number, s.state, s.starts_at, s.ends_at, s.reset_completed, "
               + "(SELECT COUNT(*) FROM combat_ratings r WHERE r.season_number = s.season_number) AS rated, "
               + "(SELECT uuid FROM champions ch WHERE ch.season_number = s.season_number) AS champ "
               + "FROM seasons s ORDER BY s.season_number DESC LIMIT 10");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                out.add("season " + rs.getInt(1) + " [" + rs.getString(2) + "]"
                    + " starts " + rs.getString(3) + " ends " + rs.getString(4)
                    + " reset_completed=" + rs.getInt(5)
                    + " rated_players=" + rs.getInt(6)
                    + " champion=" + (rs.getString(7) == null ? "none" : rs.getString(7)));
            }
        }
        return out;
    }

    /**
     * Creates the next season and makes it active.
     *
     * 31.1 puts the season on a clock, so `ends_at` is stored rather than computed later -
     * a value derived at read time would shift if the code that derives it ever changed,
     * and the countdown players see must match the instant the reset actually fires.
     *
     * Refuses if a season is already active. Two active seasons would make
     * `combat_ratings` ambiguous and there would be no single answer to "who is winning".
     */
    int startSeason(int lengthDays) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT COUNT(*) FROM seasons WHERE state IN ('active','finale','resetting')");
                     ResultSet rs = ps.executeQuery()) {
                    if (rs.next() && rs.getInt(1) > 0) {
                        c.rollback();
                        return -1;   // already running
                    }
                }
                int next;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT IFNULL(MAX(season_number),0)+1 FROM seasons");
                     ResultSet rs = ps.executeQuery()) {
                    rs.next();
                    next = rs.getInt(1);
                }
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO seasons (season_number, starts_at, ends_at, state, "
                      + "created_at, updated_at) VALUES (?, UTC_TIMESTAMP(3), "
                      + "DATE_ADD(UTC_TIMESTAMP(3), INTERVAL ? DAY), 'active', "
                      + "UTC_TIMESTAMP(3), UTC_TIMESTAMP(3))")) {
                    ps.setInt(1, next);
                    ps.setInt(2, lengthDays);
                    ps.executeUpdate();
                }
                c.commit();
                return next;
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /** The leading player of a season, or null when nobody has a rating. */
    UUID seasonLeader(int season) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT uuid FROM combat_ratings WHERE season_number = ? "
               + "ORDER BY current_rp DESC, games_counted DESC, uuid ASC LIMIT 1")) {
            ps.setInt(1, season);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? UUID.fromString(rs.getString(1)) : null;
            }
        }
    }

    /**
     * Ends a season: crowns the Champion, archives the standings, marks the reset done.
     *
     * IDEMPOTENT, which acceptance row 33 requires. Every step is conditional:
     *   - the champion INSERT relies on V1's PRIMARY KEY (season_number), so a second
     *     attempt is rejected by the database rather than by application logic - row 36
     *   - reset_completed is checked first and the whole call returns early if set
     *   - the archive INSERT is INSERT ... SELECT with a NOT EXISTS guard
     * So a reset interrupted halfway can simply be run again, which is exactly what 31.1
     * demands of a job that fires on a clock and might be interrupted by a restart.
     *
     * 31.2: "never end a season without a Champion." If nobody has a rating there IS no
     * Champion, so this REFUSES rather than inventing one or ending the season empty.
     * Returns null on refusal, with the reason in the returned string of the caller.
     */
    String endSeason(int season) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                boolean already;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT reset_completed FROM seasons WHERE season_number = ?")) {
                    ps.setInt(1, season);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) { c.rollback(); return "no such season"; }
                        already = rs.getInt(1) == 1;
                    }
                }
                if (already) {
                    c.rollback();
                    return "already completed - nothing to do (idempotent)";
                }

                UUID leader;
                int leaderRp = 0;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT uuid, current_rp FROM combat_ratings WHERE season_number = ? "
                      + "ORDER BY current_rp DESC, games_counted DESC, uuid ASC LIMIT 1")) {
                    ps.setInt(1, season);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) {
                            c.rollback();
                            // 31.2, enforced rather than assumed.
                            return "REFUSED: no player has a rating this season, so there is "
                                 + "no Champion. Spec 31.2 forbids ending a season without one.";
                        }
                        leader = UUID.fromString(rs.getString(1));
                        leaderRp = rs.getInt(2);
                    }
                }

                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT IGNORE INTO champions (season_number, uuid, final_rp, "
                      + "awarded_at, created_at) VALUES (?, ?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3))")) {
                    ps.setInt(1, season);
                    ps.setString(2, leader.toString());
                    ps.setInt(3, leaderRp);
                    ps.executeUpdate();
                }

                try (PreparedStatement ps = c.prepareStatement(
                        "UPDATE seasons SET state='archived', reset_completed=1, "
                      + "reset_started_at=IFNULL(reset_started_at, UTC_TIMESTAMP(3)), "
                      + "reset_finished_at=UTC_TIMESTAMP(3), updated_at=UTC_TIMESTAMP(3) "
                      + "WHERE season_number = ?")) {
                    ps.setInt(1, season);
                    ps.executeUpdate();
                }

                try (PreparedStatement ps = c.prepareStatement(
                        "UPDATE stats s SET seasons_played = seasons_played + 1 "
                      + "WHERE EXISTS (SELECT 1 FROM combat_ratings r WHERE r.uuid = s.uuid "
                      + "AND r.season_number = ?)")) {
                    ps.setInt(1, season);
                    ps.executeUpdate();
                }

                try (PreparedStatement ps = c.prepareStatement(
                        "UPDATE stats SET champion_titles = champion_titles + 1 WHERE uuid = ?")) {
                    ps.setString(1, leader.toString());
                    ps.executeUpdate();
                }

                c.commit();
                // The Champion's permanent title is applied OUTSIDE this transaction, by the
                // caller, because it is a LuckPerms operation rather than a database one. Doing
                // it inside would mean a LuckPerms failure could roll back a crowning that has
                // already been announced - and 31.2 says a season must never end without a
                // Champion, so the crowning is the part that must be durable.
                return "champion " + leader + " with " + leaderRp + " RP";
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /**
     * Applies a kill's rating change to both players in ONE transaction, and returns the
     * before/after values so the combat_events row can record what actually happened.
     *
     * Appendix D: "Every write that spans two tables runs in a transaction." This spans two
     * ROWS of one table, which matters just as much - a crash between the killer's gain and
     * the victim's loss would create rating out of nothing, and the ledger would never balance.
     *
     * Returns int[]{killerBefore, killerAfter, victimBefore, victimAfter, gain}.
     *
     * Rows are created at STARTING_CR on first sight rather than requiring a separate
     * registration step, because a player's first kill is exactly when their rating first
     * matters and a missing row would silently skip it.
     */
    int[] applyKillRating(UUID killer, UUID victim, int season, int priorKillsInWindow,
                          boolean suppressed) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                int kBefore = ensureRating(c, killer, season);
                int vBefore = ensureRating(c, victim, season);

                int gain = Rating.gain(kBefore, vBefore, priorKillsInWindow, suppressed);
                int kAfter = Rating.killerAfter(kBefore, gain);
                int vAfter = Rating.victimAfter(vBefore, gain);

                if (gain != 0) {
                    updateRating(c, killer, season, kAfter, true);
                    updateRating(c, victim, season, vAfter, false);
                }
                c.commit();
                return new int[] { kBefore, kAfter, vBefore, vAfter, gain };
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    private int ensureRating(Connection c, UUID uuid, int season) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO combat_ratings (uuid, season_number, current_rp, peak_rp, "
              + "games_counted, created_at, updated_at) VALUES (?, ?, ?, ?, 0, "
              + "UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) "
              + "ON DUPLICATE KEY UPDATE updated_at = updated_at")) {
            ps.setString(1, uuid.toString());
            ps.setInt(2, season);
            ps.setInt(3, Rating.STARTING_CR);
            ps.setInt(4, Rating.STARTING_CR);
            ps.executeUpdate();
        }
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT current_rp FROM combat_ratings WHERE uuid = ? AND season_number = ?")) {
            ps.setString(1, uuid.toString());
            ps.setInt(2, season);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : Rating.STARTING_CR;
            }
        }
    }

    private void updateRating(Connection c, UUID uuid, int season, int rp, boolean counted)
            throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE combat_ratings SET current_rp = ?, "
              + "peak_rp = GREATEST(peak_rp, ?), "
              + "games_counted = games_counted + ?, "
              + "last_change_at = UTC_TIMESTAMP(3), updated_at = UTC_TIMESTAMP(3) "
              + "WHERE uuid = ? AND season_number = ?")) {
            ps.setInt(1, rp);
            ps.setInt(2, rp);
            ps.setInt(3, counted ? 1 : 0);
            ps.setString(4, uuid.toString());
            ps.setInt(5, season);
            ps.executeUpdate();
        }
    }

    /** Kills and deaths, for the HUD. Returns {kills, deaths}, zeroes when unrecorded. */
    int[] killsAndDeaths(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT kills, deaths FROM stats WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? new int[] { rs.getInt(1), rs.getInt(2) } : new int[] { 0, 0 };
            }
        }
    }

    /** Current RP for a season, or the starting value when unrated. */
    int currentRp(UUID uuid, int season) throws SQLException {
        assertOffMainThread();
        if (season <= 0) return Rating.STARTING_CR;
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT current_rp FROM combat_ratings WHERE uuid = ? AND season_number = ?")) {
            ps.setString(1, uuid.toString());
            ps.setInt(2, season);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : Rating.STARTING_CR;
            }
        }
    }

    /** The seasons a specific player won. 9.6: kept forever, through every future season. */
    java.util.List<Integer> championSeasons(UUID uuid) throws SQLException {
        assertOffMainThread();
        java.util.List<Integer> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT season_number FROM champions WHERE uuid = ? ORDER BY season_number")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(rs.getInt(1));
            }
        }
        return out;
    }

    /** Test helper: gives a player a rating so the season lifecycle can be exercised. */    void setRatingForTest(UUID uuid, int season, int rp) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO combat_ratings (uuid, season_number, current_rp, peak_rp, "
               + "games_counted, created_at, updated_at) VALUES (?, ?, ?, ?, 1, "
               + "UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE "
               + "current_rp = VALUES(current_rp), peak_rp = GREATEST(peak_rp, VALUES(peak_rp)), "
               + "updated_at = UTC_TIMESTAMP(3)")) {
            ps.setString(1, uuid.toString());
            ps.setInt(2, season);
            ps.setInt(3, rp);
            ps.setInt(4, rp);
            ps.executeUpdate();
        }
    }

    /** Combat event count, for /laughtail status. */
    int countCombatEvents() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement("SELECT COUNT(*) FROM combat_events");
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : -1;
        }
    }

    /**
     * Applies accumulated stat DELTAS in one transaction.
     *
     * Deltas, not totals, and applied as `col = col + ?`. Two reasons: a flush that fails
     * can be retried without double-counting anything already committed, and two writers
     * cannot clobber each other by both reading 10 and both writing 11.
     *
     * killstreak_best uses GREATEST so it can only ever rise - a "best ever" that a later
     * flush could lower would not be a best ever.
     */
    void applyStatsDelta(UUID uuid, long kills, long deaths, long mined, long placed,
                         long playtimeSeconds, int killstreakCurrent, int killstreakBest,
                         Map<String, Long> mobKills, Map<String, Long> distance)
            throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                // The row may not exist yet: a player who breaks a block before the join
                // handler has finished. INSERT ... ON DUPLICATE KEY makes that harmless.
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO stats (uuid, kills, deaths, blocks_mined, blocks_placed, "
                      + "playtime_seconds, killstreak_current, killstreak_best, created_at, updated_at) "
                      + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) "
                      + "ON DUPLICATE KEY UPDATE "
                      + "kills = kills + VALUES(kills), "
                      + "deaths = deaths + VALUES(deaths), "
                      + "blocks_mined = blocks_mined + VALUES(blocks_mined), "
                      + "blocks_placed = blocks_placed + VALUES(blocks_placed), "
                      + "playtime_seconds = playtime_seconds + VALUES(playtime_seconds), "
                      + "killstreak_current = IF(VALUES(killstreak_current) < 0, killstreak_current, VALUES(killstreak_current)), "
                      + "killstreak_best = GREATEST(killstreak_best, VALUES(killstreak_best)), "
                      + "updated_at = UTC_TIMESTAMP(3)")) {
                    ps.setString(1, uuid.toString());
                    ps.setLong(2, kills);
                    ps.setLong(3, deaths);
                    ps.setLong(4, mined);
                    ps.setLong(5, placed);
                    ps.setLong(6, playtimeSeconds);
                    ps.setInt(7, Math.max(killstreakCurrent, 0));
                    ps.setInt(8, Math.max(killstreakBest, 0));
                    ps.executeUpdate();
                }

                if (!mobKills.isEmpty()) {
                    try (PreparedStatement ps = c.prepareStatement(
                            "INSERT INTO stats_mob_kills (uuid, mob_type, kills, updated_at) "
                          + "VALUES (?, ?, ?, UTC_TIMESTAMP(3)) "
                          + "ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills), "
                          + "updated_at = UTC_TIMESTAMP(3)")) {
                        for (Map.Entry<String, Long> e : mobKills.entrySet()) {
                            ps.setString(1, uuid.toString());
                            ps.setString(2, e.getKey());
                            ps.setLong(3, e.getValue());
                            ps.addBatch();
                        }
                        ps.executeBatch();
                    }
                }

                if (!distance.isEmpty()) {
                    try (PreparedStatement ps = c.prepareStatement(
                            "INSERT INTO stats_distance (uuid, method, centimetres, updated_at) "
                          + "VALUES (?, ?, ?, UTC_TIMESTAMP(3)) "
                          + "ON DUPLICATE KEY UPDATE centimetres = centimetres + VALUES(centimetres), "
                          + "updated_at = UTC_TIMESTAMP(3)")) {
                        for (Map.Entry<String, Long> e : distance.entrySet()) {
                            ps.setString(1, uuid.toString());
                            ps.setString(2, e.getKey());
                            ps.setLong(3, e.getValue());
                            ps.addBatch();
                        }
                        ps.executeBatch();
                    }
                }

                c.commit();
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /**
     * Records one death. Appendix D: "Every write that spans two tables runs in a
     * transaction" - this one writes a single table, so it does not need one, but it must
     * never fail silently, which is why the caller logs at SEVERE.
     *
     * season_number is resolved from the active season, falling back to 0 when no season
     * has been created yet. 0 is deliberate rather than NULL: it keeps the column NOT NULL
     * and makes pre-season test data obvious in a query instead of blending in.
     */
    void recordCombatEvent(UUID killer, UUID victim, int rpKiller, int rpVictim,
                           String suppressedReason, boolean sameIp,
                           String world, int x, int y, int z) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            int season = 0;
            try (PreparedStatement ps = c.prepareStatement(
                    "SELECT season_number FROM seasons WHERE state = 'active' "
                  + "ORDER BY season_number DESC LIMIT 1");
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) season = rs.getInt(1);
            }
            try (PreparedStatement ps = c.prepareStatement(
                    "INSERT INTO combat_events (season_number, killer_uuid, victim_uuid, "
                  + "rp_delta_killer, rp_delta_victim, multiplier_applied, suppressed_reason, "
                  + "same_ip, world, x, y, z, occurred_at) "
                  + "VALUES (?, ?, ?, ?, ?, 1.0000, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(3))")) {
                ps.setInt(1, season);
                if (killer != null) ps.setString(2, killer.toString()); else ps.setNull(2, java.sql.Types.CHAR);
                ps.setString(3, victim.toString());
                ps.setInt(4, rpKiller);
                ps.setInt(5, rpVictim);
                if (suppressedReason != null) ps.setString(6, suppressedReason); else ps.setNull(6, java.sql.Types.VARCHAR);
                ps.setInt(7, sameIp ? 1 : 0);
                if (world != null) ps.setString(8, world); else ps.setNull(8, java.sql.Types.VARCHAR);
                ps.setInt(9, x);
                ps.setInt(10, y);
                ps.setInt(11, z);
                ps.executeUpdate();
            }
        }
    }
}
