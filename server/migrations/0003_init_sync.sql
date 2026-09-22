-- KRATOS Wave 2 — Migration 0003: Sync subsystem
-- Architecture refs: 04-sync-architecture.md (transactional outbox, HLC, tombstones)
-- Decisions: outbox FIFO by seq (parent rows before children), idempotency on xp events,
--            tombstone_wins conflict strategy (ADR-008), field-level LWW (invariant 10)

BEGIN;

-- ── sync_outbox ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_outbox (
  seq               bigserial PRIMARY KEY,          -- FIFO drain order
  user_id           uuid NOT NULL REFERENCES users(id),
  op                text NOT NULL CHECK (op IN ('insert','update','delete','upsert','xp_event','restore')),
  entity            text NOT NULL,                  -- 'tasks','goals','xp_ledger','tombstones',...
  entity_id         text NOT NULL,                  -- UUID v7 of the affected row
  payload_json      jsonb NOT NULL,                 -- exact wire body serialized at write time
  hlc               text NOT NULL,                  -- HLC stamp (16-byte binary in PG; TEXT in Drift)
  device_id         uuid NOT NULL,
  idempotency_key   uuid,                           -- required for xp_event ops only
  attempts          integer NOT NULL DEFAULT 0,
  last_error_class  text CHECK (last_error_class IN ('retryable','permanent')),
  last_error_code   text,                           -- SQLSTATE / HTTP code
  status            text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','failed')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  next_attempt_at   timestamptz
);

CREATE INDEX IF NOT EXISTS idx_outbox_pending
  ON sync_outbox (user_id, seq) WHERE status = 'pending' AND (next_attempt_at IS NULL OR next_attempt_at <= now());

-- ── sync_cursors ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_cursors (
  user_id       uuid NOT NULL REFERENCES users(id),
  peer_id       uuid NOT NULL,                      -- device id of peer
  entity_kind   text NOT NULL,                      -- 'tasks','goals','xp_ledger',...
  last_applied_hlc text NOT NULL,                   -- HLC watermark
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, peer_id, entity_kind)
);

-- ── sync_tombstones ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sync_tombstones (
  id            uuid PRIMARY KEY,                   -- tombstone id (== entity_id)
  user_id       uuid NOT NULL REFERENCES users(id),
  entity        text NOT NULL,
  entity_id     uuid NOT NULL,                      -- deleted row id
  deleted_at    timestamptz NOT NULL,
  deleted_hlc   text NOT NULL,
  deleted_by    uuid,
  reason        text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, entity, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_tombstones_entity ON sync_tombstones (user_id, entity, entity_id);

COMMIT;