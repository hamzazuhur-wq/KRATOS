# KRATOS — Personal Development Operating System

> **Build the connected personal-development graph: Life Areas → Goals → Tasks → Projects → Skills → XP → Streaks → Levels → AI.**

KRATOS is a local-first, offline-capable Personal Development OS. It models your development as a **connected graph**, not a todo list:

- **Life Areas** (Professional, Mindset, Sport, Finance, Learning, Relationships + custom) — each with its own XP, Level, Tier, Streak, State and Analytics. **No global level.**
- **Goals** (unlimited nesting) with one-time completion bonus, Tasks, Projects, Activities, Sessions, Skills, Categories, Evidence, Notes.
- **XP/Point Ledger** — append-only, auditable, multi-Life-Area allocations, idempotent, replayable.
- **Levels & Tiers** — configurable, data-driven (Wood → Mythic), overflow-safe.
- **Streaks** — per Life Area, pause/protect, Duolingo-style freeze model.
- **AI layer** — replaceable provider, structured Commands, confirmation-gated, audited.
- **Offline-first sync** — local Drift/SQLite + Supabase/PostgreSQL, outbox pattern, HLC, field-level LWW.

## Repository layout (monorepo)

```
kratos/
├── app/          # Flutter app (Web/PWA-first; Android/iOS-ready)
├── server/       # Supabase/PostgreSQL (migrations, RLS, RPCs)
├── packages/     # Shared Dart packages
│   ├── kratos_lints/     # Custom analyzer lint rules
│   ├── kratos_models/    # Domain model classes (pure Dart)
│   └── uuid_v7/          # RFC 9562 UUIDv7 implementation
├── tools/        # Codegen / schema / E2E scripts
└── docs/         # (symlinked view of kratos-spec — not yet)
```

## Spec

The authoritative architecture specification lives at **`C:\Users\hamza\kratos-spec\`** — see `00-MASTER-INDEX.md`.

## Status

See `07-Implementation_Status.md` in the spec folder for the live wave tracker.

## License

Proprietary — © 2026 Hamza. All rights reserved.