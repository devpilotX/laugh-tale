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

    // ---- shop ----------------------------------------------------------------

    record SellResult(int soldUnits, long paid, long balance, long cappedAt) { }
    record BuyResult(boolean ok, long balance) { }

    /**
     * The current buy price, creating the row from the derived base on first sight.
     *
     * Also applies P5's recovery: prices drift 5% of the gap back toward base per hour since the
     * last trade. Doing it lazily on read rather than with a scheduled sweep means there is no
     * background job walking every item, and a price nobody looks at costs nothing to keep correct.
     */
    long currentPrice(Shop.Entry e) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            try (PreparedStatement ps = c.prepareStatement(
                    "INSERT INTO shop_prices (item, category, base_price, current_price, "
                  + "sell_price, updated_at) VALUES (?, ?, ?, ?, ?, UTC_TIMESTAMP(3)) "
                  + "ON DUPLICATE KEY UPDATE updated_at = updated_at")) {
                ps.setString(1, e.material().name());
                ps.setString(2, e.category());
                ps.setLong(3, e.basePrice());
                ps.setLong(4, e.basePrice());
                ps.setLong(5, Shop.sellPrice(e.basePrice()));
                ps.executeUpdate();
            }
            // Self-heal a sell price that disagrees with Shop.sellPrice. Rows written before the
            // spread was floored rather than rounded are a Berry high, and rather than a one-off
            // migration this corrects on read - which also means ANY future drift between the
            // stored value and the single source of truth repairs itself instead of quietly
            // sitting in the table waiting for the invariant test to find it.
            try (PreparedStatement ps = c.prepareStatement(
                    "SELECT current_price, sell_price FROM shop_prices WHERE item = ?")) {
                ps.setString(1, e.material().name());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        long cur = rs.getLong(1);
                        long stored = rs.getLong(2);
                        long correct = Shop.sellPrice(cur);
                        if (stored != correct) {
                            try (PreparedStatement fix = c.prepareStatement(
                                    "UPDATE shop_prices SET sell_price = ? WHERE item = ?")) {
                                fix.setLong(1, correct);
                                fix.setString(2, e.material().name());
                                fix.executeUpdate();
                            }
                        }
                    }
                }
            }
            try (PreparedStatement ps = c.prepareStatement(
                    "SELECT current_price, base_price, "
                  + "TIMESTAMPDIFF(HOUR, IFNULL(last_trade_at, updated_at), UTC_TIMESTAMP(3)) "
                  + "FROM shop_prices WHERE item = ?")) {
                ps.setString(1, e.material().name());
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) return e.basePrice();
                    long current = rs.getLong(1);
                    long base = rs.getLong(2);
                    int hours = rs.getInt(3);
                    if (hours <= 0 || current == base) {
                        Shop.cachePrice(e.material(), current);
                        return current;
                    }
                    // P5: 5% of the gap per hour, compounded over the elapsed hours.
                    double gap = current - base;
                    double recovered = gap * Math.pow(1.0 - 0.05, Math.min(hours, 240));
                    long next = Math.round(base + recovered);
                    if (next != current) {
                        try (PreparedStatement up = c.prepareStatement(
                                "UPDATE shop_prices SET current_price = ?, sell_price = ?, "
                              + "updated_at = UTC_TIMESTAMP(3) WHERE item = ?")) {
                            up.setLong(1, next);
                            up.setLong(2, Shop.sellPrice(next));
                            up.setString(3, e.material().name());
                            up.executeUpdate();
                        }
                    }
                    Shop.cachePrice(e.material(), next);
                    return next;
                }
            }
        }
    }

    /**
     * Sells up to `amount`, respecting P6's daily category cap, and moves the price down by P4's
     * elasticity.
     *
     * The cap is read, applied and the payment made in ONE transaction. Checking the cap and then
     * paying separately would let two simultaneous sales both see the same remaining allowance -
     * which is how a daily cap becomes a daily suggestion.
     */
    SellResult sell(UUID uuid, Shop.Entry e, int amount, long unitSell) throws SQLException {
        assertOffMainThread();
        final long DAILY_CAP = 3600L;   // P6
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                ensureBalanceRow(c, uuid);
                lockBalance(c, uuid);

                long already;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT berries FROM daily_sell_totals WHERE uuid = ? "
                      + "AND sell_date = UTC_DATE() AND category = ? FOR UPDATE")) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, e.category());
                    try (ResultSet rs = ps.executeQuery()) {
                        already = rs.next() ? rs.getLong(1) : 0L;
                    }
                }
                long headroom = DAILY_CAP - already;
                if (headroom <= 0) {
                    c.rollback();
                    return new SellResult(0, 0, balanceIn(c, uuid), DAILY_CAP);
                }
                int units = (int) Math.min(amount, headroom / unitSell);
                if (units <= 0) {
                    c.rollback();
                    return new SellResult(0, 0, balanceIn(c, uuid), DAILY_CAP);
                }
                long paid = units * unitSell;

                long bal = readLocked(c, uuid) + paid;
                writeBalance(c, uuid, bal, paid, 0);
                ledger(c, uuid, paid, bal, "shop_sell", null, e.material().name(), units,
                    "sold to shop at " + unitSell + " each");

                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO daily_sell_totals (uuid, sell_date, category, berries, updated_at) "
                      + "VALUES (?, UTC_DATE(), ?, ?, UTC_TIMESTAMP(3)) "
                      + "ON DUPLICATE KEY UPDATE berries = berries + VALUES(berries), "
                      + "updated_at = UTC_TIMESTAMP(3)")) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, e.category());
                    ps.setLong(3, paid);
                    ps.executeUpdate();
                }

                movePrice(c, e, -units);
                c.commit();
                long capped = (already + paid) >= DAILY_CAP ? DAILY_CAP : 0L;
                return new SellResult(units, paid, bal, capped);
            } catch (SQLException ex) {
                c.rollback();
                throw ex;
            }
        }
    }

    BuyResult buy(UUID uuid, Shop.Entry e, int amount, long unit) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                ensureBalanceRow(c, uuid);
                lockBalance(c, uuid);
                long bal = readLocked(c, uuid);
                long total = unit * amount;
                if (bal < total) {
                    c.rollback();
                    return new BuyResult(false, bal);
                }
                long after = bal - total;
                writeBalance(c, uuid, after, 0, total);
                ledger(c, uuid, -total, after, "shop_buy", null, e.material().name(), amount,
                    "bought from shop at " + unit + " each");
                movePrice(c, e, amount);
                c.commit();
                return new BuyResult(true, after);
            } catch (SQLException ex) {
                c.rollback();
                throw ex;
            }
        }
    }

    private long balanceIn(Connection c, UUID uuid) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT berries FROM balances WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0L;
            }
        }
    }

    /**
     * P4's elasticity: 0.15 per 1,000 units, clamped to the +/-40% band.
     *
     * The band is clamped HERE as well as being a CHECK constraint, so the code fails politely
     * rather than throwing on a constraint violation - but the constraint remains as the thing
     * that makes the band true even if this arithmetic is ever wrong.
     */
    private void movePrice(Connection c, Shop.Entry e, int unitsDelta) throws SQLException {
        long base = e.basePrice();
        long floor = Math.max(1L, Math.round(base * 0.6));
        long ceil = Math.round(base * 1.4);

        // Read the current price under the transaction's lock, then compute in Java.
        //
        // The earlier version did the arithmetic in SQL, which meant the 12% spread existed in
        // TWO places - Shop.sellPrice and an expression in this statement - and they had already
        // drifted: one rounded and the other floored, so a diamond sold for 106 instead of 105
        // and the spread came out at 11.7% against a stated minimum of 12%. Computing here and
        // calling Shop.sellPrice makes that impossible by construction: there is one function
        // that knows what the spread is, and both the display price and the stored price come
        // from it.
        long current;
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT current_price FROM shop_prices WHERE item = ? FOR UPDATE")) {
            ps.setString(1, e.material().name());
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return;
                current = rs.getLong(1);
            }
        }

        // P4: 0.15 per 1,000 units, clamped to the band. Buying pushes the price up, selling
        // pushes it down - so the market punishes dumping and rewards scarcity, which is the
        // whole point of a dynamic price.
        double factor = 1.0 + (0.15 * unitsDelta / 1000.0);
        long next = Math.max(floor, Math.min(ceil, Math.round(current * factor)));
        long nextSell = Shop.sellPrice(next);

        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE shop_prices SET current_price = ?, sell_price = ?, "
              + "units_traded = units_traded + ?, last_trade_at = UTC_TIMESTAMP(3), "
              + "updated_at = UTC_TIMESTAMP(3) WHERE item = ?")) {
            ps.setLong(1, next);
            ps.setLong(2, nextSell);
            ps.setInt(3, Math.abs(unitsDelta));
            ps.setString(4, e.material().name());
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

    /**
     * Deletes price rows for items no longer in the catalogue.
     *
     * When the arbitrage audit forced IRON_INGOT, GOLD_INGOT, NETHERITE_SCRAP and STONE out of the
     * catalogue, their price rows stayed behind. They were harmless - buy and sell both resolve
     * through Shop.entry, which returns nothing for them - but they made the table disagree with
     * the code, so the invariant test reported 44 priced items against a catalogue of 40. A number
     * that needs explaining is a number that will be misread later.
     *
     * Runs on every boot, so the table always matches the catalogue exactly.
     */
    int pruneOrphanPrices() throws SQLException {
        assertOffMainThread();
        java.util.List<String> keep = new java.util.ArrayList<>();
        for (Shop.Entry e : Shop.catalogue().values()) keep.add(e.material().name());
        if (keep.isEmpty()) return 0;   // never wipe the table because the catalogue failed to load
        StringBuilder sql = new StringBuilder("DELETE FROM shop_prices WHERE item NOT IN (");
        sql.append("?,".repeat(keep.size() - 1)).append("?)");
        try (Connection c = open(); PreparedStatement ps = c.prepareStatement(sql.toString())) {
            for (int i = 0; i < keep.size(); i++) ps.setString(i + 1, keep.get(i));
            return ps.executeUpdate();
        }
    }
    /**
     * Records a combat log as a death, and as a loss if an attacker is known.
     *
     * Row 33 says disconnecting while tagged is "resolved as a death". Resolved means the ladder
     * must not be able to tell the difference - otherwise the optimal play on a losing fight is
     * always to disconnect, and every close fight ends with someone pulling the plug.
     *
     * When the attacker is known this goes through the SAME rating path as a real kill, so the
     * winner is credited and the quitter demoted exactly as if the blow had landed. When it is not
     * known - the tag came from a projectile whose shooter has since left - only the death is
     * recorded. Crediting nobody is correct there; inventing a killer would be worse.
     */
    void recordCombatLog(UUID quitter, UUID attacker) throws SQLException {
        assertOffMainThread();
        int season = activeSeason();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE stats SET deaths = deaths + 1 WHERE uuid = ?")) {
            ps.setString(1, quitter.toString());
            ps.executeUpdate();
        }
        if (attacker == null || season <= 0) return;
        int rpKiller = currentRp(attacker, season);
        int rpVictim = currentRp(quitter, season);
        // suppressedReason null means the kill COUNTS - a combat log is a real loss, not a
        // suppressed one. sameIp false because the quitter is gone and cannot be compared.
        recordCombatEvent(attacker, quitter, rpKiller, rpVictim, null, false, "combat_log", 0, 0, 0);
    }
    // ---- friends and leaderboards ---------------------------------------------

    enum FriendResult { CREATED, ALREADY_PENDING, ALREADY_FRIENDS, ACCEPTED_EXISTING }

    /**
     * Sorts a pair so the same two players always produce the same key.
     *
     * The friends table keys on (uuid_low, uuid_high) rather than (owner, friend). Storing a
     * friendship twice, once per direction, allows the two rows to disagree - A believes they are
     * friends and B does not - and then every query has to choose which row to trust. One row cannot
     * contradict itself.
     */
    private static String[] pair(UUID a, UUID b) {
        String s1 = a.toString(), s2 = b.toString();
        return s1.compareTo(s2) <= 0 ? new String[] { s1, s2 } : new String[] { s2, s1 };
    }

    FriendResult friendRequest(UUID from, UUID to) throws SQLException {
        assertOffMainThread();
        String[] k = pair(from, to);
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                String state = null, requestedBy = null;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT state, requested_by FROM friends WHERE uuid_low = ? "
                      + "AND uuid_high = ? FOR UPDATE")) {
                    ps.setString(1, k[0]);
                    ps.setString(2, k[1]);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            state = rs.getString(1);
                            requestedBy = rs.getString(2);
                        }
                    }
                }
                if ("accepted".equals(state)) {
                    c.rollback();
                    return FriendResult.ALREADY_FRIENDS;
                }
                if ("pending".equals(state)) {
                    if (from.toString().equals(requestedBy)) {
                        c.rollback();
                        return FriendResult.ALREADY_PENDING;
                    }
                    // They asked first. Asking back IS accepting - requiring the exact command
                    // when the intent is unambiguous is friction for its own sake.
                    try (PreparedStatement ps = c.prepareStatement(
                            "UPDATE friends SET state = 'accepted', updated_at = UTC_TIMESTAMP(3) "
                          + "WHERE uuid_low = ? AND uuid_high = ?")) {
                        ps.setString(1, k[0]);
                        ps.setString(2, k[1]);
                        ps.executeUpdate();
                    }
                    c.commit();
                    return FriendResult.ACCEPTED_EXISTING;
                }
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO friends (uuid_low, uuid_high, requested_by, state, "
                      + "created_at, updated_at) VALUES (?, ?, ?, 'pending', UTC_TIMESTAMP(3), "
                      + "UTC_TIMESTAMP(3))")) {
                    ps.setString(1, k[0]);
                    ps.setString(2, k[1]);
                    ps.setString(3, from.toString());
                    ps.executeUpdate();
                }
                c.commit();
                return FriendResult.CREATED;
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /** Accepts only a request the OTHER player made. Returns false if there is none. */
    boolean friendAccept(UUID me, UUID other) throws SQLException {
        assertOffMainThread();
        String[] k = pair(me, other);
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE friends SET state = 'accepted', updated_at = UTC_TIMESTAMP(3) "
               + "WHERE uuid_low = ? AND uuid_high = ? AND state = 'pending' "
               + "AND requested_by = ?")) {
            ps.setString(1, k[0]);
            ps.setString(2, k[1]);
            // requested_by must be the OTHER player: without this a player could accept their own
            // request and befriend anyone unilaterally, which is the consent rule defeated.
            ps.setString(3, other.toString());
            return ps.executeUpdate() > 0;
        }
    }

    boolean friendRemove(UUID me, UUID other) throws SQLException {
        assertOffMainThread();
        String[] k = pair(me, other);
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "DELETE FROM friends WHERE uuid_low = ? AND uuid_high = ?")) {
            ps.setString(1, k[0]);
            ps.setString(2, k[1]);
            return ps.executeUpdate() > 0;
        }
    }

    java.util.List<UUID> friendList(UUID me, String state) throws SQLException {
        assertOffMainThread();
        java.util.List<UUID> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT uuid_low, uuid_high FROM friends WHERE (uuid_low = ? OR uuid_high = ?) "
               + "AND state = ?")) {
            ps.setString(1, me.toString());
            ps.setString(2, me.toString());
            ps.setString(3, state);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String low = rs.getString(1), high = rs.getString(2);
                    out.add(UUID.fromString(low.equals(me.toString()) ? high : low));
                }
            }
        }
        return out;
    }

    /** Requests made BY somebody else TO me, which are the only ones I can accept. */
    java.util.List<UUID> friendIncoming(UUID me) throws SQLException {
        assertOffMainThread();
        java.util.List<UUID> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT requested_by FROM friends WHERE (uuid_low = ? OR uuid_high = ?) "
               + "AND state = 'pending' AND requested_by <> ?")) {
            ps.setString(1, me.toString());
            ps.setString(2, me.toString());
            ps.setString(3, me.toString());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(UUID.fromString(rs.getString(1)));
            }
        }
        return out;
    }

    java.util.List<String> topByRating(int limit) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        int season = activeSeason();
        if (season <= 0) return out;
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT p.current_name, r.current_rp FROM combat_ratings r "
               + "JOIN players p ON p.uuid = r.uuid WHERE r.season_number = ? "
               + "ORDER BY r.current_rp DESC, p.current_name ASC LIMIT ?")) {
            ps.setInt(1, season);
            ps.setInt(2, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    int rp = rs.getInt(2);
                    out.add(rs.getString(1) + "  " + rp + " RP  " + Rating.tierName(rp));
                }
            }
        }
        return out;
    }

    /**
     * Top players by a stats column.
     *
     * The column name is validated against an allow-list rather than interpolated, because a column
     * name cannot be a bound parameter. Interpolating a caller-supplied string into SQL is an
     * injection even when every current caller is trusted - the next caller might not be.
     */
    java.util.List<String> topByStat(String column, int limit) throws SQLException {
        assertOffMainThread();
        java.util.Set<String> allowed = java.util.Set.of(
            "kills", "deaths", "killstreak_best", "blocks_mined", "playtime_seconds");
        if (!allowed.contains(column)) {
            throw new IllegalArgumentException("not a leaderboard column: " + column);
        }
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT p.current_name, s." + column + " FROM stats s "
               + "JOIN players p ON p.uuid = s.uuid WHERE s." + column + " > 0 "
               + "ORDER BY s." + column + " DESC, p.current_name ASC LIMIT ?")) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    long v = rs.getLong(2);
                    out.add(rs.getString(1) + "  " + (column.equals("playtime_seconds")
                        ? (v / 3600) + "h " + ((v % 3600) / 60) + "m" : String.valueOf(v)));
                }
            }
        }
        return out;
    }
    // ---- helpers shared with OrderBook -----------------------------------------
    //
    // OrderBook runs its matching inside ONE transaction, so it needs the balance and ledger
    // primitives that take an existing Connection. These are thin wrappers over the private
    // versions rather than copies: a second implementation of "write a balance" is how two code
    // paths end up disagreeing about what a balance is.

    Connection openForTransaction() throws SQLException {
        assertOffMainThread();
        return open();
    }

    void lockBalanceIn(Connection c, UUID uuid) throws SQLException {
        ensureBalanceRow(c, uuid);
        lockBalance(c, uuid);
    }

    long readBalanceIn(Connection c, UUID uuid) throws SQLException {
        return readLocked(c, uuid);
    }

    void writeBalanceIn(Connection c, UUID uuid, long newBalance, long in, long out)
            throws SQLException {
        writeBalance(c, uuid, newBalance, in, out);
    }

    void ledgerIn(Connection c, UUID uuid, long delta, long after, String type,
                  UUID counterparty, String item, Integer qty, String reason) throws SQLException {
        ledger(c, uuid, delta, after, type, counterparty, item, qty, reason);
    }

    /** Package-visible so OrderBook can assert the same rule. */
    void assertOffMainThreadPublic() {
        assertOffMainThread();
    }
    // ---- order book queries and payouts ----------------------------------------

    record Payout(String material, long berries, int items) { }
    record CancelResult(boolean ok, String message, long berries, int items, String material) { }

    /**
     * Collects everything the player's orders have earned, in one transaction.
     *
     * Berries go straight to the balance with a ledger row; item counts are returned to the caller to
     * hand over on the main thread. The payout columns are zeroed in the SAME transaction that credits
     * the balance, so a crash cannot pay twice - which is the duplication bug every "claim your
     * rewards" system eventually has.
     */
    java.util.List<Payout> claimOrderPayouts(UUID player) throws SQLException {
        assertOffMainThread();
        java.util.List<Payout> out = new java.util.ArrayList<>();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                long totalBerries = 0;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT id, material, payout_berries, payout_items FROM orders "
                      + "WHERE player = ? AND (payout_berries > 0 OR payout_items > 0) "
                      + "FOR UPDATE")) {
                    ps.setString(1, player.toString());
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            out.add(new Payout(rs.getString(2), rs.getLong(3), rs.getInt(4)));
                            totalBerries += rs.getLong(3);
                        }
                    }
                }
                if (out.isEmpty()) {
                    c.rollback();
                    return out;
                }
                try (PreparedStatement ps = c.prepareStatement(
                        "UPDATE orders SET payout_berries = 0, payout_items = 0, "
                      + "updated_at = UTC_TIMESTAMP(3) WHERE player = ? "
                      + "AND (payout_berries > 0 OR payout_items > 0)")) {
                    ps.setString(1, player.toString());
                    ps.executeUpdate();
                }
                if (totalBerries > 0) {
                    ensureBalanceRow(c, player);
                    lockBalance(c, player);
                    long bal = readLocked(c, player) + totalBerries;
                    writeBalance(c, player, bal, totalBerries, 0);
                    ledger(c, player, totalBerries, bal, "order_payout", null, null, null,
                        "collected from filled orders");
                }
                c.commit();
                return out;
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /**
     * Cancels an open order and returns its escrow.
     *
     * Only the owner can cancel, enforced in the WHERE clause rather than checked first - a check
     * followed by an update leaves a window, and the window is somebody else's order.
     */
    CancelResult cancelOrder(UUID player, long id) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                String material = null, state = null;
                long escrowB = 0;
                int escrowI = 0;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT material, state, escrow_berries, escrow_items FROM orders "
                      + "WHERE id = ? AND player = ? FOR UPDATE")) {
                    ps.setLong(1, id);
                    ps.setString(2, player.toString());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            material = rs.getString(1);
                            state = rs.getString(2);
                            escrowB = rs.getLong(3);
                            escrowI = rs.getInt(4);
                        }
                    }
                }
                if (material == null) {
                    c.rollback();
                    return new CancelResult(false, "No order #" + id + " of yours.", 0, 0, null);
                }
                if (!"open".equals(state)) {
                    c.rollback();
                    return new CancelResult(false, "Order #" + id + " is already " + state
                        + ". Use /order claim to collect what it earned.", 0, 0, null);
                }
                try (PreparedStatement ps = c.prepareStatement(
                        "UPDATE orders SET state = 'cancelled', escrow_berries = 0, "
                      + "escrow_items = 0, remaining = 0, updated_at = UTC_TIMESTAMP(3) "
                      + "WHERE id = ?")) {
                    ps.setLong(1, id);
                    ps.executeUpdate();
                }
                if (escrowB > 0) {
                    ensureBalanceRow(c, player);
                    lockBalance(c, player);
                    long bal = readLocked(c, player) + escrowB;
                    writeBalance(c, player, bal, escrowB, 0);
                    ledger(c, player, escrowB, bal, "order_refund", null, material, null,
                        "cancelled order #" + id);
                }
                c.commit();
                return new CancelResult(true, "cancelled", escrowB, escrowI, material);
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /** One side of the book, best price first. */
    java.util.List<String> bookSide(String material, String side, int limit) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        String order = side.equals("sell") ? "ASC" : "DESC";
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT unit_price, SUM(remaining) FROM orders WHERE material = ? AND side = ? "
               + "AND state = 'open' AND remaining > 0 GROUP BY unit_price "
               + "ORDER BY unit_price " + order + " LIMIT ?")) {
            ps.setString(1, material);
            ps.setString(2, side);
            ps.setInt(3, limit);
            try (ResultSet rs = ps.executeQuery()) {
                // Aggregated by price, so the book shows depth rather than a list of individual
                // orders - and nobody can tell whose order is whose, which removes a targeting hint.
                while (rs.next()) out.add(rs.getInt(2) + " at " + rs.getLong(1) + " each");
            }
        }
        return out;
    }

    java.util.List<String> myOrders(UUID player) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT id, side, material, unit_price, remaining, quantity, state, "
               + "payout_berries, payout_items FROM orders WHERE player = ? "
               + "AND (state = 'open' OR payout_berries > 0 OR payout_items > 0) "
               + "ORDER BY id DESC LIMIT 20")) {
            ps.setString(1, player.toString());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    StringBuilder sb = new StringBuilder();
                    sb.append('#').append(rs.getLong(1)).append(' ')
                      .append(rs.getString(2)).append(' ')
                      .append(rs.getString(3)).append(" at ").append(rs.getLong(4))
                      .append("  ").append(rs.getInt(5)).append('/').append(rs.getInt(6))
                      .append(" left  ").append(rs.getString(7));
                    long pb = rs.getLong(8);
                    int pi = rs.getInt(9);
                    if (pb > 0 || pi > 0) {
                        sb.append("  to collect: ");
                        if (pb > 0) sb.append(pb).append(" Berries ");
                        if (pi > 0) sb.append(pi).append(" items");
                    }
                    out.add(sb.toString());
                }
            }
        }
        return out;
    }
    /** Creates the two self-test identities the order book test needs for its foreign keys. */
    void ensureSelfTestPlayers(UUID a, UUID b) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO players (uuid, current_name, first_join, last_seen, created_at, "
               + "updated_at) VALUES (?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3), "
               + "UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE uuid = uuid")) {
            ps.setString(1, a.toString());
            ps.setString(2, "#selftest-a");
            ps.executeUpdate();
            ps.setString(1, b.toString());
            ps.setString(2, "#selftest-b");
            ps.executeUpdate();
        }
    }
    // ---- season scheduling ------------------------------------------------------

    record SeasonTiming(int season, java.time.Instant startsAt, java.time.Instant endsAt) { }

    /** The active season and its window, or null when no season is running. */
    SeasonTiming activeSeasonTiming() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT season_number, starts_at, ends_at FROM seasons "
               + "WHERE state IN ('active','finale') ORDER BY season_number DESC LIMIT 1")) {
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                return new SeasonTiming(rs.getInt(1),
                    rs.getTimestamp(2).toInstant(), rs.getTimestamp(3).toInstant());
            }
        }
    }

    boolean anySeasonExists() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement("SELECT COUNT(*) FROM seasons")) {
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1) > 0;
            }
        }
    }
    // ---- roleplay: paths, houses, titles ----------------------------------------

    record PathResult(long xp, int newLevel, boolean levelledUp) { }

    /**
     * Adds XP and recomputes the level, returning whether a level was crossed.
     *
     * The level is derived from XP and stored, in one statement, so the two can never disagree. Reading
     * the XP, computing in Java and writing both back would leave a window where a second flush
     * overwrites the first - which for a batched counter is not theoretical.
     */
    PathResult addPathXp(UUID uuid, Path path, long xp) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                long before;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT xp FROM paths WHERE uuid = ? AND path = ? FOR UPDATE")) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, path.key());
                    try (ResultSet rs = ps.executeQuery()) {
                        before = rs.next() ? rs.getLong(1) : -1;
                    }
                }
                long after = (before < 0 ? 0 : before) + xp;
                int oldLevel = Path.levelForXp(before < 0 ? 0 : before);
                int newLevel = Path.levelForXp(after);
                if (before < 0) {
                    try (PreparedStatement ps = c.prepareStatement(
                            "INSERT INTO paths (uuid, path, xp, level, created_at, updated_at) "
                          + "VALUES (?, ?, ?, ?, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3))")) {
                        ps.setString(1, uuid.toString());
                        ps.setString(2, path.key());
                        ps.setLong(3, after);
                        ps.setInt(4, newLevel);
                        ps.executeUpdate();
                    }
                } else {
                    try (PreparedStatement ps = c.prepareStatement(
                            "UPDATE paths SET xp = ?, level = ?, updated_at = UTC_TIMESTAMP(3) "
                          + "WHERE uuid = ? AND path = ?")) {
                        ps.setLong(1, after);
                        ps.setInt(2, newLevel);
                        ps.setString(3, uuid.toString());
                        ps.setString(4, path.key());
                        ps.executeUpdate();
                    }
                }
                // House standing rises with member progress, so a House of farmers competes with a
                // House of fighters. Points are XP-derived and grant nothing but standing.
                addHouseStanding(c, uuid, xp);
                c.commit();
                return new PathResult(after, newLevel, newLevel > oldLevel);
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    private void addHouseStanding(Connection c, UUID uuid, long points) throws SQLException {
        int season = activeSeasonNoAssert(c);
        if (season <= 0) return;
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO house_standing (season_number, house, points, updated_at) "
              + "SELECT ?, house, ?, UTC_TIMESTAMP(3) FROM house_members WHERE uuid = ? "
              + "ON DUPLICATE KEY UPDATE points = points + VALUES(points), "
              + "updated_at = UTC_TIMESTAMP(3)")) {
            ps.setInt(1, season);
            ps.setLong(2, points);
            ps.setString(3, uuid.toString());
            ps.executeUpdate();
        }
    }

    /** Season lookup inside an existing transaction, without re-asserting the thread. */
    private int activeSeasonNoAssert(Connection c) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT season_number FROM seasons WHERE state IN ('active','finale') "
              + "ORDER BY season_number DESC LIMIT 1")) {
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : -1;
            }
        }
    }

    java.util.Map<Path, long[]> allPaths(UUID uuid) throws SQLException {
        assertOffMainThread();
        java.util.Map<Path, long[]> out = new java.util.EnumMap<>(Path.class);
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT path, xp, level FROM paths WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Path p = Path.fromKey(rs.getString(1));
                    if (p != null) out.put(p, new long[] { rs.getLong(2), rs.getInt(3) });
                }
            }
        }
        return out;
    }

    void setActivePath(UUID uuid, Path path) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO player_identity (uuid, active_path, updated_at) "
               + "VALUES (?, ?, UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE "
               + "active_path = VALUES(active_path), updated_at = UTC_TIMESTAMP(3)")) {
            ps.setString(1, uuid.toString());
            ps.setString(2, path.key());
            ps.executeUpdate();
        }
    }

    /** The Path shown on the HUD, and its xp/level. Null when none chosen. */
    Object[] activePath(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT i.active_path, p.xp, p.level FROM player_identity i "
               + "LEFT JOIN paths p ON p.uuid = i.uuid AND p.path = i.active_path "
               + "WHERE i.uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next() || rs.getString(1) == null) return null;
                Path p = Path.fromKey(rs.getString(1));
                if (p == null) return null;
                return new Object[] { p, rs.getLong(2), rs.getInt(3) };
            }
        }
    }

    void grantTitle(UUID uuid, String key, String display, String colour, String source)
            throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO titles_owned (uuid, title_key, display, colour, source, "
                      + "earned_at) VALUES (?, ?, ?, ?, ?, UTC_TIMESTAMP(3)) "
                      + "ON DUPLICATE KEY UPDATE display = VALUES(display)")) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, key);
                    ps.setString(3, display);
                    ps.setString(4, colour);
                    ps.setString(5, source);
                    ps.executeUpdate();
                }
                // Wearing it automatically is deliberate: a reward the player has to go and equip is a
                // reward most players never see.
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO player_identity (uuid, active_title, updated_at) "
                      + "VALUES (?, ?, UTC_TIMESTAMP(3)) ON DUPLICATE KEY UPDATE "
                      + "active_title = VALUES(active_title), updated_at = UTC_TIMESTAMP(3)")) {
                    ps.setString(1, uuid.toString());
                    ps.setString(2, key);
                    ps.executeUpdate();
                }
                c.commit();
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    java.util.List<String> ownedTitles(UUID uuid) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT t.title_key, t.display, t.source, "
               + "(SELECT active_title FROM player_identity i WHERE i.uuid = t.uuid) "
               + "FROM titles_owned t WHERE t.uuid = ? ORDER BY t.earned_at")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    boolean worn = rs.getString(1).equals(rs.getString(4));
                    out.add(rs.getString(2) + "  [" + rs.getString(1) + "]"
                        + (worn ? "  (worn)" : ""));
                }
            }
        }
        return out;
    }

    /** Only a title the player owns can be worn - enforced in the WHERE, not by a prior check. */
    boolean wearTitle(UUID uuid, String key) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "INSERT INTO player_identity (uuid, active_title, updated_at) "
               + "SELECT ?, ?, UTC_TIMESTAMP(3) FROM titles_owned "
               + "WHERE uuid = ? AND title_key = ? "
               + "ON DUPLICATE KEY UPDATE active_title = VALUES(active_title), "
               + "updated_at = UTC_TIMESTAMP(3)")) {
            ps.setString(1, uuid.toString());
            ps.setString(2, key);
            ps.setString(3, uuid.toString());
            ps.setString(4, key);
            return ps.executeUpdate() > 0;
        }
    }

    /** The worn title's display text and colour, for the HUD and chat. Null when none. */
    String[] wornTitle(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT t.display, t.colour FROM player_identity i "
               + "JOIN titles_owned t ON t.uuid = i.uuid AND t.title_key = i.active_title "
               + "WHERE i.uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? new String[] { rs.getString(1), rs.getString(2) } : null;
            }
        }
    }

    /**
     * Joins or switches House.
     *
     * Switching is allowed but counted. A House you can leave the moment it starts losing is not an
     * identity, it is a bandwagon - and the counter makes a limit enforceable later without deleting
     * the history needed to apply it.
     */
    String joinHouse(UUID uuid, String house) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            String current = null;
            try (PreparedStatement ps = c.prepareStatement(
                    "SELECT house FROM house_members WHERE uuid = ?")) {
                ps.setString(1, uuid.toString());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) current = rs.getString(1);
                }
            }
            if (house.equals(current)) return "You are already in that House.";
            try (PreparedStatement ps = c.prepareStatement(
                    "INSERT INTO house_members (uuid, house, joined_at, changes) "
                  + "VALUES (?, ?, UTC_TIMESTAMP(3), 0) ON DUPLICATE KEY UPDATE "
                  + "house = VALUES(house), joined_at = UTC_TIMESTAMP(3), changes = changes + 1")) {
                ps.setString(1, uuid.toString());
                ps.setString(2, house);
                ps.executeUpdate();
            }
            return current == null
                ? "Welcome to House " + house + "."
                : "You have left House " + current + " for House " + house + ".";
        }
    }

    String myHouse(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT h.display, h.motto FROM house_members m "
               + "JOIN houses h ON h.house = m.house WHERE m.uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) + " - " + rs.getString(2) : null;
            }
        }
    }

    java.util.List<String> houseStanding() throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        int season = activeSeason();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT h.display, IFNULL(s.points, 0), "
               + "(SELECT COUNT(*) FROM house_members m WHERE m.house = h.house) "
               + "FROM houses h LEFT JOIN house_standing s ON s.house = h.house "
               + "AND s.season_number = ? ORDER BY IFNULL(s.points, 0) DESC, h.display")) {
            ps.setInt(1, season);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    out.add(rs.getString(1) + "  " + rs.getLong(2) + " points  "
                        + rs.getInt(3) + " member(s)");
                }
            }
        }
        return out;
    }
    // ---- chronicles --------------------------------------------------------------

    record ChapterView(int id, int chapter, String title, String narrative) { }
    record ChapterCompletion(int season, int chapter, String title, String nextTitle) { }

    /** Creates a chapter and its objectives if absent. Returns true when it created one. */
    boolean ensureChapter(int season, int chapter, String title, String narrative,
                          String[][] objectives) throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                int id;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT id FROM chronicle_chapters WHERE season_number = ? "
                      + "AND chapter = ?")) {
                    ps.setInt(1, season);
                    ps.setInt(2, chapter);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            c.rollback();
                            return false;
                        }
                    }
                }
                try (PreparedStatement ps = c.prepareStatement(
                        "INSERT INTO chronicle_chapters (season_number, chapter, title, narrative, "
                      + "state, started_at) VALUES (?, ?, ?, ?, ?, ?)",
                        java.sql.Statement.RETURN_GENERATED_KEYS)) {
                    ps.setInt(1, season);
                    ps.setInt(2, chapter);
                    ps.setString(3, title);
                    ps.setString(4, narrative);
                    // Chapter 1 opens immediately; the rest wait. A story where every chapter is
                    // available at once is a checklist, not a story.
                    ps.setString(5, chapter == 1 ? "active" : "locked");
                    if (chapter == 1) {
                        ps.setTimestamp(6, new java.sql.Timestamp(System.currentTimeMillis()));
                    } else {
                        ps.setNull(6, java.sql.Types.TIMESTAMP);
                    }
                    ps.executeUpdate();
                    try (ResultSet rs = ps.getGeneratedKeys()) {
                        rs.next();
                        id = rs.getInt(1);
                    }
                }
                for (String[] o : objectives) {
                    try (PreparedStatement ps = c.prepareStatement(
                            "INSERT INTO chronicle_objectives (chapter_id, description, metric, "
                          + "target, progress) VALUES (?, ?, ?, ?, 0)")) {
                        ps.setInt(1, id);
                        ps.setString(2, o[0]);
                        ps.setString(3, o[1]);
                        ps.setLong(4, Long.parseLong(o[2]));
                        ps.executeUpdate();
                    }
                }
                c.commit();
                return true;
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    /**
     * Advances every objective of the ACTIVE chapter that tracks this metric.
     *
     * Capped at the target with LEAST, so progress cannot exceed 100% - an objective showing 140%
     * looks like a bug even when the arithmetic is fine, and a cap costs nothing.
     */
    void advanceObjectives(String metric, long amount) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "UPDATE chronicle_objectives o "
               + "JOIN chronicle_chapters ch ON ch.id = o.chapter_id AND ch.state = 'active' "
               + "SET o.progress = LEAST(o.target, o.progress + ?) WHERE o.metric = ?")) {
            ps.setLong(1, amount);
            ps.setString(2, metric);
            ps.executeUpdate();
        }
    }

    /**
     * Completes the active chapter when every objective is met, and unlocks the next.
     *
     * Both happen in one transaction. Completing without unlocking would leave the Chronicle stalled
     * with nothing active, which reads to players as the story being over.
     */
    ChapterCompletion completeChapterIfDone() throws SQLException {
        assertOffMainThread();
        try (Connection c = open()) {
            c.setAutoCommit(false);
            try {
                int id = -1, season = 0, chapter = 0;
                String title = null;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT ch.id, ch.season_number, ch.chapter, ch.title "
                      + "FROM chronicle_chapters ch WHERE ch.state = 'active' "
                      + "AND NOT EXISTS (SELECT 1 FROM chronicle_objectives o "
                      + "WHERE o.chapter_id = ch.id AND o.progress < o.target) "
                      + "LIMIT 1 FOR UPDATE")) {
                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) {
                            c.rollback();
                            return null;
                        }
                        id = rs.getInt(1);
                        season = rs.getInt(2);
                        chapter = rs.getInt(3);
                        title = rs.getString(4);
                    }
                }
                try (PreparedStatement ps = c.prepareStatement(
                        "UPDATE chronicle_chapters SET state = 'complete', "
                      + "completed_at = UTC_TIMESTAMP(3) WHERE id = ?")) {
                    ps.setInt(1, id);
                    ps.executeUpdate();
                }
                String nextTitle = null;
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT id, title FROM chronicle_chapters WHERE season_number = ? "
                      + "AND chapter = ? AND state = 'locked'")) {
                    ps.setInt(1, season);
                    ps.setInt(2, chapter + 1);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            int nextId = rs.getInt(1);
                            nextTitle = rs.getString(2);
                            try (PreparedStatement up = c.prepareStatement(
                                    "UPDATE chronicle_chapters SET state = 'active', "
                                  + "started_at = UTC_TIMESTAMP(3) WHERE id = ?")) {
                                up.setInt(1, nextId);
                                up.executeUpdate();
                            }
                        }
                    }
                }
                c.commit();
                return new ChapterCompletion(season, chapter, title, nextTitle);
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    ChapterView currentChapter() throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT id, chapter, title, narrative FROM chronicle_chapters "
               + "WHERE state = 'active' LIMIT 1")) {
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                return new ChapterView(rs.getInt(1), rs.getInt(2), rs.getString(3),
                    rs.getString(4));
            }
        }
    }

    java.util.List<String> chapterObjectives(int chapterId) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT description, progress, target FROM chronicle_objectives "
               + "WHERE chapter_id = ? ORDER BY id")) {
            ps.setInt(1, chapterId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    long prog = rs.getLong(2), target = rs.getLong(3);
                    int pct = (int) Math.round(100.0 * prog / target);
                    int filled = pct / 10;
                    StringBuilder bar = new StringBuilder();
                    for (int i = 0; i < 10; i++) bar.append(i < filled ? '\u25AC' : '\u00B7');
                    out.add(bar + "  " + pct + "%  " + rs.getString(1)
                        + "  (" + prog + "/" + target + ")");
                }
            }
        }
        return out;
    }
    String houseKeyOf(UUID uuid) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT house FROM house_members WHERE uuid = ?")) {
            ps.setString(1, uuid.toString());
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : null;
            }
        }
    }

    java.util.List<UUID> houseMemberIds(String house) throws SQLException {
        assertOffMainThread();
        java.util.List<UUID> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT uuid FROM house_members WHERE house = ?")) {
            ps.setString(1, house);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(UUID.fromString(rs.getString(1)));
            }
        }
        return out;
    }
    /** How many chapters exist for a season. Lets the seeder exit cheaply once it has run. */
    int chapterCount(int season) throws SQLException {
        assertOffMainThread();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT COUNT(*) FROM chronicle_chapters WHERE season_number = ?")) {
            ps.setInt(1, season);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getInt(1);
            }
        }
    }
    /** The richest players, for the economy page. Names only, no UUIDs shown to players. */
    java.util.List<String> topBalances(int limit) throws SQLException {
        assertOffMainThread();
        java.util.List<String> out = new java.util.ArrayList<>();
        try (Connection c = open();
             PreparedStatement ps = c.prepareStatement(
                 "SELECT p.current_name, b.berries FROM balances b "
               + "JOIN players p ON p.uuid = b.uuid WHERE b.berries > 0 "
               + "ORDER BY b.berries DESC, p.current_name ASC LIMIT ?")) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                int i = 1;
                while (rs.next()) out.add((i++) + ". " + rs.getString(1) + "  " + rs.getLong(2));
            }
        }
        return out;
    }}
