# Requirements — handle OTP verify lockout (server side change)

**Date:** 2026-05-31
**Source:** cross-project security fix (mind_api Phase 27 — OTP brute-force protection)
**Status:** requirements only — pairs with mind_api Phase 27 task A; mobile is affected because the `VerifyCode` RPC behavior changes.

## What changes on the backend

mind_api is adding per-code brute-force protection to passwordless OTP. After **5 wrong code entries** for the same active code, the email is locked for **15 minutes**. The shared `verifyCode` logic backs both the web REST endpoint and the gRPC `VerifyCode` RPC the app uses (`AuthApi.dart` → `UserRepository` → `LoginViewModel`), so the app sees the new failure mode.

New error surface on `VerifyCode`:
- **Wrong code (not yet locked):** unchanged — gRPC `UNAUTHENTICATED`, message "Invalid or expired code".
- **Locked (≥5 misses, within 15 min):** gRPC **`RESOURCE_EXHAUSTED`** (mapped from HTTP 429), message "Too many attempts, request a new code". This is the new, distinct status — different from the wrong-code `UNAUTHENTICATED`.

Recovery: requesting a new code (`SendCode`) deletes the old code and resets the counter — but `SendCode` still has its own 60-second cooldown, so an immediate re-request may return `RESOURCE_EXHAUSTED` from the send side too (pre-existing behavior).

## Required app handling

1. **Distinguish "locked" from "wrong code" by gRPC status code**, not message text. On `VerifyCode`:
   - `RESOURCE_EXHAUSTED` → show a "too many attempts" state: tell the user to request a new code and try again in a few minutes. Do NOT present it as a generic "wrong code" error.
   - `UNAUTHENTICATED` → keep the existing "invalid or expired code" handling.
   Find where the app maps gRPC errors from `VerifyCode` (around `AuthApi.dart` / `LoginViewModel`) and add the `RESOURCE_EXHAUSTED` branch.

2. **Guide recovery in the UI.** From the locked state, the natural action is "Send a new code". Account for the `SendCode` 60s cooldown (also `RESOURCE_EXHAUSTED` from the send call) — surface a "try again shortly" message rather than a hard error.

3. **(Optional, nice-to-have) client-side attempt hint.** The server is the source of truth (5 tries / 15 min), but the app may soften UX by warning before the last attempt. Not required; do not try to mirror the exact counter — just react to the server status.

## Constraints / notes

- Do not weaken or work around the server lock (e.g. auto-resending codes on lockout) — it is the brute-force control.
- The proto contract for `VerifyCode` does not change (no new fields); only the returned status/message for the locked case is new. No stub regeneration needed.
- Ships with mind_api Phase 27. Until it ships, the app will simply never receive `RESOURCE_EXHAUSTED` from `VerifyCode`, so adding the branch early is safe.
