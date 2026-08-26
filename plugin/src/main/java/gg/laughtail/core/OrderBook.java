package gg.laughtail.core;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * The order book and its matching engine. Acceptance rows 28 and 29.
 *
 * Kept in its own class rather than added to Database because matching is the one piece of logic
 * here where a mistake mints or destroys value, and it deserves to be read on its own.
 *
 * ROW 28: "Server killed mid-match creates and destroys nothing."
 *
 * The whole match - the fill row, both order updates, both payouts - happens in ONE transaction. A
 * kill -9 either lands before the commit, in which case nothing happened, or after it, in which case
 * everything happened. There is no third state. This is why escrow lives in the database rather than
 * in a Java map: a map is gone on restart and the player is either short an item or holding a
 * duplicate.
 *
 * THE FILL ROW IS WRITTEN FIRST, inside the transaction. If a fill exists the trade happened; if it
 * does not, it did not. After a crash the question "did this trade go through?" has exactly one
 * answer, which is what makes row 28 provable rather than asserted.
 *
 * THE RESTING ORDER SETS THE PRICE. If a buyer offers 25 and a sell order is already sitting at 20,
 * they trade at 20 and the buyer is refunded the difference. This is how real exchanges work and it
 * matters for a reason beyond convention: if the incoming order set the price, a player could watch
 * the book, place an order one Berry better, and capture the whole spread every time - which is
 * front-running with extra steps. Rewarding the order that committed first also rewards providing
 * liquidity, which is what makes a bazaar usable at all.
 *
 * ROWS ARE LOCKED IN ID ORDER. Two simultaneous matches touching the same pair of orders in opposite
 * order would deadlock. Sorting by primary key before locking is the standard fix and the reason this
 * code takes the lower id first every time.
 *
 * SELF-TRADING IS REFUSED. Matching a player against their own order would let someone move Berries
 * between their own accounts while generating fake volume - which corrupts every price signal the
 * shop's elasticity depends on, and looks exactly like market manipulation to any later audit.
 */
final class OrderBook {

    record Fill(long buyOrderId, long sellOrderId, int quantity, long unitPrice,
                UUID buyer, UUID seller) { }

    record PlaceResult(long orderId, int filledImmediately, long spentOrEarned,
                       String refusal) {
        boolean ok() { return refusal == null; }
    }

    private final Database db;

    OrderBook(Database db) {
        this.db = db;
    }

    /**
     * Places an order and matches it as far as it will go.
     *
     * Escrow is taken in the SAME transaction that creates the order. Taking Berries and then
     * inserting the order as two steps leaves a window where a crash charges a player for an order
     * that does not exist - which is the exact failure row 28 is about.
     */
    PlaceResult place(UUID player, String side, String material, int quantity, long unitPrice)
            throws SQLException {
        db.assertOffMainThreadPublic();
        if (quantity <= 0 || unitPrice <= 0) {
            return new PlaceResult(0, 0, 0, "quantity and price must both be positive");
        }
        try (Connection c = db.openForTransaction()) {
            c.setAutoCommit(false);
            try {
                long orderId;
                if (side.equals("buy")) {
                    long cost = (long) quantity * unitPrice;
                    db.lockBalanceIn(c, player);
                    long bal = db.readBalanceIn(c, player);
                    if (bal < cost) {
                        c.rollback();
                        return new PlaceResult(0, 0, 0, "you need " + cost
                            + " Berries and have " + bal);
                    }
                    // The Berries leave the balance NOW. An order that is not funded is a promise,
                    // and a market built on promises has to handle the promise being broken - which
                    // is a whole class of problem that escrow simply removes.
                    db.writeBalanceIn(c, player, bal - cost, 0, cost);
                    db.ledgerIn(c, player, -cost, bal - cost, "order_escrow", null, material,
                        quantity, "buy order at " + unitPrice + " each");
                    orderId = insertOrder(c, player, side, material, quantity, unitPrice, cost, 0);
                } else {
                    // Sell escrow is the item count. The items themselves were already taken from
                    // the inventory by the caller, on the main thread, before this ran.
                    orderId = insertOrder(c, player, side, material, quantity, unitPrice, 0,
                        quantity);
                }

                List<Fill> fills = match(c, orderId);
                c.commit();
                int filled = fills.stream().mapToInt(Fill::quantity).sum();
                long value = fills.stream().mapToLong(f -> f.quantity() * f.unitPrice()).sum();
                return new PlaceResult(orderId, filled, value, null);
            } catch (SQLException e) {
                c.rollback();
                throw e;
            }
        }
    }

