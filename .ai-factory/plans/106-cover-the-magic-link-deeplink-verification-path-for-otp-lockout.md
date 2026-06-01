# Plan: Cover the magic-link/deeplink verification path for OTP lockout

## Context
The magic-link/deeplink verification path (`AuthCodeDeeplinkHandler` → `UserNotifier.completePasswordlessSignIn`) currently lets verify failures — including the typed `OtpLockedException` from the previous task — escape **uncaught**, and surfaces a raw, non-localized `'Ошибка входа: …'` snackbar. This milestone catches the failure on the deeplink path, shows the same localized recovery message via the global snackbar, and removes the redundant raw snackbar so **both** the lockout and the generic (expired/invalid link) case show exactly one clean, localized message.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Drop the redundant raw `authErrorStream` publish in `completePasswordlessSignIn`**
  Files: `lib/User/UserNotifier.dart`
  In `completePasswordlessSignIn` (line 51), change the `catch (e)` block to stop publishing to `_authErrorSubject` entirely — keep only the `rethrow`:
  ```dart
  } catch (e) {
    rethrow; // both callers surface a localized message; no raw publish needed
  }
  ```
  Rationale: this method's raw publish is the source of the double snackbar. Both verify-path callers already render their own localized message — the interactive path via `LoginViewModel.onErrorEvent`, and the deeplink path via Task 2 — so the raw `'Ошибка входа: …'` snackbar that `GlobalListeners` shows off `authErrorStream` is fully redundant in every case. Dropping the publish unconditionally yields exactly one localized snackbar for BOTH the lockout and the generic (expired/invalid link) case, on BOTH paths, and also removes the pre-existing interactive-path double snackbar. This is what satisfies the roadmap's "guard against a double snackbar" requirement for the generic failure, not just the lockout one.
  Scope guard: `authErrorStream` is consumed only by `GlobalListeners`, so removing this publish affects nothing else. Do NOT touch `loginWithGoogle`'s separate `_authErrorSubject.add('Failed to sign in with Google')` (line 81) — that path has no other localized presenter and must keep its publish. No new import is needed (the catch no longer type-checks the exception).

- [x] **Task 2: Catch verify failures on the deeplink path and show a localized snackbar** (depends on Task 1)
  Files: `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`
  Wrap the `await _userNotifier.completePasswordlessSignIn(code)` call (line 23) in a `try/catch`. Swallow both branches so nothing escapes uncaught (the `onError:` on `uriLinkStream.listen` in `DeeplinkRouter` does not catch exceptions thrown from the async callback):
  - `on OtpLockedException` → show the localized `loginTooManyAttemptsError` message.
  - generic `catch (_)` (any other verify failure, e.g. an expired/already-used link, currently fully unhandled here) → show the localized `loginCodeInvalidError` message.
  - Return `true` in both cases (the link was a recognized auth deeplink and was handled).

  There is no `BuildContext` on this path. Show the snackbar via the global key exactly as `GlobalListeners` does — build a `SnackBarEvent.error(message)` with `SnackBarBuilder.build(...)` and call `rootScaffoldMessengerKey.currentState?.showSnackBar(...)`.

  Obtain the localized strings from `AppLocalizations.of(...)` using `rootScaffoldMessengerKey.currentContext` (the `ScaffoldMessenger` sits below `MaterialApp`'s `localizationsDelegates`/`locale`, so the lookup resolves the current language). **Use a real null guard, not a `!` bang** — early-return and skip the snackbar when `rootScaffoldMessengerKey.currentContext == null`, mirroring the null-safe `currentState?.showSnackBar` pattern in `GlobalListeners`. Suggested shape:
  ```dart
  } on OtpLockedException {
    _showLocalizedSnackBar((l10n) => l10n.loginTooManyAttemptsError);
    return true;
  } catch (_) {
    _showLocalizedSnackBar((l10n) => l10n.loginCodeInvalidError);
    return true;
  }
  ```
  ```dart
  void _showLocalizedSnackBar(String Function(AppLocalizations) pick) {
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null) return;
    final message = pick(AppLocalizations.of(context)!);
    rootScaffoldMessengerKey.currentState
        ?.showSnackBar(SnackBarBuilder.build(SnackBarEvent.error(message)));
  }
  ```

  Add imports: `package:flutter/material.dart`, `package:mind_ui/mind_ui.dart` (`SnackBarEvent`, `SnackBarBuilder`), `package:mind_l10n/mind_l10n.dart` (`AppLocalizations`), `package:mind/Core/GlobalUI/GlobalKeys.dart` (`rootScaffoldMessengerKey`), and `package:mind/User/Models/OtpLockedException.dart`.

  Leave `DeeplinkRouter._handleDeepLink` unchanged — once the handler swallows its own failures, `await _authCodeHandler.handle(uri)` no longer throws.

  Net result: exactly one clean, localized snackbar on both the magic-link lockout and the generic verify failure; the handler needs no knowledge of `GlobalListeners`.

## Out of scope (noted, not addressed)
- **Cold-start magic link.** `DeeplinkRouter` only listens to `uriLinkStream` and never reads `getInitialAppLink()`, so a magic link that launches the app from a terminated state is not handled by this path at all. Pre-existing gap, unrelated to this milestone.
