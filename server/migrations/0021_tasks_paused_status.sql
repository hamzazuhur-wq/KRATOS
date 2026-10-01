-- KRATOS Task Dashboard: persist the explicit paused lifecycle state.
-- Existing clients may still use open/in_progress/done; paused is additive.

ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_status_check
  CHECK (status IN ('open', 'in_progress', 'paused', 'done', 'cancelled', 'deleted'));
