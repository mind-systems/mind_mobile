## Code Review Summary

**Files Reviewed:** 4 production files
**Risk Level:** Low

### Context Gates

- **ARCHITECTURE.md:** PASS — changes stay within the domain layer (`UserNotifier`) and infrastructure layer (`GlobalListeners`, `App`). No boundary violations. `LogoutNotifier` remains a pure-Dart domain class; `GlobalListeners` now depends on a `Stream<void>` instead of a concrete notifier, which is a cleaner boundary.
- **RULES.md:** not present (WARN, non-blocking)
- **ROADMAP.md:** PASS — milestone marked `[x]` in roadmap, matches plan scope exactly.

### File-by-file

**`lib/User/UserNotifier.dart`** — `_sessionExpiredSubject` is a `PublishSubject<void>` (no replay, no buffering). Emits only inside `clearSession()`, after the `GuestState` guard passes and after `GuestState(newGuest)` is emitted on the main subject. This means guest 401s are silenced (guard returns early) and user-initiated `logout()` does not emit (no unexpected session loss). Closed in `dispose()` before the other subjects. Correct.

**`lib/Core/GlobalUI/GlobalListeners.dart`** — Constructor takes `Stream<void>` instead of `LogoutNotifier`, which is a cleaner dependency (no knowledge of the concrete class). Subscription renamed accordingly. `LogoutNotifier` import removed. Docstring translated to English. Correct.

**`lib/Core/App.dart`** — `logoutNotifier` removed from class fields, constructor, and `shared = App._()` call. Stays as a local variable in `initialize()` for wiring `AuthInterceptor` and `UserNotifier`. The `LogoutNotifier` import remains because the local variable uses the class. `GlobalListeners` now receives `sessionExpiredStream` from `userNotifier`. Correct.

**`lib/User/LogoutNotifier.dart`** — Docstring updated from Russian to English. Accurately describes the class as a private mediator and directs external code to `UserNotifier.sessionExpiredStream`. Correct.

**`lib/Core/Api/AuthInterceptor.dart`** — Unchanged. Still calls `_logoutNotifier.triggerLogout()` on 401 as the producer side. No action needed.

### Behavioral verification

**Before:** 401 -> `LogoutNotifier.triggerLogout()` -> both `UserNotifier.clearSession()` AND `GlobalListeners` snackbar fire simultaneously. Guest users hitting protected endpoints see snackbar spam.

**After:** 401 -> `LogoutNotifier.triggerLogout()` -> only `UserNotifier.clearSession()`. If state is `GuestState`, nothing happens (guard returns early). If `AuthenticatedState`, state transitions to `GuestState` and `sessionExpiredStream` emits once -> `GlobalListeners` shows a single snackbar.

### Grep verification

- `App.shared.logoutNotifier` — zero remaining references in production code.
- `LogoutNotifier` references in `lib/` — only `App.dart` (local var + import), `AuthInterceptor.dart` (producer), `UserNotifier.dart` (consumer), and `LogoutNotifier.dart` (definition). All correct.
- Test files (`UserNotifier_test.dart`, `auth_code_deeplink_handler_test.dart`) still construct `LogoutNotifier` for wiring `UserNotifier` — this is correct, as the class still exists and tests need it for setup.

### Positive Notes

- Narrowing `GlobalListeners` from depending on `LogoutNotifier` to depending on `Stream<void>` is a clean improvement — the widget no longer needs knowledge of the concrete notifier class.
- The guard-then-emit pattern in `clearSession()` is sound: check state, do async work, emit state, then emit event. The sessionExpired event fires only after the state has already changed, so any listener reacting to it will see the current `GuestState`.

REVIEW_PASS
