# Plan Review #2 — Cover the magic-link/deeplink verification path for OTP lockout

**Plan:** `106-cover-the-magic-link-deeplink-verification-path-for-otp-lockout.md`
**Files Reviewed:** 2 plan tasks against `UserNotifier`, `AuthCodeDeeplinkHandler`, `LoginViewModel`, `GlobalListeners`, `GlobalKeys`, `OtpLockedException`, `mind_ui` SnackBar exports, l10n ARB files
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** PASS — the handler lives in the App layer (`lib/Core/Handlers/`) and may depend on `mind_ui`, `mind_l10n`, and `GlobalKeys`. Not a module Service, so the stateless-service boundary rule does not apply.
- **Rules (`RULES.md`):** PASS — no rule touched. No new state/streams added to `App.dart`; no module Service mutated.
- **Roadmap (`ROADMAP.md`):** Linked — Phase 27 task, spec note `59-task-otp-lockout-deeplink.md`. The roadmap's explicit "guard against a double snackbar" acceptance criterion is **now satisfied for both the lockout and the generic failure case** (see Resolution of Prior Findings).

## Resolution of Prior Findings (review #1)

- **Critical Issue #1 (double snackbar on generic verify failure) — RESOLVED.** Task 1 now drops the `_authErrorSubject` publish **unconditionally** (keeping only `rethrow`), not just for `OtpLockedException`. Verified safe against the code:
  - Interactive path: `LoginViewModel.verifyCode` (lines 70–76) renders its own localized message via `onErrorEvent` for **both** `OtpLockedException` (`loginTooManyAttemptsError`) and the generic `catch (_)` (`loginCodeInvalidError`). It does **not** read `authErrorStream`, so dropping the publish loses no message and removes the pre-existing interactive double snackbar.
  - Deeplink path: Task 2 renders the localized message in the handler.
  - This yields exactly one localized snackbar for both the lockout and generic case on both paths.
- **Minor Issue (null-context bang) — RESOLVED.** Task 2 now mandates a real null guard (early-return when `rootScaffoldMessengerKey.currentContext == null`) and the suggested `_showLocalizedSnackBar` helper implements it correctly, mirroring `GlobalListeners`' null-safe `currentState?.showSnackBar`.

## Verified Assumptions (correct)

- l10n keys `loginTooManyAttemptsError` and `loginCodeInvalidError` exist in `app_en.arb` and `app_ru.arb` (lines 35–36). ✔
- `SnackBarEvent` and `SnackBarBuilder` are exported from `mind_ui` (`packages/mind_ui/lib/mind_ui.dart`); used exactly as `GlobalListeners._showSnackBar` does. ✔
- `OtpLockedException` exists at `lib/User/Models/OtpLockedException.dart` and is thrown from `AuthApi.verifyCode` on gRPC `RESOURCE_EXHAUSTED`. ✔
- `rootScaffoldMessengerKey` is wired to `MaterialApp.scaffoldMessengerKey` (`App.dart:263`), below `localizationsDelegates`/`locale`, so `AppLocalizations.of(context)` resolves the active locale. ✔
- `authErrorStream` is consumed **only** by `GlobalListeners` — `loginWithGoogle` does not (it relies on the separate line-81 publish, which Task 1 correctly leaves untouched). ✔
- Line references (`UserNotifier:51/56`, `AuthCodeDeeplinkHandler:23`) match current code. ✔
- Import list in Task 2 is complete and correct for the handler's new dependencies. ✔
- Cold-start magic link (`getInitialAppLink()`) correctly identified as a pre-existing, out-of-scope gap. ✔

## Critical Issues

None.

## Minor Issues

- **Unused catch variable lint.** Task 1's snippet keeps `} catch (e) { rethrow; }` where `e` is now unused. Depending on the analyzer config this may trigger `unused_catch_clause`. Trivial to avoid by writing `} catch (_) { rethrow; }` (or `} catch (e) { rethrow; }` if the lint is not enabled). Non-blocking — implementer can pick whichever form keeps the analyzer clean.

## Positive Notes

- The unconditional-drop resolution is simpler than a type-conditional publish and fixes all four cases (lockout/generic × interactive/deeplink) with one change.
- Reuses the existing global-snackbar mechanism rather than coupling the handler to `GlobalListeners`.
- Correctly leaves `DeeplinkRouter` untouched, with an accurate rationale (`onError` does not catch throws from the async data callback; once the handler swallows, nothing propagates).
- Scope guards are precise: `loginWithGoogle`'s separate publish is explicitly protected, and the cold-start gap is documented but not claimed as covered.

## Verdict

Both findings from review #1 are fully addressed, and all codebase assumptions re-verified against the current source. The only remaining item is a cosmetic lint nit that does not affect correctness.

PLAN_REVIEW_PASS
