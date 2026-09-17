-- KRATOS Wave 2 — Migration 0004: Notes, Audio, Achievements, Evidence, AI, Files, Links, Attachments, Skills, Tools
-- Architecture refs: 04-architecture-synthesis.md §2.C (AI/audio/notes/achievement/evidence),
--                    §3.1 (files/links/attachment_links as the ONLY polymorphic edge — invariant 3/11),
--                    ADR-005 (Tools ≠ Skills), ADR-007 (4-table attachment model)

BEGIN;

-- ── notes (standalone) ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notes (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  body_text     text NOT NULL,
  body_markdown text,
  pinned        boolean NOT NULL DEFAULT false,
  archived_at   timestamptz,                        -- soft delete
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notes_owner ON notes (owner_id, pinned DESC, updated_at DESC);

-- ── audios (0..1 parents, both optional) ───────────────────────────────
CREATE TABLE IF NOT EXISTS audios (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  session_id    uuid REFERENCES sessions(id),
  task_id       uuid REFERENCES tasks(id),
  duration_ms   integer,
  mime          text,
  transcription_text text,
  transcription_status text DEFAULT 'pending'
                CHECK (transcription_status IN ('pending','processing','done','failed')),
  captured_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── achievements (projection of ledger; persists awarded_at) ───────────
CREATE TABLE IF NOT EXISTS achievements (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  kind          text NOT NULL,                      -- 'level_up','streak_7','goal_complete',...
  level         integer,
  awarded_at    timestamptz NOT NULL,
  xp_ledger_event_id uuid REFERENCES xp_ledger(id),
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── evidence (backing claims, e.g. GPS run file) ───────────────────────
CREATE TABLE IF NOT EXISTS evidence (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  claim_kind    text NOT NULL,                      -- 'completion','activity','custom'
  payload       jsonb NOT NULL DEFAULT '{}'::jsonb,
  captured_at   timestamptz NOT NULL,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── ai_artifacts (every AI call recorded — audit/replay) ───────────────
CREATE TABLE IF NOT EXISTS ai_artifacts (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  kind          text NOT NULL,                      -- 'context_bundle','suggest','command','audit'
  prompt        text,
  response      text,
  model         text,
  tokens_in     integer,
  tokens_out    integer,
  related_entity_id  uuid,                          -- polymorphic link target (soft)
  related_entity_kind text,                         -- 'task','goal',...
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_artifacts_owner ON ai_artifacts (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_artifacts_related ON ai_artifacts (related_entity_id, related_entity_kind);

-- ── files & links (distinct — invariant 11) ────────────────────────────
CREATE TABLE IF NOT EXISTS files (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  storage_key   text NOT NULL,                      -- path/object key in object storage
  mime          text,
  size_bytes    integer NOT NULL DEFAULT 0,
  sha256        text,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS links (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  url           text NOT NULL,
  title         text,
  description   text,
  favicon_url   text,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── attachment_links — the ONLY polymorphic edge (invariant 3/11) ──────
CREATE TABLE IF NOT EXISTS attachment_links (
  id              uuid PRIMARY KEY,
  attachment_id   uuid NOT NULL,                    -- files.id OR links.id
  attachment_kind text NOT NULL CHECK (attachment_kind IN ('file','link')),
  entity_id       uuid NOT NULL,                    -- any entity id
  entity_kind     text NOT NULL,                    -- 'task','goal','project','session','note',...
  version_hlc     text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (attachment_id, attachment_kind, entity_id, entity_kind)
);

CREATE INDEX IF NOT EXISTS idx_attachment_links_entity ON attachment_links (entity_id, entity_kind);
CREATE INDEX IF NOT EXISTS idx_attachment_links_attachment ON attachment_links (attachment_id, attachment_kind);

-- ── skills (independent of projects — invariant: destruction rule) ─────
CREATE TABLE IF NOT EXISTS skills (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  name          text NOT NULL,
  description   text,
  xp_total      integer NOT NULL DEFAULT 0,
  level         integer NOT NULL DEFAULT 1,
  icon          text,
  archived_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_skills_owner_name ON skills (owner_id, lower(name));

-- ── tools (≠ skills — ADR-005) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tools (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  name          text NOT NULL,
  description   text,
  tool_type     text NOT NULL DEFAULT 'app'
                CHECK (tool_type IN ('app','service','physical','digital')),
  archived_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tools_owner_name ON tools (owner_id, lower(name));

-- ── skill_tools (M:N — a tool develops skills) ─────────────────────────
CREATE TABLE IF NOT EXISTS skill_tools (
  skill_id      uuid NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  tool_id       uuid NOT NULL REFERENCES tools(id) ON DELETE CASCADE,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (skill_id, tool_id)
);

-- ── task_tool_links (M:N — tasks may use tools) ────────────────────────
CREATE TABLE IF NOT EXISTS task_tool_links (
  task_id       uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tool_id       uuid NOT NULL REFERENCES tools(id) ON DELETE CASCADE,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, tool_id)
);

CREATE INDEX IF NOT EXISTS idx_task_tool_links_tool ON task_tool_links (tool_id);

COMMIT;