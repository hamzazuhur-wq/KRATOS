-- KRATOS Wave 2 — Migration 0002: XP Ledger subsystem
-- Architecture refs: 01-XP_Ledger_Architecture.md (ledger_schema, allocation_model, idempotency)
-- Decisions: append-only ledger, idempotency_key unique (synthesis invariant 2/4/5),
--            xp_allocation_lines SUM = 100%, streak tables are projections (invariant 8)

BEGIN;

-- ── xp_ledger ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS xp_ledger (
  id                    uuid PRIMARY KEY,          -- UUID v7, client-generated
  owner_id              uuid NOT NULL REFERENCES users(id),
  idempotency_key       uuid NOT NULL UNIQUE,      -- UUID v4, client-generated (ADR: unique)
  source_type           text NOT NULL CHECK (source_type IN
    ('task','goal','activity','session','skill','admin','reversal')),
  source_id             uuid NOT NULL,             -- id of the source entity
  action                text NOT NULL CHECK (action IN
    ('complete','milestone','session_complete','admin_adjust','undo','reversal','restore')),
  points                integer NOT NULL CHECK (points <> 0),
  base_points           integer,
  bonus_points          integer DEFAULT 0,
  late_penalty          integer DEFAULT 0,
  streak_bonus          integer DEFAULT 0,
  category_rule_version_id uuid REFERENCES category_xp_rule_versions(id),
  reversal_event_id     uuid REFERENCES xp_ledger(id),   -- set on corrective rows (append-only)
  version_hlc           text NOT NULL,
  device_id             uuid NOT NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  -- no updated_at — append-only invariant
  CONSTRAINT xp_ledger_points_match CHECK (points = COALESCE(base_points, 0) + COALESCE(bonus_points, 0) - COALESCE(late_penalty, 0) + COALESCE(streak_bonus, 0))
);

CREATE INDEX IF NOT EXISTS idx_xp_ledger_owner ON xp_ledger (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_xp_ledger_source ON xp_ledger (source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_xp_ledger_category_version ON xp_ledger (category_rule_version_id);

-- ── xp_allocation_lines ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS xp_allocation_lines (
  id            uuid PRIMARY KEY,                  -- UUID v7
  ledger_id     uuid NOT NULL REFERENCES xp_ledger(id) ON DELETE CASCADE,
  life_area_id  uuid NOT NULL REFERENCES life_areas(id),
  allocated_points integer NOT NULL CHECK (allocated_points > 0),
  percentage    numeric(5,2) NOT NULL CHECK (percentage > 0 AND percentage <= 100),
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xp_allocation_ledger ON xp_allocation_lines (ledger_id);
CREATE INDEX IF NOT EXISTS idx_xp_allocation_area ON xp_allocation_lines (life_area_id);

-- ── user_streaks (projection — invariant 8) ────────────────────────────
CREATE TABLE IF NOT EXISTS user_streaks (
  user_id           uuid PRIMARY KEY REFERENCES users(id),
  current_streak    integer NOT NULL DEFAULT 0,
  longest_streak    integer NOT NULL DEFAULT 0,
  last_active_date  date,
  last_active_hlc   text,
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ── streak_pauses (only streak table with direct writes) ───────────────
CREATE TABLE IF NOT EXISTS streak_pauses (
  id            uuid PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES users(id),
  reason        text,
  started_at    timestamptz NOT NULL,
  ended_at      timestamptz,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (started_at < COALESCE(ended_at, started_at + interval '1 day'))
);

COMMIT;