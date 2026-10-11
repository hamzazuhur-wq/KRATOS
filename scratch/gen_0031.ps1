$ErrorActionPreference = 'Stop'
$src = Get-Content 'server\migrations\0028_sync_decisions_and_activity_events.sql' -Raw
$nl = if ($src.Contains("`r`n")) { "`r`n" } else { "`n" }
function Norm($s) { $s -replace "`r?`n", $nl }

$header = Norm @"
-- 0031_sessions_focus_time.sql
-- KRATOS Focus Time: additive extension of the canonical `sessions` table.
--   * status / source / paused_total_ms columns (legacy rows default to completed/timer)
--   * apply_sync_batch (copied verbatim from 0028) now persists these fields for
--     entity 'sessions'. No other entity branch is modified.
--   * Index for range analytics (owner_id, started_at).
-- Only FINALIZED sessions are synced by the client; ON CONFLICT (id) + HLC guard
-- makes repeated sync idempotent (same canonical session id).

BEGIN;

ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'timer',
  ADD COLUMN IF NOT EXISTS paused_total_ms integer NOT NULL DEFAULT 0;

DO `$`$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sessions_status_check') THEN
    ALTER TABLE public.sessions ADD CONSTRAINT sessions_status_check
      CHECK (status IN ('running','paused','completed'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sessions_source_check') THEN
    ALTER TABLE public.sessions ADD CONSTRAINT sessions_source_check
      CHECK (source IN ('timer','manual'));
  END IF;
END `$`$;

CREATE INDEX IF NOT EXISTS idx_sessions_owner_started
  ON public.sessions (owner_id, started_at) WHERE deleted_at IS NULL;

"@

# Take everything from CREATE OR REPLACE FUNCTION to the end of file (incl. COMMIT).
$idx = $src.IndexOf('CREATE OR REPLACE FUNCTION public.apply_sync_batch')
if ($idx -lt 0) { throw 'function start not found' }
$body = $src.Substring($idx)

$oldInsert = Norm @"
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
"@
$newInsert = Norm @"
        INSERT INTO public.sessions
          (id, owner_id, task_id, activity_id, started_at, ended_at,
           duration_ms, note, life_area_id, status, source, paused_total_ms,
           version_hlc, created_at, updated_at)
        VALUES
          (v_entity_id, p_user_id, (v_payload->>'task_id')::uuid,
           (v_payload->>'activity_id')::uuid,
           COALESCE((v_payload->>'started_at')::timestamptz, now()),
           (v_payload->>'ended_at')::timestamptz,
           (v_payload->>'duration_ms')::integer,
           v_payload->>'note',
           (v_payload->>'life_area_id')::uuid,
           COALESCE(v_payload->>'status', 'completed'),
           COALESCE(v_payload->>'source', 'timer'),
           COALESCE((v_payload->>'paused_total_ms')::integer, 0),
           v_hlc, now(), now())
        ON CONFLICT (id) DO UPDATE SET
          task_id = EXCLUDED.task_id, activity_id = EXCLUDED.activity_id,
          started_at = EXCLUDED.started_at, ended_at = EXCLUDED.ended_at,
          duration_ms = EXCLUDED.duration_ms, note = EXCLUDED.note,
          life_area_id = EXCLUDED.life_area_id,
          status = EXCLUDED.status, source = EXCLUDED.source,
          paused_total_ms = EXCLUDED.paused_total_ms,
          version_hlc = EXCLUDED.version_hlc, updated_at = now()
"@
if (-not $body.Contains($oldInsert)) { throw 'sessions insert block not found (line endings?)' }
$body = $body.Replace($oldInsert, $newInsert)
Set-Content -Path 'server\migrations\0031_sessions_focus_time.sql' -Value ($header + $body) -NoNewline -Encoding UTF8
"written: " + (Get-Item 'server\migrations\0031_sessions_focus_time.sql').Length
