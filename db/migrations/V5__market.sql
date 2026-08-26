-- V5 - the auction house and the order book (bazaar).
--
-- Two different markets, deliberately, because they solve different problems:
--
--   AUCTIONS are for ONE specific item at a fixed price. The item may be enchanted, named, damaged -
--   anything - so it is stored as a serialised stack. You browse, you buy, you get that exact item.
--
--   ORDERS are for FUNGIBLE resources: 500 iron, any iron. Buy orders and sell orders sit in a book
--   and are matched automatically. Nobody has to be online for a trade to happen, which is the whole
--   point of a bazaar and the reason it is not just an auction with extra steps.
--
-- WHY ESCROW IS IN THE DATABASE AND NOT IN MEMORY. Acceptance row 28 requires that killing the
-- server mid-match "creates and destroys nothing". Anything held in a Java map is gone on restart,
-- and the player is either down an item or up a duplicate. So a listed item leaves the player's
-- inventory and becomes a row; Berries committed to a buy order leave the balance and become a row.
-- The database is the only thing that survives a kill -9, so the database is where value lives.
--
-- WHY ORDERS DO NOT STORE A SERIALISED STACK. An order is for a material and a quantity, nothing
-- more. Allowing NBT in the order book would mean a buy order for "iron ingot" could be filled with
-- a renamed iron ingot, or a differently enchanted one, and every fill would need a comparison
-- nobody can reason about. Fungible means fungible. Anything with NBT goes to the auction house.

-- COLLATE IS EXPLICIT. Without it these tables take the server default (utf8mb4_general_ci) while
-- players.uuid is utf8mb4_unicode_ci, and a foreign key between two different collations fails with
-- the famously unhelpful "errno: 150 Foreign key constraint is incorrectly formed". Every table in
-- this schema states its collation for that reason.
SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ---------------------------------------------------------------------------
-- auctions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auctions (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  seller        CHAR(36)        NOT NULL,
  item_blob     BLOB            NOT NULL COMMENT 'Bukkit serializeAsBytes. The item itself lives here, not in anyone inventory, so a restart cannot lose it',
  item_name     VARCHAR(64)     NOT NULL COMMENT 'Material name, denormalised for searching and for the GUI - reading every blob to render a page would be absurd',
  display_name  VARCHAR(128)        NULL COMMENT 'custom name if the item had one, so a listing shows what a player would recognise',
  quantity      INT UNSIGNED    NOT NULL,
  price         BIGINT UNSIGNED NOT NULL COMMENT 'total price for the whole stack, not per unit - a fixed-price listing is one decision, not arithmetic',
  state         ENUM('active','sold','expired','cancelled') NOT NULL DEFAULT 'active',
  buyer         CHAR(36)            NULL,
  created_at    DATETIME(3)     NOT NULL COMMENT 'UTC',
  expires_at    DATETIME(3)     NOT NULL COMMENT 'UTC',
  resolved_at   DATETIME(3)         NULL COMMENT 'UTC. When it sold, expired or was cancelled',
  claimed       TINYINT(1)      NOT NULL DEFAULT 0 COMMENT 'whether the seller has collected the proceeds or the unsold item back',
  PRIMARY KEY (id),
  KEY idx_auction_active (state, expires_at),
  KEY idx_auction_seller (seller, state),
  KEY idx_auction_item (item_name, state),
  CONSTRAINT fk_auction_seller FOREIGN KEY (seller) REFERENCES players (uuid),
  CONSTRAINT fk_auction_buyer  FOREIGN KEY (buyer)  REFERENCES players (uuid),
  CONSTRAINT chk_auction_price CHECK (price > 0),
  CONSTRAINT chk_auction_qty   CHECK (quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- orders - the bazaar
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  player         CHAR(36)        NOT NULL,
  side           ENUM('buy','sell') NOT NULL,
  material       VARCHAR(64)     NOT NULL COMMENT 'Bukkit Material name. No NBT: fungible means fungible',
  unit_price     BIGINT UNSIGNED NOT NULL,
  quantity       INT UNSIGNED    NOT NULL COMMENT 'the original size, kept so a partly filled order can still be explained',
  remaining      INT UNSIGNED    NOT NULL,
  escrow_berries BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'for buy orders: Berries already taken from the balance and held here',
  escrow_items   INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT 'for sell orders: items already taken from the inventory and held here',
  payout_berries BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'proceeds waiting to be collected',
  payout_items   INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT 'bought items waiting to be collected',
  state          ENUM('open','filled','cancelled') NOT NULL DEFAULT 'open',
  created_at     DATETIME(3)     NOT NULL COMMENT 'UTC. Also the tie-break for matching - time priority',
  updated_at     DATETIME(3)     NOT NULL COMMENT 'UTC',
  PRIMARY KEY (id),
  -- The matching engine scans this index: one side, one material, ordered by price then age.
  KEY idx_book (material, side, state, unit_price, created_at),
  KEY idx_order_player (player, state),
  CONSTRAINT fk_order_player FOREIGN KEY (player) REFERENCES players (uuid),
  CONSTRAINT chk_order_price CHECK (unit_price > 0),
  CONSTRAINT chk_order_qty   CHECK (quantity > 0),
  -- remaining can reach zero but must never go below it, and never exceed what was ordered.
  CONSTRAINT chk_order_remaining CHECK (remaining <= quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- order_fills - the audit trail for every match
-- ---------------------------------------------------------------------------
-- Every match writes a row here BEFORE the orders are updated, inside the same transaction. If a
-- fill exists, the trade happened; if it does not, it did not. That is what makes row 28 provable
-- rather than asserted - after a kill -9 the question "did this trade happen?" has exactly one
-- answer, and it is not "compare two inventories and guess".
CREATE TABLE IF NOT EXISTS order_fills (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  buy_order_id  BIGINT UNSIGNED NOT NULL,
  sell_order_id BIGINT UNSIGNED NOT NULL,
  material      VARCHAR(64)     NOT NULL,
  quantity      INT UNSIGNED    NOT NULL,
  unit_price    BIGINT UNSIGNED NOT NULL COMMENT 'the price actually paid - the resting order sets it, see the note in Market.java',
  buyer         CHAR(36)        NOT NULL,
  seller        CHAR(36)        NOT NULL,
  occurred_at   DATETIME(3)     NOT NULL COMMENT 'UTC, millisecond precision',
  PRIMARY KEY (id),
  KEY idx_fill_buy (buy_order_id),
  KEY idx_fill_sell (sell_order_id),
  KEY idx_fill_time (occurred_at),
  CONSTRAINT fk_fill_buy  FOREIGN KEY (buy_order_id)  REFERENCES orders (id),
  CONSTRAINT fk_fill_sell FOREIGN KEY (sell_order_id) REFERENCES orders (id),
  CONSTRAINT chk_fill_qty CHECK (quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
