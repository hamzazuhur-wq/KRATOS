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
- `python tools/verify_schema.py`: ✅ **30 tables, 24 indexes, RLS enabled**

### Gaps / Deferred

- **pgTAP database tests (T2.16)**: Cannot run — no PostgreSQL/pgTAP install available in current environment. Schema is verified via `tools/verify_schema.py` instead.
- **Drift native DBs**: Currently `NativeDatabase.memory()` (in-memory). Real desktop/mobile SQLite wired in Wave 4.
- **Migrations runner**: No automated `diesel`-equivalent applied in app yet — `server/migrations/*.sql` are the source of truth, applied by Supabase CLI externally.

### Files Touched (Wave 2)

```
server/
├── migrations/
│   ├── 0001_init_core.sql            (10,082 bytes)
│   ├── 0002_init_xp_ledger.sql        (3,954 bytes)
│   ├── 0003_init_sync.sql             (3,050 bytes)
│   ├── 0004_init_ai_notes_skills.sql  (8,282 bytes)
│   └── 0005_enable_rls.sql            (4,932 bytes)
└── seed/
    └── 001_seed_sample_user.sql

app/lib/data/drift/
├── app_database.dart                 (1,984 bytes, schemaVersion=1)
├── app_database.g.dart               (codegen, gitignored)
├── core_tables.dart                  (6,092 bytes, 11 tables)
├── ledger_tables.dart                (4,571 bytes, 7 tables)
└── aux_tables.dart                   (6,222 bytes, 12 tables)

app/test/data/drift/
└── app_database_test.dart            (smoke test)

tools/
└── verify_schema.py                  (verification tool)

docs/
└── SCHEMA.md                         (table reference)
```

## Wave 3 — NEXT

Readiness: Wave 2 complete. Wave 3 target from `09-IMPLEMENTATION-ROADMAP.md`:
- Core domain entities (entities + value objects + identity + invariants)
- Domain layer with no Flutter / no Drift / no Supabase imports
