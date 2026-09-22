-- KRATOS Wave 6 — Migration 0007: Levels & Tiers Engine
-- ADR-010: Compound level gates (xp_threshold AND all(objectives complete))
-- ADR-011: Gentle exponential level curve + Duolingo tier ladder
-- Invariant #3: No global level — progression belongs to LifeArea only

BEGIN;

-- ── 1. level_curves ────────────────────────────────────────────────────────
-- 100 levels pre-computed with gentle exponential growth:
-- delta_xp = floor(100 * 1.085^level), cumulative capped at 14M XP.
CREATE TABLE IF NOT EXISTS level_curves (
  level                   integer PRIMARY KEY CHECK (level >= 1 AND level <= 100),
  delta_xp                integer NOT NULL CHECK (delta_xp >= 0),
  cumulative_xp_required  integer NOT NULL CHECK (cumulative_xp_required >= 0)
);

CREATE INDEX IF NOT EXISTS idx_level_curves_cumulative ON level_curves (cumulative_xp_required);

-- Pre-seed levels 1 through 100
DO $$
DECLARE
  v_lvl integer;
  v_delta integer;
  v_cumul integer := 0;
BEGIN
  -- Level 1 starts at 0 cumulative XP
  INSERT INTO level_curves (level, delta_xp, cumulative_xp_required)
  VALUES (1, 100, 0)
  ON CONFLICT (level) DO NOTHING;

  FOR v_lvl IN 2..100 LOOP
    -- delta_xp = floor(100 * 1.085^v_lvl)
    v_delta := floor(100 * power(1.085, v_lvl))::integer;
    v_cumul := v_cumul + v_delta;
    -- Cap at 14M XP
    IF v_cumul > 14000000 THEN
      v_cumul := 14000000;
    END IF;

    INSERT INTO level_curves (level, delta_xp, cumulative_xp_required)
    VALUES (v_lvl, v_delta, v_cumul)
    ON CONFLICT (level) DO UPDATE
      SET delta_xp = EXCLUDED.delta_xp,
          cumulative_xp_required = EXCLUDED.cumulative_xp_required;
  END LOOP;
END;
$$;

-- ── 2. tier_definitions ───────────────────────────────────────────────────
-- ADR-011 ladder: Bronze 1k → Silver 3k → Gold 7k → Crystal 15k → Diamond 30k → Mythic 60k
CREATE TABLE IF NOT EXISTS tier_definitions (
  name        text PRIMARY KEY,
  entry_xp    integer NOT NULL CHECK (entry_xp >= 0),
  ordinal     integer NOT NULL UNIQUE CHECK (ordinal >= 1),
  icon        text,
  color       text
);

CREATE INDEX IF NOT EXISTS idx_tier_definitions_ordinal ON tier_definitions (ordinal);

INSERT INTO tier_definitions (name, entry_xp, ordinal, icon, color) VALUES
  ('Bronze',    1000, 1, 'shield_bronze', '#CD7F32'),
  ('Silver',    3000, 2, 'shield_silver', '#C0C0C0'),
  ('Gold',      7000, 3, 'shield_gold',   '#FFD700'),
  ('Crystal',  15000, 4, 'gem_crystal',   '#00FFFF'),
  ('Diamond',  30000, 5, 'gem_diamond',   '#B9F2FF'),
  ('Mythic',   60000, 6, 'crown_mythic',  '#C6F135')
ON CONFLICT (name) DO UPDATE
  SET entry_xp = EXCLUDED.entry_xp,
      ordinal = EXCLUDED.ordinal,
      icon = EXCLUDED.icon,
      color = EXCLUDED.color;

