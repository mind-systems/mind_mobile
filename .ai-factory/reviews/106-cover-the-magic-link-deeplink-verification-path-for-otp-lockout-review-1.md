# Code Review — Cover the magic-link/deeplink verification path for OTP lockout

**Plan:** `106-cover-the-magic-link-deeplink-verification-path-for-otp-lockout.md`
**Changed source files:** `lib/User/UserNotifier.dart`, `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`
**Risk Level:** 🟡 Medium — code logic is correct, but the change breaks an existing test (red `flutter test`) and leaves a doc describing the removed behavior.

## Summary of the change

- `UserNotifier.completePasswordlessSignIn` no longer publishes `e.toString()` to `_authErrorSubject` on failure — the catch is now `} catch (e) { rethrow; }`.
- `AuthCodeDeeplinkHandler.handle` wraps the verify call in try/catch: `on OtpLockedException` → localized `loginTooManyAttemptsError` snackbar; generic `catch (_)` → localized `loginCodeInvalidError` snackbar; both swallow and return `true`. A `_showLocalizedSnackBar` helper resolves l10n via `rootScaffoldMessengerKey.currentContext` with a real null guard.

The core logic matches the plan and the prior plan reviews, and the analyzer is clean (`flutter analyze` on both files: *No issues found*). The interactive path was verified to still surface its own localized message (`LoginViewModel.verifyCode` → `LoginService.completePasswordlessSignIn` → `UserNotifier`, with `onErrorEvent` rendering `tooManyAttempts`/`codeInvalidOrExpired`), so dropping the publish loses no user-facing message there. `loginWithGoogle`'s separate publish (line 80) is correctly untouched.

## Critical Issues

### 1. Existing test now fails — `flutter test` is red (blocking)

`test/User/UserNotifier_test.dart:196` asserts the exact behavior this change removes:

```dart
test('emits error string when completePasswordlessSignIn fails', () async {
  final errorFuture = expectLater(
    userNotifier.authErrorStream,
    emits(contains('invalid code')),
  );
  final future = userNotifier.completePasswordlessSignIn('bad-code');
  fakeRepo.failSignIn(Exception('invalid code'));
  await expectLater(future, throwsA(isA<Exception>()));
  await errorFuture;
});
```

Since `completePasswordlessSignIn` no longer publishes on failure, the stream never emits. I ran the suite to confirm — this test times out after 30s and then fails (`emitted x Stream closed`):

```
00:30 +8 -1: authErrorStream emits error string when completePasswordlessSignIn fails [E]
  TimeoutException after 0:00:30.000000
  Expected: should emit an event that contains 'invalid code'
    Actual: emitted x Stream closed.
```

The plan's "Testing: no" setting overlooked that an existing regression test pins the old contract. This must be fixed before merge. The right fix is to flip this test to assert the **new** contract — that `completePasswordlessSignIn` does **not** emit on `authErrorStream` on failure (mirroring the adjacent `does NOT emit … when … succeeds` test), or delete it. Leaving it red blocks CI.

(The two other tests in that group — `does NOT emit … succeeds` and `does not replay old errors` — still pass, since they assert emptiness.)

## Minor Issues

### 2. Stale documentation — `docs/user/login-flow.md:32` now describes removed behavior

The doc states:

> Если аутентификация через диплинк падает, `UserNotifier` публикует сообщение в `authErrorStream`, `GlobalListeners` показывает снэкбар…

After this change the deeplink path no longer routes failures through `authErrorStream`/`GlobalListeners` — `AuthCodeDeeplinkHandler` now shows a localized snackbar directly. The sentence is now factually wrong for the deeplink path. The plan set "Docs: no," but this existing paragraph actively contradicts the new code and should be updated to describe the handler-localized snackbar (lockout → `loginTooManyAttemptsError`, otherwise → `loginCodeInvalidError`).

### 3. Unused catch variable (cosmetic, non-blocking)

`} catch (e) { rethrow; }` in `UserNotifier` leaves `e` unused. `flutter analyze` reports no issue under the project's `flutter_lints` config, so this is purely stylistic — could be `} catch (_) {` for clarity, but no action required.

## Non-issues verified

- **Exception ordering** — `on OtpLockedException` precedes the generic `catch (_)`; the typed branch is reachable. ✔
- **Null-context guard** — real early-return, not a `!` bang; `AppLocalizations.of(context)!` is only reached after the null check, and `currentState?.showSnackBar` is null-safe. ✔
- **Redundant `return true`** — both catch branches return `true` and the success path falls through to the trailing `return true`; correct, just slightly verbose. Not a bug.
- **No uncaught escape** — both failure branches are swallowed, so `DeeplinkRouter._handleDeepLink`'s un-try/caught `await` no longer propagates to the zone. ✔
- **Locale resolution** — `rootScaffoldMessengerKey` is wired to `MaterialApp.scaffoldMessengerKey` below `localizationsDelegates`/`locale`, so `AppLocalizations.of` resolves the active language. ✔

## Verdict

The implementation is logically correct and matches the plan, but it ships with a failing test (Critical #1) and a now-inaccurate doc paragraph (Minor #2). Update `UserNotifier_test.dart` to assert the new no-publish contract (and ideally fix the login-flow doc), then re-run `flutter test` to confirm green.
