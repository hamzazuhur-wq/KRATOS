-- KRATOS Wave 19 / Level 8 — Migration 0012: Vector Embeddings & Semantic Search
-- Refs: 05-ai-architecture.md §13.1, 09-IMPLEMENTATION-ROADMAP.md Wave 19
-- Provides storage for entity vector embeddings to power semantic retrieval.

BEGIN;

CREATE TABLE IF NOT EXISTS vector_embeddings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_kind text NOT NULL CHECK (entity_kind IN ('goals', 'tasks', 'notes', 'evidence', 'skills', 'activities')),
  entity_id uuid NOT NULL,
  embedding_json text NOT NULL, -- Stored as float array JSON or sqlite-vec/pgvector compatible text
  dimensions int NOT NULL DEFAULT 384,
  model_id text NOT NULL DEFAULT 'bge-small-en-v1.5',
  version_hlc text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_entity_embedding UNIQUE (owner_id, entity_kind, entity_id)
);

-- Index for owner lookups
CREATE INDEX IF NOT EXISTS idx_vector_embeddings_owner ON vector_embeddings (owner_id, entity_kind);

-- Enable RLS
ALTER TABLE vector_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE vector_embeddings FORCE ROW LEVEL SECURITY;

CREATE POLICY "vector_embeddings_owner_policy" ON vector_embeddings
  FOR ALL USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

COMMIT;
