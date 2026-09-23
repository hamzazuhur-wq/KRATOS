-- KRATOS Wave 10 / Level 6 — Migration 0011: Analytics Read Views
-- Refs: 09-IMPLEMENTATION-ROADMAP.md Wave 13 / Level 6
-- Provides fast, aggregated read models for the dashboard without scanning raw xp_ledger.

BEGIN;

-- 1. Daily XP Summary View per user, date, and life area
CREATE OR REPLACE VIEW daily_xp_summary AS
SELECT
  l.owner_id AS user_id,
  DATE(l.created_at) AS activity_date,
  al.life_area_id,
  SUM(al.allocated_points) AS total_xp,
  COUNT(DISTINCT l.id) AS event_count
FROM xp_ledger l
JOIN xp_allocation_lines al ON l.id = al.ledger_id
WHERE l.reversal_event_id IS NULL
GROUP BY l.owner_id, DATE(l.created_at), al.life_area_id;

-- 2. Category XP Breakdown View
CREATE OR REPLACE VIEW category_xp_breakdown AS
SELECT
  l.owner_id AS user_id,
  COALESCE(c.id, 'uncategorized') AS category_id,
  COALESCE(c.name, 'General') AS category_name,
  SUM(l.points) AS total_xp,
  COUNT(l.id) AS action_count
FROM xp_ledger l
LEFT JOIN category_xp_rule_versions crv ON l.category_rule_version_id = crv.id
LEFT JOIN categories c ON crv.category_id = c.id
WHERE l.reversal_event_id IS NULL
GROUP BY l.owner_id, c.id, c.name;

-- 3. Weekly XP Summary View (rolling 7-day aggregate)
CREATE OR REPLACE VIEW weekly_xp_summary AS
SELECT
  l.owner_id AS user_id,
  al.life_area_id,
  SUM(al.allocated_points) AS weekly_xp,
  COUNT(DISTINCT l.id) AS weekly_events
FROM xp_ledger l
JOIN xp_allocation_lines al ON l.id = al.ledger_id
WHERE l.reversal_event_id IS NULL
  AND l.created_at >= (now() - interval '7 days')
GROUP BY l.owner_id, al.life_area_id;

COMMIT;
