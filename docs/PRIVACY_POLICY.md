# KRATOS — Privacy Policy & Data Sovereignty

> Last Updated: September 23, 2026 | Effective: v1.0.0 Release

## 1. Core Commitment: Local-First Data Sovereignty
KRATOS is built on a strict **local-first** architecture. Your daily goals, tasks, notes, sessions, and XP progression live primarily on your physical device in an offline-first SQLite database.

## 2. Information We Process
- **Account Data**: When syncing across devices, your account identifier and email are handled securely via Supabase Authentication.
- **Voice Notes & Audio**: Audio memos recorded through QuickCapture are transcribed using local/dedicated transcription models. Raw audio files are stored in your private storage container and are never shared.
- **AI Interactions**: AI Habit Coach and plan decomposition queries are processed via secure endpoints. As defined by Invariant #11, AI is strictly advisory and cannot mutate your personal state without explicit confirmation.
- **Telemetry**: Application diagnostics (such as database query latency and crash logs) are completely anonymized and stripped of personal content.

## 3. Data Ownership and Export
You retain 100% ownership of your data at all times:
- **Full JSON Export**: Download your complete life area, goal, task, note, and XP history at any time.
- **Right to Erasure (Trash & Purge)**: Soft-deleted items are held in your 30-day trash bin and can be restored or immediately purged permanently (ADR-012).

## 4. Third-Party Sharing
KRATOS does **NOT** sell, rent, or monetize your personal data or habit history to advertisers or third parties.
