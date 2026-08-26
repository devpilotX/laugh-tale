-- V6 - roleplay: Paths, Houses and Chronicles. See docs/roleplay-design.md.
--
-- THE RULE THIS SCHEMA ENFORCES: roleplay grants STATUS, never POWER.
--
-- There is deliberately no column anywhere in this migration for damage, health, speed, drop rate,
-- reach, discount or permission. That is not an omission to be filled in later - it is the design.
-- A Path level that made a player stronger would break Law 1's total equality and violate acceptance
-- row 30, which requires that two hours of mining change combat rating by EXACTLY ZERO. It would also
-- make the PvP ladder measure who ground a profession rather than who fought better.
--
-- The Champion title already works this way (9.6: a prefix, a crown, a Hall of Fame entry, and
-- explicitly no Berries, items, gear, stats, permissions or discounts) and is valuable precisely
-- BECAUSE it buys nothing. This whole system is that insight scaled up.
--
-- WHAT SURVIVES A SEASON RESET: Path levels, House membership, unlocked titles and cosmetics. These
-- are identity, and 31.x is explicit that identity is not deleted by a reset. What resets is seasonal
-- HOUSE STANDING, because that is a competition, and a competition that never restarts is a museum.
--
-- COLLATE IS EXPLICIT on every table. Without it these take the server default while players.uuid is
-- utf8mb4_unicode_ci, and a foreign key across two collations fails with the famously unhelpful
-- "errno: 150 Foreign key constraint is incorrectly formed". V5 hit exactly that.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ---------------------------------------------------------------------------
-- paths - the personal ladder
-- ---------------------------------------------------------------------------
-- One row per player per Path. Six Paths, all levelling independently, so something is always moving
-- for everyone regardless of how they play.
CREATE TABLE IF NOT EXISTS paths (
  uuid       CHAR(36)        NOT NULL,
  path       ENUM('delver','cultivator','hunter','wayfinder','artificer','broker') NOT NULL,
  xp         BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'lifetime, never reset - this is identity, not a competition',
  level      INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT 'derived from xp, stored so the HUD and leaderboards do not recompute a curve per render',
  created_at DATETIME(3)     NOT NULL COMMENT 'UTC',
  updated_at DATETIME(3)     NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid, path),
  KEY idx_path_level (path, level DESC),
  CONSTRAINT fk_path_player FOREIGN KEY (uuid) REFERENCES players (uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- houses - the group identity
-- ---------------------------------------------------------------------------
-- Four Houses, fixed by the server rather than player-created. Player-created factions need land
-- claims, war declarations and taxes; taxes would create a second economy alongside the Berry ledger,
-- which is the same mistake as the shard shop refused in D-0035.
CREATE TABLE IF NOT EXISTS houses (
  house       ENUM('ember','tide','verdant','ashen') NOT NULL,
  display     VARCHAR(32)   NOT NULL,
  motto       VARCHAR(128)  NOT NULL,
  colour      VARCHAR(7)    NOT NULL COMMENT 'hex, for banners and name colours',
  created_at  DATETIME(3)   NOT NULL COMMENT 'UTC',
  PRIMARY KEY (house)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS house_members (
  uuid        CHAR(36)     NOT NULL,
  house       ENUM('ember','tide','verdant','ashen') NOT NULL,
  joined_at   DATETIME(3)  NOT NULL COMMENT 'UTC',
  changes     INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'how many times they have switched. Switching is meant to be rare, and a counter makes that enforceable without deleting history',
  PRIMARY KEY (uuid),
  KEY idx_house (house),
  CONSTRAINT fk_hm_player FOREIGN KEY (uuid)  REFERENCES players (uuid),
  CONSTRAINT fk_hm_house  FOREIGN KEY (house) REFERENCES houses (house)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seasonal standing. Reset per season BY DESIGN - a competition that never restarts is a museum.
CREATE TABLE IF NOT EXISTS house_standing (
  season_number INT UNSIGNED NOT NULL,
  house         ENUM('ember','tide','verdant','ashen') NOT NULL,
  points        BIGINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at    DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (season_number, house),
  CONSTRAINT fk_hs_house FOREIGN KEY (house) REFERENCES houses (house)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- chronicles - the server-wide story
-- ---------------------------------------------------------------------------
-- Progress is SERVER-WIDE, not per player. That makes strangers cooperate without a party system, it
-- costs almost nothing to compute, and it avoids the NPCs, dialogue trees and per-player quest state
-- machines that make roleplay plugins expensive - none of which fit in the memory this box has.
CREATE TABLE IF NOT EXISTS chronicle_chapters (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  season_number INT UNSIGNED  NOT NULL,
  chapter       INT UNSIGNED  NOT NULL,
  title         VARCHAR(96)   NOT NULL,
  narrative     TEXT          NOT NULL COMMENT 'what players are told. The reason anyone cares',
  state         ENUM('locked','active','complete') NOT NULL DEFAULT 'locked',
  started_at    DATETIME(3)       NULL COMMENT 'UTC',
  completed_at  DATETIME(3)       NULL COMMENT 'UTC',
  PRIMARY KEY (id),
  UNIQUE KEY uq_chapter (season_number, chapter),
  KEY idx_chapter_state (state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chronicle_objectives (
  id          INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  chapter_id  INT UNSIGNED  NOT NULL,
  description VARCHAR(128)  NOT NULL,
  metric      VARCHAR(48)   NOT NULL COMMENT 'which counter advances it, e.g. blocks_mined or mob_kills',
  target      BIGINT UNSIGNED NOT NULL,
  progress    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_obj_chapter (chapter_id),
  CONSTRAINT fk_obj_chapter FOREIGN KEY (chapter_id) REFERENCES chronicle_chapters (id) ON DELETE CASCADE,
  CONSTRAINT chk_obj_target CHECK (target > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- titles - everything the system actually awards
-- ---------------------------------------------------------------------------
-- The complete reward surface. Note what a title row can hold: text and a colour. There is nowhere to
-- put a bonus even if someone later wanted to add one, which is the point - the schema makes the rule
-- structural rather than a promise in a comment.
CREATE TABLE IF NOT EXISTS titles_owned (
  uuid        CHAR(36)     NOT NULL,
  title_key   VARCHAR(48)  NOT NULL COMMENT 'stable identifier, e.g. path.delver.10',
  display     VARCHAR(48)  NOT NULL COMMENT 'what players see',
  colour      VARCHAR(7)   NOT NULL,
  source      VARCHAR(32)  NOT NULL COMMENT 'path, house, chronicle, champion - so provenance is auditable',
  earned_at   DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid, title_key),
  KEY idx_title_source (source),
  CONSTRAINT fk_title_player FOREIGN KEY (uuid) REFERENCES players (uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which title a player is currently wearing, and which Path the HUD shows.
CREATE TABLE IF NOT EXISTS player_identity (
  uuid          CHAR(36)     NOT NULL,
  active_title  VARCHAR(48)      NULL,
  active_path   ENUM('delver','cultivator','hunter','wayfinder','artificer','broker') NULL,
  updated_at    DATETIME(3)  NOT NULL COMMENT 'UTC',
  PRIMARY KEY (uuid),
  CONSTRAINT fk_identity_player FOREIGN KEY (uuid) REFERENCES players (uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- the four Houses
-- ---------------------------------------------------------------------------
INSERT INTO houses (house, display, motto, colour, created_at) VALUES
  ('ember',   'House Ember',   'What burns, forges.',        '#E25822', UTC_TIMESTAMP(3)),
  ('tide',    'House Tide',    'Patience wears the stone.',  '#2E86AB', UTC_TIMESTAMP(3)),
  ('verdant', 'House Verdant', 'We plant for those after.',  '#4C9A2A', UTC_TIMESTAMP(3)),
  ('ashen',   'House Ashen',   'From the quiet, everything.', '#8D8D92', UTC_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE display = VALUES(display);
