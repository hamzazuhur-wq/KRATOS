-- KRATOS Phase 2 — Migration 0027: Database Foundation & Data Model Normalization
-- Completes core entity foundation:
-- 1. auth.users <-> public.users auto-provisioning trigger & default Life Areas
-- 2. Tasks: adds missing direct life_area_id foreign key
-- 3. Projects: adds missing completed_at timestamp
-- 4. Decisions: first-class entity for tracking commitments, resolutions, and outcomes
-- 5. Activity Events: generic lifecycle event stream foundation for analytics & audit
-- Invariant #15: RLS enforced on all tables, auth.uid() = owner_id isolation.

BEGIN;

-- ── 1. Default Life Areas Provisioner & Auth User Trigger ─────────────────────
CREATE OR REPLACE FUNCTION public.ensure_default_life_areas(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.life_areas
    WHERE owner_id = p_user_id AND deleted_at IS NULL
  ) THEN
    INSERT INTO public.life_areas (
      id, owner_id, name, description, color, icon, sort_order, version_hlc, created_at, updated_at
    )
    VALUES
      (gen_random_uuid(), p_user_id, 'Professional', 'Career, craft, and mission', '#3B82F6', 'work', 1, '0', NOW(), NOW()),
      (gen_random_uuid(), p_user_id, 'Mindset', 'Clarity, discipline, and mental fortitude', '#8B5CF6', 'psychology', 2, '0', NOW(), NOW()),
      (gen_random_uuid(), p_user_id, 'Sport', 'Physical health, stamina, and vitality', '#C6F135', 'fitness_center', 3, '0', NOW(), NOW()),
      (gen_random_uuid(), p_user_id, 'Finance', 'Capital, investments, and wealth systems', '#10B981', 'account_balance', 4, '0', NOW(), NOW()),
      (gen_random_uuid(), p_user_id, 'Learning', 'Intellectual depth, mastery, and research', '#F59E0B', 'school', 5, '0', NOW(), NOW()),
      (gen_random_uuid(), p_user_id, 'Relationships', 'Family, alliance, and social circle', '#EC4899', 'favorite', 6, '0', NOW(), NOW())
    ON CONFLICT DO NOTHING;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, device_id, display_name, timezone, created_at, updated_at)
  VALUES (
    NEW.id,
    gen_random_uuid(),
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      split_part(COALESCE(NEW.email, 'user'), '@', 1)
    ),
    COALESCE(NEW.raw_user_meta_data->>'timezone', 'UTC'),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    display_name = COALESCE(EXCLUDED.display_name, public.users.display_name),
    updated_at = NOW();

  PERFORM public.ensure_default_life_areas(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ── 2. Tasks Table Enhancement (Direct Life Area Relationship) ────────────────
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS life_area_id uuid REFERENCES public.life_areas(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_life_area ON public.tasks (life_area_id);

-- ── 3. Projects Table Enhancement (completed_at lifecycle timestamp) ──────────
ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS completed_at timestamptz;
CREATE INDEX IF NOT EXISTS idx_projects_completed_at ON public.projects (completed_at);

-- ── 4. Decisions Entity ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.decisions (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title         text NOT NULL,
  content       text,
  status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'cancelled', 'archived', 'deleted')),
  goal_id       uuid REFERENCES public.goals(id) ON DELETE SET NULL,
  project_id    uuid REFERENCES public.projects(id) ON DELETE SET NULL,
  life_area_id  uuid REFERENCES public.life_areas(id) ON DELETE SET NULL,
  category_id   uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  resolved_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT decisions_title_not_blank CHECK (length(btrim(title)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_decisions_owner ON public.decisions (owner_id);
CREATE INDEX IF NOT EXISTS idx_decisions_status ON public.decisions (status);
CREATE INDEX IF NOT EXISTS idx_decisions_goal ON public.decisions (goal_id);
CREATE INDEX IF NOT EXISTS idx_decisions_project ON public.decisions (project_id);
CREATE INDEX IF NOT EXISTS idx_decisions_life_area ON public.decisions (life_area_id);
CREATE INDEX IF NOT EXISTS idx_decisions_resolved_at ON public.decisions (resolved_at);

ALTER TABLE public.decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.decisions FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "decisions_select_owner" ON public.decisions;
CREATE POLICY "decisions_select_owner" ON public.decisions FOR SELECT TO authenticated
  USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "decisions_insert_owner" ON public.decisions;
CREATE POLICY "decisions_insert_owner" ON public.decisions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "decisions_update_owner" ON public.decisions;
CREATE POLICY "decisions_update_owner" ON public.decisions FOR UPDATE TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "decisions_delete_owner" ON public.decisions;
CREATE POLICY "decisions_delete_owner" ON public.decisions FOR DELETE TO authenticated
  USING (auth.uid() = owner_id);

-- ── 5. Activity Events (Generic Lifecycle Event Stream Foundation) ─────────────
CREATE TABLE IF NOT EXISTS public.activity_events (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type    text NOT NULL,
  entity_type   text NOT NULL,
  entity_id     uuid,
  life_area_id  uuid REFERENCES public.life_areas(id) ON DELETE SET NULL,
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_events_owner_occurred ON public.activity_events (owner_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_events_entity ON public.activity_events (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_events_type ON public.activity_events (event_type);
CREATE INDEX IF NOT EXISTS idx_activity_events_life_area ON public.activity_events (life_area_id);

ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_events FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "activity_events_select_owner" ON public.activity_events;
CREATE POLICY "activity_events_select_owner" ON public.activity_events FOR SELECT TO authenticated
  USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "activity_events_insert_owner" ON public.activity_events;
CREATE POLICY "activity_events_insert_owner" ON public.activity_events FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "activity_events_update_owner" ON public.activity_events;
CREATE POLICY "activity_events_update_owner" ON public.activity_events FOR UPDATE TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "activity_events_delete_owner" ON public.activity_events;
CREATE POLICY "activity_events_delete_owner" ON public.activity_events FOR DELETE TO authenticated
  USING (auth.uid() = owner_id);

COMMIT;
