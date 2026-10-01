-- KRATOS Phase 7 — Migration 0029: Notifications Subsystem
-- Adds cloud persistence, RLS isolation, and Sync Engine support for in-app notifications.
-- Supports:
--   - Event-driven notifications (Level Up, Achievement, Goal/Project Completion, Streaks)
--   - Deadline notifications (Overdue, Due Today, Stale Paused)
--   - Read/Unread and Dismissed state tracking
--   - Activity Event idempotency linking
--   - apply_sync_batch integration for two-way cloud synchronization

BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type          text NOT NULL,
  title         text NOT NULL,
  body          text NOT NULL,
  entity_type   text,
  entity_id     uuid,
  activity_event_id uuid,
  severity      text NOT NULL DEFAULT 'info' CHECK (severity IN ('urgent', 'warning', 'info')),
  read_at       timestamptz,
  dismissed_at  timestamptz,
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_owner_created ON public.notifications (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_owner_unread ON public.notifications (owner_id, read_at) WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_activity_event ON public.notifications (owner_id, activity_event_id);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_owner" ON public.notifications;
CREATE POLICY "notifications_select_owner" ON public.notifications FOR SELECT TO authenticated
  USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "notifications_insert_owner" ON public.notifications;
CREATE POLICY "notifications_insert_owner" ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "notifications_update_owner" ON public.notifications;
CREATE POLICY "notifications_update_owner" ON public.notifications FOR UPDATE TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "notifications_delete_owner" ON public.notifications;
CREATE POLICY "notifications_delete_owner" ON public.notifications FOR DELETE TO authenticated
  USING (auth.uid() = owner_id);

COMMIT;
