# Task Spec — Cover the magic-link/deeplink verification path for OTP lockout

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 27
**Provenance:** note 45 + deeplink-path review. Depends on note 58.

## Current state
`lib/Core/Handlers/AuthCodeDeeplinkHandler.dart:23` verifies the code via `_userNotifier.completePasswordlessSignIn(code)` **directly, bypassing `LoginViewModel`**, and its caller `DeeplinkRouter._handleDeepLink` (`lib/Core/DeeplinkRouter.dart:28`) does `await _authCodeHandler.handle(uri)` with NO try/catch — while `uriLinkStream.listen(onError:)` only catches stream errors, not exceptions thrown from the async callback. So any verify failure on the magic-link path (including the new `OtpLockedException` from note 58) escapes **uncaught**.

Reachable when an email is already locked (by prior interactive misses or API brute-force) and the user taps a legitimate magic link → `RESOURCE_EXHAUSTED`.

Behavior nuance: `UserNotifier.completePasswordlessSignIn` already publishes `e.toString()` to `authErrorStream`, which `GlobalListeners` surfaces as a raw, non-localized snackbar (`'Ошибка входа: Instance of 'OtpLockedException''`) via `rootScaffoldMessengerKey` — so this path today shows an ugly message AND throws uncaught.

## Target

Two coordinated changes — chosen path resolves the double-snackbar concretely:

1. **Suppress the raw double-snackbar at the source.** `UserNotifier.completePasswordlessSignIn`'s catch currently does `_authErrorSubject.add(e.toString()); rethrow;`. Change it to skip the publish for the typed OTP exception:
   ```dart
   } catch (e) {
     if (e is! OtpLockedException) _authErrorSubject.add(e.toString());
     rethrow;
   }
   ```
   **Why here, not in `GlobalListeners`:** `authErrorStream` is `Stream<String>` carrying `e.toString()` (`UserNotifier._authErrorSubject` is `PublishSubject<String>`) — `GlobalListeners` only has the string and cannot type-check the exception without matching on message text (the anti-pattern we avoid). The exception object is in scope only here. Note: `OtpSendCooldownException` flows from the `sendCode` path, which does NOT publish to `authErrorStream`, so only `OtpLockedException` needs suppressing.

2. **Handle the exception on the deeplink path.** In `AuthCodeDeeplinkHandler.handle` (or `DeeplinkRouter._handleDeepLink`), wrap the `completePasswordlessSignIn(code)` call in try/catch: on `OtpLockedException`, show the localized `tooManyAttempts` message via the global `rootScaffoldMessengerKey` snackbar (no `BuildContext` on this path); on a generic verify failure (currently fully unhandled here), show the localized invalid/expired message. Swallow both so nothing escapes uncaught.

Net result: exactly one clean, localized snackbar on the magic-link lockout; the handler needs no knowledge of `GlobalListeners`.

## Guards
- Depends on note 58 (reuses `OtpLockedException`, `LoginError.tooManyAttempts`, and its l10n keys). Independently shippable after it.
- The source suppression also removes the redundant raw `'Ошибка входа: …'` snackbar on the INTERACTIVE path (where `LoginViewModel.onErrorEvent` already shows the localized message) — a welcome side-effect, not a regression.

## Files
- `lib/User/UserNotifier.dart` (suppress the OTP publish at source)
- `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart` (or `lib/Core/DeeplinkRouter.dart`)
