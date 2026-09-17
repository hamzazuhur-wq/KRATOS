-- KRATOS Wave 2 — Seed: Sample local user
-- WARNING: Do NOT use production credentials here.
-- This seed is for local development ONLY.
-- Run AFTER migrations 0001-0004.
BEGIN;
  INSERT INTO users (id, device_id, display_name, timezone, created_at, updated_at)
  VALUES (
    'usr_seed_dev_01',
    'dev:localhost:sample-user-01',
    'Sample Dev User',
    'UTC',
    NOW(),
    NOW()
  );
COMMIT;
-- Verify:
-- SELECT * FROM users WHERE id = 'usr_seed_dev_01';
