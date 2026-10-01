-- KRATOS Skills system: groups, independent mastery, and Life Area links.
-- Existing skills/tools/attachment_links are extended; no duplicate Skill entity is created.

BEGIN;

CREATE TABLE IF NOT EXISTS skill_groups (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id),
  name          text NOT NULL,
  description   text,
  archived_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT skill_groups_name_not_blank CHECK (length(btrim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_skill_groups_owner_name
  ON skill_groups (owner_id, lower(name)) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_skill_groups_owner_active
  ON skill_groups (owner_id, archived_at, deleted_at);

ALTER TABLE skills ADD COLUMN IF NOT EXISTS group_id uuid REFERENCES skill_groups(id) ON DELETE SET NULL;
ALTER TABLE skills ADD COLUMN IF NOT EXISTS mastery_level integer NOT NULL DEFAULT 1;
ALTER TABLE skills DROP CONSTRAINT IF EXISTS skills_mastery_level_check;
ALTER TABLE skills ADD CONSTRAINT skills_mastery_level_check CHECK (mastery_level BETWEEN 1 AND 5);
CREATE INDEX IF NOT EXISTS idx_skills_owner_group ON skills (owner_id, group_id);
CREATE INDEX IF NOT EXISTS idx_skills_owner_mastery ON skills (owner_id, mastery_level);

-- A Skill may reference only a Group owned by the same user.
DROP POLICY IF EXISTS "skills_insert_owner" ON skills;
DROP POLICY IF EXISTS "skills_update_owner" ON skills;
CREATE POLICY "skills_insert_owner" ON skills FOR INSERT TO authenticated
  WITH CHECK (
    (select auth.uid()) = owner_id AND
    (group_id IS NULL OR EXISTS (
      SELECT 1 FROM skill_groups g
      WHERE g.id = group_id AND g.owner_id = (select auth.uid())
    ))
  );
CREATE POLICY "skills_update_owner" ON skills FOR UPDATE TO authenticated
  USING ((select auth.uid()) = owner_id)
  WITH CHECK (
    (select auth.uid()) = owner_id AND
    (group_id IS NULL OR EXISTS (
      SELECT 1 FROM skill_groups g
      WHERE g.id = group_id AND g.owner_id = (select auth.uid())
    ))
  );

-- The existing local relationship contract already uses attachment_links for
-- Skill edges. Extend the original file/link constraint without creating a
-- second polymorphic relationship table.
ALTER TABLE attachment_links DROP CONSTRAINT IF EXISTS attachment_links_attachment_kind_check;
ALTER TABLE attachment_links ADD CONSTRAINT attachment_links_attachment_kind_check
  CHECK (attachment_kind IN ('file', 'link', 'skill'));

CREATE TABLE IF NOT EXISTS skill_life_area_links (
  owner_id      uuid NOT NULL REFERENCES users(id),
  skill_id      uuid NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  life_area_id  uuid NOT NULL REFERENCES life_areas(id) ON DELETE CASCADE,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (skill_id, life_area_id)
);
CREATE INDEX IF NOT EXISTS idx_skill_life_area_links_owner ON skill_life_area_links (owner_id);
CREATE INDEX IF NOT EXISTS idx_skill_life_area_links_life_area ON skill_life_area_links (life_area_id);

ALTER TABLE skill_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE skill_groups FORCE ROW LEVEL SECURITY;
ALTER TABLE skill_life_area_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE skill_life_area_links FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE skill_groups, skill_life_area_links FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE skill_groups, skill_life_area_links TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE attachment_links TO authenticated;

CREATE POLICY skill_groups_select_owner ON skill_groups FOR SELECT TO authenticated
  USING ((select auth.uid()) = owner_id);
CREATE POLICY skill_groups_insert_owner ON skill_groups FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = owner_id);
CREATE POLICY skill_groups_update_owner ON skill_groups FOR UPDATE TO authenticated
  USING ((select auth.uid()) = owner_id) WITH CHECK ((select auth.uid()) = owner_id);
CREATE POLICY skill_groups_delete_owner ON skill_groups FOR DELETE TO authenticated
  USING ((select auth.uid()) = owner_id);

CREATE POLICY skill_life_area_links_select_owner ON skill_life_area_links FOR SELECT TO authenticated
  USING ((select auth.uid()) = owner_id);
CREATE POLICY skill_life_area_links_insert_owner ON skill_life_area_links FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = owner_id);
CREATE POLICY skill_life_area_links_update_owner ON skill_life_area_links FOR UPDATE TO authenticated
  USING ((select auth.uid()) = owner_id) WITH CHECK ((select auth.uid()) = owner_id);
CREATE POLICY skill_life_area_links_delete_owner ON skill_life_area_links FOR DELETE TO authenticated
  USING ((select auth.uid()) = owner_id);

