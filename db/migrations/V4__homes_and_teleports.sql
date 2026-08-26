-- V4__homes_and_teleports.sql
--
-- Section 15: homes up to 20, rename, home-to-home, with slots bought using Berries. Plus the
-- teleport guards 15.x requires, and the friends list from D-0035's new-feature set.
--
-- WHY HOME SLOTS ARE A COLUMN AND NOT A COUNT OF ROWS. The obvious design stores homes and
-- counts them against a limit derived from rank. That breaks the moment a player is demoted:
-- their 8th home would become invalid and either vanish or block a save. Storing the purchased
-- allowance separately means a slot bought with Berries is OWNED - demotion can take a tier,
-- it cannot take something that was paid for. Same principle as cosmetics_owned in Appendix D,
-- which is explicitly "never deleted by a reset".

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ---------------------------------------------------------------------------
-- homes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS homes (
  uuid        CHAR(36)     NOT NULL,
  name        VARCHAR(24)  NOT NULL COMMENT 'lowercased on write so "Base" and "base" are the same home rather than two',
  world       VARCHAR(48)  NOT NULL,
  x           DOUBLE       NOT NULL,
  y           DOUBLE       NOT NULL,
  z           DOUBLE       NOT NULL,
  yaw         FLOAT        NOT NULL DEFAULT 0 COMMENT 'stored so a player faces the way they were looking - a home that spins you round feels broken',
  pitch       FLOAT        NOT NULL DEFAULT 0,
  created_at  DATETIME(3)  NOT NULL COMMENT 'UTC',
  updated_at  DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid, name),
  KEY idx_homes_world (world) COMMENT 'so a world deletion can find the homes it would orphan - the resource world resets monthly',
  CONSTRAINT fk_homes_player FOREIGN KEY (uuid) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- home_slots - the purchased allowance, owned permanently
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS home_slots (
  uuid            CHAR(36)     NOT NULL,
  purchased_slots INT          NOT NULL DEFAULT 0 COMMENT 'bought with Berries. Never revoked, never reset - a slot paid for is owned (see the header note)',
  total_spent     BIGINT       NOT NULL DEFAULT 0 COMMENT 'for the ledger cross-check and for a refund conversation',
  updated_at      DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid),
  -- 15.x caps homes at 20; 2 are free, so at most 18 can ever be bought.
  -- NOTE: MariaDB does not accept COMMENT on a CHECK constraint - it parses as a syntax
  -- error, which is how this migration failed on its first attempt. The runner refused to
  -- record it, which is exactly what forward-only migrations must do with a failure.
  CONSTRAINT chk_slots_range CHECK (purchased_slots BETWEEN 0 AND 18),
  CONSTRAINT fk_slots_player FOREIGN KEY (uuid) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- friends - mutual, and stored once rather than twice
-- ---------------------------------------------------------------------------
-- The pair is stored with the LOWER uuid first and a CHECK enforcing it. Storing both
-- directions is the usual approach and it is worse: two rows can disagree, and "are we
-- friends" becomes a question with two possible answers. One canonical row cannot disagree
-- with itself.
CREATE TABLE IF NOT EXISTS friends (
  uuid_low    CHAR(36)     NOT NULL,
  uuid_high   CHAR(36)     NOT NULL,
  requested_by CHAR(36)    NOT NULL COMMENT 'who asked - needed to show a pending request to the right person',
  state       ENUM('pending','accepted') NOT NULL DEFAULT 'pending',
  created_at  DATETIME(3)  NOT NULL COMMENT 'UTC',
  updated_at  DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid_low, uuid_high),
  KEY idx_friends_state (state),
  -- The canonical ordering (uuid_low < uuid_high) is enforced in APPLICATION CODE, not here.
  -- MariaDB rejects a CHECK that compares two columns in this position with
  -- ERROR 1901: Function or expression 'uuid_low' cannot be used in the CHECK clause.
  -- That is a real limitation rather than a preference, so the invariant lives in one place
  -- instead of two - and it is stated here so the next person does not assume the database
  -- is guarding it. Everything that writes this table must order the pair first.
  CONSTRAINT fk_friend_low  FOREIGN KEY (uuid_low)  REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_friend_high FOREIGN KEY (uuid_high) REFERENCES players (uuid)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
