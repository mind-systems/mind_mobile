# Plan Review: C — Handle `ABANDONED`: reset + re-arm channels + snackbar

**Plan:** `79-c-handle-abandoned-reset-re-arm-channels-snackbar.md`
**Files Cross-Checked:** 8 (4 target files + ModuleStateEvent, ModuleState, App.dart, l10n ARBs + generated)
**Risk Level:** 🟢 Low — accurate, well-scoped, ready to implement with two minor notes

## Verification Summary

Every concrete claim in the plan was checked against the codebase and holds:

- **Line numbers are accurate** across all six tasks (`BreathModuleStateChannel` `_stateSub`/`_channelSub` `:26-27`, `reset()` `:137-148`, dispose `:155-156`, `channel.state` sub `:38-42`; Meditation `:15-16`/`:24-29`/`:44`/`:45-46`; `ModuleStateChannel` sessionError `:92-93`, ABANDONED `:149-151`; `GlobalListeners` `:18`/`:21-25`/`:32`/`:37-39`/`:44`/`:64-69`/`:71-74`; App.dart builder `:309-312`; ARBs `:11`).
- **`ModuleSessionAbandoned` exists** in `ModuleStateEvent.dart:19` and is already emitted at `ModuleStateChannel.dart:149-151` — Phase 1/3 have a real signal to hook.
- **`ModuleState.initial()` sets `moduleSessionId: null`** (confirmed `:10-11`), which is the exact stale-latch trigger Tasks 1-2 address.
- **`moduleStateChannel` is a public `App` field** (`App.dart:96`) and `.events` is the same `PublishSubject` already consumed by `BiometricStreamClient` (`:226`) and `KeepAliveCoordinator` (`:229`) — Task 5's claim "no new field to expose" is correct, and `PublishSubject` being broadcast means the extra subscriber is safe.
- **ARB keys exist but generated getter does not** — `sessionAbandoned` is present in both `app_en.arb:11` / `app_ru.arb:11`, but the generated files only expose `sessionExpired` (`app_localizations.dart:141`, `_en.dart:30`, `_ru.dart:30`). Task 6 is genuinely required for Task 4 to compile.
- **Import gaps correctly identified** — `App.dart` currently imports only `ModuleStateChannel.dart` (`:51`), not `ModuleStateEvent.dart`; both module channels import `ModuleStateChannel.dart` but need the explicit `ModuleStateEvent.dart` import (Dart imports are not transitive). All three are flagged in the plan.
- **Meditation re-arm correctly includes `_moduleSessionId = null`** — its `_channelSub` only assigns when non-null (`:25-28`), so the state stream alone would *not* clear it on abandon; the plan's explicit inline reset is necessary and correct.

### Context Gates

- **Architecture** — `WARN` (advisory). The wiring follows the established `sessionExpiredStream` pattern (constructor injection into `GlobalListeners`, which owns its own subscription), consistent with RULES.md rule 3.
- **Rules (`RULES.md`)** — `WARN` (non-blocking). Rule 2 says "Never add module-specific state, streams, or triggers to App.dart." Task 5 adds `moduleStateChannel.events.where((e) => e is ModuleSessionAbandoned).map(...)` in the builder. This is defensible: abandonment is a cross-cutting session concern (not breath/meditation-specific), it derives from existing infrastructure, and it mirrors the already-present `sessionExpiredStream` wiring at the same site. Treat as acceptable, but be deliberate — do not let it become a precedent for per-module triggers in App.dart.
- **Roadmap** — `WARN` (optional). Plan declares dependency on milestone A (`152-present-module-session-id-on-reconnect`); no explicit ROADMAP linkage line, which is fine for this fix-shaped milestone.

## Findings

### Minor (non-blocking)

1. **Task 6 dependency direction is mislabeled.** The plan marks Task 6 "(depends on Task 4)", but the relationship is the reverse: the ARB keys already exist, so Task 6 (regen) has *no* dependency on Task 4, while Task 4's code (`AppLocalizations.of(context)?.sessionAbandoned`) will not compile until Task 6 runs. Because both land in Commit 3, the final commit compiles regardless of intra-commit order — so this is cosmetic. Recommend running the l10n regen (Task 6) **first** within Commit 3 so intermediate state stays buildable.

2. **`.map((_) {})` yields `Stream<Null>`, assigned to `Stream<void>`.** This is fine — with the `Stream<void>` target context Dart infers the `map` type argument as `void`, matching the existing `sessionExpiredStream`. No action needed; noting so the implementer doesn't "fix" it into a typed payload.

### Informational (out of scope, no change requested)

3. **`_isPendingStart` is not reset on ABANDONED** in `ModuleStateChannel._processProtoEvent` (`:149-151`), unlike the `ACTIVITY_STATUS_UNSPECIFIED` branch. In the server-confirmed-dead-session scenario the activity was previously `ACTIVE`, which already cleared `_isPendingStart`, so the next `start()` is not suppressed. No defect for this plan, but worth keeping in mind if abandonment can ever arrive while a start is still pending.

4. **Task 3's silent reset re-arms only the `ModuleStateChannel` state, not the module-channel latches.** On `no_active_session`, `_state.add(ModuleState.initial())` nulls `moduleSessionId` (and the Breath `_channelSub` will mirror that), but `_started`/`_ended` in the module channels stay as-is because no `ModuleSessionAbandoned` event is emitted (by design — silent path). If a session were genuinely mid-flight when this defensive rejection arrives, the Breath channel could buffer instructions into `_pendingInstruction` with no session id. This matches the plan's stated intent (rare defensive path, stale client view) and is acceptable; flagged only for awareness.

## Positive Notes

- The plan correctly distinguishes the two reset triggers: `sessionState{ABANDONED}` (the real signal, event-driven re-arm) vs. `sessionError{no_active_session}` (a command-rejection demoted to a silent reconciliation). This separation is the crux of the milestone and is reasoned out precisely.
- The **additive subscription** approach (new `channel.events` listener alongside the untouched `channel.state` listener) is the right call — it avoids disturbing the existing instruction-flush path that depends on the state stream.
- Excellent pin-down quality: exact symbol names, import paths, declaration sites, and the observation that the ARB keys exist but the getter is unregenerated. Leaves essentially no guesswork for the implementer.
- Commit plan maps cleanly onto the three phases with self-contained, compilable commits.

PLAN_REVIEW_PASS
