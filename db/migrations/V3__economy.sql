-- V3__economy.sql
--
-- Berries: the single currency (Law: one currency, no dual-currency hyperinflation), its
-- ledger, and the shop's price state. Appendix D's economy tables.
--
-- NOW BUILDABLE because D-0031 fixed the numbers Q-10 was blocking on:
--   target_berries_per_hour 1200, minimum spread 12%, elasticity 0.15 per 1000 units with a
--   +/-40% band, recovery 5% of the gap per hour, daily sell cap 3600 per category,
--   transfer tax 5% above 5000.
--
-- THE LEDGER IS THE POINT. `balances` is a cache of `transactions`, not the other way round.
-- Every movement writes a transaction row, and a balance is only ever changed in the same
-- transaction that records why. That is what makes the Phase 3 arbitrage audit possible at
-- all: an audit that cannot see every movement cannot find a money printer.
--
-- MONEY IS BIGINT, in whole Berries. Not DECIMAL, not double. A float balance cannot be
-- summed reliably across a million rows, and the arbitrage audit sums.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ---------------------------------------------------------------------------
-- balances - current holdings. A CACHE of the ledger.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS balances (
  uuid          CHAR(36)     NOT NULL,
  berries       BIGINT       NOT NULL DEFAULT 0 COMMENT 'whole Berries. Signed BIGINT deliberately: a negative balance should be IMPOSSIBLE, and storing it unsigned would make an underflow wrap to a vast positive number instead of failing. A CHECK enforces it below',
  lifetime_in   BIGINT       NOT NULL DEFAULT 0 COMMENT 'total ever earned - for the 31.10 growth alert, which needs a rate and not just a level',
  lifetime_out  BIGINT       NOT NULL DEFAULT 0,
  last_modified DATETIME(3)  NOT NULL COMMENT 'UTC',
  created_at    DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid),
  KEY idx_bal_amount (berries DESC) COMMENT 'the rich list, and the median for the P7 alert',
  CONSTRAINT chk_bal_nonneg CHECK (berries >= 0),
  CONSTRAINT fk_bal_player FOREIGN KEY (uuid) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- transactions - every Berry movement, permanently
-- ---------------------------------------------------------------------------
-- Appendix D: "Every Berry movement, with type, counterparty, amount, and reason."
--
-- Retention: permanent, and deliberately so. This is the evidence base for the arbitrage
-- audit, for row 14a's wagering detector (a payment correlated with a death inside 60
-- seconds, hence DATETIME(3)), and for any dispute about where money went. 31.13 governs
-- personal data, not the ledger - anonymising a player scrubs their name, not their trades.
--
-- balance_after is stored ON EACH ROW. That is denormalised on purpose: it makes the ledger
-- self-checking. If row N's balance_after plus row N+1's delta does not equal row N+1's
-- balance_after, the ledger has been corrupted and it can be found by scanning rather than
-- by reconstructing from zero.
CREATE TABLE IF NOT EXISTS transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uuid           CHAR(36)        NOT NULL COMMENT 'whose balance moved',
  delta          BIGINT          NOT NULL COMMENT 'signed. Positive is income, negative is spend',
  balance_after  BIGINT          NOT NULL COMMENT 'denormalised so the ledger is self-checking - see the note above',
  type           VARCHAR(32)     NOT NULL COMMENT 'shop_buy, shop_sell, transfer_in, transfer_out, transfer_tax, auction_sale, auction_fee, admin_grant, admin_take, sink_fee, bounty, reward',
  counterparty   CHAR(36)             NULL COMMENT 'the other player, when there is one. NULL for shop and system movements',
  item            VARCHAR(64)         NULL COMMENT 'the item involved, for shop and auction rows',
  quantity        INT                 NULL,
  reason         VARCHAR(200)         NULL COMMENT 'human-readable, for disputes',
  occurred_at    DATETIME(3)     NOT NULL COMMENT 'UTC, millisecond precision for row 14a',
  PRIMARY KEY (id),
  KEY idx_tx_player (uuid, occurred_at),
  KEY idx_tx_type (type, occurred_at),
  KEY idx_tx_counterparty (counterparty, occurred_at) COMMENT 'reciprocal-transfer detection',
  KEY idx_tx_item (item, occurred_at) COMMENT 'the arbitrage audit walks by item',
  CONSTRAINT fk_tx_player FOREIGN KEY (uuid) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- shop_prices - the dynamic price band of 8.x
