# KRATOS Schema — 30 Tables

> Mirror of `server/migrations/0001-0004` for reference.
> Drift source: `app/lib/data/drift/`.

## Conventions

- Primary keys: `id TEXT NOT NULL` (UUID v7 from `gen_lua_uuid()` in Postgres, or `UuidV7.new()` in Drift)
- Version ordering: `version_hlc TEXT NOT NULL DEFAULT encode(gen_hlc(), 'hex')` (Postgres) / `HLC.now()` (Drift)
- Soft delete: `deleted_at`, `deleted_by`, `deleted_reason` — nullable
- Archive: `archived_at` — nullable, separate from soft-delete
- Timestamps: `created_at`/`updated_at` TIMESTAMPTZ NOT NULL DEFAULT NOW()
- HLC: 16-byte BYTEA in Postgres (stored as 32-char hex TEXT). Stored as TEXT in Drift for portability.

## Table Inventory (30)

### Core (0001) — 11 tables
- `users`, `life_areas`, `categories`, `category_actions`, `category_xp_rule_versions`
- `goals` (recursive: parent_id, root_id, path, depth), `projects`, `tasks`
- `task_goal_links` (M:N composite PK), `activities`, `sessions`

### XP Ledger (0002) — 4 tables
- `xp_ledger` (idempotency_key UNIQUE, append-only)
- `xp_allocation_lines` (multi-Life-Area split)
- `user_streaks` (ADR-005 Duolingo + freeze tokens)
- `streak_pauses` (effective-dated)

### Sync (0003) — 3 tables
- `sync_outbox` (bigserial seq FIFO, idempotency_key, hlc BYTEA — ADR-008 server-hub)
- `sync_cursors` (peer+entity composite PK)
- `sync_tombstones` (UNIQUE entity+entity_id)

### Notes / AI / Skills / Attachments (0004) — 12 tables
- `notes` (pinned), `audios` (transcription), `achievements` (xp_ledger_event_id FK)
- `evidence` (JSON payload), `ai_artifacts` (tokens, model)
- `files` (sha256), `links`, `attachment_links` (4-table attachment pattern — ADR-007)
- `skills` (xp_total), `tools` (no xp — ADR-004)
- `skill_tools` (M:N junction), `task_tool_links` (M:N junction)

## Indexes (24)

See `server/migrations/*.sql` for full index definitions.
Critical: `xp_ledger.idempotency_key UNIQUE`, `sync_tombstones UNIQUE (entity, entity_id)`, FK indexes on every relationship.

## RLS

All 30 tables have RLS enabled and forced.
Full policy bodies deferred to Wave 15 (security hardening).

## Drift

Drift schema mirrors this exactly: `app/lib/data/drift/app_database.dart`.
Codegen output: `app/lib/data/drift/app_database.g.dart` (gitignored, regeneratable via `flutter pub run build_runner build --delete-conflicting-outputs`).

Schema version: 1 (single-version migration strategy).

## Architecture Docs

- `C:\Users\hamza\kratos-spec\03-id-and-database-architecture.md` — full table definitions
- `C:\Users\hamza\kratos-spec\04-sync-architecture.md` — outbox/sync semantics
- `C:\Users\hamza\kratos-spec\06-DECISIONS-LOG.md` — ADRs 001-012
