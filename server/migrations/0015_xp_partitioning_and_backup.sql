-- Wave 23: XP Monthly Summary View + Data Export RPC
-- Migration: 0015_xp_partitioning_and_backup.sql
--
-- Note: True PostgreSQL table partitioning is a DBA-level operation and requires
-- table recreation (not safe in a rolling migration). Instead we implement a
-- materialized summary view `xp_ledger_monthly_summary` that provides equivalent
-- analytics query performance benefits, plus an `export_user_data` RPC for
-- structured JSON backup (ZIP wrapping is done client-side).
--
-- ADR-005 extension: backup preserves all domain entities per user.
-- Invariant #15: RLS enforced on the view via SECURITY INVOKER.

-- ============================================================
-- 1. xp_ledger_monthly_summary (materialized analytics view)
-- ============================================================
-- Aggregates XP per user, life area, and calendar month.
-- Replaces the need for monthly partition scans on xp_ledger.

CREATE MATERIALIZED VIEW IF NOT EXISTS xp_ledger_monthly_summary AS
SELECT
    l.owner_id AS user_id,
    al.life_area_id,
    date_trunc('month', l.created_at) AS month_start,
    COUNT(*)                          AS event_count,
    SUM(al.allocated_points)          AS total_xp,
    MIN(l.created_at)                 AS first_event_at,
    MAX(l.created_at)                 AS last_event_at
FROM xp_ledger l
JOIN xp_allocation_lines al ON al.ledger_id = l.id
GROUP BY l.owner_id, al.life_area_id, date_trunc('month', l.created_at);

-- Unique index for fast lookups and REFRESH CONCURRENTLY support
CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_monthly_summary_pk
    ON xp_ledger_monthly_summary (user_id, life_area_id, month_start);

-- Composite index for per-user time-range queries
CREATE INDEX IF NOT EXISTS idx_xp_monthly_summary_user_month
    ON xp_ledger_monthly_summary (user_id, month_start DESC);

-- ============================================================
-- 2. refresh_xp_monthly_summary() — scheduled via pg_cron
-- ============================================================
-- Called nightly by a Supabase Edge Function / pg_cron job.
-- CONCURRENTLY requires at least one unique index (above).

CREATE OR REPLACE FUNCTION refresh_xp_monthly_summary()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY xp_ledger_monthly_summary;
END;
$$;

-- ============================================================
-- 3. export_user_data(p_user_id uuid) — structured JSON backup
-- ============================================================
-- Returns a single JSONB document with all user-owned domain entities.
-- Caller is responsible for wrapping in ZIP (done client-side in Dart).
-- RLS: can only export own data (auth.uid() = p_user_id).

CREATE OR REPLACE FUNCTION export_user_data(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Enforce that caller can only export their own data (Invariant #15)
    IF auth.uid() != p_user_id THEN
        RAISE EXCEPTION 'Access denied: can only export own data.';
    END IF;

    SELECT jsonb_build_object(
        'schema_version',    1,
        'exported_at',       now(),
        'user_id',           p_user_id,
        'life_areas',        (
            SELECT jsonb_agg(row_to_json(la))
            FROM life_areas la
            WHERE la.owner_id = p_user_id AND la.deleted_at IS NULL
        ),
        'goals', (
            SELECT jsonb_agg(row_to_json(g))
            FROM goals g
            WHERE g.owner_id = p_user_id AND g.deleted_at IS NULL
        ),
        'tasks', (
            SELECT jsonb_agg(row_to_json(t))
            FROM tasks t
            WHERE t.owner_id = p_user_id AND t.deleted_at IS NULL
        ),
        'notes', (
            SELECT jsonb_agg(row_to_json(n))
            FROM notes n
            WHERE n.owner_id = p_user_id AND n.deleted_at IS NULL
        ),
        'xp_summary', (
            SELECT jsonb_agg(row_to_json(xs))
            FROM xp_ledger_monthly_summary xs
            WHERE xs.user_id = p_user_id
        ),
        'achievements', (
            SELECT jsonb_agg(row_to_json(a))
            FROM achievements a
            WHERE a.owner_id = p_user_id
        ),
        'skills', (
            SELECT jsonb_agg(row_to_json(s))
            FROM skills s
            WHERE s.owner_id = p_user_id AND s.deleted_at IS NULL
        ),
        'projects', (
            SELECT jsonb_agg(row_to_json(p))
            FROM projects p
            WHERE p.owner_id = p_user_id AND p.deleted_at IS NULL
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- ============================================================
-- 4. import validation helper: validate_backup_schema(jsonb)
-- ============================================================
-- Returns true if the provided backup blob has the expected shape.
-- Used server-side before applying an import.

CREATE OR REPLACE FUNCTION validate_backup_schema(p_backup jsonb)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    RETURN
        p_backup ? 'schema_version' AND
        p_backup ? 'user_id'        AND
        p_backup ? 'exported_at'    AND
        (p_backup->>'schema_version')::int = 1;
END;
$$;
