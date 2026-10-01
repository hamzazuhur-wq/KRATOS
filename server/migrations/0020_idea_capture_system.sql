-- KRATOS Wave 35 / Idea Capture Feature — Migration 0020: Idea Capture & Knowledge System
-- Architecture: Dedicated Idea Capture knowledge module (IdeaSpaces, Ideas, IdeaSpaceLinks, IdeaBlocks, IdeaLinks, Tags, IdeaTags, IdeaAttachments)
-- Invariant #15: RLS enforced on all tables with auth.uid() = owner_id

BEGIN;

-- 1. idea_spaces
CREATE TABLE IF NOT EXISTS idea_spaces (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  icon          text,
  archived_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_idea_spaces_owner_name ON idea_spaces(owner_id, lower(name)) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_idea_spaces_owner ON idea_spaces(owner_id, updated_at DESC);

-- 2. ideas
CREATE TABLE IF NOT EXISTS ideas (
  id            uuid PRIMARY KEY,
  owner_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title         text NOT NULL,
  content_json  text NOT NULL DEFAULT '[]',
  excerpt       text,
  is_pinned     boolean NOT NULL DEFAULT false,
  archived_at   timestamptz,
  deleted_at    timestamptz,
  deleted_by    uuid,
  deleted_reason text,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ideas_owner ON ideas(owner_id, is_pinned DESC, updated_at DESC);

-- 3. idea_space_links (M:N between Idea and Idea Space)
CREATE TABLE IF NOT EXISTS idea_space_links (
  id            uuid PRIMARY KEY,
  idea_id       uuid NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  idea_space_id uuid NOT NULL REFERENCES idea_spaces(id) ON DELETE CASCADE,
  owner_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(idea_id, idea_space_id)
);

CREATE INDEX IF NOT EXISTS idx_idea_space_links_space ON idea_space_links(idea_space_id);
CREATE INDEX IF NOT EXISTS idx_idea_space_links_idea ON idea_space_links(idea_id);

-- 4. idea_blocks (Normalized block level persistence)
CREATE TABLE IF NOT EXISTS idea_blocks (
  id            uuid PRIMARY KEY,
  idea_id       uuid NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  owner_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  block_type    text NOT NULL,
  content       text NOT NULL DEFAULT '',
  payload_json  text,
  sort_order    integer NOT NULL DEFAULT 0,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_idea_blocks_idea ON idea_blocks(idea_id, sort_order ASC);

-- 5. idea_links (Internal links between ideas [[Idea]])
CREATE TABLE IF NOT EXISTS idea_links (
  id              uuid PRIMARY KEY,
  owner_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_idea_id  uuid NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  source_block_id uuid,
  target_idea_id  uuid NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  target_block_id uuid,
  display_text    text NOT NULL,
  version_hlc     text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_idea_links_source ON idea_links(source_idea_id);
CREATE INDEX IF NOT EXISTS idx_idea_links_target ON idea_links(target_idea_id);

-- 6. tags & idea_tags
CREATE TABLE IF NOT EXISTS tags (
  id          uuid PRIMARY KEY,
  owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  version_hlc text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_owner_name ON tags(owner_id, lower(name));

CREATE TABLE IF NOT EXISTS idea_tags (
  id          uuid PRIMARY KEY,
  idea_id     uuid NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  tag_id      uuid NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  version_hlc text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(idea_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_idea_tags_idea ON idea_tags(idea_id);
CREATE INDEX IF NOT EXISTS idx_idea_tags_tag ON idea_tags(tag_id);

-- 7. idea_attachments
CREATE TABLE IF NOT EXISTS idea_attachments (
  id            uuid PRIMARY KEY,
  idea_id       uuid NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  block_id      uuid,
  owner_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  storage_path  text NOT NULL,
  file_name     text NOT NULL,
  mime_type     text NOT NULL,
  file_size     integer NOT NULL DEFAULT 0,
  version_hlc   text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_idea_attachments_idea ON idea_attachments(idea_id);

-- 8. Enable + Force Row Level Security (RLS)
ALTER TABLE idea_spaces       ENABLE ROW LEVEL SECURITY;
ALTER TABLE idea_spaces       FORCE  ROW LEVEL SECURITY;
ALTER TABLE ideas             ENABLE ROW LEVEL SECURITY;
ALTER TABLE ideas             FORCE  ROW LEVEL SECURITY;
ALTER TABLE idea_space_links  ENABLE ROW LEVEL SECURITY;
ALTER TABLE idea_space_links  FORCE  ROW LEVEL SECURITY;
ALTER TABLE idea_blocks       ENABLE ROW LEVEL SECURITY;
ALTER TABLE idea_blocks       FORCE  ROW LEVEL SECURITY;
ALTER TABLE idea_links        ENABLE ROW LEVEL SECURITY;
ALTER TABLE idea_links        FORCE  ROW LEVEL SECURITY;
ALTER TABLE tags              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags              FORCE  ROW LEVEL SECURITY;
ALTER TABLE idea_tags         ENABLE ROW LEVEL SECURITY;
ALTER TABLE idea_tags         FORCE  ROW LEVEL SECURITY;
ALTER TABLE idea_attachments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE idea_attachments  FORCE  ROW LEVEL SECURITY;

-- 9. Granular RLS Policies for each table
-- idea_spaces
CREATE POLICY "idea_spaces_select_owner" ON idea_spaces FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "idea_spaces_insert_owner" ON idea_spaces FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_spaces_update_owner" ON idea_spaces FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_spaces_delete_owner" ON idea_spaces FOR DELETE USING (auth.uid() = owner_id);

-- ideas
CREATE POLICY "ideas_select_owner" ON ideas FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "ideas_insert_owner" ON ideas FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "ideas_update_owner" ON ideas FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "ideas_delete_owner" ON ideas FOR DELETE USING (auth.uid() = owner_id);

-- idea_space_links
CREATE POLICY "idea_space_links_select_owner" ON idea_space_links FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "idea_space_links_insert_owner" ON idea_space_links FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_space_links_update_owner" ON idea_space_links FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_space_links_delete_owner" ON idea_space_links FOR DELETE USING (auth.uid() = owner_id);

-- idea_blocks
CREATE POLICY "idea_blocks_select_owner" ON idea_blocks FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "idea_blocks_insert_owner" ON idea_blocks FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_blocks_update_owner" ON idea_blocks FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_blocks_delete_owner" ON idea_blocks FOR DELETE USING (auth.uid() = owner_id);

-- idea_links
CREATE POLICY "idea_links_select_owner" ON idea_links FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "idea_links_insert_owner" ON idea_links FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_links_update_owner" ON idea_links FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_links_delete_owner" ON idea_links FOR DELETE USING (auth.uid() = owner_id);

-- tags
CREATE POLICY "tags_select_owner" ON tags FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "tags_insert_owner" ON tags FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tags_update_owner" ON tags FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "tags_delete_owner" ON tags FOR DELETE USING (auth.uid() = owner_id);

-- idea_tags
CREATE POLICY "idea_tags_select_owner" ON idea_tags FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "idea_tags_insert_owner" ON idea_tags FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_tags_update_owner" ON idea_tags FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_tags_delete_owner" ON idea_tags FOR DELETE USING (auth.uid() = owner_id);

-- idea_attachments
CREATE POLICY "idea_attachments_select_owner" ON idea_attachments FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "idea_attachments_insert_owner" ON idea_attachments FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_attachments_update_owner" ON idea_attachments FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "idea_attachments_delete_owner" ON idea_attachments FOR DELETE USING (auth.uid() = owner_id);

COMMIT;
