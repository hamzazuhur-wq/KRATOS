-- Wave 24: Real-Time Collaboration & CRDT Shared Notes / Comments
-- Migration: 0016_crdt_collaborative_notes.sql
--
-- References: 04-sync-architecture.md (§future_v2_collaborative)
-- Enables multi-party collaborative notes and rich discussion threads between
-- accountability partners without merge conflicts.
--
-- Invariant #15: RLS enforced based on goal sharing and ownership.

CREATE TABLE IF NOT EXISTS collaborative_notes (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    shared_goal_id UUID REFERENCES shared_goals(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    crdt_doc_state BYTEA, -- Packed binary state / state vector for delta CRDT merges
    plain_text TEXT NOT NULL DEFAULT '',
    version_hlc TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    deleted_reason TEXT
);

CREATE TABLE IF NOT EXISTS collaborative_note_deltas (
    id UUID PRIMARY KEY,
    note_id UUID NOT NULL REFERENCES collaborative_notes(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta_op TEXT NOT NULL, -- JSON delta / operation (insert/delete/replace)
    client_sequence INT NOT NULL,
    version_hlc TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_collab_notes_owner ON collaborative_notes(owner_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_collab_notes_goal ON collaborative_notes(shared_goal_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_collab_deltas_note ON collaborative_note_deltas(note_id, applied_at ASC);

-- Row Level Security
ALTER TABLE collaborative_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE collaborative_note_deltas ENABLE ROW LEVEL SECURITY;

CREATE POLICY collab_notes_participant_access ON collaborative_notes
    FOR ALL
    USING (
        auth.uid() = owner_id
        OR shared_goal_id IN (
            SELECT id FROM shared_goals
            WHERE partner_id = auth.uid() OR owner_id = auth.uid()
        )
    );

CREATE POLICY collab_deltas_participant_access ON collaborative_note_deltas
    FOR ALL
    USING (
        auth.uid() = author_id
        OR note_id IN (
            SELECT id FROM collaborative_notes
            WHERE owner_id = auth.uid()
            OR shared_goal_id IN (
                SELECT id FROM shared_goals
                WHERE partner_id = auth.uid() OR owner_id = auth.uid()
            )
        )
    );
