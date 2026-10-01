-- ==============================================================================
-- APP MODULE: SECURE PRIVATE JOURNALS (2026 Zero-Trust Standard)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Table Definitions
-- ------------------------------------------------------------------------------
CREATE TABLE public.private_journals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    -- MANDATORY: User Isolation
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    entry_title text NOT NULL,
    entry_content text,
    mood text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 2. Performance Indexes (CRITICAL FOR RLS SPEED IN 2026)
-- ------------------------------------------------------------------------------
CREATE INDEX idx_private_journals_user_id ON public.private_journals(user_id);

-- ------------------------------------------------------------------------------
-- 3. Enable RLS (NON-NEGOTIABLE)
-- ------------------------------------------------------------------------------
ALTER TABLE public.private_journals ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 4. Granular Policies for 'private_journals' Table
-- ------------------------------------------------------------------------------
CREATE POLICY "journals_select_policy" 
    ON public.private_journals FOR SELECT 
    TO authenticated 
    USING ((select auth.uid()) = user_id);

CREATE POLICY "journals_insert_policy" 
    ON public.private_journals FOR INSERT 
    TO authenticated 
    WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "journals_update_policy" 
    ON public.private_journals FOR UPDATE 
    TO authenticated 
    USING ((select auth.uid()) = user_id) 
    WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "journals_delete_policy" 
    ON public.private_journals FOR DELETE 
    TO authenticated 
    USING ((select auth.uid()) = user_id);

-- ------------------------------------------------------------------------------
-- 5. Automation: Auto-update 'updated_at' Timestamp
-- ------------------------------------------------------------------------------
-- Assuming public.handle_updated_at() might already exist in your robust schema
-- We'll safely use it if it exists, or create if not.
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'handle_updated_at') THEN
        CREATE FUNCTION public.handle_updated_at()
        RETURNS TRIGGER AS $func$
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        $func$ language 'plpgsql';
    END IF;
END $$;

CREATE TRIGGER set_private_journals_updated_at
    BEFORE UPDATE ON public.private_journals
    FOR EACH ROW
    EXECUTE PROCEDURE public.handle_updated_at();