    private long insertOrder(Connection c, UUID player, String side, String material,
                             int quantity, long unitPrice, long escrowBerries, int escrowItems)
            throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "INSERT INTO orders (player, side, material, unit_price, quantity, remaining, "
              + "escrow_berries, escrow_items, state, created_at, updated_at) VALUES "
              + "(?, ?, ?, ?, ?, ?, ?, ?, 'open', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3))",
                java.sql.Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, player.toString());
            ps.setString(2, side);
            ps.setString(3, material);
            ps.setLong(4, unitPrice);
            ps.setInt(5, quantity);
            ps.setInt(6, quantity);
            ps.setLong(7, escrowBerries);
            ps.setInt(8, escrowItems);
            ps.executeUpdate();
            try (ResultSet rs = ps.getGeneratedKeys()) {
                if (!rs.next()) throw new SQLException("order insert returned no id");
                return rs.getLong(1);
            }
        }
    }

    /**
     * Matches one order against the book until it is filled or nothing crosses.
     *
     * Runs inside the caller's transaction, deliberately. Matching in its own transaction would mean
     * an order could exist, funded, with a matching counterparty, and no trade - which is a market
     * that silently stops working.
     */
    private List<Fill> match(Connection c, long orderId) throws SQLException {
        List<Fill> fills = new ArrayList<>();

        String side, material;
        long price;
        int remaining;
        UUID owner;
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT side, material, unit_price, remaining, player FROM orders "
              + "WHERE id = ? FOR UPDATE")) {
            ps.setLong(1, orderId);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return fills;
                side = rs.getString(1);
                material = rs.getString(2);
                price = rs.getLong(3);
                remaining = rs.getInt(4);
                owner = UUID.fromString(rs.getString(5));
            }
        }
        if (remaining <= 0) return fills;

        boolean buying = side.equals("buy");
        // Best price first, then oldest first. A buy order takes the CHEAPEST sell available; a sell
        // order takes the HIGHEST buy. Time is the tie-break, so waiting is never punished.
        String sql = "SELECT id, player, unit_price, remaining FROM orders "
                   + "WHERE material = ? AND side = ? AND state = 'open' AND remaining > 0 "
                   + "AND player <> ? AND unit_price " + (buying ? "<= ?" : ">= ?")
                   + " ORDER BY unit_price " + (buying ? "ASC" : "DESC") + ", created_at ASC, id ASC";

        List<long[]> candidates = new ArrayList<>();
        List<UUID> candidateOwners = new ArrayList<>();
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, material);
            ps.setString(2, buying ? "sell" : "buy");
            // Self-trading refused in the query itself, so it cannot be forgotten in the loop.
            ps.setString(3, owner.toString());
            ps.setLong(4, price);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    candidates.add(new long[] { rs.getLong(1), rs.getLong(3), rs.getInt(4) });
                    candidateOwners.add(UUID.fromString(rs.getString(2)));
                }
            }
        }

        for (int i = 0; i < candidates.size() && remaining > 0; i++) {
            long otherId = candidates.get(i)[0];
            long restingPrice = candidates.get(i)[1];
            UUID otherOwner = candidateOwners.get(i);

            // Lock both rows in id order. The opposite order would deadlock against a simultaneous
            // match on the same pair.
            long first = Math.min(orderId, otherId), second = Math.max(orderId, otherId);
            int otherRemaining = lockAndReadRemaining(c, first, second, orderId, otherId);
            if (otherRemaining <= 0) continue;

            // Re-read our own remaining under the lock: an earlier iteration changed it.
            remaining = readRemaining(c, orderId);
            if (remaining <= 0) break;

            int qty = Math.min(remaining, otherRemaining);
            long dealPrice = restingPrice;   // the resting order sets it - see the class note

            long buyOrder = buying ? orderId : otherId;
            long sellOrder = buying ? otherId : orderId;
            UUID buyer = buying ? owner : otherOwner;
            UUID seller = buying ? otherOwner : owner;

            // The fill row goes in FIRST, so its existence is the record that the trade happened.
            try (PreparedStatement ps = c.prepareStatement(
                    "INSERT INTO order_fills (buy_order_id, sell_order_id, material, quantity, "
                  + "unit_price, buyer, seller, occurred_at) VALUES (?, ?, ?, ?, ?, ?, ?, "
                  + "UTC_TIMESTAMP(3))")) {
                ps.setLong(1, buyOrder);
                ps.setLong(2, sellOrder);
                ps.setString(3, material);
                ps.setInt(4, qty);
                ps.setLong(5, dealPrice);
                ps.setString(6, buyer.toString());
                ps.setString(7, seller.toString());
                ps.executeUpdate();
            }

            long paid = qty * dealPrice;

            // Buyer: consume escrow, receive items to collect. If they offered more than the deal
            // price, the difference is refunded rather than kept - a market that pockets the
            // difference is charging a hidden fee.
            long buyerOffer = buying ? price : restingPrice;
            long escrowUsed = qty * buyerOffer;
            long refund = escrowUsed - paid;
            try (PreparedStatement ps = c.prepareStatement(
                    "UPDATE orders SET escrow_berries = escrow_berries - ?, "
                  + "payout_items = payout_items + ?, payout_berries = payout_berries + ?, "
                  + "remaining = remaining - ?, updated_at = UTC_TIMESTAMP(3) WHERE id = ?")) {
                ps.setLong(1, escrowUsed);
                ps.setInt(2, qty);
                ps.setLong(3, refund);
                ps.setInt(4, qty);
                ps.setLong(5, buyOrder);
                ps.executeUpdate();
            }

            // Seller: consume item escrow, receive Berries to collect.
            try (PreparedStatement ps = c.prepareStatement(
                    "UPDATE orders SET escrow_items = escrow_items - ?, "
                  + "payout_berries = payout_berries + ?, remaining = remaining - ?, "
                  + "updated_at = UTC_TIMESTAMP(3) WHERE id = ?")) {
                ps.setInt(1, qty);
                ps.setLong(2, paid);
                ps.setInt(3, qty);
                ps.setLong(4, sellOrder);
                ps.executeUpdate();
            }

            closeIfDone(c, buyOrder);
            closeIfDone(c, sellOrder);

            fills.add(new Fill(buyOrder, sellOrder, qty, dealPrice, buyer, seller));
            remaining -= qty;
        }
        return fills;
    }

    private int lockAndReadRemaining(Connection c, long first, long second,
                                     long mine, long other) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT id, remaining FROM orders WHERE id IN (?, ?) ORDER BY id FOR UPDATE")) {
            ps.setLong(1, first);
            ps.setLong(2, second);
            int otherRemaining = 0;
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    if (rs.getLong(1) == other) otherRemaining = rs.getInt(2);
                }
            }
            return otherRemaining;
        }
    }

    private int readRemaining(Connection c, long id) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT remaining FROM orders WHERE id = ?")) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** Marks an order filled once nothing is left. State is derived, never guessed. */
    private void closeIfDone(Connection c, long id) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "UPDATE orders SET state = 'filled' WHERE id = ? AND remaining = 0")) {
            ps.setLong(1, id);
            ps.executeUpdate();
        }
    }

    /**
     * Runs a real match and ROLLS IT BACK, asserting that value was conserved.
     *
     * This is the strongest evidence available for row 28 without two live players. It exercises the
     * ACTUAL matching code against the ACTUAL database - the same inserts, the same locks, the same
     * arithmetic - and then rolls back, so it leaves nothing behind and can run on every boot.
     *
     * A test that reimplemented the arithmetic in SQL would only prove that two of my mistakes agree.
     * A test against a mock would prove less. Rolling back a real transaction is the only way to
     * exercise the real path without polluting live data.
     *
     * WHAT IT ASSERTS, in order of importance:
     *   1. CONSERVATION. Berries in escrow and payouts, plus balances, are unchanged by the match.
     *      A match must move value, never create or destroy it - that is row 28 in one sentence.
     *   2. The resting order sets the price, and the aggressor is refunded the difference.
     *   3. Item escrow moves to item payout, exactly.
     *   4. Self-trading is refused.
     *   5. A fill row exists for every trade.
     *
     * @return failure descriptions. Empty is a pass.
     */
    List<String> selfTest(UUID a, UUID b) throws SQLException {
        db.assertOffMainThreadPublic();
        List<String> fails = new ArrayList<>();
        try (Connection c = db.openForTransaction()) {
            c.setAutoCommit(false);
            try {
                final String MAT = "__SELFTEST__";

                // A rests a SELL of 10 at 20. B aggresses with a BUY of 4 at 25.
                // Expected: 4 trade at 20 (the resting price), B is refunded 4 x 5 = 20.
                long sellId = insertOrder(c, a, "sell", MAT, 10, 20, 0, 10);
                long buyId  = insertOrder(c, b, "buy",  MAT, 4, 25, 100, 0);

                List<Fill> fills = match(c, buyId);

                if (fills.size() != 1) {
                    fails.add("expected exactly 1 fill, got " + fills.size());
                } else {
                    Fill f = fills.get(0);
                    if (f.quantity() != 4) fails.add("expected 4 filled, got " + f.quantity());
                    if (f.unitPrice() != 20) {
                        fails.add("the RESTING price should apply: expected 20, got "
                            + f.unitPrice());
                    }
                    if (!f.seller().equals(a)) fails.add("seller should be the resting order owner");
                    if (!f.buyer().equals(b)) fails.add("buyer should be the aggressor");
                }

                // Seller: 10 items escrowed, 4 sold, so 6 escrowed and 80 Berries to collect.
                long[] s = readOrder(c, sellId);
                if (s[0] != 6) fails.add("seller item escrow should be 6, is " + s[0]);
                if (s[1] != 80) fails.add("seller payout should be 80 Berries, is " + s[1]);
                if (s[2] != 6) fails.add("seller remaining should be 6, is " + s[2]);

                // Buyer: escrowed 100 (4 x 25), spent 80, so 20 refunded and 4 items to collect.
                long[] bu = readOrder(c, buyId);
                if (bu[0] != 0) fails.add("buyer berry escrow should be 0, is " + bu[0]);
                if (bu[1] != 20) {
                    fails.add("buyer should be refunded 20 - the difference between the offer and "
                        + "the resting price - but has " + bu[1]);
                }
                if (bu[3] != 4) fails.add("buyer item payout should be 4, is " + bu[3]);

                // CONSERVATION. Everything the two orders hold must still add to what went in:
                // 100 Berries from the buyer, 10 items from the seller.
                long berriesNow = s[0] * 0 + s[1] + bu[0] + bu[1];   // payouts plus escrow
                if (berriesNow != 100) {
                    fails.add("BERRIES NOT CONSERVED: 100 went in, " + berriesNow
                        + " is accounted for");
                }
                long itemsNow = s[0] + bu[3];
                if (itemsNow != 10) {
                    fails.add("ITEMS NOT CONSERVED: 10 went in, " + itemsNow
                        + " is accounted for");
                }

                // Self-trading: A aggresses against A's own resting sell. Must not match.
                long selfBuy = insertOrder(c, a, "buy", MAT, 2, 25, 50, 0);
                List<Fill> selfFills = match(c, selfBuy);
                if (!selfFills.isEmpty()) {
                    fails.add("SELF-TRADE MATCHED: " + selfFills.size()
                        + " fill(s) between one player's own orders");
                }

                // A fill row must exist for the real trade and not for the self-trade.
                try (PreparedStatement ps = c.prepareStatement(
                        "SELECT COUNT(*) FROM order_fills WHERE material = ?")) {
                    ps.setString(1, MAT);
                    try (ResultSet rs = ps.executeQuery()) {
                        rs.next();
                        if (rs.getInt(1) != 1) {
                            fails.add("expected exactly 1 fill row, found " + rs.getInt(1));
                        }
                    }
                }
                return fails;
            } finally {
                // ALWAYS rolled back, including on an assertion failure, so a failing test cannot
                // leave test orders in a live book.
                c.rollback();
            }
        }
    }

    /** {escrow_items, payout_berries, remaining, payout_items} for a self-test order. */
    private long[] readOrder(Connection c, long id) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(
                "SELECT escrow_items, payout_berries, remaining, payout_items, escrow_berries "
              + "FROM orders WHERE id = ?")) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return new long[] { -1, -1, -1, -1, -1 };
                // escrow_berries is returned in slot 0 for buy orders via the caller's convention;
                // buy orders have no item escrow, so the two never collide.
                long itemEscrow = rs.getLong(1);
                long berryEscrow = rs.getLong(5);
                return new long[] { itemEscrow > 0 ? itemEscrow : berryEscrow,
                                    rs.getLong(2), rs.getLong(3), rs.getLong(4) };
            }
        }
    }}
