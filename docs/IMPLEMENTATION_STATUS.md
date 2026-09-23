# KRATOS — Implementation Status (Live)

> Status: **ALL WAVES 0 TO 23 COMPLETE & VERIFIED** ✅
> Last Updated: 2026-09-23 | Levels 1–8 fully implemented, tested, and committed.

## Wave Status Table

| Wave | Status | Description | Verified |
|---|---|---|---|
| Wave 0 — Architecture Validation | ✅ COMPLETE | ADRs, system bounds, and schema designs | 2026-09-14 |
| Wave 0.5 — Doc Rewrite + Lints | ⏭️ SKIPPED | Consolidated into Wave 1 | — |
| Wave 1 — Foundation | ✅ COMPLETE | Flutter monorepo, HLC value object, CI pipeline | 2026-09-16 |
| Wave 2 — Database + Drift | ✅ COMPLETE | 30 PostgreSQL tables, Drift schemas, RLS foundation | 2026-09-17 |
| Wave 3 — Core Domain Foundation | ✅ COMPLETE | User, LifeArea, Goal entities & recursive path tree | 2026-09-22 |
| Wave 4 — Junction Tables + Indexes | ✅ COMPLETE | Task entity, M:N links, Attachment edges, DAOs | 2026-09-23 |
| Wave 5 — XP Ledger + Idempotency | ✅ COMPLETE | Append-only ledger, Hamilton-Hare rounding, RPC | 2026-09-23 |
| Wave 6 — Levels / Tiers Engine | ✅ COMPLETE | 100-level curve, 6 tiers ladder, compound gates | 2026-09-23 |
| Wave 7 — Streak Engine | ✅ COMPLETE | Freeze tokens, auto-freeze, weekly +20% bonus | 2026-09-23 |
| Wave 8 — Categories, Skills & Tools | ✅ COMPLETE | SCD Type 2 rule versioning, Skills & Tools registry | 2026-09-23 |
| Wave 9 — Sessions, Activities, Projects | ✅ COMPLETE | Focus timer, session logging, projects containers | 2026-09-23 |
| Wave 10 — XP Dashboard & Analytics | ✅ COMPLETE | Aggregation DAO, 7-day sparkline, area breakdown | 2026-09-23 |
| Wave 11 — AI Notes & Voice Memos | ✅ COMPLETE | OmniRoute QuickCapture, Whisper transcription | 2026-09-23 |
| Wave 12 — Skills & Tools Registry Full UX | ✅ COMPLETE | SkillDetail, tool assignment, attribution display | 2026-09-23 |
| Wave 13 — Evidence Hub & Attachments | ✅ COMPLETE | Polymorphic attachment links, files, URLs, evidence | 2026-09-23 |
| Wave 14 — PWA Web Polish (iPhone Access) | ✅ COMPLETE | Web manifest shortcuts, iOS standalone PWA meta | 2026-09-23 |
| Wave 15 — Supabase Auth & Security Hardening | ✅ COMPLETE | Google OAuth, dev bypass, granular RLS, 30/30 purge | 2026-09-23 |
| Wave 16 — Background Sync Engine | ✅ COMPLETE | Outbox drain worker, apply_sync_batch, reminders | 2026-09-23 |
| Wave 17 — Onboarding Flow | ✅ COMPLETE | Curated life areas, initial goal, mechanics wizard | 2026-09-23 |
| Wave 18 — Launch Hardening & AppShell | ✅ COMPLETE | Liquid Glass navigation shell, KratosApp, E2E test | 2026-09-23 |
| Wave 19 — Semantic Vector Search | ✅ COMPLETE | VectorEmbeddingsDao, top-K cosine similarity, SemanticSearchBar | 2026-09-23 |
| Wave 20 — Multimodal Vision & Streaming | ✅ COMPLETE | MultimodalVisionService, ProviderFallbackPolicy (30%), VisionProposalDialog | 2026-09-23 |
| Wave 21 — Collaborative Goals | ✅ COMPLETE | shared_goals + goal_comments, CollaborationDao, ShareGoalDialog | 2026-09-23 |
| Wave 22 — Achievement-Gated Promotions | ✅ COMPLETE | Compound gate (XP + objectives), Streak Society milestones, PromotionGateScreen | 2026-09-23 |
| Wave 23 — XP Partitioning & Backup | ✅ COMPLETE | Materialized monthly summary, export_user_data RPC, BackupService, BackupScreen | 2026-09-23 |

---

## Detailed Deliverables by Wave (Waves 8–18)

### Wave 8 — Categories, Skills & Tools Registry ✅
- **ADR-003 & Invariant #9**: SCD Type 2 rule versioning for categories. Modifying base XP or action modifiers freezes the previous rule snapshot and publishes a new immutable version without rewriting historical XP.
- **ADR-004 & Invariant #4**: Strict separation of Skills (graded competencies, attribution only) and Tools (reusable inventory items).
- **Presentation**: `CategoriesScreen`, `SkillsRegistryScreen`, `ToolsRegistryScreen` with Liquid Glass cards and badges.
- **Tests**: `wave8_categories_skills_tools_test.dart` (20+ assertions).

