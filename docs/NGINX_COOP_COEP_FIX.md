# Nginx / OpenResty — Required Headers for KRATOS Web (Drift Wasm)

## Why this is needed

Drift's Wasm SQLite engine on the web uses `SharedArrayBuffer` for multi-threaded
operation. Browsers only expose `SharedArrayBuffer` when the page is **cross-origin
isolated**, which requires both these response headers to be set on **every response**:

| Header | Required value |
|---|---|
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Embedder-Policy` | `require-corp` |

Without them, `WasmDatabase.open()` hangs or falls back to in-memory mode and
`onboardingService.isCompleted()` never resolves → the app is permanently stuck on
the loading spinner after Google OAuth.

---

## Nginx / OpenResty config snippet

Add the following inside the **`server { ... }`** block that serves `kratos-os.online`:

```nginx
# ─────────────────────────────────────────────────────────────────────────────
# KRATOS Web — Required Cross-Origin Isolation headers for Drift Wasm SQLite
# ─────────────────────────────────────────────────────────────────────────────

# SharedArrayBuffer isolation (Drift / sqlite3.wasm)
add_header Cross-Origin-Opener-Policy  "same-origin" always;
add_header Cross-Origin-Embedder-Policy "require-corp" always;

# Security hardening (already present — keep them)
add_header X-Content-Type-Options  "nosniff" always;
add_header X-Frame-Options         "SAMEORIGIN" always;
add_header X-XSS-Protection        "\"1; mode=block\"" always;
add_header Referrer-Policy         "no-referrer-when-downgrade" always;
add_header Strict-Transport-Security "max-age=31536000" always;

# Correct MIME type for the Wasm binary (REQUIRED for browsers to load it)
location ~* \.wasm$ {
    add_header Content-Type "application/wasm" always;
    add_header Cross-Origin-Opener-Policy  "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
}

# Service worker & JS workers (drift_worker.js) — COEP must travel with them
location ~* \.(js|mjs)$ {
    add_header Cross-Origin-Opener-Policy  "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
}
```

> **Important:** In nginx/OpenResty, `add_header` directives in a child `location`
> block **override** the parent's `add_header` calls. Always repeat COOP/COEP in
> every `location` block that you define.

---

## After applying

1. Test: `nginx -t` then `nginx -s reload`
2. Verify with curl:
   ```bash
   curl -I https://kratos-os.online/ | grep -i "cross-origin"
   # Expected:
   # cross-origin-opener-policy: same-origin
   # cross-origin-embedder-policy: require-corp
   ```
3. Verify `.wasm` MIME type:
   ```bash
   curl -I https://kratos-os.online/sqlite3.wasm | grep -i content-type
   # Expected: content-type: application/wasm
   ```

---

## Flutter / Dart code fixes applied alongside this (2026-09-28)

| File | Fix |
|---|---|
| `app/lib/app/kratos_app.dart` | `_loadOnboarding` now has `try/catch/finally` + 12-second timeout. If Drift hangs/throws, `_checkingOnboarding` is reset and the app falls through to the onboarding screen instead of spinning forever. |
| `app/lib/features/auth/data/supabase_auth_service.dart` | Auth stream now has `onError` handler — silent auth errors are logged and fall back to `AuthUnauthenticated`. Google OAuth `redirectTo` now explicitly uses `Uri.base.origin` on web to prevent PKCE verifier mismatch. |
