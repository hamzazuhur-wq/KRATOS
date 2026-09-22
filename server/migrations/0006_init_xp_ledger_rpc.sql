-- KRATOS Wave 5 — Migration 0006: XP Ledger RPC & Sum Invariant Constraint
-- Invariants:
--   #1  Append-only ledger: corrections are compensating events with reversal_event_id.
--   #2  SUM(xp_allocation_lines.allocated_points) = xp_ledger.points exactly.
--   #13 Outbox in same transaction as domain write.
--   #15 Direct XP inserts blocked; only RPCs can write XP.

BEGIN;

-- ── 1. Deferred Constraint Trigger: Allocation Sum Check ──────────────────
-- Enforces that at COMMIT time, the sum of child allocation lines equals
-- the points in the parent xp_ledger row.
CREATE OR REPLACE FUNCTION tg_xp_allocation_sum_check()
RETURNS TRIGGER AS $$
DECLARE
  v_ledger_id uuid;
  v_expected_points integer;
  v_actual_points integer;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_ledger_id := OLD.ledger_id;
  ELSE
    v_ledger_id := NEW.ledger_id;
  END IF;

  -- If the parent ledger row was deleted in this transaction (e.g. cascaded), exit early
  SELECT points INTO v_expected_points
  FROM xp_ledger
  WHERE id = v_ledger_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(SUM(allocated_points), 0) INTO v_actual_points
  FROM xp_allocation_lines
  WHERE ledger_id = v_ledger_id;

  IF v_expected_points <> v_actual_points THEN
    RAISE EXCEPTION 'Allocation sum mismatch for xp_ledger %: expected %, got %',
      v_ledger_id, v_expected_points, v_actual_points
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_xp_allocation_sum_check ON xp_allocation_lines;

CREATE CONSTRAINT TRIGGER trg_xp_allocation_sum_check
AFTER INSERT OR UPDATE OR DELETE ON xp_allocation_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION tg_xp_allocation_sum_check();

-- ── 2. Server-side RPC: record_xp_event ────────────────────────────────────
-- Sole authorized mutation pathway for XP creation.
-- Handles idempotency deduplication, payload sum validation, ledger insertion,
-- allocation lines insertion, and outbox event enqueue in a single atomic transaction.
CREATE OR REPLACE FUNCTION public.record_xp_event(payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id                 uuid;
  v_event_id                uuid;
  v_idempotency_key         uuid;
  v_source_type             text;
  v_source_id               uuid;
  v_action                  text;
  v_points                  integer;
  v_base_points             integer;
  v_bonus_points            integer;
  v_late_penalty            integer;
  v_streak_bonus            integer;
  v_category_rule_version_id uuid;
  v_reversal_event_id       uuid;
  v_version_hlc             text;
  v_device_id               uuid;
  v_line                    jsonb;
  v_lines_sum               integer := 0;
  v_existing                jsonb;
BEGIN
  -- Authenticate owner
  IF auth.uid() IS NOT NULL THEN
    v_user_id := auth.uid();
  ELSIF (payload->>'owner_id') IS NOT NULL THEN
    v_user_id := (payload->>'owner_id')::uuid;
  ELSE
    RAISE EXCEPTION 'owner_id required' USING ERRCODE = 'invalid_parameter_value';
  END IF;

  v_idempotency_key := (payload->>'idempotency_key')::uuid;

  -- 1. Idempotency Check: if key already exists, return existing row immediately (Idempotent 200)
  SELECT row_to_json(x)::jsonb INTO v_existing
  FROM xp_ledger x
  WHERE idempotency_key = v_idempotency_key;

  IF v_existing IS NOT NULL THEN
    RETURN v_existing;
  END IF;

  -- 2. Extract fields
  v_event_id                := (payload->>'id')::uuid;
  v_source_type             := payload->>'source_type';
  v_source_id               := (payload->>'source_id')::uuid;
  v_action                  := payload->>'action';
  v_points                  := (payload->>'points')::integer;
  v_base_points             := (payload->>'base_points')::integer;
  v_bonus_points            := COALESCE((payload->>'bonus_points')::integer, 0);
  v_late_penalty            := COALESCE((payload->>'late_penalty')::integer, 0);
  v_streak_bonus            := COALESCE((payload->>'streak_bonus')::integer, 0);
  v_category_rule_version_id := (payload->>'category_rule_version_id')::uuid;
  v_reversal_event_id       := (payload->>'reversal_event_id')::uuid;
  v_version_hlc             := payload->>'version_hlc';
  v_device_id               := (payload->>'device_id')::uuid;

  -- Invariant checks
  IF v_points = 0 THEN
    RAISE EXCEPTION 'xp points cannot be 0' USING ERRCODE = 'check_violation';
  END IF;

  IF v_points <> (COALESCE(v_base_points, 0) + v_bonus_points - v_late_penalty + v_streak_bonus) THEN
    RAISE EXCEPTION 'xp points arithmetic mismatch' USING ERRCODE = 'check_violation';
  END IF;

  -- 3. Verify allocation lines sum in payload before inserting
  IF jsonb_array_length(payload->'allocation_lines') = 0 THEN
    RAISE EXCEPTION 'at least one allocation line is required' USING ERRCODE = 'check_violation';
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(payload->'allocation_lines')
  LOOP
    v_lines_sum := v_lines_sum + (v_line->>'allocated_points')::integer;
  END LOOP;

  IF v_lines_sum <> v_points THEN
    RAISE EXCEPTION 'Allocation lines sum (%) does not match points (%)', v_lines_sum, v_points
      USING ERRCODE = 'check_violation';
  END IF;

  -- 4. Insert into xp_ledger
  INSERT INTO xp_ledger (
    id, owner_id, idempotency_key, source_type, source_id, action,
    points, base_points, bonus_points, late_penalty, streak_bonus,
    category_rule_version_id, reversal_event_id, version_hlc, device_id, created_at
  ) VALUES (
    v_event_id, v_user_id, v_idempotency_key, v_source_type, v_source_id, v_action,
    v_points, v_base_points, v_bonus_points, v_late_penalty, v_streak_bonus,
    v_category_rule_version_id, v_reversal_event_id, v_version_hlc, v_device_id, NOW()
  );

  -- 5. Insert allocation lines
  FOR v_line IN SELECT * FROM jsonb_array_elements(payload->'allocation_lines')
  LOOP
    INSERT INTO xp_allocation_lines (
      id, ledger_id, life_area_id, allocated_points, percentage, version_hlc, created_at
    ) VALUES (
      COALESCE((v_line->>'id')::uuid, gen_random_uuid()),
      v_event_id,
      (v_line->>'life_area_id')::uuid,
      (v_line->>'allocated_points')::integer,
      (v_line->>'percentage')::numeric(5,2),
      v_version_hlc,
      NOW()
    );
  END LOOP;

  -- 6. Enqueue into sync_outbox (single transaction guarantee)
  INSERT INTO sync_outbox (
    user_id, op, entity, entity_id, payload_json, hlc, device_id, idempotency_key, status
  ) VALUES (
    v_user_id, 'INSERT', 'xp_ledger', v_event_id, payload::text, v_version_hlc, v_device_id, v_idempotency_key::text, 'pending'
  );

  RETURN (
    SELECT row_to_json(x)::jsonb FROM xp_ledger x WHERE id = v_event_id
  );
END;
$$;

COMMIT;