### Wave 9 — Sessions, Activities & Projects UX ✅
- **Drift DAOs**: `SessionsDao`, `ActivitiesDao`, `ProjectsDao` registered in `AppDatabase`.
- **Domain Models**: `SessionEntity` (lifecycle: running -> completed/abandoned), `ActivityEntity` with `ActivityXpRule` (per-minute and flat XP formulas), and `ProjectEntity` status lifecycle.
- **Presentation**: `SessionTimerScreen` with pulsing ring animation and XP estimate chip; `ProjectsScreen` and `ActivitiesScreen`.
- **Tests**: `wave9_sessions_activities_projects_test.dart` (22 assertions).

### Wave 10 — XP Dashboard & Analytics ✅
- **Analytics DAO**: `XpAnalyticsDao` providing read-only aggregates (`totalXpForLifeArea`, `xpByLifeArea`, `dailyXpTotals`, `xpBySourceType`, `totalStreakBonusXp`).
- **Presentation**: `XpDashboardScreen` with Hero XP Card, 7-day bar sparkline, and life-area progress breakdowns.
- **Tests**: `wave10_xp_analytics_test.dart`.

### Wave 11 — AI Notes & Voice Memos ✅
- **Drift DAOs**: `NotesDao` (pinned notes, soft-delete, AI artifact audits) and `AudioDao` (voice memos, transcription status tracking).
- **Presentation**: `AiNotesScreen` with tabbed notes/memos and OmniRoute `QuickCapture` modal bottom sheet.

### Wave 12 — Skills & Tools Registry Full UX ✅
- **Presentation**: `SkillDetailScreen` with level progress bar, XP attribution disclaimer, and linked tools chips.

### Wave 13 — Evidence Hub & Attachments ✅
- **Drift DAO**: `AttachmentsDao` handling polymorphic `AttachmentLinks`, `Files`, `Links`, and `Evidence`.
- **Presentation**: `EvidenceHubScreen` with 3-tab browser (Files, Links, Evidence).

### Wave 14 — PWA Web Polish (iPhone Access) ✅
- **iOS Meta & Manifest**: Configured `apple-mobile-web-app-capable`, `black-translucent` status bar, theme-color `#C6F135`, and manifest app shortcuts ("Quick Capture" & "Start Session").
- **Zero Flash**: Inline CSS background prevents white flicker on iOS PWA cold start.

