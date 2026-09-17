-- KRATOS Wave 2 — Migration 0005: Enable Row-Level Security
-- Refs: 03-id-and-database-architecture.md (RLS section), 06-DECISIONS-LOG.md ADR-002 (per-entity RLS)
-- Note: full policy bodies are Wave 8/10 scope; here we enable RLS + FORCE + deny-by-default,
--       which locks every table until granular policies are added.
-- NOTE: we use explicit ALTER TABLE statements (not a DO loop) so the verify_schema.py
--       tool can detect them with a simple text scan.

BEGIN;

-- 1. Enable + Force RLS on every KRATOS table (30 tables).
ALTER TABLE users                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE users                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE life_areas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE life_areas              FORCE  ROW LEVEL SECURITY;
ALTER TABLE categories              ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories              FORCE  ROW LEVEL SECURITY;
ALTER TABLE category_actions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_actions        FORCE  ROW LEVEL SECURITY;
ALTER TABLE category_xp_rule_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_xp_rule_versions FORCE  ROW LEVEL SECURITY;
ALTER TABLE goals                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE projects                ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects                FORCE  ROW LEVEL SECURITY;
ALTER TABLE tasks                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE task_goal_links         ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_goal_links         FORCE  ROW LEVEL SECURITY;
ALTER TABLE activities              ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities              FORCE  ROW LEVEL SECURITY;
ALTER TABLE sessions                ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions                FORCE  ROW LEVEL SECURITY;
ALTER TABLE xp_ledger               ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_ledger               FORCE  ROW LEVEL SECURITY;
ALTER TABLE xp_allocation_lines     ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_allocation_lines     FORCE  ROW LEVEL SECURITY;
ALTER TABLE user_streaks            ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_streaks            FORCE  ROW LEVEL SECURITY;
ALTER TABLE streak_pauses           ENABLE ROW LEVEL SECURITY;
ALTER TABLE streak_pauses           FORCE  ROW LEVEL SECURITY;
ALTER TABLE sync_outbox             ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_outbox             FORCE  ROW LEVEL SECURITY;
ALTER TABLE sync_cursors            ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_cursors            FORCE  ROW LEVEL SECURITY;
ALTER TABLE sync_tombstones         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_tombstones         FORCE  ROW LEVEL SECURITY;
ALTER TABLE notes                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE audios                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE audios                  FORCE  ROW LEVEL SECURITY;
ALTER TABLE achievements            ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements            FORCE  ROW LEVEL SECURITY;
ALTER TABLE evidence                ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence                FORCE  ROW LEVEL SECURITY;
ALTER TABLE ai_artifacts            ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_artifacts            FORCE  ROW LEVEL SECURITY;
ALTER TABLE files                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE files                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE links                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE links                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE attachment_links        ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachment_links        FORCE  ROW LEVEL SECURITY;
ALTER TABLE skills                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE skills                  FORCE  ROW LEVEL SECURITY;
ALTER TABLE tools                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tools                   FORCE  ROW LEVEL SECURITY;
ALTER TABLE skill_tools             ENABLE ROW LEVEL SECURITY;
ALTER TABLE skill_tools             FORCE  ROW LEVEL SECURITY;
ALTER TABLE task_tool_links         ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tool_links         FORCE  ROW LEVEL SECURITY;

-- 2. Guardian trigger: block any write to xp_ledger that bypasses the ledger service.
--    Enforced app-side invariant; DB-level guard remains as a second line of defence.
CREATE OR REPLACE FUNCTION guard_xp_ledger_direct_write()
RETURNS trigger AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND current_user = 'authenticated' THEN
    RAISE EXCEPTION 'direct write to xp_ledger denied: %', NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_xp_ledger
BEFORE INSERT OR UPDATE ON xp_ledger
FOR EACH ROW EXECUTE FUNCTION guard_xp_ledger_direct_write();

COMMIT;
