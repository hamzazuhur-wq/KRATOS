-- KRATOS Wave 2 — Migration 0001: Core entities (users, life_areas, categories, goals, projects, tasks, activities, sessions)
-- Architecture refs: 03-id-and-database-architecture.md, 04-architecture-synthesis.md §1.A/§1.C/§1.G/§2.A
-- Decisions: UUID v7 (ADR-001), per-entity tables (ADR-002), task_goal_links junction (ADR-003),
--            categories 3-table split (ADR-004), recursive goals with path (ADR-008 → synthesis §1.G)

BEGIN;

-- ── users ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            uuid PRIMARY KEY,
  device_id     uuid NOT NULL,          -- generated once per install; sync source
  display_name  text,
  timezone      text NOT NULL DEFAULT 'UTC',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── life_areas ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS life_areas (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  name          text NOT NULL,
  description   text,
  color         text,                    -- hex string, presentation concern (no UI decision yet)
  icon          text,
  sort_order    integer NOT NULL DEFAULT 0,
  archived_at   timestamptz,             -- soft delete
  deleted_at    timestamptz,             -- tombstone
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,           -- HLC stamp (BYTEA 16 in PG; TEXT in Drift)
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── categories (3-table split — ADR-004 / synthesis §2.A) ──────────────
CREATE TABLE IF NOT EXISTS categories (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  name          text NOT NULL,
  base_xp       integer NOT NULL DEFAULT 0,
  is_immutable  boolean NOT NULL DEFAULT false,  -- ADR: categories are NOT immutable by default
  archived_at   timestamptz,
  sort_order    integer NOT NULL DEFAULT 0,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS category_actions (
  id            uuid PRIMARY KEY,
  category_id   uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  action_name   text NOT NULL,           -- 'summarize', 'apply', 'review', ...
  modifier_percent numeric(5,2) NOT NULL DEFAULT 0,   -- +0.25 = +25%
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_until timestamptz,           -- null = currently active
  version       integer NOT NULL DEFAULT 1,
  UNIQUE (category_id, action_name, version)
);

CREATE INDEX IF NOT EXISTS idx_category_actions_active
  ON category_actions (category_id, action_name)
  WHERE effective_until IS NULL;

CREATE TABLE IF NOT EXISTS category_xp_rule_versions (
  id            uuid PRIMARY KEY,
  category_id   uuid NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  snapshot      jsonb NOT NULL,          -- {base_xp, actions: [{name, modifier}]}
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_until timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── goals (recursive — synthesis §1.G) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS goals (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  parent_id     uuid REFERENCES goals(id),           -- null = root goal
  root_id       uuid NOT NULL REFERENCES goals(id),  -- self for roots
  path          text NOT NULL,            -- ltree in PG; '.'-delimited materialized path in Drift (ADR-008)
  depth         integer NOT NULL DEFAULT 0,
  title         text NOT NULL,
  description   text,
  life_area_id  uuid REFERENCES life_areas(id),      -- a goal belongs to ONE life area
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','archived','deleted')),
  xp_target     integer,
  progress      numeric(5,2) NOT NULL DEFAULT 0,
  progress_hlc  text,
  due_date      date,
  completed_at  timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT goals_path_wellformed CHECK (path <> '' AND path NOT LIKE '/%' AND path NOT LIKE '%/')
);

CREATE INDEX IF NOT EXISTS idx_goals_root ON goals (root_id);
CREATE INDEX IF NOT EXISTS idx_goals_parent ON goals (parent_id);
-- path_prefix index enables "all descendants of X" via path LIKE 'X.%'

-- ── projects ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  goal_id       uuid REFERENCES goals(id),
  life_area_id  uuid REFERENCES life_areas(id),
  title         text NOT NULL,
  description   text,
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','completed','archived','deleted')),
  due_date      date,
  member_ids    jsonb NOT NULL DEFAULT '[]'::jsonb,  -- array of user ids (single-tenant: self)
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_projects_goal ON projects (goal_id);
CREATE INDEX IF NOT EXISTS idx_projects_life_area ON projects (life_area_id);

-- ── tasks ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tasks (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  project_id    uuid REFERENCES projects(id),
  primary_goal_id uuid REFERENCES goals(id),   -- cached convenience; task_goal_links is source of truth (synthesis §1.C)
  title         text NOT NULL,
  notes         text,
  due_date      date,
  priority      integer NOT NULL DEFAULT 0,    -- 0..4
  status        text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled','deleted')),
  sort_order    integer NOT NULL DEFAULT 0,
  xp_reward     integer,                       -- manual reward; null = computed from category rules
  recurring_rule text,                         -- RFC 5545 RRULE string, null = none
  completed_at  timestamptz,
  completed_hlc text,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tasks_status_completed CHECK (status <> 'done' OR completed_at IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks (project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status);
CREATE INDEX IF NOT EXISTS idx_tasks_primary_goal ON tasks (primary_goal_id);

-- ── task_goal_links (M:N junction — ADR-003) ───────────────────────────
CREATE TABLE IF NOT EXISTS task_goal_links (
  task_id       uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  goal_id       uuid NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  role          text NOT NULL DEFAULT 'contributes_to'
                CHECK (role IN ('contributes_to','blocks','inspired_by','tracks')),
  sort_order    integer NOT NULL DEFAULT 0,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, goal_id)
);

CREATE INDEX IF NOT EXISTS idx_task_goal_links_goal ON task_goal_links (goal_id);

-- ── activities ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS activities (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  life_area_id  uuid REFERENCES life_areas(id),
  name          text NOT NULL,
  description   text,
  xp_rule       jsonb,                           -- {base_xp, per_unit, unit}
  archived_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── sessions (exactly one of {task, activity} may be set — synthesis §3.1) ──
CREATE TABLE IF NOT EXISTS sessions (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  task_id       uuid REFERENCES tasks(id),
  activity_id   uuid REFERENCES activities(id),
  started_at    timestamptz NOT NULL,
  ended_at      timestamptz,
  duration_ms   integer,
  note          text,
  life_area_id  uuid REFERENCES life_areas(id),
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sessions_parent_exactly_one CHECK (
    (task_id IS NOT NULL AND activity_id IS NULL) OR
    (task_id IS NULL AND activity_id IS NOT NULL) OR
    (task_id IS NULL AND activity_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_sessions_task ON sessions (task_id);
CREATE INDEX IF NOT EXISTS idx_sessions_activity ON sessions (activity_id);

COMMIT;