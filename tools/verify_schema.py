#!/usr/bin/env python3
"""KRATOS Wave 2 — schema verification tool.

Verifies that the SQL migrations under server/migrations/ match the
architectural table inventory, UUID/HLC/con/constraint conventions.

Usage: python tools/verify_schema.py
Exit code 0 = verified, 1 = mismatch.
"""
import re, sys
from pathlib import Path

MIGRATIONS = Path(__file__).resolve().parent.parent / "server" / "migrations"

EXPECTED_TABLES = {
    # 0001 core
    "users", "life_areas", "categories", "category_actions",
    "category_xp_rule_versions", "goals", "projects", "tasks",
    "task_goal_links", "activities", "sessions",
    # 0002 xp
    "xp_ledger", "xp_allocation_lines", "user_streaks", "streak_pauses",
    # 0003 sync
    "sync_outbox", "sync_cursors", "sync_tombstones",
    # 0004 aux
    "notes", "audios", "achievements", "evidence", "ai_artifacts",
    "files", "links", "attachment_links", "skills", "tools",
    "skill_tools", "task_tool_links",
}

EXPECTED_COLUMNS = {
    # Note: 'users' uses 'device_id' (auth is external via Supabase/SSO); no email column.
    # Color/icon/version_hlc are on most entity tables for soft delete + sync ordering.
    "users": {"id", "device_id", "display_name", "created_at", "updated_at"},
    "life_areas": {"id", "owner_id", "name", "color", "version_hlc"},
    "categories": {"id", "owner_id", "name", "version_hlc"},
    "xp_ledger": {"id", "owner_id", "idempotency_key", "source_type",
                  "source_id", "action", "points", "version_hlc", "device_id"},
    "xp_allocation_lines": {"id", "ledger_id", "life_area_id", "allocated_points", "percentage"},
    "user_streaks": {"user_id", "life_area_id", "current_streak", "longest_streak"},
    "sync_outbox": {"seq", "user_id", "op", "entity", "entity_id", "payload_json", "hlc", "device_id", "status"},
    "sync_tombstones": {"id", "user_id", "entity", "entity_id", "deleted_at", "deleted_hlc"},
    "goals": {"id", "owner_id", "parent_id", "root_id", "path", "depth"},
    "skills": {"id", "owner_id", "name", "xp_total", "level"},
    "attachment_links": {"id", "attachment_id", "attachment_kind", "entity_id", "entity_kind"},
}


def read_sql() -> str:
    files = sorted(MIGRATIONS.glob("*.sql"))
    if not files:
        print(f"ERROR: no SQL files in {MIGRATIONS}")
        sys.exit(1)
    return "\n".join(f.read_text(encoding="utf-8") for f in files)


def main() -> int:
    sql = read_sql()
    errors = []

    # 1. table presence
    for t in sorted(EXPECTED_TABLES):
        if not re.search(rf"CREATE TABLE(?: IF NOT EXISTS)?\s+{re.escape(t)}\b", sql):
            errors.append(f"missing table: {t}")

    # 2. column presence (only checked for tables with expectations)
    for table, cols in EXPECTED_COLUMNS.items():
        m = re.search(rf"CREATE TABLE(?: IF NOT EXISTS)?\s+{re.escape(table)}\s*\((.*?)\);",
                      sql, re.S)
        if not m:
            continue  # already reported missing
        body = m.group(1)
        for col in cols:
            if not re.search(rf"\b{re.escape(col)}\b", body):
                errors.append(f"table {table}: missing column {col}")

    # 3. conventions
    if "idempotency_key" in sql and "UNIQUE" not in re.search(
            r"idempotency_key\s+uuid[^,]*", sql).group(0):
        errors.append("xp_ledger.idempotency_key must be UNIQUE")

    if "version_hlc" in sql and "text" not in re.search(r"version_hlc\s+\w+", sql).group(0):
        errors.append("version_hlc must be text")

    # RLS count: the 0005 migration uses DO $$ ... LOOP ... ENABLE ROW LEVEL SECURITY
    # (one enable per table in a dynamic block). Count by table name referenced in
    # EXECUTE format() calls instead of the static string.
    rls_table_refs = re.findall(
        r"EXECUTE\s+format\([^)]*format\(\s*'ENABLE ROW LEVEL SECURITY[^\n]*'%s[^)]*\),?\s*(?:t)?\.[^\n]*\)\s*USING\s+([\w.\"]+)",
        sql, re.I | re.S)
    # Easier: count "ALTER TABLE x ENABLE ROW LEVEL SECURITY" occurrences.
    rls_count = len(re.findall(
        r"ALTER\s+TABLE\s+[\w\.\"]+\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY", sql, re.I))
    if rls_count < 30:
        errors.append(f"RLS enable count = {rls_count} (< 30)")

    if errors:
        print("SCHEMA VERIFICATION FAILED")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"SCHEMA VERIFICATION PASSED: {len(EXPECTED_TABLES)} tables, "
          f"{sql.count('CREATE TABLE')} CREATE TABLE statements, "
          f"{sql.count('CREATE INDEX')} indexes, RLS enabled.")
    return 0


if __name__ == "__main__":
    sys.exit(main())