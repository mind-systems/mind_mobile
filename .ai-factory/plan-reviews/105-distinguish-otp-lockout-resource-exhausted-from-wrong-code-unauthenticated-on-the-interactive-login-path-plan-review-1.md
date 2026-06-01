# Plan Review: Distinguish OTP lockout (`RESOURCE_EXHAUSTED`) from wrong code (`UNAUTHENTICATED`) on the interactive login path

**Plan:** `105-distinguish-otp-lockout-resource-exhausted-from-wrong-code-unauthenticated-on-the-interactive-login-path.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid. One known limitation to surface (deliberately deferred to note 59).

## Scope & Intent Check

The plan is a faithful, near-verbatim implementation of the task spec in `.ai-factory/notes/58-task-otp-lockout-interactive.md` (interactive path), which explicitly defers the magic-link/deeplink path and double-snackbar suppression to note 59. File paths, layering, and the propagation chain all match the actual codebase. No proto regeneration is needed (note 58 confirms the proto is unchanged), which the plan correctly omits.

## Context Gates

- **ARCHITECTURE.md** — WARN (informational only): The new typed exceptions live in `lib/User/Models/` and the mapping is split AuthApi (boundary) → ViewModel (presentation), consistent with the existing `GoogleSignInCanceledException` boundary pattern and the layered dependency rules. No boundary violation.
- **RULES.md** — PASS: No module Service state added, no App.dart changes, all wiring stays constructor-based. The plan touches none of the rule-governed areas.
- **ROADMAP.md** — PASS: Linked to Phase 27 (via note 58/45). Milestone alignment is explicit.
- **skill-context** (`aif-review/SKILL.md`) — Not present; no project-specific review overrides to apply.

## Correctness Verification (against actual code)

Confirmed accurate in the plan:
- `lib/User/AuthApi.dart` — `verifyCode`/`sendCode` currently let `GrpcError` propagate raw; `grpc: ^5.1.0` is a direct dependency and `StatusCode.resourceExhausted` is the standard constant (same import as `GrpcAuthInterceptor.dart`). Wrapping order is correct: the `_storage.write` only runs after a successful response, so it stays outside the failure path.
- Propagation chain verified end-to-end: `AuthApi` → `UserRepository.completePasswordlessSignIn` (awaits, no catch) → `UserNotifier.completePasswordlessSignIn` (catches, publishes, **rethrows**) → `LoginService` (awaits) → `LoginViewModel`. No intermediate-layer code changes are required for the exception to reach the ViewModel — confirmed.
- `LoginError` enum has exactly the two values the plan states; both screen `switch (error)` expressions are exhaustive (`LoginScreen.dart:32`, `OnboardingScreen.dart:31`), so adding enum values forces both updates — Task 6 correctly covers both. Grep confirms these are the **only** two switch sites; `OnboardingModule.dart` wires the provider but has no error switch.
- Dart syntax `on OtpLockedException { ... } catch (_) { ... }` (no binding on the typed clause) is valid, and `on`-clauses are matched before the generic `catch` — the ordering in Task 4 is correct.
- `const` exceptions: valid for field-less classes even though `GoogleSignInCanceledException` itself is not const-constructed today; adding `const` constructors enables `throw const OtpLockedException()` as planned.
- l10n: `packages/mind_l10n/l10n.yaml` uses `synthetic-package: false` with committed `app_localizations*.dart`. Task 5 correctly notes `flutter gen-l10n` (not build_runner) is the regen path.

## Critical Issues

None.

## Important Issue — Known Limitation (deliberately deferred, but must be surfaced)

**Double error display on the interactive lockout path.** Task 2 asserts "no changes are needed in those intermediate layers," and strictly for *exception propagation* that is true. But `UserNotifier.completePasswordlessSignIn` (line 56–58) does `_authErrorSubject.add(e.toString()); rethrow;`, and `GlobalListeners` (line 44–46) renders every `authErrorStream` event as a raw snackbar: `'Ошибка входа: <e.toString()>'`. So on OTP lockout the user will see **both**:
1. a raw, non-localized snackbar `Ошибка входа: OtpLockedException: ...` (from `authErrorStream` → `GlobalListeners`), **and**
2. the intended localized `AppAlert` (`tooManyAttempts`) from `LoginViewModel.onErrorEvent`.

This is documented in `.ai-factory/notes/59-task-otp-lockout-deeplink.md` (change #1: suppress the publish with `if (e is! OtpLockedException) _authErrorSubject.add(e.toString())`), and note 58 explicitly scopes that suppression out of this plan. So **this is not a plan defect** — it mirrors the project's own scoping decision.

Caveats worth recording for the implementer:
- The double-display is **pre-existing** today for the wrong-code path (`codeInvalidOrExpired` already shows a raw `Ошибка входа: ...` snackbar alongside the localized alert), so this plan does not introduce a new regression — it carries the wart forward to the lockout case.
- However, it partially undercuts this plan's stated goal ("dedicated `LoginError` recovery copy"). Recommend one of: (a) fold note 59's one-line source suppression for `OtpLockedException` into this plan's Task 2/Commit 1 (it touches only `UserNotifier`, is interactive-path-relevant, and note 59 itself calls it a "welcome side-effect" on the interactive path), or (b) add an explicit "Known limitation / depends-on note 59" line to the plan so it is not mistaken for a clean single-message UX at verify/QA time.

## Minor / Informational

- **Wrong-code `UNAUTHENTICATED` triggers `GrpcAuthInterceptor._onUnauthenticatedError` → `triggerLogout()`** for every unary 401, including a wrong verify code. This is pre-existing and effectively a no-op during login (`UserNotifier.clearSession` early-returns when already `GuestState`). Not introduced by this plan and out of scope — noted only so it is not mistaken for a side effect of the new mapping.
- **`OtpSendCooldownException` does not need suppression** — the `sendCode` path never publishes to `authErrorStream` (`UserNotifier.sendPasswordlessSignInLink` has no try/catch), so the cooldown case yields a single clean localized alert. Consistent with note 59's analysis.
- **Regenerated `app_localizations_en.dart` / `app_localizations_ru.dart` must be committed** alongside the ARB edits, since this package commits generated output (`synthetic-package: false`). Worth an explicit reminder in Task 5's done-check.

## Positive Notes

- Strict status-code discrimination (`e.code == StatusCode.resourceExhausted`), never message-text matching — matches the existing `GrpcAuthInterceptor` convention and the note's guard.
- No auto-resend on lockout — correctly preserves the server's brute-force control.
- Exception placement, naming, and `const` boundary pattern mirror the established `GoogleSignInCanceledException`.
- Both error switches identified and updated; enum exhaustiveness gives a compile-time guarantee nothing is missed.
- Commit plan is sensibly split (boundary mapping vs. presentation/copy) and each commit is independently coherent.

PLAN_REVIEW_PASS