### Wave 15 — Supabase Auth & Security Hardening ✅
- **Migration 0009**: Granular per-user RLS policies (`auth.uid() = user_id`), 30/30 day trash retention and purge routine (`purge_expired_trash`), and `restore_entity` RPC enforcing 30-day window (Invariant #14 & #15).
- **Auth Layer**: `AuthService` interface, `MockAuthService` with instant dev bypass (`usr_seed_dev_01`), `SupabaseAuthService` with platform-aware Google OAuth redirects.
- **Presentation**: `LoginScreen` in Liquid Glass with Google sign-in, magic link, and dev bypass.
- **Tests**: `wave15_auth_test.dart`.

### Wave 16 — Background Sync Engine & Notifications ✅
- **Migration 0010**: `apply_sync_batch` RPC implementing field-level LWW conflict resolution via HLC and tombstone preservation.
- **Engine & DAO**: `SyncDao` FIFO queue management, `SyncEngine` with exponential retry backoff, and `NotificationService` for streak and freeze alerts.
- **Presentation**: `SyncStatusBadge` widget.
- **Tests**: `wave16_sync_test.dart`.

### Wave 17 — Onboarding Flow ✅
- **Domain & Service**: `OnboardingDefaults` with 4 curated life areas, `OnboardingService` seeding Life Areas, initial root Goal, and 2 streak freeze tokens per area (ADR-005).
- **Presentation**: `OnboardingScreen` 4-step interactive wizard.
- **Tests**: `wave17_onboarding_test.dart`.

### Wave 18 — Launch Hardening & AppShell ✅
- **Theme & Root**: `KratosTheme` (Dark Volcanic + Liquid Glass + Acid Lime) and `KratosApp` state-driven router.
- **AppShell**: Complete navigation shell uniting all 6 core modules with real-time streak and sync badges in the top bar.
- **E2E Test**: `wave18_e2e_integration_test.dart` verifying cross-system execution from Auth -> LifeArea -> Goal -> Task -> Session -> Largest-Remainder XP Allocation -> Streak +20% Bonus -> Level Progression Curve -> Tier promotion -> Sync Outbox mutation queue.
- **Entrypoint**: `main.dart` updated to run `KratosApp`.

---

## Level 8 — Expansion & Intelligence (Waves 19–23)

### Wave 19 — Semantic Vector Search ✅
- **Migration**: `0012_vector_embeddings.sql` — `vector_embeddings` table with cosine similarity index and RLS.
- **Drift**: `VectorEmbeddings` table + `VectorEmbeddingsDao` with top-K cosine similarity ranking (client-side dot-product).
- **Domain**: `VectorEmbedding`, `CosineSimilarity`, `SearchResultItem` models.
- **Presentation**: `SemanticSearchBar` with match percentage badges (Acid Lime gradient).
- **Tests**: `wave19_vector_search_test.dart`.
- **Commit**: `960f309`

### Wave 20 — Multimodal Vision & Streaming ✅
- **Domain**: `MultimodalInput`, `VisionAnalysisResult`, `StreamingToolCallChunk`, `ProviderFallbackPolicy` (30% error threshold per ADR-012).
- **Service**: `MultimodalVisionService` — vision analysis with ai_artifacts audit trail (Invariant #11) + streaming plan decomposition.
- **Presentation**: `VisionProposalDialog` — explicit user confirmation before any AI-generated action (Invariant #11).
- **Tests**: `wave20_multimodal_ai_test.dart`.
- **Commit**: `8f75254`

### Wave 21 — Collaborative Goals ✅
- **Migration**: `0013_collaborative_goals.sql` — `shared_goals` + `goal_comments` tables with scoped RLS per partner role.
- **Drift**: `SharedGoals`, `GoalComments` tables + `CollaborationDao` (invite, accept, comment CRUD).
- **Domain**: `SharedGoalEntity`, `GoalCommentEntity`, `PartnerRole` enum (Viewer/Partner/Coach).
- **Presentation**: `ShareGoalDialog` — partner invite with role selector, Liquid Glass design.
- **Tests**: `wave21_collaborative_goals_test.dart`.
- **Commit**: `413de8c`

### Wave 22 — Achievement-Gated Level Promotions ✅
- **Migration**: `0014_achievement_gated_promotion.sql` — `evaluate_level_promotion_gate` RPC enforcing compound gates (XP threshold + mandatory `level_objectives` completion → inserts into `achievements`).
- **Domain Models**: `PromotionGateResult` sealed class (Locked/PendingObjectives/Ready/Promoted), `PromotionObjective`, `StreakSocietyMilestone`, `StreakSocietyTier` enum (100/200/365 days, 5/10/20 bonus freeze tokens).
- **Services**: `AchievementGateService` (compound gate evaluation + local promotion execution), `StreakSocietyService` (idempotent milestone awards).
- **Presentation**: `PromotionGateScreen` — Liquid Glass UI with XP gauge, objectives checklist, promote button, and promotion celebration dialog.
- **app_database.dart**: Added `VectorEmbeddings`, `SharedGoals`, `GoalComments` tables + `VectorEmbeddingsDao`, `CollaborationDao` DAOs (outstanding from Waves 19 & 21).
- **Tests**: `wave22_achievement_gate_test.dart` (12 tests: gate math, Streak Society milestones, idempotency, DB writes).
- **Commit**: `eaed9d0`

### Wave 23 — XP Partitioning & Full Backup ✅
- **Migration**: `0015_xp_partitioning_and_backup.sql`:
  - `xp_ledger_monthly_summary` — materialized view aggregating XP per user/life-area/month with unique index for REFRESH CONCURRENTLY.
  - `refresh_xp_monthly_summary()` — SECURITY DEFINER function for scheduled nightly refresh.
  - `export_user_data(p_user_id uuid)` — structured JSONB backup RPC (SECURITY INVOKER, enforces `auth.uid() = p_user_id`).
  - `validate_backup_schema(jsonb)` — schema version guard for import safety.
- **Domain**: `BackupService` — export (all domain entities + client-side XP monthly aggregation) + import (insertOnConflictUpdate with HLC conflict resolution, schema validation, Invariant #1: xp_ledger excluded from import).
- **Models**: `BackupManifest` (versioned JSON document), `BackupImportResult`.
- **Presentation**: `BackupScreen` — Liquid Glass settings screen with Export and Import sections, JSON paste dialog, and status banners.
- **Tests**: `wave23_backup_test.dart` (10 tests: manifest round-trip, schema validation, empty/seeded export, import failure modes, idempotency).
- **Commit**: `aa09156`

---

## Level 8 — Comprehensive Test Suite

- `level8_expansion_intelligence_test.dart` — Cross-wave integration harness:
  - All 33 Drift tables accessible (VectorEmbeddings + SharedGoals + GoalComments registered in `app_database.dart`)
  - Wave 19 + 22 coexistence: vector search and achievement gate in same DB session
  - Wave 21 + 23: backup export includes life area data
  - Wave 22 + 23: achievement rows from promotion appear in backup manifest
  - Import→export round-trip preserves life areas across fresh DB instances
  - StreakSocietyTier completeness: all 3 tiers with increasing thresholds and bonus tokens

