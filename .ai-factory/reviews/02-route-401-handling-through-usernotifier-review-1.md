# Review: Route 401 handling through UserNotifier

**Plan:** `.ai-factory/plans/02-route-401-handling-through-usernotifier.md`
**Scope:** 4 files changed, 1 new file (plan)

## Verification

- `flutter analyze` on all changed files: **no issues**
- `flutter test` on both test files that reference `LogoutNotifier` (`UserNotifier_test.dart`, `auth_code_deeplink_handler_test.dart`): **22/22 passed**
- Grep for `App.shared.logoutNotifier`: **no remaining references in code** (only in the plan doc)

## File-by-file review

### `lib/User/UserNotifier.dart`

**Correct.** `_sessionExpiredSubject` is a `PublishSubject<void>` — no replay, no buffering. It emits only inside `clearSession()`, after the GuestState guard passes and after `_subject.add(GuestState(newGuest))`. This means:
- Guest 401s are silenced (guard returns early)
- User-initiated `logout()` does not emit (intentional — no unexpected session loss)
- `dispose()` closes the subject before the other subjects

No issues.

### `lib/Core/GlobalUI/GlobalListeners.dart`

**Correct.** Constructor takes `Stream<void>` instead of `LogoutNotifier` — a cleaner dependency (no knowledge of the concrete notifier class). Subscription variable renamed. `LogoutNotifier` import removed. Docstring updated to English.

No issues.

### `lib/Core/App.dart`

**Correct.** `logoutNotifier` removed from the `App` class fields, constructor, and `shared = App._(...)`. Stays as a local variable in `initialize()` for wiring `AuthInterceptor` and `UserNotifier`. The `LogoutNotifier` import remains (needed for the local variable). `GlobalListeners` now receives `sessionExpiredStream` from `userNotifier`.

No issues.

### `lib/User/LogoutNotifier.dart`

**Correct.** Docstring updated to English. Accurately describes the class as a private mediator and directs external code to `UserNotifier.sessionExpiredStream`.

No issues.

### `lib/Core/Api/AuthInterceptor.dart`

**Unchanged.** Still calls `_logoutNotifier.triggerLogout()` on 401 — correct, this is the producer side that feeds into the private channel.

## Behavioral analysis

**Before:** Every 401 → `LogoutNotifier.triggerLogout()` → both `UserNotifier.clearSession()` AND `GlobalListeners` snackbar fire simultaneously. Guest users hitting protected endpoints see snackbar spam.

**After:** Every 401 → `LogoutNotifier.triggerLogout()` → only `UserNotifier.clearSession()`. If state is GuestState, nothing happens. If Authenticated, state transitions to Guest and `sessionExpiredStream` emits once → `GlobalListeners` shows a single snackbar.

The flow matches the target diagram from the design note.

## Pre-existing note (not introduced by this change)

`clearSession()` is `async` and the GuestState guard is not atomic — two concurrent 401s could both pass the guard before either completes the `await repository.clearSession()` call. This would result in two `GuestState` emissions and two `sessionExpired` events. This race window existed before this change (the same guard was already in place) and is narrow in practice since `clearSession()` is local I/O. Flagging for awareness, not as a blocker.

REVIEW_PASS
