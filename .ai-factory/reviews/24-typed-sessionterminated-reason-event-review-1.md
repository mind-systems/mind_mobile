# Code Review: Typed `SessionTerminated(reason)` event

**Plan:** `.ai-factory/plans/24-typed-sessionterminated-reason-event.md`
**Scope:** `git diff HEAD` — 7 code files + 5 l10n files (2 ARB + 3 generated).

## What was reviewed

- `lib/Core/Grpc/ModuleStateEvent.dart` — new `SessionTerminationReason` enum + `SessionTerminated` event.
- `lib/Biometrics/BiometricStreamClient.dart` — exhaustive switch case.
- `lib/Core/Background/KeepAliveCoordinator.dart` — exhaustive switch case.
- `lib/BreathModule/Core/BreathModuleStateChannel.dart`, `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — `is`-check reset.
- `lib/Core/GlobalUI/GlobalListeners.dart` — reason-switched snackbar + new message helper + import.
- `lib/Core/App.dart` — stream wiring.
- `packages/mind_l10n/lib/l10n/*` — ARB keys + regenerated `AppLocalizations`.

## Verification performed

- **Exhaustiveness / compile-ordering.** The only two exhaustive `switch (ModuleStateEvent)` sites in the tree are `BiometricStreamClient._onLifecycleEvent` and `KeepAliveCoordinator._onEvent`; both add a `SessionTerminated()` case in the same commit as the type, so the sealed hierarchy is never non-exhaustive. All other `ModuleStateEvent` consumers (`HomeService.dart:59-60`, `App.dart:321`, adapters) use `is`/`.where()` filters, not switches, so they neither gate compilation nor silently drop a case. No test file switches over `ModuleStateEvent`. Confirmed no `default:`/wildcard masks the new variant.
- **Reset bodies are byte-identical to the existing terminal branches.** Bio merges `SessionTerminated` into the existing `ModuleSessionEnded() || ModuleSessionAbandoned()` branch (`_currentSessionId`/`_sessionConfirmed`/`_lastOpenAttempt`/`_replayRing.clear()`); keep-alive reuses `_foregroundKeepAlive.stop()`; meditation reuses the 5-field re-arm; breath reuses `reset()`. Reset is reason-agnostic as specified.
- **Reason switch is exhaustive** over all three enum values with no `default`; `movedToAnotherDevice` → new copy, `abandoned`/`rootDeath` → existing `_sessionAbandonedMessage()`. The new `_sessionMovedToAnotherDeviceMessage()` mirrors the existing helper exactly (same `rootScaffoldMessengerKey` context guard + fallback string).
- **l10n regeneration is complete and consistent.** `sessionMovedToAnotherDevice` exists in both ARB files and in all three generated Dart files (`app_localizations.dart` abstract getter, `_en`, `_ru`), so `AppLocalizations.of(context)?.sessionMovedToAnotherDevice` resolves. RU translation present.
- **Wiring.** `App.dart` uses core-`Stream` `.where(...).map((e) => (e as SessionTerminated).reason)` (no rxdart `whereType`), matching the adjacent `sessionAbandonedStream` precedent; `channel.events` is a broadcast `PublishSubject.stream`, so the additional subscription is safe. `GlobalListeners` is instantiated in exactly one place, which now supplies the new required param; no other call site or test constructs it. Subscription is cancelled in `dispose()`.
- **Dormant as intended.** No emitter — `ModuleStateChannel` (`:179-203`) still only emits the pre-existing variants; `SessionTerminated` is never produced yet. The per-child `ModuleSessionAbandoned` snackbar path is untouched, so the previous double-snackbar failure mode cannot recur.

## Findings

None. The change matches the plan precisely, compiles (exhaustive switches complete, all referenced symbols/imports present), regenerates l10n consistently, and is correctly dormant with no runtime emitter.

Note (informational, not a defect): in the shipped config `BiometricStreamClient` is always constructed with `rootIdChanges` (`App.dart:234`), so `_onLifecycleEvent` returns early at the `_rootSourced` guard and the new bio case is exhaustiveness-only dead code; the real whole-tree bio reset will flow through `_onRootIdChanged(null)`. This is exactly as documented in the plan and is the correct dependency for the downstream reconnect emitter (ROADMAP.md:91) — no action needed here.

REVIEW_PASS