-- Existing polymorphic attachment links are the established KRATOS relationship
-- contract for Goals/Projects/Tasks/Activities/Sessions. Restrict skill edges to
-- the owner of the referenced Skill without introducing a second edge system.
CREATE OR REPLACE FUNCTION public.skill_attachment_entity_owned(
  p_entity_id uuid,
  p_entity_kind text,
  p_owner_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT CASE p_entity_kind
    WHEN 'goal' THEN EXISTS (SELECT 1 FROM goals g WHERE g.id = p_entity_id AND g.owner_id = p_owner_id)
    WHEN 'project' THEN EXISTS (SELECT 1 FROM projects p WHERE p.id = p_entity_id AND p.owner_id = p_owner_id)
    WHEN 'task' THEN EXISTS (SELECT 1 FROM tasks t WHERE t.id = p_entity_id AND t.owner_id = p_owner_id)
    WHEN 'activity' THEN EXISTS (SELECT 1 FROM activities a WHERE a.id = p_entity_id AND a.owner_id = p_owner_id)
    WHEN 'session' THEN EXISTS (SELECT 1 FROM sessions s WHERE s.id = p_entity_id AND s.owner_id = p_owner_id)
    ELSE false
  END;
$$;

CREATE POLICY attachment_links_skill_select_owner ON attachment_links FOR SELECT TO authenticated
  USING (
    (attachment_kind = 'skill' AND EXISTS (
      SELECT 1 FROM skills s WHERE s.id = attachment_id AND s.owner_id = (select auth.uid())
    ) AND public.skill_attachment_entity_owned(entity_id, entity_kind, (select auth.uid()))) OR
    (attachment_kind = 'file' AND EXISTS (
      SELECT 1 FROM files f WHERE f.id = attachment_id AND f.owner_id = (select auth.uid())
    )) OR
    (attachment_kind = 'link' AND EXISTS (
      SELECT 1 FROM links l WHERE l.id = attachment_id AND l.owner_id = (select auth.uid())
    ))
  );
CREATE POLICY attachment_links_skill_insert_owner ON attachment_links FOR INSERT TO authenticated
  WITH CHECK (
    (attachment_kind = 'skill' AND EXISTS (
      SELECT 1 FROM skills s WHERE s.id = attachment_id AND s.owner_id = (select auth.uid())
    ) AND public.skill_attachment_entity_owned(entity_id, entity_kind, (select auth.uid()))) OR
    (attachment_kind = 'file' AND EXISTS (
      SELECT 1 FROM files f WHERE f.id = attachment_id AND f.owner_id = (select auth.uid())
    )) OR
    (attachment_kind = 'link' AND EXISTS (
      SELECT 1 FROM links l WHERE l.id = attachment_id AND l.owner_id = (select auth.uid())
    ))
  );
CREATE POLICY attachment_links_skill_update_owner ON attachment_links FOR UPDATE TO authenticated
  USING (
    (attachment_kind = 'skill' AND EXISTS (SELECT 1 FROM skills s WHERE s.id = attachment_id AND s.owner_id = (select auth.uid())) AND public.skill_attachment_entity_owned(entity_id, entity_kind, (select auth.uid()))) OR
    (attachment_kind = 'file' AND EXISTS (SELECT 1 FROM files f WHERE f.id = attachment_id AND f.owner_id = (select auth.uid()))) OR
    (attachment_kind = 'link' AND EXISTS (SELECT 1 FROM links l WHERE l.id = attachment_id AND l.owner_id = (select auth.uid())))
  )
  WITH CHECK (
    (attachment_kind = 'skill' AND EXISTS (SELECT 1 FROM skills s WHERE s.id = attachment_id AND s.owner_id = (select auth.uid())) AND public.skill_attachment_entity_owned(entity_id, entity_kind, (select auth.uid()))) OR
    (attachment_kind = 'file' AND EXISTS (SELECT 1 FROM files f WHERE f.id = attachment_id AND f.owner_id = (select auth.uid()))) OR
    (attachment_kind = 'link' AND EXISTS (SELECT 1 FROM links l WHERE l.id = attachment_id AND l.owner_id = (select auth.uid())))
  );
CREATE POLICY attachment_links_skill_delete_owner ON attachment_links FOR DELETE TO authenticated
  USING (
    (attachment_kind = 'skill' AND EXISTS (SELECT 1 FROM skills s WHERE s.id = attachment_id AND s.owner_id = (select auth.uid())) AND public.skill_attachment_entity_owned(entity_id, entity_kind, (select auth.uid()))) OR
    (attachment_kind = 'file' AND EXISTS (SELECT 1 FROM files f WHERE f.id = attachment_id AND f.owner_id = (select auth.uid()))) OR
    (attachment_kind = 'link' AND EXISTS (SELECT 1 FROM links l WHERE l.id = attachment_id AND l.owner_id = (select auth.uid())))
  );

COMMIT;
