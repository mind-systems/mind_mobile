# Code Review: Fix Google Sign-In silent failure on network errors

**Branch:** dev
**Scope reviewed:** `lib/User/Infrastructure/GoogleAuthProvider.dart` (only code change in the diff)
**Plan:** `.ai-factory/plans/62-fix-google-sign-in-silent-failure-on-network-errors.md`

## Summary

The change removes the `try`/`on GoogleSignInException` wrapper from `_gmsFlow()`, so every GMS failure (including `canceled`) now bubbles to `getServerAuthCode()`'s outer `catch (e)` and falls through to `_browserFlow()`. This matches the plan exactly. The change is minimal and the core logic is correct:

- `_gmsFlow()` no longer conflates user-cancel with technical failure. ✓
- The `google_sign_in` import is still required (`GoogleSignIn.instance`), so removing the `GoogleSignInExceptionCode`/`GoogleSignInException` references leaves no dangling/unused import. ✓
- `GoogleSignInCanceledException` import is still used (in `_browserFlow()` and `getServerAuthCode()`). ✓
- Downstream contract is unchanged: `UserRepository.getGoogleServerAuthCode()` and `UserNotifier.loginWithGoogle()` still receive the same record shape and still swallow `GoogleSignInCanceledException` (line 68–70) — correct for the browser cancel path.
- Existing tests use interface fakes (`FakeGoogleAuthProvider` in `UserRepository_test.dart`, `UserNotifier_test.dart`) that do not exercise `_gmsFlow()` internals, so nothing in the test suite breaks.

No bugs, no security issues, no runtime-breaking problems found in the diff. The two items below are low-severity / informational and do not block.

## Findings

### LOW-1 — Dead `on GoogleSignInCanceledException` clause in `getServerAuthCode()`

`getServerAuthCode()` (lines 13–22) still has:

```dart
try {
  return await _gmsFlow();
} on GoogleSignInCanceledException {
  rethrow;
} catch (e) {
  ... return await _browserFlow();
}
```

After this change, `_gmsFlow()` can no longer throw `GoogleSignInCanceledException` — it is the only call in the `try` block — so the `on GoogleSignInCanceledException { rethrow; }` clause is now unreachable dead code.

The plan's stated rationale for keeping it ("preserves the browser-flow cancel-silently behavior") is inaccurate: `_browserFlow()` is invoked **inside the `catch` block**, not the `try`, so any `GoogleSignInCanceledException` it throws propagates directly out of `getServerAuthCode()` without passing through this clause. Behavior is therefore still correct (browser cancel → propagates → `UserNotifier` swallows), but the clause itself no longer does anything.

Not blocking. Optional cleanup: remove the dead `on GoogleSignInCanceledException { rethrow; }` clause, leaving just `try { return await _gmsFlow(); } catch (e) { … _browserFlow(); }`. Leaving it in is harmless.

### LOW-2 — Milestone goal depends on browser flow surfacing a non-cancel exception when offline (verify manually)

The milestone's primary goal is that a GMS **network** failure becomes user-visible. After this change the path is: GMS network error → outer catch → `_browserFlow()`. `_browserFlow()` only raises a non-silent error when `FlutterWebAuth2.authenticate` throws a non-`CANCELED` exception. Because `FlutterWebAuth2` opens a system browser/custom tab rather than performing its own HTTP request, a device-offline condition typically manifests as a failed page inside the browser, after which the user closes it → `PlatformException(CANCELED)` → `GoogleSignInCanceledException` → swallowed silently (line 68–70).

So it is possible that the offline-GMS scenario remains silent in practice, depending on platform/`FlutterWebAuth2` behavior. This is the accepted trade-off documented in the spec note (`.ai-factory/notes/127-fix-google-signin-silent-failure.md`), and the note's verification step 1 ("Disable network on device, tap Google Sign-In → snackbar must appear") is exactly the check that confirms whether the goal is met. Recommend executing that manual verification before considering the milestone closed; this is a behavioral confirmation, not a code defect in the diff.

## Verification performed

- `git status` / `git diff HEAD` — only `GoogleAuthProvider.dart` changed in `lib/` (plus plan/review artifacts).
- Read `GoogleAuthProvider.dart` in full; traced error propagation through `UserRepository.getGoogleServerAuthCode()` and `UserNotifier.loginWithGoogle()`.
- Grepped all `.dart` usages of `GoogleSignInCanceledException`, `getServerAuthCode`, `getGoogleServerAuthCode`, `authErrorSubject` across `lib/` and `test/` — no caller depends on the removed catch behavior.