-- ── 3. level_objectives (Compound gate ADR-010) ───────────────────────────
CREATE TABLE IF NOT EXISTS level_objectives (
  id            uuid PRIMARY KEY,
  level         integer NOT NULL REFERENCES level_curves(level),
  title         text NOT NULL,
  description   text,
  is_mandatory  boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_level_objectives_level ON level_objectives (level);

-- ── 4. RLS on reference tables ─────────────────────────────────────────────
ALTER TABLE level_curves       ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_curves       FORCE  ROW LEVEL SECURITY;
ALTER TABLE tier_definitions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE tier_definitions   FORCE  ROW LEVEL SECURITY;
ALTER TABLE level_objectives   ENABLE ROW LEVEL SECURITY;
ALTER TABLE level_objectives   FORCE  ROW LEVEL SECURITY;

-- Permissive read policies for all users
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'allow_read_level_curves') THEN
    CREATE POLICY allow_read_level_curves ON level_curves FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'allow_read_tier_definitions') THEN
    CREATE POLICY allow_read_tier_definitions ON tier_definitions FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'allow_read_level_objectives') THEN
    CREATE POLICY allow_read_level_objectives ON level_objectives FOR SELECT USING (true);
  END IF;
END;
$$;

-- ── 5. plpgsql RPC: calculate_life_area_progression ────────────────────────
-- Invariant #3: Returns real-time progression for a specific LifeArea of a user.
CREATE OR REPLACE FUNCTION public.calculate_life_area_progression(
  p_user_id uuid,
  p_life_area_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_xp integer := 0;
  v_level integer := 1;
  v_tier text := 'Bronze';
  v_tier_color text := '#CD7F32';
  v_tier_icon text := 'shield_bronze';
  v_cumul_current integer := 0;
  v_cumul_next integer := 100;
  v_xp_in_level integer := 0;
  v_xp_to_next integer := 100;
  v_progress_pct numeric(5,2) := 0.0;
BEGIN
  -- 1. Compute total XP for this user & life_area from xp_allocation_lines
  SELECT COALESCE(SUM(l.allocated_points), 0)::integer INTO v_total_xp
  FROM xp_allocation_lines l
  JOIN xp_ledger x ON x.id = l.ledger_id
  WHERE x.owner_id = p_user_id
    AND l.life_area_id = p_life_area_id;

  -- 2. Find matching Level
  SELECT c.level, c.cumulative_xp_required INTO v_level, v_cumul_current
  FROM level_curves c
  WHERE c.cumulative_xp_required <= v_total_xp
  ORDER BY c.level DESC
  LIMIT 1;

  IF v_level IS NULL THEN
    v_level := 1;
    v_cumul_current := 0;
  END IF;

  -- Next level target
  SELECT c.cumulative_xp_required INTO v_cumul_next
  FROM level_curves c
  WHERE c.level = v_level + 1;

  IF v_cumul_next IS NULL THEN
    -- Max level (100) reached
    v_cumul_next := v_cumul_current;
    v_xp_in_level := 0;
    v_xp_to_next := 0;
    v_progress_pct := 100.0;
  ELSE
    v_xp_in_level := v_total_xp - v_cumul_current;
    v_xp_to_next := v_cumul_next - v_cumul_current;
    IF v_xp_to_next > 0 THEN
      v_progress_pct := round((v_xp_in_level::numeric / v_xp_to_next::numeric) * 100.0, 2);
    ELSE
      v_progress_pct := 100.0;
    END IF;
  END IF;

  -- 3. Find matching Tier
  SELECT t.name, t.color, t.icon INTO v_tier, v_tier_color, v_tier_icon
  FROM tier_definitions t
  WHERE t.entry_xp <= v_total_xp
  ORDER BY t.ordinal DESC
  LIMIT 1;

  IF v_tier IS NULL THEN
    SELECT t.name, t.color, t.icon INTO v_tier, v_tier_color, v_tier_icon
    FROM tier_definitions t
    ORDER BY t.ordinal ASC
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'life_area_id', p_life_area_id,
    'total_xp', v_total_xp,
    'level', v_level,
    'tier', v_tier,
    'tier_color', v_tier_color,
    'tier_icon', v_tier_icon,
    'xp_in_level', v_xp_in_level,
    'xp_to_next', v_xp_to_next,
    'progress_pct', v_progress_pct
  );
END;
$$;

COMMIT;
