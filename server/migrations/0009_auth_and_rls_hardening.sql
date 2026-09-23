-- KRATOS Wave 15 — Migration 0009: Auth, Granular RLS Policies, Trash Purge, and Restore RPC
-- Refs: 03-id-and-database-architecture.md, 06-DECISIONS-LOG.md ADR-002, ADR-012 (30/30 trash retention)
-- Invariant #14: Tombstones always win; restore window enforced server-side.
-- Invariant #15: RLS enforces auth.uid() = user_id on all tables; direct INSERT on xp_ledger is blocked.

BEGIN;

-- 1. Helper function to check row ownership
CREATE OR REPLACE FUNCTION kratos_is_owner(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN auth.uid() = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 2. Granular RLS policies for core user tables
-- Core Life Areas
CREATE POLICY "life_areas_select_owner" ON life_areas FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "life_areas_insert_owner" ON life_areas FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "life_areas_update_owner" ON life_areas FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "life_areas_delete_owner" ON life_areas FOR DELETE USING (auth.uid() = owner_id);

-- Categories
CREATE POLICY "categories_select_owner" ON categories FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "categories_insert_owner" ON categories FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "categories_update_owner" ON categories FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "categories_delete_owner" ON categories FOR DELETE USING (auth.uid() = owner_id);

-- Goals
CREATE POLICY "goals_select_owner" ON goals FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "goals_insert_owner" ON goals FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "goals_update_owner" ON goals FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "goals_delete_owner" ON goals FOR DELETE USING (auth.uid() = owner_id);

-- Tasks
CREATE POLICY "tasks_select_owner" ON tasks FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "tasks_insert_owner" ON tasks FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tasks_update_owner" ON tasks FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tasks_delete_owner" ON tasks FOR DELETE USING (auth.uid() = owner_id);

-- Projects
CREATE POLICY "projects_select_owner" ON projects FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "projects_insert_owner" ON projects FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "projects_update_owner" ON projects FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "projects_delete_owner" ON projects FOR DELETE USING (auth.uid() = owner_id);

-- Activities
CREATE POLICY "activities_select_owner" ON activities FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "activities_insert_owner" ON activities FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "activities_update_owner" ON activities FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "activities_delete_owner" ON activities FOR DELETE USING (auth.uid() = owner_id);

-- Sessions
CREATE POLICY "sessions_select_owner" ON sessions FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "sessions_insert_owner" ON sessions FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "sessions_update_owner" ON sessions FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "sessions_delete_owner" ON sessions FOR DELETE USING (auth.uid() = owner_id);

-- XP Ledger (Read allowed, Direct Insert Blocked by Invariant #15)
CREATE POLICY "xp_ledger_select_owner" ON xp_ledger FOR SELECT USING (auth.uid() = owner_id);
-- Insert allowed ONLY via SECURITY DEFINER RPC record_xp_event()

-- Sync Outbox
CREATE POLICY "sync_outbox_select_user" ON sync_outbox FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "sync_outbox_insert_user" ON sync_outbox FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "sync_outbox_update_user" ON sync_outbox FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "sync_outbox_delete_user" ON sync_outbox FOR DELETE USING (auth.uid() = user_id);

-- Sync Tombstones
CREATE POLICY "sync_tombstones_select_user" ON sync_tombstones FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "sync_tombstones_insert_user" ON sync_tombstones FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Notes & Audios
CREATE POLICY "notes_select_owner" ON notes FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "notes_insert_owner" ON notes FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "notes_update_owner" ON notes FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "notes_delete_owner" ON notes FOR DELETE USING (auth.uid() = owner_id);

CREATE POLICY "audios_select_owner" ON audios FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "audios_insert_owner" ON audios FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "audios_update_owner" ON audios FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "audios_delete_owner" ON audios FOR DELETE USING (auth.uid() = owner_id);

-- Skills & Tools
CREATE POLICY "skills_select_owner" ON skills FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "skills_insert_owner" ON skills FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "skills_update_owner" ON skills FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "skills_delete_owner" ON skills FOR DELETE USING (auth.uid() = owner_id);

CREATE POLICY "tools_select_owner" ON tools FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "tools_insert_owner" ON tools FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tools_update_owner" ON tools FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tools_delete_owner" ON tools FOR DELETE USING (auth.uid() = owner_id);


-- 3. ADR-012: 30/30 Day Trash Retention & Automated Purge Routine
-- Phase 1 (30 days): soft-deleted (deleted_at IS NOT NULL), visible in Trash, recoverable.
-- Phase 2 (30 days): permanently purged from active query tables, archived to sync_tombstones.
CREATE OR REPLACE FUNCTION purge_expired_trash(p_retention_days int DEFAULT 30)
RETURNS jsonb AS $$
DECLARE
  v_cutoff timestamptz := now() - (p_retention_days || ' days')::interval;
  v_tasks_purged int := 0;
  v_goals_purged int := 0;
  v_notes_purged int := 0;
BEGIN
  -- 1. Tasks
  WITH deleted AS (
    DELETE FROM tasks
    WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff
    RETURNING id, owner_id, version_hlc
  )
  INSERT INTO sync_tombstones (id, user_id, entity, entity_id, deleted_at, deleted_hlc, reason)
  SELECT id, owner_id, 'tasks', id, now(), version_hlc, 'auto_purge_30d' FROM deleted;
  GET DIAGNOSTICS v_tasks_purged = ROW_COUNT;

  -- 2. Goals
  WITH deleted AS (
    DELETE FROM goals
    WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff
    RETURNING id, owner_id, version_hlc
  )
  INSERT INTO sync_tombstones (id, user_id, entity, entity_id, deleted_at, deleted_hlc, reason)
  SELECT id, owner_id, 'goals', id, now(), version_hlc, 'auto_purge_30d' FROM deleted;
  GET DIAGNOSTICS v_goals_purged = ROW_COUNT;

  -- 3. Notes
  WITH deleted AS (
    DELETE FROM notes
    WHERE deleted_at IS NOT NULL AND deleted_at < v_cutoff
    RETURNING id, owner_id, version_hlc
  )
  INSERT INTO sync_tombstones (id, user_id, entity, entity_id, deleted_at, deleted_hlc, reason)
  SELECT id, owner_id, 'notes', id, now(), version_hlc, 'auto_purge_30d' FROM deleted;
  GET DIAGNOSTICS v_notes_purged = ROW_COUNT;

  RETURN jsonb_build_object(
    'status', 'success',
    'tasks_purged', v_tasks_purged,
    'goals_purged', v_goals_purged,
    'notes_purged', v_notes_purged,
    'cutoff', v_cutoff
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Restore Entity RPC (Invariant #14: Enforces 30-day restore window)
CREATE OR REPLACE FUNCTION restore_entity(
  p_entity_kind text,
  p_entity_id uuid,
  p_new_hlc text
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_cutoff timestamptz := now() - interval '30 days';
  v_restored boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: must be authenticated to restore entities';
  END IF;

  IF p_entity_kind = 'tasks' THEN
    UPDATE tasks
    SET deleted_at = NULL, deleted_by = NULL, deleted_reason = NULL,
        version_hlc = p_new_hlc, updated_at = now()
    WHERE id = p_entity_id AND owner_id = v_user_id AND deleted_at >= v_cutoff;
    v_restored := FOUND;

  ELSIF p_entity_kind = 'goals' THEN
    UPDATE goals
    SET deleted_at = NULL, deleted_by = NULL, deleted_reason = NULL,
        version_hlc = p_new_hlc, updated_at = now()
    WHERE id = p_entity_id AND owner_id = v_user_id AND deleted_at >= v_cutoff;
    v_restored := FOUND;

  ELSIF p_entity_kind = 'notes' THEN
    UPDATE notes
    SET deleted_at = NULL, deleted_by = NULL, deleted_reason = NULL,
        version_hlc = p_new_hlc, updated_at = now()
    WHERE id = p_entity_id AND owner_id = v_user_id AND deleted_at >= v_cutoff;
    v_restored := FOUND;

  ELSE
    RAISE EXCEPTION 'Unsupported entity kind for restore: %', p_entity_kind;
  END IF;

  IF NOT v_restored THEN
    RAISE EXCEPTION 'Entity % not found or restore window (30 days) expired', p_entity_id;
  END IF;

  RETURN jsonb_build_object(
    'status', 'restored',
    'entity_kind', p_entity_kind,
    'entity_id', p_entity_id,
    'version_hlc', p_new_hlc
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
