# KRATOS — Implementation Status (Live)

> Updated: Wave 5 complete.

## Wave Status

| Wave | Status | Verified |
|------|--------|----------|
| Wave 0 — Architecture Validation | ✅ COMPLETE | 2026-09-14 |
| Wave 0.5 — Doc Rewrite + Lints | ⏭️ Skipped | — |
| Wave 1 — Foundation | ✅ COMPLETE | 2026-09-16 |
| Wave 2 — Database + Drift | ✅ COMPLETE | 2026-09-17 |
| Wave 3 — Core Domain Foundation | ✅ COMPLETE | 2026-09-22 |
| Wave 4 — Junction Tables + Indexes | ✅ COMPLETE | 2026-09-23 |
| Wave 5 — XP Ledger + Idempotency | ✅ COMPLETE | 2026-09-23 |
| Wave 6 — Levels / Tiers Engine | ✅ COMPLETE | 2026-09-23 |
| Wave 7 — Streak Engine | ✅ COMPLETE | 2026-09-23 |
| Wave 8 | 🔵 NEXT | — |




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

## Wave 4 — Junction Tables + Indexes ✅ COMPLETE

**Location:** `app/lib/domain/entities/task.dart`, `app/lib/features/tasks/`, `app/test/domain/wave4_junctions_test.dart`

### Deliverables

1. **Domain Entity — Task**:
   - `task.dart` — immutable `Task` entity with `create()`, `rename()`, `complete()`, `cancel()`, `delete()` — all invariants enforced
   - `TaskStatus` enum (`pending`, `inProgress`, `completed`, `cancelled`)
   - `TaskGoalRole` enum (`contributesTo`, `blocks`, `inspiredBy`, `tracks`) with JSON serialization
   - `TaskGoalLink`, `SkillToolLink`, `AttachmentLink` junction value objects
   - `AttachmentLink` guards `entityKind` ∈ `kValidEntityKinds` and `attachmentKind` ∈ `kValidAttachmentKinds`
   - `Task.fromData()` public factory for repository reconstruction

2. **Domain Value Objects (enhancements)**:
   - `Hlc.parse(String)` — reconstruct Hlc from stored string representation (graceful fallback)

3. **Repository Interfaces** (`app/lib/domain/repositories/junction_repositories.dart`):
   - `TaskRepository` — CRUD for tasks
   - `TaskGoalLinkRepository` — link/unlink tasks to goals with role
   - `SkillToolLinkRepository` — link/unlink skills to tools
   - `AttachmentLinkRepository` — polymorphic attach/detach

4. **Drift DAOs** (`app/lib/features/tasks/data/`):
   - `TasksDao` — minimal stub (allTasks, findById, upsert, softDelete)
   - `TaskGoalLinksDao` — forTask, forGoal, upsert, remove
   - `SkillToolsDao` — forSkill, forTool, upsert, remove
   - `TaskToolLinksDao` — forTask, upsert, remove
   - `AttachmentLinksDao` — forEntity, upsert, remove
   - All DAOs registered in `@DriftDatabase` annotation

5. **Repository Implementation**:
   - `DriftTaskRepository` — Drift ↔ domain bridge; outbox enqueue in same transaction

6. **Placeholder UI** (`app/lib/features/tasks/presentation/`):
   - `TasksPlaceholderScreen` — dark/acid-lime stub screen (full UX in Wave 9)
   - `AttachmentPickerPlaceholder` — file + URL attachment widget (full impl in Wave 13)

7. **Tests** (`app/test/domain/wave4_junctions_test.dart`):
   - Task invariants: empty title, priority range, complete/cancel/delete rules
   - Invariant #8: cancelled tasks cannot be completed; completed tasks cannot be cancelled
   - `TaskGoalRole` round-trip JSON serialization
   - `AttachmentLink` kind guard: rejects unknown `entityKind` and `attachmentKind`
   - `TaskGoalLink` equality via composite PK `(taskId, goalId)`

