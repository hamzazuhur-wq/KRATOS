-- =============================================================================
-- Migration 0024: xp_constraint_fixes
-- =============================================================================
-- Fixes three CHECK constraint bugs in the XP ledger found during audit.
--
-- Bug 1 — xp_allocation_lines.allocated_points
--   Old: CHECK (allocated_points > 0)
--   Problem: Reversal / compensating events write NEGATIVE point values, which
--            violates this constraint and causes the insert to be rejected.
--   Fix: Relax to CHECK (allocated_points <> 0) — zero is still disallowed
--        because an allocation line must always move the ledger by some amount.
--
-- Bug 2 — xp_ledger.source_type
--   Old: CHECK (source_type IN ('task','goal','activity','session','skill','admin','reversal'))
--   Problem: Project-level XP events write source_type = 'project', which is
--            not in the allowed set.
--   Fix: Add 'project' to the IN list.
--
-- Bug 3 — xp_ledger.action
--   Old: CHECK (action IN ('complete','milestone','session_complete','admin_adjust',
--                          'undo','reversal','restore'))
--   Problem: Three action values are emitted by domain services but were never
--            added to the constraint:
--              • 'project_completed'      — ProjectXpService
--              • 'focus_completed'        — FocusSessionXpService
--              • 'goal_completion_bonus'  — GoalXpService bonus path
--            Additionally, GoalXpService already writes action = 'completed'
--            (not 'complete'), so that value must be preserved as well.
--   Fix: Extend the IN list to include all four missing values while keeping
--        every previously accepted value.
--
-- Safe to re-run: DROP CONSTRAINT IF EXISTS is used before every ADD CONSTRAINT.
-- No data is destroyed; existing rows are not touched.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Bug 1: allocated_points must be nonzero (positive OR negative)
-- ---------------------------------------------------------------------------
ALTER TABLE xp_allocation_lines
    DROP CONSTRAINT IF EXISTS xp_allocation_lines_allocated_points_check;

ALTER TABLE xp_allocation_lines
    ADD CONSTRAINT xp_allocation_lines_allocated_points_check
        CHECK (allocated_points <> 0);

-- ---------------------------------------------------------------------------
-- Bug 2: source_type must accept 'project'
-- ---------------------------------------------------------------------------
ALTER TABLE xp_ledger
    DROP CONSTRAINT IF EXISTS xp_ledger_source_type_check;

ALTER TABLE xp_ledger
    ADD CONSTRAINT xp_ledger_source_type_check
        CHECK (source_type IN (
            'task',
            'goal',
            'activity',
            'session',
            'skill',
            'admin',
            'reversal',
            'project'          -- added: project-level XP events
        ));

-- ---------------------------------------------------------------------------
-- Bug 3: action must accept the full set of values emitted by domain services
-- ---------------------------------------------------------------------------
ALTER TABLE xp_ledger
    DROP CONSTRAINT IF EXISTS xp_ledger_action_check;

ALTER TABLE xp_ledger
    ADD CONSTRAINT xp_ledger_action_check
        CHECK (action IN (
            'complete',
            'completed',           -- GoalXpService (existing dart usage)
            'milestone',
            'session_complete',
            'admin_adjust',
            'undo',
            'reversal',
            'restore',
            'project_completed',   -- added: ProjectXpService
            'focus_completed',     -- added: FocusSessionXpService
            'goal_completion_bonus' -- added: GoalXpService bonus path
        ));

COMMIT;
