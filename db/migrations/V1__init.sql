-- V1__init.sql - LaughTail SMP initial schema
--
-- Appendix D: "Use schema migrations from the first commit. Never modify a live
-- schema by hand." Spec 5.2 names MariaDB. This file is FORWARD-ONLY: once it has
-- been applied anywhere, it is never edited. Corrections arrive as V2, V3, ...
-- scripts/remote/db-migrate.sh enforces that with a checksum.
--
-- SCOPE. This migration deliberately does NOT create all 23 Appendix D tables.
-- It creates the migration bookkeeping, the two tables Phase 0 and Phase 1 need,
-- and the season/champion pair. Each later phase adds its own tables in its own
-- migration, which is what forward-only migrations are for and what keeps the
-- schema reviewable. The economy tables in particular should not be guessed at
-- now: questions.md Q-10 records that the economy has no numbers anywhere in the
-- specification, and schema written against undecided mechanics gets rewritten.
--
-- The one exception is `champions`, created here even though seasons are Phase 4.
-- Acceptance row 36 requires "exactly one Champion per season" to be proven with
-- "schema plus failed-insert test" - a DATABASE CONSTRAINT, not application logic.
-- So the constraint is a Phase 0 artefact by the acceptance table's own wording.
--
-- CONVENTIONS, and why each was chosen:
--
-- UUIDs are CHAR(36) with an ascii_bin collation, not BINARY(16). BINARY(16) is
-- more compact and is the usual advice, but this server holds tens of players, not
-- millions, so the space saving is irrelevant while the debugging cost is real -
-- every manual query, every log line and every support conversation would need
-- hex conversion. ascii_bin gives exact, case-sensitive matching with no
-- collation surprises. Appendix D's rule is that tables key on UUID and never on
-- name; both representations satisfy it.
--
-- Timestamps are DATETIME(3), not TIMESTAMP. TIMESTAMP is stored as a 32-bit
-- offset and dies in 2038, and MariaDB silently converts it using the session
-- time zone, which means the same row reads differently from two connections.
-- Every value here is UTC by convention, stated in each column comment. 31.1 puts
-- the season reset on a clock, so an ambiguous instant is a real bug.
--
-- Money is BIGINT, never a float. Berries are integers; a floating-point balance
-- cannot be summed reliably and would break the arbitrage audit in Phase 3.
--
-- Engine is InnoDB throughout, because Appendix D requires that "every write that
-- spans two tables runs in a transaction" and only InnoDB gives that.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ---------------------------------------------------------------------------
-- schema_migrations - what has been applied, and proof it has not been edited
-- ---------------------------------------------------------------------------
-- Retention: permanent. One row per migration, forever. It is the audit trail.
CREATE TABLE IF NOT EXISTS schema_migrations (
  version        VARCHAR(20)   NOT NULL COMMENT 'V1, V2, ... sorts by numeric part',
  description    VARCHAR(200)  NOT NULL,
  checksum       CHAR(64)      NOT NULL COMMENT 'SHA-256 of the file as applied; a mismatch means someone edited an applied migration',
  applied_at     DATETIME(3)   NOT NULL COMMENT 'UTC',
  applied_by     VARCHAR(100)  NOT NULL COMMENT 'who or what ran it',
  duration_ms    INT UNSIGNED  NOT NULL,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- players - one row per human, keyed on Mojang UUID
-- ---------------------------------------------------------------------------
-- Retention: permanent while access exists. 31.13 governs deletion on request;
-- a deletion anonymises this row rather than removing it, so that transaction and
-- punishment history stays referentially intact.
CREATE TABLE IF NOT EXISTS players (
  uuid                   CHAR(36)     NOT NULL COMMENT 'Mojang UUID, dashed lowercase. Version 4 only: an offline-mode v3 UUID must never appear here (decision D-0017)',
  current_name           VARCHAR(16)  NOT NULL COMMENT 'Minecraft names are at most 16 chars. Cached for display ONLY - never key on it, players rename',
  first_join             DATETIME(3)  NOT NULL COMMENT 'UTC',
  last_seen              DATETIME(3)  NOT NULL COMMENT 'UTC',
  rules_version_accepted VARCHAR(20)       NULL COMMENT 'NULL = has not accepted. Acceptance row 17 requires the VERSION be stored, not just a boolean, so a rules change can re-gate everyone',
  rules_accepted_at      DATETIME(3)       NULL COMMENT 'UTC',
  first_ip_hash          CHAR(64)          NULL COMMENT 'SHA-256 of the IP, never the IP itself. Row 32 needs same-IP kill detection; that needs comparison, not readability. 31.13 governs retention',
  anonymised_at          DATETIME(3)       NULL COMMENT 'UTC. Set by a 31.13 deletion request; when set, current_name and first_ip_hash are scrubbed',
  created_at             DATETIME(3)  NOT NULL COMMENT 'UTC',
  updated_at             DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid),
  KEY idx_players_current_name (current_name) COMMENT 'for staff lookup by name; NOT a unique key, because a freed name can be taken by another account',
  KEY idx_players_last_seen (last_seen)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- access_grants - the paywall's memory. Why someone is allowed to connect
-- ---------------------------------------------------------------------------
-- Retention: permanent. A refund dispute six months later is settled from here,
-- so a revoked grant is marked revoked and never deleted.
--
-- expires_at is NULLABLE ON PURPOSE. Decision D-0002 and spec 24.1: the owner has
-- not chosen between one-time and recurring pricing. NULL means "never expires"
-- (one-time), a value means recurring. Both models are therefore already
-- supported and the pricing decision costs no schema change later.
CREATE TABLE IF NOT EXISTS access_grants (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uuid               CHAR(36)        NOT NULL COMMENT 'FK to players.uuid',
  source             VARCHAR(30)     NOT NULL COMMENT 'store, manual, founder, staff, compensation - how access was obtained. Row 12 audits the whitelist against paid transactions, so an unpaid grant must be explainable',
  transaction_ref    VARCHAR(120)         NULL COMMENT 'the store or payment provider reference. NULL only for non-purchase sources',
  amount_minor       BIGINT               NULL COMMENT 'amount actually paid, in the minor unit (paise). Integer, never a float',
  currency           CHAR(3)              NULL COMMENT 'ISO 4217, expected INR',
  granted_at         DATETIME(3)     NOT NULL COMMENT 'UTC',
  expires_at         DATETIME(3)          NULL COMMENT 'UTC. NULL = never expires; see the note above',
  revoked_at         DATETIME(3)          NULL COMMENT 'UTC. Set on refund or chargeback',
  revoked_reason     VARCHAR(200)         NULL,
  created_at         DATETIME(3)     NOT NULL COMMENT 'UTC',
  updated_at         DATETIME(3)     NOT NULL COMMENT 'UTC',
  PRIMARY KEY (id),
  UNIQUE KEY uq_access_transaction_ref (transaction_ref) COMMENT 'the same payment can never grant access twice - this is what makes the webhook safe to retry, and payment webhooks WILL be delivered more than once',
  KEY idx_access_uuid (uuid),
  KEY idx_access_active (uuid, revoked_at, expires_at) COMMENT 'the join-time question: does this player have a live grant',
  CONSTRAINT fk_access_player FOREIGN KEY (uuid) REFERENCES players (uuid) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- seasons - the monthly cycle
-- ---------------------------------------------------------------------------
-- Retention: permanent.
--
-- reset_completed exists because 31.1 and acceptance row 33 require the season
-- reset to be IDEMPOTENT and to survive interruption. A reset that crashes
-- halfway must be resumable, and that is impossible without a durable flag.
CREATE TABLE IF NOT EXISTS seasons (
  season_number     INT UNSIGNED  NOT NULL COMMENT 'monotonic from 1',
  starts_at         DATETIME(3)   NOT NULL COMMENT 'UTC',
  ends_at           DATETIME(3)   NOT NULL COMMENT 'UTC. 31.1 fixes the instant; storing it avoids recomputing it from a clock later',
  state             ENUM('pending','active','finale','resetting','archived') NOT NULL DEFAULT 'pending',
  reset_completed   TINYINT(1)    NOT NULL DEFAULT 0 COMMENT 'row 33: the reset must be idempotent, so it needs a durable did-this-finish flag',
  reset_started_at  DATETIME(3)        NULL COMMENT 'UTC',
  reset_finished_at DATETIME(3)        NULL COMMENT 'UTC',
  created_at        DATETIME(3)   NOT NULL COMMENT 'UTC',
  updated_at        DATETIME(3)   NOT NULL COMMENT 'UTC',
  PRIMARY KEY (season_number),
  KEY idx_seasons_state (state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- champions - exactly one per season, enforced by the DATABASE
-- ---------------------------------------------------------------------------
-- Retention: permanent. This is the Hall of Fame.
--
-- ACCEPTANCE ROW 36 IS THE REASON THIS TABLE EXISTS IN PHASE 0. It requires
-- "exactly one Champion per season", with evidence "schema plus failed-insert
-- test". So the guarantee must live in the schema: PRIMARY KEY on season_number
-- means a second champion for a season is rejected by MariaDB itself, and no
-- application bug, race condition or manual console command can produce two.
-- Application-level checking would satisfy the words and not the intent.
CREATE TABLE IF NOT EXISTS champions (
  season_number  INT UNSIGNED  NOT NULL COMMENT 'PRIMARY KEY: this IS the one-champion-per-season guarantee (row 36)',
  uuid           CHAR(36)      NOT NULL COMMENT 'FK to players.uuid',
  final_rp       INT           NOT NULL COMMENT 'rating at the moment of victory',
  awarded_at     DATETIME(3)   NOT NULL COMMENT 'UTC',
  created_at     DATETIME(3)   NOT NULL COMMENT 'UTC',
  PRIMARY KEY (season_number),
  KEY idx_champions_uuid (uuid),
  CONSTRAINT fk_champion_player FOREIGN KEY (uuid) REFERENCES players (uuid) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_champion_season FOREIGN KEY (season_number) REFERENCES seasons (season_number) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
