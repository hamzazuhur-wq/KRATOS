-- KRATOS Wave 7 — Migration 0008: Streak Engine & Freeze Tokens
-- ADR-005: Duolingo-style positive-only streaks with freeze tokens; weekly flat +20% streak modifier
-- ADR-012: Per-LifeArea streaks (user_streaks composite PK: user_id, life_area_id)
-- Invariant #3: No global streak — streaks belong to LifeAreas
-- Invariant #7: Late penalty (-30%) and streak modifier (+20%) are mutually exclusive
-- Invariant #8: Cancelled items never receive XP, penalties, or streak credit

BEGIN;

-- ── 1. streak_freeze_inventory ─────────────────────────────────────────────
-- Tracks available freeze tokens per user and life_area.
-- Users get 2 free tokens; extra tokens rewarded upon reaching milestones (e.g. 100-day Streak Society).
CREATE TABLE IF NOT EXISTS streak_freeze_inventory (
  id              uuid PRIMARY KEY,
  user_id         uuid NOT NULL REFERENCES users(id),
  life_area_id    uuid NOT NULL REFERENCES life_areas(id),
  tokens_available integer NOT NULL DEFAULT 2 CHECK (tokens_available >= 0),
  tokens_used     integer NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),
  last_used_date  date,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_life_area_freezes UNIQUE (user_id, life_area_id)
);

CREATE INDEX IF NOT EXISTS idx_freeze_inventory_user_area ON streak_freeze_inventory (user_id, life_area_id);

-- RLS
ALTER TABLE streak_freeze_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE streak_freeze_inventory FORCE  ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'user_manage_own_freezes') THEN
    CREATE POLICY user_manage_own_freezes ON streak_freeze_inventory
      FOR ALL USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END;
$$;

-- ── 2. plpgsql RPC: process_streak_activity ────────────────────────────────
-- Called upon any positive XP event for a life area.
-- Evaluates calendar day continuity in user's timezone:
--   - Same day: no-op (streak remains current).
--   - Consecutive day (yesterday): streak increments (+1); updates longest_streak if exceeded.
--   - Missed 1 day: checks streak_freeze_inventory. If token available, consumes 1 token, logs pause, preserves streak.
--   - Missed >1 days or no tokens: resets current_streak to 1.
CREATE OR REPLACE FUNCTION public.process_streak_activity(
  p_user_id uuid,
  p_life_area_id uuid,
  p_activity_date date,
  p_version_hlc text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_streak record;
  v_new_current integer := 1;
  v_new_longest integer := 1;
  v_day_diff integer;
  v_freeze_consumed boolean := false;
  v_tokens_left integer := 0;
  v_is_weekly_bonus_eligible boolean := false;
BEGIN
  -- Fetch current streak projection
  SELECT * INTO v_streak
  FROM user_streaks
  WHERE user_id = p_user_id AND life_area_id = p_life_area_id;

  IF v_streak IS NULL THEN
    -- First activity ever in this life area
    INSERT INTO user_streaks (
      user_id, life_area_id, current_streak, longest_streak,
      last_active_date, last_active_hlc, updated_at
    ) VALUES (
      p_user_id, p_life_area_id, 1, 1,
      p_activity_date, p_version_hlc, NOW()
    );

    -- Ensure initial 2 freeze tokens exist
    INSERT INTO streak_freeze_inventory (
      id, user_id, life_area_id, tokens_available, tokens_used, updated_at
    ) VALUES (
      gen_random_uuid(), p_user_id, p_life_area_id, 2, 0, NOW()
    ) ON CONFLICT (user_id, life_area_id) DO NOTHING;

    RETURN jsonb_build_object(
      'current_streak', 1,
      'longest_streak', 1,
      'freeze_consumed', false,
      'weekly_bonus_active', false
    );
  END IF;

  -- Calculate day difference between incoming activity and last_active_date
  IF v_streak.last_active_date IS NULL THEN
    v_day_diff := 1;
  ELSE
    v_day_diff := p_activity_date - v_streak.last_active_date;
  END IF;

  IF v_day_diff = 0 THEN
    -- Already logged activity today; streak remains unchanged
    v_new_current := v_streak.current_streak;
    v_new_longest := v_streak.longest_streak;
  ELSIF v_day_diff = 1 THEN
    -- Perfect consecutive day! Increment streak
    v_new_current := v_streak.current_streak + 1;
    v_new_longest := GREATEST(v_streak.longest_streak, v_new_current);
  ELSIF v_day_diff = 2 THEN
    -- Missed exactly 1 day. Check if a freeze token can save it
    SELECT tokens_available INTO v_tokens_left
    FROM streak_freeze_inventory
    WHERE user_id = p_user_id AND life_area_id = p_life_area_id;

    IF v_tokens_left IS NOT NULL AND v_tokens_left > 0 THEN
      -- Auto-consume 1 freeze token (Trophy.so / Duolingo retention model)
      UPDATE streak_freeze_inventory
      SET tokens_available = tokens_available - 1,
          tokens_used = tokens_used + 1,
          last_used_date = p_activity_date - 1,
          updated_at = NOW()
      WHERE user_id = p_user_id AND life_area_id = p_life_area_id;

      -- Log freeze pause row for audit
      INSERT INTO streak_pauses (
        id, user_id, life_area_id, reason, started_at, ended_at, version_hlc, created_at
      ) VALUES (
        gen_random_uuid(), p_user_id, p_life_area_id, 'Auto freeze token consumed',
        (p_activity_date - 1)::timestamptz, p_activity_date::timestamptz, p_version_hlc, NOW()
      );

      v_freeze_consumed := true;
      v_new_current := v_streak.current_streak + 1;
      v_new_longest := GREATEST(v_streak.longest_streak, v_new_current);
    ELSE
      -- No freeze available: streak resets to 1
      v_new_current := 1;
      v_new_longest := v_streak.longest_streak;
    END IF;
  ELSE
    -- Missed more than 1 day: streak resets to 1
    v_new_current := 1;
    v_new_longest := v_streak.longest_streak;
  END IF;

  -- Update user_streaks projection
  UPDATE user_streaks
  SET current_streak = v_new_current,
      longest_streak = v_new_longest,
      last_active_date = p_activity_date,
      last_active_hlc = p_version_hlc,
      updated_at = NOW()
  WHERE user_id = p_user_id AND life_area_id = p_life_area_id;

  -- Invariant: weekly +20% bonus active if streak >= 7 (ADR-005)
  v_is_weekly_bonus_eligible := (v_new_current >= 7);

  RETURN jsonb_build_object(
    'current_streak', v_new_current,
    'longest_streak', v_new_longest,
    'freeze_consumed', v_freeze_consumed,
    'weekly_bonus_active', v_is_weekly_bonus_eligible
  );
END;
$$;

COMMIT;
