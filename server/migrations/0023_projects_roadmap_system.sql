-- 0023_projects_roadmap_system.sql
-- KRATOS Projects workspace & Roadmap Phases system
-- Extends projects with difficulty, level link, cover image, and progress.
-- Adds project_phases table, links tasks to phases, activities to projects,
-- and allows 'note' in attachment_links.

BEGIN;

-- 1. Extend projects table
ALTER TABLE projects ADD COLUMN IF NOT EXISTS difficulty integer NOT NULL DEFAULT 1;
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_difficulty_check;
ALTER TABLE projects ADD CONSTRAINT projects_difficulty_check CHECK (difficulty BETWEEN 1 AND 10);

ALTER TABLE projects ADD COLUMN IF NOT EXISTS level_id integer;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS cover_image_path text;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS progress real NOT NULL DEFAULT 0.0;
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_progress_check;
ALTER TABLE projects ADD CONSTRAINT projects_progress_check CHECK (progress >= 0.0 AND progress <= 100.0);

-- 2. Project Phases table
CREATE TABLE IF NOT EXISTS project_phases (
  id            uuid PRIMARY KEY,
  project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  sort_order    integer NOT NULL DEFAULT 0,
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
  progress      real NOT NULL DEFAULT 0.0 CHECK (progress >= 0.0 AND progress <= 100.0),
  completed_at  timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT project_phases_name_not_blank CHECK (length(btrim(name)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_project_phases_project_sort
  ON project_phases (project_id, sort_order) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_project_phases_status
  ON project_phases (project_id, status);

-- 3. Link tasks to Roadmap Phases
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS phase_id uuid REFERENCES project_phases(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_phase ON tasks (phase_id);

-- 4. Link activities to Projects
ALTER TABLE activities ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES projects(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_activities_project ON activities (project_id);

-- 5. Extend files with filename metadata
ALTER TABLE files ADD COLUMN IF NOT EXISTS filename text;

-- 6. Support 'note' in attachment_links
ALTER TABLE attachment_links DROP CONSTRAINT IF EXISTS attachment_links_attachment_kind_check;
ALTER TABLE attachment_links ADD CONSTRAINT attachment_links_attachment_kind_check
  CHECK (attachment_kind IN ('file', 'link', 'skill', 'note'));

-- 7. RLS for project_phases
ALTER TABLE project_phases ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_phases FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "project_phases_select_owner" ON project_phases;
CREATE POLICY "project_phases_select_owner" ON project_phases FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_phases.project_id AND p.owner_id = (select auth.uid())
  ));

DROP POLICY IF EXISTS "project_phases_insert_owner" ON project_phases;
CREATE POLICY "project_phases_insert_owner" ON project_phases FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_phases.project_id AND p.owner_id = (select auth.uid())
  ));

DROP POLICY IF EXISTS "project_phases_update_owner" ON project_phases;
CREATE POLICY "project_phases_update_owner" ON project_phases FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_phases.project_id AND p.owner_id = (select auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_phases.project_id AND p.owner_id = (select auth.uid())
  ));

DROP POLICY IF EXISTS "project_phases_delete_owner" ON project_phases;
CREATE POLICY "project_phases_delete_owner" ON project_phases FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM projects p
    WHERE p.id = project_phases.project_id AND p.owner_id = (select auth.uid())
  ));

COMMIT;
