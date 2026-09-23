-- KRATOS Wave 16 — Migration 0010: Sync Batch RPC and Field-Level LWW
-- Refs: 03-id-and-database-architecture.md, 06-DECISIONS-LOG.md ADR-006 (HLC), ADR-008 (Hub-and-spoke)
-- Invariant #13: Every domain write enqueues into sync_outbox.
-- Invariant #14: Tombstones always win over concurrent edits.

BEGIN;

-- 1. Batch Sync RPC: Receives an array of outbox mutations and applies them with LWW.
CREATE OR REPLACE FUNCTION apply_sync_batch(
  p_user_id uuid,
  p_device_id text,
  p_changes jsonb
)
RETURNS jsonb AS $$
DECLARE
  v_item jsonb;
  v_op text;
  v_entity text;
  v_entity_id uuid;
  v_hlc text;
  v_payload jsonb;
  v_applied_count int := 0;
  v_skipped_count int := 0;
  v_current_hlc text;
BEGIN
  -- Authenticate owner
  IF auth.uid() IS NOT NULL AND auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized sync batch for user %', p_user_id;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_changes)
  LOOP
    v_op := v_item->>'op';
    v_entity := v_item->>'entity';
    v_entity_id := (v_item->>'entity_id')::uuid;
    v_hlc := v_item->>'hlc';
    v_payload := v_item->'payload';

    -- Check if tombstone exists (Tombstone always wins, Invariant #14)
    IF EXISTS (
      SELECT 1 FROM sync_tombstones
      WHERE user_id = p_user_id AND entity = v_entity AND entity_id = v_entity_id
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- LWW comparison per entity
    IF v_entity = 'tasks' THEN
      SELECT version_hlc INTO v_current_hlc FROM tasks WHERE id = v_entity_id;
      IF v_current_hlc IS NULL OR v_hlc > v_current_hlc THEN
        -- Newer HLC wins
        IF v_op = 'delete' THEN
          UPDATE tasks
          SET deleted_at = now(), version_hlc = v_hlc, updated_at = now()
          WHERE id = v_entity_id;
          INSERT INTO sync_tombstones (id, user_id, entity, entity_id, deleted_at, deleted_hlc)
          VALUES (gen_random_uuid(), p_user_id, 'tasks', v_entity_id, now(), v_hlc)
          ON CONFLICT (id) DO NOTHING;
        ELSE
          INSERT INTO tasks (id, owner_id, title, status, priority, sort_order, version_hlc, created_at, updated_at)
          VALUES (
            v_entity_id,
            p_user_id,
            COALESCE(v_payload->>'title', 'Untitled Task'),
            COALESCE(v_payload->>'status', 'active'),
            COALESCE((v_payload->>'priority')::int, 0),
            COALESCE((v_payload->>'sort_order')::int, 0),
            v_hlc,
            now(),
            now()
          )
          ON CONFLICT (id) DO UPDATE
          SET title = COALESCE(v_payload->>'title', tasks.title),
              status = COALESCE(v_payload->>'status', tasks.status),
              priority = COALESCE((v_payload->>'priority')::int, tasks.priority),
              version_hlc = v_hlc,
              updated_at = now()
          WHERE tasks.version_hlc < v_hlc;
        END IF;
        v_applied_count := v_applied_count + 1;
      ELSE
        v_skipped_count := v_skipped_count + 1;
      END IF;

    ELSIF v_entity = 'goals' THEN
      SELECT version_hlc INTO v_current_hlc FROM goals WHERE id = v_entity_id;
      IF v_current_hlc IS NULL OR v_hlc > v_current_hlc THEN
        IF v_op = 'delete' THEN
          UPDATE goals SET deleted_at = now(), version_hlc = v_hlc, updated_at = now() WHERE id = v_entity_id;
        ELSE
          INSERT INTO goals (id, owner_id, root_id, path, depth, title, progress, status, version_hlc, created_at, updated_at)
          VALUES (
            v_entity_id,
            p_user_id,
            COALESCE((v_payload->>'root_id')::uuid, v_entity_id),
            COALESCE(v_payload->>'path', v_entity_id::text),
            COALESCE((v_payload->>'depth')::int, 0),
            COALESCE(v_payload->>'title', 'Goal'),
            COALESCE((v_payload->>'progress')::numeric, 0.0),
            COALESCE(v_payload->>'status', 'active'),
            v_hlc,
            now(),
            now()
          )
          ON CONFLICT (id) DO UPDATE
          SET title = COALESCE(v_payload->>'title', goals.title),
              progress = COALESCE((v_payload->>'progress')::numeric, goals.progress),
              status = COALESCE(v_payload->>'status', goals.status),
              version_hlc = v_hlc,
              updated_at = now()
          WHERE goals.version_hlc < v_hlc;
        END IF;
        v_applied_count := v_applied_count + 1;
      ELSE
        v_skipped_count := v_skipped_count + 1;
      END IF;

    ELSIF v_entity = 'notes' THEN
      SELECT version_hlc INTO v_current_hlc FROM notes WHERE id = v_entity_id;
      IF v_current_hlc IS NULL OR v_hlc > v_current_hlc THEN
        IF v_op = 'delete' THEN
          UPDATE notes SET deleted_at = now(), version_hlc = v_hlc, updated_at = now() WHERE id = v_entity_id;
        ELSE
          INSERT INTO notes (id, owner_id, body_text, pinned, version_hlc, created_at, updated_at)
          VALUES (
            v_entity_id,
            p_user_id,
            COALESCE(v_payload->>'body_text', ''),
            COALESCE((v_payload->>'pinned')::boolean, false),
            v_hlc,
            now(),
            now()
          )
          ON CONFLICT (id) DO UPDATE
          SET body_text = COALESCE(v_payload->>'body_text', notes.body_text),
              pinned = COALESCE((v_payload->>'pinned')::boolean, notes.pinned),
              version_hlc = v_hlc,
              updated_at = now()
          WHERE notes.version_hlc < v_hlc;
        END IF;
        v_applied_count := v_applied_count + 1;
      ELSE
        v_skipped_count := v_skipped_count + 1;
      END IF;
    END IF;

    -- Update sync cursor for peer
    INSERT INTO sync_cursors (user_id, peer_id, entity_kind, last_applied_hlc, updated_at)
    VALUES (p_user_id, p_device_id, v_entity, v_hlc, now())
    ON CONFLICT (user_id, peer_id, entity_kind) DO UPDATE
    SET last_applied_hlc = GREATEST(sync_cursors.last_applied_hlc, EXCLUDED.last_applied_hlc),
        updated_at = now();

  END LOOP;

  RETURN jsonb_build_object(
    'status', 'success',
    'applied', v_applied_count,
    'skipped', v_skipped_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
