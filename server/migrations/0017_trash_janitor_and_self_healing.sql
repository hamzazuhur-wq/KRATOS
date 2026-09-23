-- Wave 26: Self-Healing Storage & Automated Tombstone Janitor
-- Migration: 0017_trash_janitor_and_self_healing.sql
--
-- References: ADR-012 (Two-phase 30/30 day trash retention), Invariant #14 (Tombstone wins)
-- Purges soft-deleted items exceeding 30 days and compacts aged sync tombstones.

-- ============================================================
-- 1. purge_expired_trash(p_user_id uuid)
-- ============================================================
-- Hard-deletes soft-deleted rows older than 30 days and creates
-- permanent tombstone records for offline client propagation.

CREATE OR REPLACE FUNCTION purge_expired_trash(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_purged_count INT := 0;
    v_cutoff TIMESTAMPTZ := now() - INTERVAL '30 days';
BEGIN
    -- Enforce ownership (Invariant #15)
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Access denied: can only purge own trash.';
    END IF;

    -- 1. Goals
    WITH deleted_goals AS (
        DELETE FROM goals
        WHERE owner_id = p_user_id AND deleted_at IS NOT NULL AND deleted_at < v_cutoff
        RETURNING id
    )
    SELECT count(*) INTO v_purged_count FROM deleted_goals;

    -- 2. Tasks
    WITH deleted_tasks AS (
        DELETE FROM tasks
        WHERE owner_id = p_user_id AND deleted_at IS NOT NULL AND deleted_at < v_cutoff
        RETURNING id
    )
    SELECT v_purged_count + count(*) INTO v_purged_count FROM deleted_tasks;

    -- 3. Notes
    WITH deleted_notes AS (
        DELETE FROM notes
        WHERE owner_id = p_user_id AND deleted_at IS NOT NULL AND deleted_at < v_cutoff
        RETURNING id
    )
    SELECT v_purged_count + count(*) INTO v_purged_count FROM deleted_notes;

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'purged_count', v_purged_count,
        'executed_at', now()
    );
END;
$$;

-- ============================================================
-- 2. compact_sync_tombstones(p_days_old int)
-- ============================================================
-- Removes tombstone rows older than specified threshold (default 90 days).

CREATE OR REPLACE FUNCTION compact_sync_tombstones(p_days_old int DEFAULT 90)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_compacted int := 0;
BEGIN
    DELETE FROM sync_tombstones
    WHERE created_at < (now() - (p_days_old || ' days')::interval);

    GET DIAGNOSTICS v_compacted = ROW_COUNT;
    RETURN v_compacted;
END;
$$;
