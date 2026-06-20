# Plan Review: Fix Google Sign-In silent failure on network errors

**Plan:** `62-fix-google-sign-in-silent-failure-on-network-errors.md`
**Files Reviewed:** 1 plan + 7 source/test files
**Risk Level:** 🟢 Low

## Verdict

The plan is correct, well-scoped, and matches the codebase exactly. The root-cause analysis is accurate: `_gmsFlow()` converts `GoogleSignInException(canceled)` into `GoogleSignInCanceledException`, which `UserNotifier.loginWithGoogle()` swallows via the `on GoogleSignInCanceledException { return; }` at `lib/User/UserNotifier.dart:68`, so a GMS *technical* failure is indistinguishable from a deliberate cancel and produces no UI feedback. Removing the catch lets all GMS failures fall to the outer `catch (e)` in `getServerAuthCode()` (line 18) and route to `_browserFlow()`. Verified.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** PASS — change is confined to a single Infrastructure provider, no boundary or DI changes.
- **Rules (`RULES.md`):** PASS — rules concern Module Services / App.dart / constructor injection; none apply to this edit.
- **Roadmap (`ROADMAP.md`):** WARN (non-blocking) — this is a bug fix; the plan does not reference a roadmap milestone. Optional linkage only.

## Verified Claims

- **Error path is real end-to-end.** `_authErrorSubject.add('Failed to sign in with Google')` (`UserNotifier.dart:80`) → `authErrorStream` (line 39) → wired in `App.dart:296` → `GlobalListeners._authErrorSubscription` → `SnackBarEvent.error('Ошибка входа: $error')` (`GlobalListeners.dart:44-45`). The note's predicted snackbar text "Ошибка входа: Failed to sign in with Google" is exact.
- **Outer-catch type matching is correct.** After removal, GMS cancel raises `GoogleSignInException` (not `GoogleSignInCanceledException`), so the `on GoogleSignInCanceledException { rethrow; }` clause in `getServerAuthCode()` does *not* intercept it — it falls to `catch (e)` → `_browserFlow()`. The browser cancel path still works: `_browserFlow()` maps `PlatformException('CANCELED')` → `GoogleSignInCanceledException` (line 68), which the outer `on` clause rethrows and `UserNotifier` silently swallows. Both behaviors preserved as the plan claims.
- **No test breakage.** Tests exercise the repository via `FakeGoogleAuthProvider` (`test/User/UserRepository_test.dart:80`), which throws `GoogleSignInCanceledException` directly and never invokes the real `_gmsFlow()`. No test asserts the GMS cancel-conversion behavior, so removing it breaks nothing. `Testing: no` is the right call.
- **Guards are accurate.** `_browserFlow()`, `GoogleSignInCanceledException`, `UserNotifier`, and the `on GoogleSignInCanceledException { rethrow; }` clause should all remain untouched — confirmed correct.

## Minor Notes (non-blocking)

- **Import-retention reasoning is slightly off, but the conclusion is right.** Task 1 says to keep the `google_sign_in` import because "`GoogleSignIn`, `GoogleSignInException` types remain via `authorizationClient`". After the edit, `GoogleSignInException` will **no longer** be referenced anywhere in the file (its only use is the `on GoogleSignInException catch` being deleted). The import must stay solely because `GoogleSignIn.instance` is still used at line 10. Net effect is identical — keep the import — so this does not change the implementation, just the stated justification. `GoogleSignInExceptionCode` likewise becomes unreferenced, which is fine.
- **Documented trade-off is acceptable.** A user who explicitly cancels the GMS picker will now see the browser OAuth flow open. The plan and note both call this out; it is a reasonable cost for surfacing real network failures.

## Positive Notes

- Single-file, ~3-line surgical change with no migrations, no API/proto impact, no DI rewiring.
- Strong supporting note (`notes/127`) with a concrete manual verification script (network off → snackbar; cancel → browser; happy path → works).
- Correctly identifies and explicitly fences off the parts that must NOT change.

PLAN_REVIEW_PASS
