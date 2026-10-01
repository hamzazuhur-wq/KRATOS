-- Migration 0025: Activity Difficulty Column
-- Phase 2 — Activity Duration XP Engine.
-- Adds a difficulty column (1–10) to the activities table.
-- The new ActivityXpCalculator (Dart) uses difficulty + session duration
-- to compute XP via an anchor-point diminishing-returns curve.
--
-- Default = 5 (mid-range) so all existing activities get a sensible baseline.

BEGIN;

ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS difficulty integer NOT NULL DEFAULT 5;

ALTER TABLE activities
  DROP CONSTRAINT IF EXISTS activities_difficulty_check;

ALTER TABLE activities
  ADD CONSTRAINT activities_difficulty_check CHECK (difficulty BETWEEN 1 AND 10);

COMMIT;
