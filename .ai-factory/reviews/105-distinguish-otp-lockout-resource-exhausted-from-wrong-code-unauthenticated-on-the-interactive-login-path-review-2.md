# Code Review (pass 2): Distinguish OTP lockout (`RESOURCE_EXHAUSTED`) from wrong code (`UNAUTHENTICATED`) on the interactive login path

**Scope reviewed:** `git diff HEAD` — `AuthApi.dart`, `OtpLockedException.dart`, `OtpSendCooldownException.dart`, `LoginViewModel.dart`, `LoginState.dart`, `LoginScreen.dart`, `OnboardingScreen.dart`, `mind_l10n` ARB + generated localizations.
**Verdict:** The code changes are correct and complete for their scope. No bugs, security issues, or correctness problems found in the diff. One pre-existing, explicitly-deferred behavioral caveat is recorded as informational only (it is *not* a defect introduced by these changes).

## What I verified independently this pass

- **gRPC mapping is sound.** `AuthApi.verifyCode`/`sendCode` catch `GrpcError`, translate only `StatusCode.resourceExhausted` to the typed exceptions, and `rethrow` all other codes (wrong-code `UNAUTHENTICATED` included). Discrimination is purely code-based, never message-text. `package:grpc/grpc.dart` is the correct, already-used source of `GrpcError`/`StatusCode`.
- **No partial-success on the failure path.** In `verifyCode`, the token `_storage.write` and `_mapUser` run only after a successful response; a `RESOURCE_EXHAUSTED` throw short-circuits before any storage mutation. No half-written auth state.
- **Non-`GrpcError` failures still degrade correctly.** A network/timeout/storage error that is not a `GrpcError` is not caught by the `on GrpcError` clause, propagates up, and lands in the ViewModel's generic `catch (_)` → `codeInvalidOrExpired` / `sendCodeFailed` — identical to prior behavior.
- **Exception routing cannot cross wires.** `verifyCode` can only throw `OtpLockedException`; `sendCode` only `OtpSendCooldownException`. The ViewModel's `verifyCode` matches `on OtpLockedException`, `sendPasswordlessSignInLink` matches `on OtpSendCooldownException` — each typed clause precedes its generic `catch (_)`, and `isLoading:false` is reset in every branch. No resend is triggered on lockout.
- **Interceptor does not misfire on lockout.** `GrpcAuthInterceptor` reacts only to `StatusCode.unauthenticated`; `RESOURCE_EXHAUSTED` (code 8) is ignored, so no spurious `triggerLogout()`. The interceptor's `onError` observes the original `GrpcError` (attached to the raw response future) independently of `AuthApi`'s `await`/translate — no interaction.
- **Enum exhaustiveness is enforced and satisfied.** `LoginScreen.dart:32` and `OnboardingScreen.dart:31` are the only two `switch (error)` sites; both handle all four `LoginError` cases, so the additions compile and nothing is silently unhandled.
- **l10n is fully wired.** Only `en` and `ru` locales exist (`l10n.yaml` template `app_en.arb`, `synthetic-package: false`, pubspec `generate: true`). The new keys are present in both ARBs, the abstract `AppLocalizations` declares both getters, and **both** concrete subclasses (`_en`, `_ru`) override them — no missing-override compile error. ARB JSON remains valid (commas correct), and the generated output matches what `flutter gen-l10n` produces, so no committed-vs-generated drift. RU/EN copy matches the spec.
- **Screen interaction is unaffected.** In `LoginScreen`, `verifyCode` is awaited only after the code-entry dialog has already resolved (`_isAlertOpen` is `false` by then), so the lockout alert (`AppAlert.show`) and the `isLoginInProgress`/auto-pop logic in `build()` do not collide. Pre-existing behavior is preserved.

## Informational (not a finding against this diff — pre-existing, deferred to note 59)

On the verify-code lockout path the user still receives a second, raw global snackbar (`Ошибка входа: OtpLockedException: …`) alongside the intended localized alert, because `UserNotifier.completePasswordlessSignIn` publishes `e.toString()` to `authErrorStream` (rendered verbatim by `GlobalListeners`) before rethrowing. This mechanism is unchanged by this diff — the same double-display already exists for the wrong-code path — and the spec (note 58) explicitly scopes the `authErrorStream` suppression to the next roadmap task (note 59). Recorded so QA does not expect a single clean message on lockout; no action required for this milestone. (Already captured in review pass 1.)

## Notes

- No migrations, schema, or proto changes — consistent with the unchanged proto contract.
- New exceptions mirror the established `GoogleSignInCanceledException` boundary pattern (const constructor, doc comment, `toString`).
- Commit split is coherent and each commit is independently buildable.

REVIEW_PASS
