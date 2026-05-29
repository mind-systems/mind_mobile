# Code Review: Create `ActiveRrSource` in `lib/Biometrics/`

**Plan:** `.ai-factory/plans/72-create-activerrsource-in-lib-biometrics.md`
**Spec:** `.ai-factory/notes/29-heart-rate-tick-source.md` (Milestone 1)
**Scope reviewed:** Single purely-additive file `lib/Biometrics/ActiveRrSource.dart` (129 LOC).

## Files Changed

```
A  .ai-factory/plan-reviews/72-create-activerrsource-in-lib-biometrics-plan-review-1.md
A  .ai-factory/plans/72-create-activerrsource-in-lib-biometrics.md
A  lib/Biometrics/ActiveRrSource.dart
```

Only one code file was added. No existing files modified — purely additive, as the plan required.

## Verification

### Imports & dependencies
- `dart:async` ✓
- `package:rxdart/rxdart.dart` ✓ — `rxdart: ^0.28.0` declared in `pubspec.yaml`.
- `../Logger.dart` ✓ — resolves to `lib/Logger.dart`, which exports `logPrint`. Matches sibling-file convention (`lib/Bci/NeiryBciProvider.dart` uses the same `../Logger.dart` form).
- `IRrIntervalSource.dart` ✓ — exists at `lib/Biometrics/IRrIntervalSource.dart`, exposes `Stream<RrInterval> get rrStream`.
- `Models/RrInterval.dart` ✓ — exists at `lib/Biometrics/Models/RrInterval.dart`, exposes `intervalMs` (int), `isArtifact` (bool), `source` (`SensorSource` enum with `.name`).

No `package:flutter` or `package:riverpod` direct imports. (Logger transitively imports `package:flutter/foundation.dart` for `debugPrint`; consistent with how the rest of `lib/Biometrics/` and `lib/Bci/` log.)

### Architecture & rules
- `lib/Biometrics/` is the correct location per `CLAUDE.md` (hardware-agnostic biometric streaming).
- Pure-Dart class, no module concerns leaking in. Symmetric with `BioStreamRouter` which already lives in the same folder and consumes the same `IRrIntervalSource` instances with the opposite policy.
- `RULES.md` Rule 3 (constructor injection) — followed: `sources` injected once, subscriptions managed internally.
- Rules 1 and 2 are N/A (this is not a module Service and does not touch `App.dart` yet).

## Correctness Analysis

### Higher-priority steal flow
`_onInterval` order: update `_lastSeenAt[index]` → maybe steal (`index < _activeIndex`) → return-if-not-active → forward + restart watchdog. When source 0 (preferred) revives mid-session while source 1 is active:
1. `_lastSeenAt[0]` updated.
2. `_activeIndex` reassigned from 1 → 0 with log line.
3. `index == _activeIndex` now true, so the interval IS forwarded (not dropped — important: this is the first interval from the recovered preferred source and must reach downstream).
4. Watchdog restarted with the new interval's ms. Old timer cancelled by `_restartWatchdog`.

Correct. ✓

### Non-active source emission (no steal)
Lower-priority source emits while a higher-priority source is active: `_lastSeenAt[i]` updated → `index < _activeIndex` is false → no steal → `index != _activeIndex` returns early. No spurious forwarding, no watchdog churn. Lower-priority `lastSeenAt` is still tracked so failover can find it later. Correct. ✓

### Watchdog cancellation
`_restartWatchdog` calls `_watchdog?.cancel()` before scheduling, preventing timer accumulation. ✓
`dispose` calls `_watchdog?.cancel()` first thing. ✓

### Silence cascade
`_onSilence` walks sources in priority order, skipping `_activeIndex`, picks first one with `_lastSeenAt[i]` within `_silenceFloor` (2 s) of now. On miss, sets `_activeIndex = null`, `_lastIntervalMs = null`, `_ensureHasActive(false)` — and intentionally does NOT restart the watchdog. Revival is correctly handled by `_onInterval` (`_activeIndex == null` branch). Self-consistent. ✓

### `hasActiveSource` transitions
- Seeded `false` at construction.
- Flips to `true` only inside `_onInterval` after a forward.
- Flips back to `false` only inside `_onSilence` when all sources are stale.
- `_ensureHasActive` guards duplicate emissions.

`BehaviorSubject` semantics give late `hasActiveSourceStream` subscribers the current value, as required. ✓

### Memory/leak surface
- `_lastSeenAt` is bounded by `_sources.length` (immutable). ✓
- Single broadcast `StreamController<RrInterval>` and single `BehaviorSubject<bool>` — both closed in `dispose`. ✓
- Subscriptions stored in `_subs`, awaited-cancelled in `dispose`. ✓
- No retained references to upstream sources beyond the unmodifiable list and the subscriptions. ✓

### Source-list ownership
`dispose` only cancels its own subscriptions and closes its own controllers. It does NOT dispose the `IRrIntervalSource` instances themselves — correct, per spec ("App owns them"). ✓

### Empty sources list
Constructor accepts `[]`. Loop body never runs, no subscriptions, no `_onInterval` calls, `_activeIndex` stays `null`, `hasActiveSource` stays `false`. `dispose` safely cancels nothing. Acceptable.

## Observations (non-blocking)

1. **Theoretical dispose-race on in-flight events.** `dispose` cancels the watchdog synchronously, then awaits each `sub.cancel()`. If an `_onInterval` event were already queued in the microtask loop between the watchdog cancel and the subscription cancel completing, it could call `_restartWatchdog()` and schedule a new timer; that timer could later fire after the controllers are closed, throwing `StateError` on `_hasActiveController.add(false)`. In practice this race is extremely unlikely (the watchdog cancel and the cancel-await happen back-to-back with no awaits between them, and broadcast-stream listener delivery is synchronous with `add()` on the source side). The spec does not require defensive guards, and no other class in `lib/Biometrics/` adds such guards. Informational only.

2. **Dartdoc `[BioStreamRouter]` reference is unresolved.** The class is in the same package but not imported, so dartdoc cannot resolve the link. `flutter analyze` does not flag this; it's a doc-only nit and matches how the spec wrote it.

3. **`_silenceFloor` (2 s) is the failover-candidate liveness window, not the per-source effective window.** A source with a >2 s cadence (e.g. slow heart rate or sparse fallback) will be skipped on failover and not picked back up until it emits again. This is intentional per spec (uniform "alive in the last 2 s" cut-off) but worth knowing.

None of the three observations indicate a bug, security issue, or correctness problem.

## Conclusion

The implementation is a faithful, line-by-line realization of Milestone 1 of the spec. Imports are correct, the priority/failover/revival/silence logic matches the spec, the watchdog is properly cancelled in every code path that needs it, no resources leak, and the dispose semantics correctly respect external ownership of the source instances. No bugs, security issues, or correctness problems were found.

REVIEW_PASS
