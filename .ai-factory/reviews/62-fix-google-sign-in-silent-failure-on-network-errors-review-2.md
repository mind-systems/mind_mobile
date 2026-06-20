# Code Review (Pass 2): Fix Google Sign-In silent failure on network errors

**Branch:** dev
**Scope reviewed:** `lib/User/Infrastructure/GoogleAuthProvider.dart` (only code change in the diff)
**Plan:** `.ai-factory/plans/62-fix-google-sign-in-silent-failure-on-network-errors.md`

## What changed since pass 1

The diff now does two things:

1. Removes the `try`/`on GoogleSignInException` wrapper from `_gmsFlow()` (the planned change).
2. **Also removes the `on GoogleSignInCanceledException { rethrow; }` clause from `getServerAuthCode()`** — this resolves LOW-1 from review-1 (that clause was unreachable dead code once `_gmsFlow()` stopped throwing `GoogleSignInCanceledException`).

This is a deviation from the plan (which said to keep that clause), but it is a **correct and behavior-neutral** deviation — the clause could never fire after the `_gmsFlow()` change, so removing it changes nothing at runtime and leaves the method cleaner.

## Correctness analysis

`getServerAuthCode()` now:

```dart
try {
  return await _gmsFlow();
} catch (e) {
  logPrint('[GoogleAuthProvider] GMS failed ($e), falling back to browser flow');
  return await _browserFlow();
}
```

Traced paths:

- **GMS success** → returns server auth code. ✓
- **GMS any failure** (cancel, network, `MissingPluginException`, `PlatformException`, null serverAuth) → caught by `catch (e)` → logged → `_browserFlow()`. ✓ This is the intended fix: GMS cancel and GMS technical failure are no longer distinguished, both proceed to the browser flow.
- **Browser cancel** → `_browserFlow()` throws `GoogleSignInCanceledException` from inside the `catch` block; Dart does not re-apply the same `try`/`catch` to exceptions raised in its `catch` block, so it propagates directly out of `getServerAuthCode()` → `UserNotifier.loginWithGoogle()` swallows it (return on `GoogleSignInCanceledException`). ✓ Silent, as intended.
- **Browser non-cancel failure** (e.g. network, missing code) → regular `Exception`/`PlatformException` propagates out → `UserNotifier` catch → `_authErrorSubject.add('Failed to sign in with Google')` → snackbar. ✓

Imports and symbols:

- `package:google_sign_in/google_sign_in.dart` still required (`GoogleSignIn.instance`, `authorizationClient`). No unused import. ✓
- `GoogleSignInCanceledException` import still used in `_browserFlow()` (line 58). ✓
- `flutter/services.dart` (`PlatformException`) still used in `_browserFlow()`. ✓
- No remaining references to `GoogleSignInException` / `GoogleSignInExceptionCode`; nothing dangling. ✓

Test impact: `UserRepository_test.dart` and `UserNotifier_test.dart` use interface fakes (`FakeGoogleAuthProvider`) that implement `getServerAuthCode()` directly and never exercise `_gmsFlow()` internals — no test breaks. ✓

No bugs, no security issues, no type mismatches, no race conditions, no missing-migration concerns (pure client-side control-flow change).

## Informational note (no code change required)

The milestone's end-to-end goal — that a **GMS network** failure becomes user-visible — depends on `_browserFlow()` surfacing a non-`CANCELED` exception when the device is offline. `FlutterWebAuth2.authenticate` opens a system browser rather than making its own HTTP request, so an offline condition may instead show a failed page that the user closes → `PlatformException(CANCELED)` → silent. This is the accepted trade-off documented in `.ai-factory/notes/127-fix-google-signin-silent-failure.md`, whose verification step 1 ("disable network, tap Google Sign-In → snackbar must appear") is the manual check that confirms it. This is a verification reminder, not a defect in the diff, and requires no code change.

## Verdict

No blocking findings. The code change is minimal, correct, and the prior dead-code observation is now resolved.

REVIEW_PASS
