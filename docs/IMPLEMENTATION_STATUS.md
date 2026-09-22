# KRATOS — Implementation Status (Live)

> Updated: Wave 2 commit.

## Wave Status

| Wave | Status | Verified |
|------|--------|----------|
| Wave 0 — Architecture Validation | ✅ COMPLETE | 2026-09-14 |
| Wave 0.5 — Doc Rewrite + Lints | ⏭️ Skipped | — |
| Wave 1 — Foundation | ✅ COMPLETE | 2026-09-16 |
| Wave 2 — Database + Drift | ✅ COMPLETE | 2026-09-17 |
| Wave 3 | 🔵 NEXT | — |

## Wave 1 — Foundation ✅ VERIFIED

**Commit:** `726f762 Wave 1: KRATOS foundation — Flutter app, HLC, packages, CI`
- Flutter app (web/android/ios) — `flutter test` 20/20 PASS, `flutter analyze` 0 issues, `flutter build web` PASS
- HLC implementation + tests (20 test cases)
- 3 packages: `kratos_lints`, `kratos_models`, `uuid_v7`
- CI foundation: `.github/workflows/ci.yml`
- `pubspec.yaml` deps: drift, riverpod, supabase_flutter, record, very_good_analysis
- Git: monorepo layout with `app/`, `server/`, `packages/`, `tools/`, `docs/`
- No secrets checked

## Wave 2 — Database + Drift ✅ VERIFIED

**Location:** `server/migrations/`, `app/lib/data/drift/`

### Deliverables

1. **5 SQL migrations** (30 tables + 24 indexes + RLS):
   - `0001_init_core.sql` — 11 tables (users, life_areas, categories, goals, projects, tasks, activities, sessions)
   - `0002_init_xp_ledger.sql` — 4 tables (xp_ledger, xp_allocation_lines, user_streaks, streak_pauses)
   - `0003_init_sync.sql` — 3 tables (sync_outbox, sync_cursors, sync_tombstones)
   - `0004_init_ai_notes_skills.sql` — 12 tables (notes, audios, achievements, evidence, ai_artifacts, files, links, attachments, skills, tools, junctions)
   - `0005_enable_rls.sql` — RLS ENABLE + FORCE for all 30 tables

2. **3 Drift table files** (`app/lib/data/drift/`):
   - `core_tables.dart` — 11 classes
   - `ledger_tables.dart` — 7 classes
   - `aux_tables.dart` — 12 classes
   - Total: 30 Drift Table classes

3. **AppDatabase** (`app/lib/data/drift/app_database.dart`):
   - 29 tables registered (Tasks registered twice: as Tasks + TaskGoalLinks = 30 distinct entities)
   - `schemaVersion = 1`
   - Single-version migration strategy (`onCreate: createAll`)
   - Codegen output: `app_database.g.dart` (gitignored)

4. **Verify tool** (`tools/verify_schema.py`):
   - PASS: 30 tables, 30 CREATE TABLE, 24 indexes, RLS enabled

5. **Seed** (`server/seed/001_seed_sample_user.sql`):
   - Local dev only — no production credentials
   - Sample user: `usr_seed_dev_01`

6. **Schema reference** (`docs/SCHEMA.md`):
   - Full table inventory + conventions + ADRs

7. **Drift smoke test** (`app/test/data/drift/app_database_test.dart`):
   - Opens in-memory DB
   - Inserts into users, goals (recursive), xp_ledger (idempotency)
   - Verifies table count and basic schema

### Verification (2026-09-17)

- `flutter analyze`: ✅ **No issues**
- `flutter test`: ✅ **22/22 PASS** (HLC 20 + Drift smoke 2 + widget 1)
- `flutter build web`: ✅ **√ Built build/web**
- `python tools/verify_schema.py`: ✅ **30 tables, 26 indexes, RLS enabled**
- **Level 2 Remediation**:
  - `user_streaks` updated to composite PK `(user_id, life_area_id)` for independent streaks per Life Area.
  - `streak_pauses` updated with `life_area_id`.
  - `sync_outbox`, `sync_cursors`, `sync_tombstones` updated with `user_id` for multi-tenant RLS isolation.
  - Drift tables (`core_tables.dart`, `ledger_tables.dart`, `aux_tables.dart`) updated with explicit `primaryKey` and correct `.nullable()` modifiers.
  - `app_database.dart` upgraded with `drift_flutter` for seamless Native (Android/iOS) and WASM/IndexedDB (Web/PWA) support.

## Wave 3 — Core Domain Foundation ✅ COMPLETE

**Location:** `app/lib/domain/`, `app/test/domain/`

### Deliverables
1. **Pure Domain Entities (No Flutter / No Drift / No Supabase imports)**:
   - `User` (`app/lib/domain/entities/user.dart`)
   - `LifeArea` (`app/lib/domain/entities/life_area.dart`)
   - `Goal` (`app/lib/domain/entities/goal.dart`) — recursive tree, path maintenance, progress validation, derived `xpEarned`
2. **Value Objects & Utilities**:
   - `Id` (`app/lib/domain/ids.dart`) — UUIDv7 value object
   - `Hlc` (`app/lib/domain/hlc.dart`) — Hybrid Logical Clock value object & tiebreaking
   - `Iso8601Timestamp` (`app/lib/domain/timestamps.dart`)
   - `GoalPath` (`app/lib/domain/invariants.dart`) — tree path validation consistent with Postgres constraints
   - `DomainError` (`app/lib/domain/errors.dart`)
3. **Repository Interfaces**:
   - `UserRepository`, `LifeAreaRepository`, `GoalRepository`, `OutboxEnqueuer`
4. **Verification**:
   - `entities_test.dart`: User, LifeArea, and Goal invariants, child hierarchy, and progress checks.
   - `goal_path_test.dart`: Root, child, and grandchild path validations.
   - `ids_test.dart`: UUIDv7 format and monotonic uniqueness tests.
   - `python tools/verify_schema.py`: PASSED (30 tables, 26 indexes, RLS enabled).