### Skills Installed (Global)
| Skill | Path |
|-------|------|
| `token-optimizer` | `C:\Users\hamza\.gemini\config\skills\token-optimizer\` |
| `flutter-riverpod-drift` | `C:\Users\hamza\.gemini\config\skills\flutter-riverpod-drift\` |
| `supabase-auth-sync` | `C:\Users\hamza\.gemini\config\skills\supabase-auth-sync\` |
| `kratos-ui-liquid-glass` | `C:\Users\hamza\.gemini\config\skills\kratos-ui-liquid-glass\` |
| `kratos-backend-rpc` | `C:\Users\hamza\.gemini\config\skills\kratos-backend-rpc\` |
| `kratos-feature-architecture` | `C:\Users\hamza\.gemini\config\skills\kratos-feature-architecture\` |
| `kratos-wave-planner` | `C:\Users\hamza\.gemini\config\skills\kratos-wave-planner\` |
| `kratos-domain-logic` | `C:\Users\hamza\.gemini\config\skills\kratos-domain-logic\` |

## Wave 5 — XP Ledger + Idempotency ✅ COMPLETE

**Location:** `server/migrations/0006_init_xp_ledger_rpc.sql`, `app/lib/features/xp/`, `app/test/features/xp/`

### Deliverables

1. **PostgreSQL Migration (`0006_init_xp_ledger_rpc.sql`)**:
   - `tg_xp_allocation_sum_check()` trigger function and `trg_xp_allocation_sum_check` `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED` on `xp_allocation_lines`. Enforces that at commit time, `SUM(allocated_points) = xp_ledger.points` (Invariant #2).
   - `record_xp_event(payload jsonb)` RPC:
     - `SECURITY DEFINER` function with `search_path = public`.
     - Validates caller authentication (`auth.uid()`).
     - Idempotency check: if `idempotency_key` exists, returns existing row (idempotent 200).
     - Validates `points != 0`, `points = base_points + bonus_points - late_penalty + streak_bonus`.
     - Validates allocation line sum in payload.
     - Atomically inserts into `xp_ledger`, `xp_allocation_lines`, and enqueues into `sync_outbox`.

2. **Drift Schema & DAOs (`app/lib/data/drift/` & `app/lib/features/xp/data/`)**:
   - `ProcessedIdempotencyKeys` table added to `ledger_tables.dart` with 7-day TTL support.
   - `XpLedgerDao`: accessor for `xp_ledger`, `xp_allocation_lines`, and `processed_idempotency_keys`.
   - Registered in `@DriftDatabase` in `app_database.dart`.

3. **Core Domain Math & Entities (`app/lib/features/xp/domain/`)**:
   - `HamiltonHareAllocator`: Implements Largest-Remainder method for proportional allocation without round-off drift. Supports both positive allocations and negative reversals.
   - `LatePenaltyCalculator`: Enforces Invariant #7 (-30% penalty if overdue) and Invariant #8 (0 penalty and 0 XP for cancelled items).
   - `XpLedgerEvent` & `XpAllocationLineEntity`: Immutable pure domain entities validating non-zero points, net arithmetic, and allocation sum.
   - `XpLedgerWriter` interface.

4. **Service Implementation (`app/lib/features/xp/data/xp_ledger_writer_impl.dart`)**:
   - `DriftXpLedgerWriter`:
     - Checks idempotency before execution.
     - Performs Hamilton-Hare proportional allocation.
     - Executes writes in a single Drift transaction (`xp_ledger` + `xp_allocation_lines` + `sync_outbox` + `processed_idempotency_keys`).
     - `reverse()` creates compensating events with negative points, preserving immutable append-only chain (Invariant #1).

5. **Automated Tests (`app/test/features/xp/`)**:
   - `xp_ledger_writer_test.dart`: Entity invariant enforcement (allocation sum mismatch rejection, zero-point rejection, net arithmetic, and RPC payload serialization).
   - `python tools/verify_schema.py`: PASSED (30 tables, 26 indexes, RLS enabled).

## Wave 6 — Levels / Tiers Engine ✅ COMPLETE

**Location:** `server/migrations/0007_init_progression.sql`, `app/lib/features/progression/`, `app/test/features/progression/`

### Deliverables

1. **PostgreSQL Migration (`0007_init_progression.sql`)**:
   - `level_curves` table with 100 levels pre-seeded using gentle exponential formula $\lfloor 100 \times 1.085^{\text{level}} \rfloor$ capped at 14M XP (ADR-011).
   - `tier_definitions` table with 6 tiers pre-seeded (Bronze 1k $\rightarrow$ Silver 3k $\rightarrow$ Gold 7k $\rightarrow$ Crystal 15k $\rightarrow$ Diamond 30k $\rightarrow$ Mythic 60k).
   - `level_objectives` table for compound promotion gates (ADR-010).
   - RLS enabled on all three tables with permissive SELECT read policies.
   - `calculate_life_area_progression(p_user_id, p_life_area_id)` plpgsql RPC: aggregates total XP for a specific LifeArea and returns level, tier, XP in level, XP to next, and progress percentage (Invariant #3).

2. **Drift Schema & DAOs (`app/lib/data/drift/` & `app/lib/features/progression/data/`)**:
   - `LevelCurves`, `TierDefinitions`, `LevelObjectives` tables in `progression_tables.dart`.
   - `ProgressionDao`: manages queries for curves, tiers, and objectives; includes auto-seeding for local offline operation.
   - Registered in `@DriftDatabase` in `app_database.dart`.

3. **Core Domain Models & Calculator (`app/lib/features/progression/domain/`)**:
   - `ProgressionInfo`, `LevelCurveSnapshot`, `TierDefinitionSnapshot`, `LevelObjectiveSnapshot`.
   - `ProgressionCalculator`: pure Dart algorithm computing real-time Level, Tier, XP to next level, and progress percentage.
   - Compound gate evaluator: level promotion requires mandatory objectives to be completed unless bypassed via test-out (ADR-010).
   - `LifeAreaProgressionService`: aggregates `xp_allocation_lines` for a LifeArea and computes real-time progression state.

4. **Presentation Screen (`app/lib/features/progression/presentation/`)**:
   - `ProgressionSettingsScreen`: Liquid Glass / Acid Lime UI with interactive progression card, XP simulator slider, and Tier Definitions ladder.

5. **Automated Tests (`app/test/features/progression/`)**:
   - `progression_service_test.dart`: Exhaustive test suite verifying level curves (1-100), tier thresholds (Bronze through Mythic), and compound gate promotion rules.
   - `python tools/verify_schema.py`: PASSED (30 tables, 33 CREATE TABLE statements, 29 indexes, RLS enabled).

## Wave 7 — Streak Engine ✅ COMPLETE

**Location:** `server/migrations/0008_init_streaks.sql`, `app/lib/features/streaks/`, `app/test/features/streaks/`

### Deliverables

1. **PostgreSQL Migration (`0008_init_streaks.sql`)**:
   - `streak_freeze_inventory` table tracking available and used freeze tokens per user and LifeArea (ADR-005, ADR-012).
   - `process_streak_activity(p_user_id, p_life_area_id, p_activity_date, p_version_hlc)` plpgsql RPC:
     - Consecutive day activity increments streak (+1) and updates longest streak.
     - Missed 1 day: auto-consumes 1 freeze token from inventory, logs pause into `streak_pauses`, and preserves the streak unbroken.
     - Missed >1 days or no tokens: resets current streak to 1.
     - Evaluates weekly +20% streak modifier eligibility (active when current streak $\ge 7$).

2. **Drift Schema & DAOs (`app/lib/data/drift/` & `app/lib/features/streaks/data/`)**:
   - `StreakFreezeInventory` table added to `ledger_tables.dart`.
   - `StreaksDao` in `streaks_dao.dart`: handles local transactional activity processing and freeze token logic.
   - Registered in `@DriftDatabase` in `app_database.dart`.

3. **Core Domain Models & Service (`app/lib/features/streaks/domain/`)**:
   - `StreakInfo`: model calculating weekly +20% bonus (ADR-005) and Streak Society milestone (current streak $\ge 100$).
   - `StreakService`: coordinates reading streak status and logging activities per LifeArea (Invariant #3).

4. **Presentation Widget (`app/lib/features/streaks/presentation/`)**:
   - `StreakBadgeWidget`: Liquid Glass / Dark Volcanic styling with glowing flame icon, active days counter, and cyan ice icons for freeze tokens.

5. **Automated Tests (`app/test/features/streaks/`)**:
   - `streak_service_test.dart`: unit tests verifying initial state, 7-day +20% weekly bonus activation, and 100-day Streak Society milestone.
   - `python tools/verify_schema.py`: PASSED (30 tables, 34 CREATE TABLE statements, 30 indexes, RLS enabled).