-- ---------------------------------------------------------------------------
-- base_price is derived from Appendix B's base-value formula against
-- target_berries_per_hour = 1200 (P2). current_price moves with trade under P4's elasticity
-- and drifts back under P5's recovery.
--
-- The band is enforced in the SCHEMA as well as in code, because "prices stay within a
-- bounded band" is the property that stops a money printer, and a bounded band enforced only
-- by application logic is one bug away from unbounded.
CREATE TABLE IF NOT EXISTS shop_prices (
  item           VARCHAR(64)  NOT NULL COMMENT 'Bukkit Material name',
  category       VARCHAR(32)  NOT NULL COMMENT 'for the P6 daily sell cap, which is per category so rotating between similar items does not dodge it',
  base_price     BIGINT       NOT NULL COMMENT 'derived from P2. Never changes at runtime',
  current_price  BIGINT       NOT NULL COMMENT 'moves with trade, bounded to +/-40% of base (P4)',
  sell_price     BIGINT       NOT NULL COMMENT 'current_price minus the 12% minimum spread (P3)',
  units_traded   BIGINT       NOT NULL DEFAULT 0 COMMENT 'drives elasticity',
  last_trade_at  DATETIME(3)       NULL COMMENT 'UTC. Drives the P5 recovery toward base',
  updated_at     DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (item),
  KEY idx_price_category (category),
  CONSTRAINT chk_price_band CHECK (current_price >= base_price * 0.6
                               AND current_price <= base_price * 1.4),
  CONSTRAINT chk_spread CHECK (sell_price < current_price)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- daily_sell_totals - the P6 cap, per player per category per UTC day
-- ---------------------------------------------------------------------------
-- A separate table rather than a rolling query over `transactions`, because the cap is
-- checked on every sale and scanning the ledger for each one would put a growing query in a
-- hot path. This is a counter that resets by date, which is cheap to read and cheap to reset
-- by simply having a different key tomorrow.
CREATE TABLE IF NOT EXISTS daily_sell_totals (
  uuid       CHAR(36)     NOT NULL,
  sell_date  DATE         NOT NULL COMMENT 'UTC date, so the cap resets at the same instant for everyone regardless of timezone',
  category   VARCHAR(32)  NOT NULL,
  berries    BIGINT       NOT NULL DEFAULT 0,
  updated_at DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid, sell_date, category),
  CONSTRAINT fk_dst_player FOREIGN KEY (uuid) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- shop_tier_state - which shop tier a player has unlocked (Section 10)
-- ---------------------------------------------------------------------------
-- Tier derives from rank, so this is a cache with a peak, exactly like combat_ratings. Kept
-- per season because rank resets, and `peak_tier` is kept because 10.x gates purchases on
-- what a player has REACHED rather than on where they currently sit - otherwise a bad week
-- would revoke access to items they already earned.
CREATE TABLE IF NOT EXISTS shop_tier_state (
  uuid          CHAR(36)      NOT NULL,
  season_number INT UNSIGNED  NOT NULL,
  current_tier  TINYINT       NOT NULL DEFAULT 1,
  peak_tier     TINYINT       NOT NULL DEFAULT 1,
  updated_at    DATETIME(3)   NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid, season_number),
  CONSTRAINT chk_tier_range CHECK (current_tier BETWEEN 1 AND 8 AND peak_tier BETWEEN 1 AND 8),
  CONSTRAINT fk_sts_player FOREIGN KEY (uuid) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
