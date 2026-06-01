# Plan Review — Cover the magic-link/deeplink verification path for OTP lockout

**Plan:** `106-cover-the-magic-link-deeplink-verification-path-for-otp-lockout.md`
**Files Reviewed:** 2 plan tasks against `UserNotifier`, `AuthCodeDeeplinkHandler`, `DeeplinkRouter`, `GlobalListeners`, `GlobalKeys`, `LoginViewModel`, `App.dart`, l10n + spec note 59
**Risk Level:** 🟡 Medium

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN — none. The handler lives in the App layer (`lib/Core/Handlers/`) and is allowed to depend on `mind_ui`, `mind_l10n`, and `GlobalKeys`. No module-boundary violation (it is not a Module Service, so `RULES.md`'s stateless-service rule does not apply).
- **Rules (`RULES.md`):** PASS — no rule touched. No new state/streams added to `App.dart`; no module Service mutated.
- **Roadmap (`ROADMAP.md`):** Linked. Phase 27, the open task "Cover the magic-link/deeplink verification path for OTP lockout" (line 265), spec note `59-task-otp-lockout-deeplink.md`. The roadmap states an explicit acceptance requirement: **"guard against a double snackbar."** See the Critical Issue below — the plan satisfies this for the lockout case but **violates it for the generic verify-failure case**.

## Verified Assumptions (correct)

- l10n keys `loginTooManyAttemptsError` and `loginCodeInvalidError` exist in `app_en.arb`/`app_ru.arb` and on `AppLocalizations`. ✔
- `SnackBarEvent.error(...)` and `SnackBarBuilder.build(...)` are exported from `mind_ui`; `AppLocalizations` from `mind_l10n`. ✔ (Plan uses them exactly as `GlobalListeners` already does.)
- All import paths are correct (`OtpLockedException`, `GlobalKeys`, `mind_ui`, `mind_l10n`). ✔
- `rootScaffoldMessengerKey` is wired to `MaterialApp.scaffoldMessengerKey` (`App.dart:263`) **below** `localizationsDelegates`/`locale`. Flutter builds the `ScaffoldMessenger` inside `WidgetsApp`'s builder, beneath the `Localizations` widget, so `AppLocalizations.of(rootScaffoldMessengerKey.currentContext!)` resolves the active locale. ✔
- `uriLinkStream.listen(onError:)` does **not** catch exceptions thrown from the async data callback — they escape to the zone uncaught. So wrapping the call in the handler is the correct fix, and leaving `DeeplinkRouter` unchanged is valid. ✔
- Line references (`UserNotifier:51/56`, `AuthCodeDeeplinkHandler:23`, `DeeplinkRouter onError`) match the current code. ✔
- `authErrorStream` is consumed **only** by `GlobalListeners` (raw `'Ошибка входа: $error'`), confirming the source-suppression reasoning. ✔

## Critical Issues

### 1. Generic deeplink verify failure produces a DOUBLE snackbar — violates the roadmap's "guard against a double snackbar" requirement

Task 1 suppresses the raw `authErrorStream` publish **only** for `OtpLockedException` (`if (e is! OtpLockedException) _authErrorSubject.add(e.toString())`). Task 2, however, adds a **generic** `catch (_)` on the deeplink path that shows the localized `loginCodeInvalidError` snackbar for "any other verify failure."

Trace a generic (non-lockout) magic-link failure — e.g. an **expired or already-used link**, which is the *most common* deeplink failure:

1. `AuthCodeDeeplinkHandler.handle` → `completePasswordlessSignIn(code)`
2. `UserNotifier` catch: `e` is **not** `OtpLockedException` → **still publishes** `e.toString()` → `GlobalListeners` shows `'Ошибка входа: …'` (raw, non-localized). Then `rethrow`.
3. Handler's generic `catch (_)` → shows localized `loginCodeInvalidError`.

**Result: two snackbars** (raw + localized) for the generic case — a regression versus today's single raw snackbar, and a direct breach of the roadmap's "guard against a double snackbar" acceptance criterion. The plan's "exactly one clean message" claim holds **only** for the lockout branch.

Note this same gap pre-exists on the *interactive* path: `LoginViewModel.verifyCode`'s generic `catch (_)` shows `codeInvalidOrExpired` while `UserNotifier` also publishes the raw error → double snackbar there too. The plan inherits the flaw from spec note 59 (§18 + §27) rather than introducing it, but it does not fix it and actively extends it to the deeplink path.

**Recommended fix (simpler than the plan's conditional and fixes all cases):** In Task 1, drop the publish for the *entire* `completePasswordlessSignIn` catch rather than only for `OtpLockedException`. Both verify-path callers now render their own localized message (interactive via `LoginViewModel.onErrorEvent`, deeplink via Task 2), so the raw `authErrorStream` publish from this method is fully redundant:

```dart
} catch (e) {
  rethrow; // both callers surface a localized message; no raw publish needed
}
```

This yields exactly one localized snackbar for **both** the lockout and the generic case, on **both** the interactive and deeplink paths, and removes the pre-existing interactive double-snackbar. `loginWithGoogle`'s separate publish (line 81) is untouched. If you prefer to keep the change minimal and OTP-scoped, then Task 2 must *not* add a generic localized snackbar (let the existing raw one stand) — but that contradicts the stated goal of localized messages, so the broader suppression is the better resolution.

## Minor Issues

- **Null-context guard is described inconsistently.** Task 2 prose says "guard the nullable context before use," but the inline guidance uses `AppLocalizations.of(rootScaffoldMessengerKey.currentContext!)` with a bang. The implementation should early-return (skip the snackbar) when `rootScaffoldMessengerKey.currentContext == null`, mirroring the null-safe `currentState?.showSnackBar` pattern in `GlobalListeners`. In practice the running-app deeplink path has a mounted tree so the context is non-null, but the guard should be real, not a `!`.
- **Cold-start link is out of scope (acceptable).** `DeeplinkRouter` only listens to `uriLinkStream` and never reads `getInitialAppLink()`, so a magic link that launches the app from a terminated state is not handled by this path at all. Pre-existing gap, unrelated to this milestone — noted only so it is not mistaken for something this plan covers.

## Positive Notes

- Correctly identifies that `authErrorStream` is `Stream<String>` and therefore the exception type can only be discriminated inside `UserNotifier`, not in `GlobalListeners` — avoiding the message-text-matching anti-pattern.
- Correctly reuses the existing global-snackbar mechanism (`rootScaffoldMessengerKey` + `SnackBarBuilder`) instead of inventing a new presentation channel, keeping the handler free of `GlobalListeners` knowledge.
- Correctly leaves `DeeplinkRouter` untouched and explains why (`onError` does not catch callback throws; once the handler swallows, nothing propagates).
- Task dependency ordering (Task 2 depends on Task 1) and l10n-key reuse from the prior interactive task are accurate.
- Settings (no tests, minimal logging, no docs) are reasonable for a small two-file change.

## Verdict

The plan is well-researched and its codebase assumptions check out, but it does not fully satisfy the roadmap's explicit "guard against a double snackbar" requirement: the generic (expired/invalid) magic-link failure will show two snackbars. Address Critical Issue #1 (broaden the source suppression) and tighten the null-context guard, then it is ready to implement.
