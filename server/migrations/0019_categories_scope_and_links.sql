-- KRATOS Wave 34 / Goals Feature — Migration 0019: Category scopes and entity category linkage
-- Architecture: ADR-004 categories split extended with taxonomy scope (life_area, goal, task, activity)
-- Invariant #15: RLS preserved on categories and entity tables

BEGIN;

-- 1. Extend categories with category_type and optional description
ALTER TABLE categories ADD COLUMN IF NOT EXISTS category_type text NOT NULL DEFAULT 'goal';
ALTER TABLE categories ADD COLUMN IF NOT EXISTS description text;

CREATE INDEX IF NOT EXISTS idx_categories_owner_type ON categories(owner_id, category_type) WHERE archived_at IS NULL;

-- 2. Link goals to categories
ALTER TABLE goals ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES categories(id);
CREATE INDEX IF NOT EXISTS idx_goals_category ON goals(category_id);

-- 3. Link tasks to categories
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES categories(id);
CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category_id);

-- 4. Link activities to categories
ALTER TABLE activities ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES categories(id);
CREATE INDEX IF NOT EXISTS idx_activities_category ON activities(category_id);

COMMIT;
