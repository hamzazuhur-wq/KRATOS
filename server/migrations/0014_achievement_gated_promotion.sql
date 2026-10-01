-- KRATOS Wave 22 / Level 8 — Migration 0014: Achievement-Gated Level Promotions & Streak Society
-- Refs: 06-DECISIONS-LOG.md ADR-010 (Compound promotion gates), ADR-005 (Streak Society)
-- Enforces compound gate: Level promotion requires XP threshold AND all mandatory objectives in level_objectives.

BEGIN;

CREATE OR REPLACE FUNCTION evaluate_level_promotion_gate(
  p_user_id uuid,
  p_life_area_id uuid,
  p_target_level int
)
RETURNS jsonb AS $$
DECLARE
  v_total_xp int := 0;
  v_required_xp int := 0;
  v_missing_objectives int := 0;
  v_promoted boolean := false;
BEGIN
  -- 1. Compute user total XP for this LifeArea
  SELECT COALESCE(SUM(al.allocated_points), 0) INTO v_total_xp
  FROM xp_allocation_lines al
  JOIN xp_ledger l ON al.ledger_id = l.id
  WHERE l.owner_id = p_user_id
    AND al.life_area_id = p_life_area_id
    AND l.reversal_event_id IS NULL;

  -- 2. Lookup required cumulative XP for target level
  SELECT cumulative_xp_required INTO v_required_xp
  FROM level_curves
  WHERE level = p_target_level;

  IF v_required_xp IS NULL THEN
    RAISE EXCEPTION 'Level curve not found for target level %', p_target_level;
  END IF;

  -- Check XP threshold
  IF v_total_xp < v_required_xp THEN
    RETURN jsonb_build_object(
      'status', 'locked',
      'reason', 'insufficient_xp',
      'current_xp', v_total_xp,
      'required_xp', v_required_xp
    );
  END IF;

  -- 3. Check compound gate: mandatory objectives in level_objectives (ADR-010)
  -- Count objectives for this level that user has NOT completed in achievements
  SELECT COUNT(*) INTO v_missing_objectives
  FROM level_objectives lo
  WHERE lo.level = p_target_level
    AND NOT EXISTS (
      SELECT 1 FROM achievements a
      WHERE a.owner_id = p_user_id
        AND a.kind = lo.title
    );

  IF v_missing_objectives > 0 THEN
    RETURN jsonb_build_object(
      'status', 'locked',
      'reason', 'pending_objectives',
      'missing_objectives_count', v_missing_objectives
    );
  END IF;

  -- 4. Gate passed! Record promotion achievement
  INSERT INTO achievements (id, owner_id, kind, level, awarded_at, version_hlc, created_at)
  VALUES (
    gen_random_uuid(),
    p_user_id,
    'level_promotion',
    p_target_level,
    now(),
    'promotion:' || p_target_level::text || ':' || extract(epoch FROM now())::bigint,
    now()
  );

  RETURN jsonb_build_object(
    'status', 'promoted',
    'target_level', p_target_level,
    'total_xp', v_total_xp
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
