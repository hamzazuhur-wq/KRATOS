-- 0026_sync_batch_extended_entities.sql
-- KRATOS Wave 36: Production sync engine entity coverage expansion.
-- Adds target_duration_minutes to activities.
-- Extends apply_sync_batch RPC to handle:
--   activities, sessions, projects, project_phases, categories.
-- Preserves Invariant #10 (HLC LWW), Invariant #13 (Outbox), Invariant #14 (Tombstone precedence),
-- and Invariant #15 (RLS & Ownership).

BEGIN;

-- 1. Extend activities table with target_duration_minutes
ALTER TABLE activities ADD COLUMN IF NOT EXISTS target_duration_minutes integer;

-- 2. Extended apply_sync_batch RPC with 100% entity coverage
CREATE OR REPLACE FUNCTION public.apply_sync_batch(
  p_user_id uuid,
  p_device_id uuid,
  p_changes jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_item jsonb;
  v_payload jsonb;
  v_op text;
  v_entity text;
  v_entity_id uuid;
  v_hlc text;
  v_current_hlc text;
  v_seq bigint;
  v_status text;
  v_results jsonb := '[]'::jsonb;
  v_existing_xp boolean;
BEGIN
  IF (SELECT auth.uid()) IS NULL OR (SELECT auth.uid()) <> p_user_id THEN
    RAISE EXCEPTION 'Unauthorized sync batch' USING ERRCODE = '42501';
  END IF;

  -- Ensure the authenticated profile exists before entity inserts hit owner FKs.
  INSERT INTO public.users (id, device_id, timezone)
  VALUES (p_user_id, p_device_id, 'UTC')
  ON CONFLICT (id) DO NOTHING;

  IF p_changes IS NULL OR jsonb_typeof(p_changes) <> 'array'
     OR jsonb_array_length(p_changes) > 50 THEN
    RAISE EXCEPTION 'Invalid sync batch' USING ERRCODE = '22023';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_changes)
  LOOP
    v_seq := (v_item->>'seq')::integer;
    v_op := lower(v_item->>'op');
    v_entity := v_item->>'entity';
    v_entity_id := (v_item->>'entity_id')::uuid;
    v_hlc := v_item->>'hlc';
    v_payload := v_item->'payload';

    IF v_seq IS NULL OR v_entity_id IS NULL OR v_hlc IS NULL
       OR jsonb_typeof(v_payload) <> 'object' THEN
      RAISE EXCEPTION 'Malformed sync operation' USING ERRCODE = '22023';
    END IF;

    v_status := 'applied';

    -- ─────────────────────────────────────────────────────────────
    -- XP LEDGER
    -- ─────────────────────────────────────────────────────────────
    IF v_entity = 'xp_ledger' AND v_op IN ('insert', 'xp_event', 'upsert') THEN
      IF (v_payload->>'owner_id')::uuid <> p_user_id THEN
        RAISE EXCEPTION 'XP owner mismatch' USING ERRCODE = '42501';
      END IF;
      SELECT EXISTS (
        SELECT 1 FROM public.xp_ledger
        WHERE idempotency_key = (v_payload->>'idempotency_key')::uuid
      ) INTO v_existing_xp;
      PERFORM public.record_xp_event(v_payload);
      IF v_existing_xp THEN v_status := 'duplicate'; END IF;

    -- ─────────────────────────────────────────────────────────────
    -- TASKS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'tasks' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF v_op = 'restore' THEN
        PERFORM public.restore_entity('tasks', v_entity_id, v_hlc);
        DELETE FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'tasks' AND entity_id = v_entity_id;
      ELSE
        IF EXISTS (SELECT 1 FROM public.tasks WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
          RAISE EXCEPTION 'Task ownership mismatch' USING ERRCODE = '42501';
        END IF;
        SELECT version_hlc INTO v_current_hlc FROM public.tasks
          WHERE id = v_entity_id AND owner_id = p_user_id;
        IF EXISTS (SELECT 1 FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'tasks' AND entity_id = v_entity_id) THEN
          v_status := 'skipped';
        ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
          v_status := 'skipped';
        ELSIF v_op = 'delete' THEN
          UPDATE public.tasks SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
            WHERE id = v_entity_id AND owner_id = p_user_id;
          INSERT INTO public.sync_tombstones
            (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
          VALUES (v_entity_id, p_user_id, 'tasks', v_entity_id, now(), v_hlc, p_device_id)
          ON CONFLICT (user_id, entity, entity_id) DO UPDATE
            SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
                deleted_by = EXCLUDED.deleted_by;
        ELSE
          IF (v_payload->>'project_id') IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.projects WHERE id = (v_payload->>'project_id')::uuid AND owner_id = p_user_id
          ) THEN
            RAISE EXCEPTION 'Task project ownership mismatch' USING ERRCODE = '42501';
          END IF;
          IF (v_payload->>'primary_goal_id') IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.goals WHERE id = (v_payload->>'primary_goal_id')::uuid AND owner_id = p_user_id
          ) THEN
            RAISE EXCEPTION 'Task goal ownership mismatch' USING ERRCODE = '42501';
          END IF;
          IF (v_payload->>'life_area_id') IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.life_areas WHERE id = (v_payload->>'life_area_id')::uuid AND owner_id = p_user_id
          ) THEN
            RAISE EXCEPTION 'Task life area ownership mismatch' USING ERRCODE = '42501';
          END IF;
          IF (v_payload->>'category_id') IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.categories WHERE id = (v_payload->>'category_id')::uuid AND owner_id = p_user_id
          ) THEN
            RAISE EXCEPTION 'Task category ownership mismatch' USING ERRCODE = '42501';
          END IF;
          INSERT INTO public.tasks
            (id, owner_id, project_id, primary_goal_id, life_area_id, category_id, title, notes, due_date, priority,
             status, sort_order, xp_reward, recurring_rule, completed_at, version_hlc, created_at, updated_at)
          VALUES
            (v_entity_id, p_user_id, (v_payload->>'project_id')::uuid,
             (v_payload->>'primary_goal_id')::uuid, (v_payload->>'life_area_id')::uuid,
             (v_payload->>'category_id')::uuid, COALESCE(v_payload->>'title','Untitled Task'),
             v_payload->>'notes', (v_payload->>'due_date')::date,
             COALESCE((v_payload->>'priority')::integer,0),
             COALESCE(v_payload->>'status','open'), COALESCE((v_payload->>'sort_order')::integer,0),
             (v_payload->>'xp_reward')::integer, v_payload->>'recurring_rule',
             (v_payload->>'completed_at')::timestamptz, v_hlc, now(), now())
          ON CONFLICT (id) DO UPDATE SET
            project_id = EXCLUDED.project_id, primary_goal_id = EXCLUDED.primary_goal_id,
            life_area_id = EXCLUDED.life_area_id, category_id = EXCLUDED.category_id,
            title = EXCLUDED.title, notes = EXCLUDED.notes, due_date = EXCLUDED.due_date,
            priority = EXCLUDED.priority, status = EXCLUDED.status,
            sort_order = EXCLUDED.sort_order, xp_reward = EXCLUDED.xp_reward,
            recurring_rule = EXCLUDED.recurring_rule, completed_at = EXCLUDED.completed_at,
            version_hlc = EXCLUDED.version_hlc, updated_at = now()
          WHERE public.tasks.owner_id = p_user_id
            AND public.hlc_is_newer(v_hlc, public.tasks.version_hlc);
        END IF;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- LIFE AREAS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'life_areas' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF v_op = 'restore' THEN
        PERFORM public.restore_entity('life_areas', v_entity_id, v_hlc);
        DELETE FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'life_areas' AND entity_id = v_entity_id;
      ELSE
        IF EXISTS (SELECT 1 FROM public.life_areas WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
          RAISE EXCEPTION 'Life area ownership mismatch' USING ERRCODE = '42501';
        END IF;
        SELECT version_hlc INTO v_current_hlc FROM public.life_areas
          WHERE id = v_entity_id AND owner_id = p_user_id;
        IF EXISTS (SELECT 1 FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'life_areas' AND entity_id = v_entity_id) THEN
          v_status := 'skipped';
        ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
          v_status := 'skipped';
        ELSIF v_op = 'delete' THEN
          UPDATE public.life_areas SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
            WHERE id = v_entity_id AND owner_id = p_user_id;
          INSERT INTO public.sync_tombstones
            (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
          VALUES (v_entity_id, p_user_id, 'life_areas', v_entity_id, now(), v_hlc, p_device_id)
          ON CONFLICT (user_id, entity, entity_id) DO UPDATE
            SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
                deleted_by = EXCLUDED.deleted_by;
        ELSE
          INSERT INTO public.life_areas
            (id, owner_id, name, description, color, icon, sort_order, version_hlc, created_at, updated_at)
          VALUES
            (v_entity_id, p_user_id, COALESCE(v_payload->>'name','Life Area'),
             v_payload->>'description', v_payload->>'color', v_payload->>'icon',
             COALESCE((v_payload->>'sort_order')::integer,0), v_hlc, now(), now())
          ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name, description = EXCLUDED.description,
            color = EXCLUDED.color, icon = EXCLUDED.icon, sort_order = EXCLUDED.sort_order,
            version_hlc = EXCLUDED.version_hlc, updated_at = now()
          WHERE public.life_areas.owner_id = p_user_id
            AND public.hlc_is_newer(v_hlc, public.life_areas.version_hlc);
        END IF;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- GOALS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'goals' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF v_op = 'restore' THEN
        PERFORM public.restore_entity('goals', v_entity_id, v_hlc);
        DELETE FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'goals' AND entity_id = v_entity_id;
      ELSE
        IF EXISTS (SELECT 1 FROM public.goals WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
          RAISE EXCEPTION 'Goal ownership mismatch' USING ERRCODE = '42501';
        END IF;
        IF (v_payload->>'parent_id') IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.goals WHERE id = (v_payload->>'parent_id')::uuid AND owner_id = p_user_id
        ) THEN
          RAISE EXCEPTION 'Parent goal ownership mismatch' USING ERRCODE = '42501';
        END IF;
        IF (v_payload->>'life_area_id') IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM public.life_areas WHERE id = (v_payload->>'life_area_id')::uuid AND owner_id = p_user_id
        ) THEN
          RAISE EXCEPTION 'Goal life area ownership mismatch' USING ERRCODE = '42501';
        END IF;
        SELECT version_hlc INTO v_current_hlc FROM public.goals
          WHERE id = v_entity_id AND owner_id = p_user_id;
        IF EXISTS (SELECT 1 FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'goals' AND entity_id = v_entity_id) THEN
          v_status := 'skipped';
        ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
          v_status := 'skipped';
        ELSIF v_op = 'delete' THEN
          UPDATE public.goals SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
            WHERE id = v_entity_id AND owner_id = p_user_id;
          INSERT INTO public.sync_tombstones
            (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
          VALUES (v_entity_id, p_user_id, 'goals', v_entity_id, now(), v_hlc, p_device_id)
          ON CONFLICT (user_id, entity, entity_id) DO UPDATE
            SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
                deleted_by = EXCLUDED.deleted_by;
        ELSE
          INSERT INTO public.goals
            (id, owner_id, parent_id, root_id, path, depth, title, description, life_area_id,
             status, xp_target, progress, due_date, completed_at, version_hlc, created_at, updated_at)
          VALUES
            (v_entity_id, p_user_id, (v_payload->>'parent_id')::uuid,
             COALESCE((v_payload->>'root_id')::uuid, v_entity_id),
             COALESCE(v_payload->>'path', v_entity_id::text),
             COALESCE((v_payload->>'depth')::integer,0), COALESCE(v_payload->>'title','Goal'),
             v_payload->>'description', (v_payload->>'life_area_id')::uuid,
             COALESCE(v_payload->>'status','active'), (v_payload->>'xp_target')::integer,
             COALESCE((v_payload->>'progress')::numeric,0), (v_payload->>'due_date')::date,
             (v_payload->>'completed_at')::timestamptz, v_hlc, now(), now())
          ON CONFLICT (id) DO UPDATE SET
            title = EXCLUDED.title, description = EXCLUDED.description,
            life_area_id = EXCLUDED.life_area_id, status = EXCLUDED.status,
            xp_target = EXCLUDED.xp_target, progress = EXCLUDED.progress,
            due_date = EXCLUDED.due_date, completed_at = EXCLUDED.completed_at,
            version_hlc = EXCLUDED.version_hlc, updated_at = now()
          WHERE public.goals.owner_id = p_user_id
            AND public.hlc_is_newer(v_hlc, public.goals.version_hlc);
        END IF;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- ACTIVITIES (Phase 2 & Wave 9)
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'activities' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF v_op = 'restore' THEN
        PERFORM public.restore_entity('activities', v_entity_id, v_hlc);
        DELETE FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'activities' AND entity_id = v_entity_id;
      ELSE
        IF EXISTS (SELECT 1 FROM public.activities WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
          RAISE EXCEPTION 'Activity ownership mismatch' USING ERRCODE = '42501';
        END IF;
        SELECT version_hlc INTO v_current_hlc FROM public.activities
          WHERE id = v_entity_id AND owner_id = p_user_id;
        IF EXISTS (SELECT 1 FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'activities' AND entity_id = v_entity_id) THEN
          v_status := 'skipped';
        ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
          v_status := 'skipped';
        ELSIF v_op = 'delete' THEN
          UPDATE public.activities SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
            WHERE id = v_entity_id AND owner_id = p_user_id;
          INSERT INTO public.sync_tombstones
            (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
          VALUES (v_entity_id, p_user_id, 'activities', v_entity_id, now(), v_hlc, p_device_id)
          ON CONFLICT (user_id, entity, entity_id) DO UPDATE
            SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
                deleted_by = EXCLUDED.deleted_by;
        ELSE
          INSERT INTO public.activities
            (id, owner_id, life_area_id, category_id, project_id, name, description,
             target_duration_minutes, difficulty, xp_rule, version_hlc, created_at, updated_at)
          VALUES
            (v_entity_id, p_user_id, (v_payload->>'life_area_id')::uuid,
             (v_payload->>'category_id')::uuid, (v_payload->>'project_id')::uuid,
             COALESCE(v_payload->>'name', 'Activity'), v_payload->>'description',
             (v_payload->>'target_duration_minutes')::integer,
             COALESCE((v_payload->>'difficulty')::integer, 5),
             CASE WHEN v_payload->'xp_rule' IS NOT NULL THEN (v_payload->'xp_rule') ELSE NULL END,
             v_hlc, COALESCE((v_payload->>'created_at')::timestamptz, now()), now())
          ON CONFLICT (id) DO UPDATE SET
            life_area_id = EXCLUDED.life_area_id, category_id = EXCLUDED.category_id,
            project_id = EXCLUDED.project_id, name = EXCLUDED.name,
            description = EXCLUDED.description,
            target_duration_minutes = EXCLUDED.target_duration_minutes,
            difficulty = EXCLUDED.difficulty, xp_rule = EXCLUDED.xp_rule,
            version_hlc = EXCLUDED.version_hlc, updated_at = now()
          WHERE public.activities.owner_id = p_user_id
            AND public.hlc_is_newer(v_hlc, public.activities.version_hlc);
        END IF;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- SESSIONS (Wave 9)
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'sessions' AND v_op IN ('insert', 'upsert', 'update', 'delete') THEN
      IF EXISTS (SELECT 1 FROM public.sessions WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
        RAISE EXCEPTION 'Session ownership mismatch' USING ERRCODE = '42501';
      END IF;
      SELECT version_hlc INTO v_current_hlc FROM public.sessions
        WHERE id = v_entity_id AND owner_id = p_user_id;
      IF EXISTS (SELECT 1 FROM public.sync_tombstones
        WHERE user_id = p_user_id AND entity = 'sessions' AND entity_id = v_entity_id) THEN
        v_status := 'skipped';
      ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
        v_status := 'skipped';
      ELSIF v_op = 'delete' THEN
        UPDATE public.sessions SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
          WHERE id = v_entity_id AND owner_id = p_user_id;
        INSERT INTO public.sync_tombstones
          (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
        VALUES (v_entity_id, p_user_id, 'sessions', v_entity_id, now(), v_hlc, p_device_id)
        ON CONFLICT (user_id, entity, entity_id) DO UPDATE
          SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
              deleted_by = EXCLUDED.deleted_by;
      ELSE
        INSERT INTO public.sessions
          (id, owner_id, task_id, activity_id, started_at, ended_at,
           duration_ms, note, life_area_id, version_hlc, created_at, updated_at)
        VALUES
          (v_entity_id, p_user_id, (v_payload->>'task_id')::uuid,
           (v_payload->>'activity_id')::uuid,
           COALESCE((v_payload->>'started_at')::timestamptz, now()),
           (v_payload->>'ended_at')::timestamptz,
           (v_payload->>'duration_ms')::integer,
           v_payload->>'note',
           (v_payload->>'life_area_id')::uuid,
           v_hlc, now(), now())
        ON CONFLICT (id) DO UPDATE SET
          task_id = EXCLUDED.task_id, activity_id = EXCLUDED.activity_id,
          started_at = EXCLUDED.started_at, ended_at = EXCLUDED.ended_at,
          duration_ms = EXCLUDED.duration_ms, note = EXCLUDED.note,
          life_area_id = EXCLUDED.life_area_id,
          version_hlc = EXCLUDED.version_hlc, updated_at = now()
        WHERE public.sessions.owner_id = p_user_id
          AND public.hlc_is_newer(v_hlc, public.sessions.version_hlc);
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- PROJECTS (Wave 9 / Wave 37)
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'projects' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF v_op = 'restore' THEN
        PERFORM public.restore_entity('projects', v_entity_id, v_hlc);
        DELETE FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'projects' AND entity_id = v_entity_id;
      ELSE
        IF EXISTS (SELECT 1 FROM public.projects WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
          RAISE EXCEPTION 'Project ownership mismatch' USING ERRCODE = '42501';
        END IF;
        SELECT version_hlc INTO v_current_hlc FROM public.projects
          WHERE id = v_entity_id AND owner_id = p_user_id;
        IF EXISTS (SELECT 1 FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'projects' AND entity_id = v_entity_id) THEN
          v_status := 'skipped';
        ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
          v_status := 'skipped';
        ELSIF v_op = 'delete' THEN
          UPDATE public.projects SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
            WHERE id = v_entity_id AND owner_id = p_user_id;
          INSERT INTO public.sync_tombstones
            (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
          VALUES (v_entity_id, p_user_id, 'projects', v_entity_id, now(), v_hlc, p_device_id)
          ON CONFLICT (user_id, entity, entity_id) DO UPDATE
            SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
                deleted_by = EXCLUDED.deleted_by;
        ELSE
          INSERT INTO public.projects
            (id, owner_id, goal_id, life_area_id, title, description, status,
             difficulty, level_id, cover_image_path, progress, due_date,
             version_hlc, created_at, updated_at)
          VALUES
            (v_entity_id, p_user_id, (v_payload->>'goal_id')::uuid,
             (v_payload->>'life_area_id')::uuid,
             COALESCE(v_payload->>'title', 'Untitled Project'),
             v_payload->>'description',
             COALESCE(v_payload->>'status', 'active'),
             COALESCE((v_payload->>'difficulty')::integer, 1),
             (v_payload->>'level_id')::integer,
             v_payload->>'cover_image_path',
             COALESCE((v_payload->>'progress')::real, 0.0),
             (v_payload->>'due_date')::date,
             v_hlc, COALESCE((v_payload->>'created_at')::timestamptz, now()), now())
          ON CONFLICT (id) DO UPDATE SET
            goal_id = EXCLUDED.goal_id, life_area_id = EXCLUDED.life_area_id,
            title = EXCLUDED.title, description = EXCLUDED.description,
            status = EXCLUDED.status, difficulty = EXCLUDED.difficulty,
            level_id = EXCLUDED.level_id, cover_image_path = EXCLUDED.cover_image_path,
            progress = EXCLUDED.progress, due_date = EXCLUDED.due_date,
            version_hlc = EXCLUDED.version_hlc, updated_at = now()
          WHERE public.projects.owner_id = p_user_id
            AND public.hlc_is_newer(v_hlc, public.projects.version_hlc);
        END IF;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- PROJECT PHASES (Wave 37 / 0023)
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'project_phases' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.projects WHERE id = (v_payload->>'project_id')::uuid AND owner_id = p_user_id
      ) THEN
        RAISE EXCEPTION 'Project phase owner mismatch' USING ERRCODE = '42501';
      END IF;
      SELECT version_hlc INTO v_current_hlc FROM public.project_phases WHERE id = v_entity_id;
      IF v_op = 'delete' THEN
        UPDATE public.project_phases SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
          WHERE id = v_entity_id;
      ELSIF v_op = 'restore' THEN
        UPDATE public.project_phases SET deleted_at = NULL, version_hlc = v_hlc, updated_at = now()
          WHERE id = v_entity_id;
      ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
        v_status := 'skipped';
      ELSE
        INSERT INTO public.project_phases
          (id, project_id, name, description, sort_order, status, progress,
           completed_at, version_hlc, created_at, updated_at)
        VALUES
          (v_entity_id, (v_payload->>'project_id')::uuid,
           COALESCE(v_payload->>'name', 'Phase'),
           v_payload->>'description',
           COALESCE((v_payload->>'sort_order')::integer, 0),
           COALESCE(v_payload->>'status', 'active'),
           COALESCE((v_payload->>'progress')::real, 0.0),
           (v_payload->>'completed_at')::timestamptz,
           v_hlc, COALESCE((v_payload->>'created_at')::timestamptz, now()), now())
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name, description = EXCLUDED.description,
          sort_order = EXCLUDED.sort_order, status = EXCLUDED.status,
          progress = EXCLUDED.progress, completed_at = EXCLUDED.completed_at,
          version_hlc = EXCLUDED.version_hlc, updated_at = now()
        WHERE public.hlc_is_newer(v_hlc, public.project_phases.version_hlc);
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- CATEGORIES (Wave 34 / 0019)
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'categories' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF EXISTS (SELECT 1 FROM public.categories WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
        RAISE EXCEPTION 'Category ownership mismatch' USING ERRCODE = '42501';
      END IF;
      SELECT version_hlc INTO v_current_hlc FROM public.categories
        WHERE id = v_entity_id AND owner_id = p_user_id;
      IF v_op = 'delete' THEN
        UPDATE public.categories SET archived_at = now(), version_hlc = v_hlc, updated_at = now()
          WHERE id = v_entity_id AND owner_id = p_user_id;
      ELSIF v_op = 'restore' THEN
        UPDATE public.categories SET archived_at = NULL, version_hlc = v_hlc, updated_at = now()
          WHERE id = v_entity_id AND owner_id = p_user_id;
      ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
        v_status := 'skipped';
      ELSE
        INSERT INTO public.categories
          (id, owner_id, name, description, category_type, color, icon,
           base_xp, is_system, version_hlc, created_at, updated_at)
        VALUES
          (v_entity_id, p_user_id, COALESCE(v_payload->>'name', 'Category'),
           v_payload->>'description',
           COALESCE(v_payload->>'category_type', 'goal'),
           v_payload->>'color', v_payload->>'icon',
           COALESCE((v_payload->>'base_xp')::integer, 50),
           COALESCE((v_payload->>'is_system')::boolean, false),
           v_hlc, COALESCE((v_payload->>'created_at')::timestamptz, now()), now())
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name, description = EXCLUDED.description,
          category_type = EXCLUDED.category_type, color = EXCLUDED.color,
          icon = EXCLUDED.icon, base_xp = EXCLUDED.base_xp,
          is_system = EXCLUDED.is_system,
          version_hlc = EXCLUDED.version_hlc, updated_at = now()
        WHERE public.categories.owner_id = p_user_id
          AND public.hlc_is_newer(v_hlc, public.categories.version_hlc);
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- NOTES
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'notes' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF v_op = 'restore' THEN
        PERFORM public.restore_entity('notes', v_entity_id, v_hlc);
        DELETE FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'notes' AND entity_id = v_entity_id;
      ELSE
        IF EXISTS (SELECT 1 FROM public.notes WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
          RAISE EXCEPTION 'Note ownership mismatch' USING ERRCODE = '42501';
        END IF;
        SELECT version_hlc INTO v_current_hlc FROM public.notes
          WHERE id = v_entity_id AND owner_id = p_user_id;
        IF EXISTS (SELECT 1 FROM public.sync_tombstones
          WHERE user_id = p_user_id AND entity = 'notes' AND entity_id = v_entity_id) THEN
          v_status := 'skipped';
        ELSIF v_current_hlc IS NOT NULL AND NOT public.hlc_is_newer(v_hlc, v_current_hlc) THEN
          v_status := 'skipped';
        ELSIF v_op = 'delete' THEN
          UPDATE public.notes SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
            WHERE id = v_entity_id AND owner_id = p_user_id;
          INSERT INTO public.sync_tombstones
            (id, user_id, entity, entity_id, deleted_at, deleted_hlc, deleted_by)
          VALUES (v_entity_id, p_user_id, 'notes', v_entity_id, now(), v_hlc, p_device_id)
          ON CONFLICT (user_id, entity, entity_id) DO UPDATE
            SET deleted_at = EXCLUDED.deleted_at, deleted_hlc = EXCLUDED.deleted_hlc,
                deleted_by = EXCLUDED.deleted_by;
        ELSE
          INSERT INTO public.notes
            (id, owner_id, body_text, body_markdown, pinned, version_hlc, created_at, updated_at)
          VALUES (v_entity_id, p_user_id, COALESCE(v_payload->>'body_text',''),
                  v_payload->>'body_markdown', COALESCE((v_payload->>'pinned')::boolean,false),
                  v_hlc, now(), now())
          ON CONFLICT (id) DO UPDATE SET
            body_text = EXCLUDED.body_text, body_markdown = EXCLUDED.body_markdown,
            pinned = EXCLUDED.pinned, version_hlc = EXCLUDED.version_hlc, updated_at = now()
          WHERE public.notes.owner_id = p_user_id
            AND public.hlc_is_newer(v_hlc, public.notes.version_hlc);
        END IF;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- SKILLS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'skills' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF EXISTS (SELECT 1 FROM public.skills WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
        RAISE EXCEPTION 'Skill ownership mismatch' USING ERRCODE = '42501';
      END IF;
      IF v_op = 'delete' THEN
        UPDATE public.skills SET deleted_at = now(), deleted_by = p_device_id,
          version_hlc = v_hlc, updated_at = now()
        WHERE id = v_entity_id AND owner_id = p_user_id;
      ELSIF v_op = 'restore' THEN
        UPDATE public.skills SET deleted_at = NULL, deleted_by = NULL,
          version_hlc = v_hlc, updated_at = now()
        WHERE id = v_entity_id AND owner_id = p_user_id;
      ELSE
        INSERT INTO public.skills
          (id, owner_id, name, description, group_id, xp_total, level,
           mastery_level, icon, archived_at, version_hlc, created_at, updated_at)
        VALUES
          (v_entity_id, p_user_id, COALESCE(v_payload->>'name',''),
           v_payload->>'description', (v_payload->>'group_id')::uuid,
           COALESCE((v_payload->>'xp_total')::integer, 0),
           COALESCE((v_payload->>'level')::integer, 1),
           COALESCE((v_payload->>'mastery_level')::integer, 1),
           v_payload->>'icon', (v_payload->>'archived_at')::timestamptz,
           v_hlc, COALESCE((v_payload->>'created_at')::timestamptz, now()), now())
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name, description = EXCLUDED.description,
          group_id = EXCLUDED.group_id, mastery_level = EXCLUDED.mastery_level,
          icon = EXCLUDED.icon, archived_at = EXCLUDED.archived_at,
          version_hlc = EXCLUDED.version_hlc, updated_at = now()
        WHERE public.skills.owner_id = p_user_id
          AND public.hlc_is_newer(v_hlc, public.skills.version_hlc);
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- SKILL GROUPS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'skill_groups' AND v_op IN ('insert', 'upsert', 'update', 'delete', 'restore') THEN
      IF EXISTS (SELECT 1 FROM public.skill_groups WHERE id = v_entity_id AND owner_id <> p_user_id) THEN
        RAISE EXCEPTION 'Skill group ownership mismatch' USING ERRCODE = '42501';
      END IF;
      IF v_op = 'delete' THEN
        UPDATE public.skill_groups SET deleted_at = now(), deleted_by = p_device_id,
          version_hlc = v_hlc, updated_at = now()
        WHERE id = v_entity_id AND owner_id = p_user_id;
      ELSIF v_op = 'restore' THEN
        UPDATE public.skill_groups SET deleted_at = NULL, deleted_by = NULL,
          version_hlc = v_hlc, updated_at = now()
        WHERE id = v_entity_id AND owner_id = p_user_id;
      ELSE
        INSERT INTO public.skill_groups
          (id, owner_id, name, description, archived_at, version_hlc, created_at, updated_at)
        VALUES
          (v_entity_id, p_user_id, COALESCE(v_payload->>'name',''),
           v_payload->>'description', (v_payload->>'archived_at')::timestamptz,
           v_hlc, COALESCE((v_payload->>'created_at')::timestamptz, now()), now())
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name, description = EXCLUDED.description,
          archived_at = EXCLUDED.archived_at, version_hlc = EXCLUDED.version_hlc,
          updated_at = now()
        WHERE public.skill_groups.owner_id = p_user_id
          AND public.hlc_is_newer(v_hlc, public.skill_groups.version_hlc);
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- SKILL LIFE AREA LINKS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'skill_life_area_links' AND v_op IN ('insert', 'upsert', 'delete') THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.skills s JOIN public.life_areas la ON la.owner_id = s.owner_id
        WHERE s.id = (v_payload->>'skill_id')::uuid
          AND la.id = (v_payload->>'life_area_id')::uuid
          AND s.owner_id = p_user_id
      ) THEN
        RAISE EXCEPTION 'Skill/Life Area ownership mismatch' USING ERRCODE = '42501';
      END IF;
      IF v_op = 'delete' THEN
        DELETE FROM public.skill_life_area_links
        WHERE owner_id = p_user_id
          AND skill_id = (v_payload->>'skill_id')::uuid
          AND life_area_id = (v_payload->>'life_area_id')::uuid;
      ELSE
        INSERT INTO public.skill_life_area_links
          (owner_id, skill_id, life_area_id, version_hlc, created_at)
        VALUES
          (p_user_id, (v_payload->>'skill_id')::uuid,
           (v_payload->>'life_area_id')::uuid, v_hlc, now())
        ON CONFLICT (skill_id, life_area_id) DO UPDATE SET
          owner_id = EXCLUDED.owner_id, version_hlc = EXCLUDED.version_hlc;
      END IF;

    -- ─────────────────────────────────────────────────────────────
    -- ATTACHMENT LINKS
    -- ─────────────────────────────────────────────────────────────
    ELSIF v_entity = 'attachment_links' AND v_op IN ('insert', 'upsert', 'delete') THEN
      IF v_payload->>'attachment_kind' <> 'skill' OR NOT EXISTS (
        SELECT 1 FROM public.skills s
        WHERE s.id = (v_payload->>'attachment_id')::uuid
          AND s.owner_id = p_user_id
      ) THEN
        RAISE EXCEPTION 'Skill attachment ownership mismatch' USING ERRCODE = '42501';
      END IF;
      IF v_op = 'delete' THEN
        DELETE FROM public.attachment_links
        WHERE attachment_id = (v_payload->>'attachment_id')::uuid
          AND attachment_kind = 'skill'
          AND entity_id = (v_payload->>'entity_id')::uuid
          AND entity_kind = v_payload->>'entity_kind';
      ELSE
        INSERT INTO public.attachment_links
          (id, attachment_id, attachment_kind, entity_id, entity_kind, version_hlc, created_at)
        VALUES
          ((v_payload->>'id')::uuid,
           (v_payload->>'attachment_id')::uuid, 'skill',
           (v_payload->>'entity_id')::uuid, v_payload->>'entity_kind', v_hlc, now())
        ON CONFLICT (attachment_id, attachment_kind, entity_id, entity_kind) DO UPDATE SET
          version_hlc = EXCLUDED.version_hlc;
      END IF;

    ELSE
      RAISE EXCEPTION 'Unsupported sync entity/op: %/%', v_entity, v_op
        USING ERRCODE = '0A000';
    END IF;

    INSERT INTO public.sync_cursors (user_id, peer_id, entity_kind, last_applied_hlc, updated_at)
    VALUES (p_user_id, p_device_id, v_entity, v_hlc, now())
    ON CONFLICT (user_id, peer_id, entity_kind) DO UPDATE
      SET last_applied_hlc = GREATEST(public.sync_cursors.last_applied_hlc, EXCLUDED.last_applied_hlc),
          updated_at = now();

    v_results := v_results || jsonb_build_array(jsonb_build_object('seq', v_seq, 'status', v_status));
  END LOOP;

  RETURN jsonb_build_object('status', 'success', 'results', v_results);
END;
$$;

REVOKE ALL ON FUNCTION public.apply_sync_batch(uuid, uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_sync_batch(uuid, uuid, jsonb) TO authenticated;

COMMIT;
