-- KRATOS Wave 21 / Level 8 — Migration 0013: Collaborative Goals & Accountability Partners
-- Refs: 06-open-issues-research-C.md §B7, 09-IMPLEMENTATION-ROADMAP.md Wave 21
-- Enables sharing specific goals with an accountability partner or coach without exposing private personal ledger.

BEGIN;

CREATE TABLE IF NOT EXISTS shared_goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  partner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('viewer', 'accountability_partner', 'coach')),
  can_comment boolean NOT NULL DEFAULT true,
  can_verify boolean NOT NULL DEFAULT false,
  version_hlc text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_goal_partner UNIQUE (goal_id, partner_id)
);

CREATE TABLE IF NOT EXISTS goal_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body_text text NOT NULL,
  version_hlc text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_shared_goals_partner ON shared_goals (partner_id);
CREATE INDEX IF NOT EXISTS idx_goal_comments_goal ON goal_comments (goal_id, created_at);

-- RLS
ALTER TABLE shared_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_goals FORCE ROW LEVEL SECURITY;
ALTER TABLE goal_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_comments FORCE ROW LEVEL SECURITY;

-- Owner can CRUD their shared goals
CREATE POLICY "shared_goals_owner" ON shared_goals
  FOR ALL USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- Partner can read goals shared with them
CREATE POLICY "shared_goals_partner_read" ON shared_goals
  FOR SELECT USING (auth.uid() = partner_id);

-- Goal comments policies
CREATE POLICY "goal_comments_read" ON goal_comments
  FOR SELECT USING (
    auth.uid() = author_id OR
    EXISTS (SELECT 1 FROM goals WHERE id = goal_comments.goal_id AND owner_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM shared_goals WHERE goal_id = goal_comments.goal_id AND partner_id = auth.uid())
  );

CREATE POLICY "goal_comments_insert" ON goal_comments
  FOR INSERT WITH CHECK (
    auth.uid() = author_id AND (
      EXISTS (SELECT 1 FROM goals WHERE id = goal_comments.goal_id AND owner_id = auth.uid()) OR
      EXISTS (SELECT 1 FROM shared_goals WHERE goal_id = goal_comments.goal_id AND partner_id = auth.uid() AND can_comment = true)
    )
  );

COMMIT;
