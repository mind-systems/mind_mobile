# Plan Review: Create `ActiveRrSource` in `lib/Biometrics/`

**Plan:** `.ai-factory/plans/72-create-activerrsource-in-lib-biometrics.md`
**Spec:** `.ai-factory/notes/29-heart-rate-tick-source.md` (Milestone 1)
**Reviewed scope:** A single purely-additive class. No wiring, no UI.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. `lib/Biometrics/` is the hardware-agnostic biometric layer (per CLAUDE.md folder map). `ActiveRrSource` is pure Dart, no Flutter/Riverpod, no module concerns leaking in. Sits alongside `BioStreamRouter` as a parallel client-side consumer of the same `IRrIntervalSource` instances — symmetric with documented architecture.
- **Rules (`.ai-factory/RULES.md`):** PASS for this milestone.
  - Rule 1 ("Module Services stateless") — N/A. `ActiveRrSource` is a domain class, not a module Service.
  - Rule 2 ("No module state in App.dart") — N/A for M1. Will become relevant in M2; reviewer notes the `ActiveRrSource` instance is a cross-module infrastructure object (analogous to `BioStreamRouter`), so M2 wiring should be acceptable, but that is out of scope here.
  - Rule 3 ("Constructor injection") — followed: sources list injected via constructor; subscriptions managed internally.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN — file exists, but the plan does not explicitly cite a Phase 22 / milestone anchor. The spec note references "ROADMAP Phase 22 milestones 1–7"; the plan only references the spec. Non-blocking.

## Codebase Verification

Each assumption in the plan was checked against the live codebase:

| Assumption | Reality | Status |
|---|---|---|
| `lib/Biometrics/ActiveRrSource.dart` is a new file | File does not exist | ✅ |
| Logger lives at `lib/Logger.dart`, not `lib/Core/Logger.dart` | Confirmed (`lib/Logger.dart` exports `logPrint`) | ✅ Plan correctly overrides spec |
| Relative path `../Logger.dart` from `lib/Biometrics/ActiveRrSource.dart` | Resolves to `lib/Logger.dart` | ✅ |
| `IRrIntervalSource.dart` lives in `lib/Biometrics/` and exposes `rrStream` of `RrInterval` | Confirmed | ✅ |
| `RrInterval` has `intervalMs`, `isArtifact`, `source` (SensorSource) | Confirmed in `Models/RrInterval.dart` | ✅ |
| `SensorSource` is an enum with `.name` available | Confirmed (`enum SensorSource { neiry, garmin, polar, appleHealth }`) | ✅ |
| `rxdart` is available | Used in `BioStreamRouter.dart` and elsewhere | ✅ |
| Sibling style (relative imports) | Matches `BioStreamRouter.dart` convention | ✅ |

## Critical Issues

None.

## Notes / Minor Observations

1. **`logPrint` transitively imports Flutter.** `lib/Logger.dart` does `import 'package:flutter/foundation.dart'` for `debugPrint`. The plan's verification clause "contains no `package:flutter` or `package:riverpod` imports" is about *direct* imports and still passes. The class doc-comment claim of "pure Dart" should be understood the same way (direct imports). This is consistent with how the rest of `lib/Biometrics/` works (e.g. `BioStreamRouter` doesn't import Flutter directly either). Non-blocking.

2. **`_lastSeenAt` field declaration.** The plan lists `Map<int, DateTime> _lastSeenAt = {}` without `final`. The spec source uses `final Map<int, DateTime> _lastSeenAt = {};`. Recommend `final` for consistency with `_sources`/`_subs` and standard Dart style. Minor.

3. **Watchdog after total silence.** When `_onSilence` finds no fallback candidate, it sets `_activeIndex = null` and `_lastIntervalMs = null` but does not restart the watchdog. A revived source will be picked up by `_onInterval` (which sets `_activeIndex` and calls `_restartWatchdog()`), so the state machine recovers correctly. Behavior is correct; documenting this in a code comment would help future readers but is not required.

4. **Silence-floor check in `_onSilence`.** The fallback candidate criterion is `now.difference(lastSeen) <= _silenceFloor` (a fixed 2 s window), not the effective silence window of the candidate. This is intentional per the spec — the floor is the universal "alive in the last two seconds" cut-off — but a `_silenceFloor` comparison can feel arbitrary on first read. Acceptable as specified.

5. **Higher-priority steal does not restart watchdog before forwarding.** Sequence in `_onInterval`: if `index < _activeIndex`, the steal happens, then the index match check passes, then `_restartWatchdog()` runs at the end. Correct — no issue, just worth confirming when implementing.

6. **`_sources = List.unmodifiable(sources)`.** The plan reasserts immutability; consumers cannot mutate the list afterward. Symmetric with `BioStreamRouter`'s register-before-subscribe model. Good.

7. **Doc-comment language guidance from global CLAUDE.md.** Doc comments are in English (matching neighbouring `BioStreamRouter` and `IRrIntervalSource`). Aligned with project convention.

## Positive Notes

- Plan correctly identifies and overrides the **only material error in the spec** (Logger import path) and explains why (`../Logger.dart` matches existing sibling-file style — verified against `BioStreamRouter.dart`).
- Every public symbol (`stream`, `hasActiveSource`, `hasActiveSourceStream`, `dispose`) is enumerated with exact semantics — implementer has zero ambiguity.
- Private helper contracts (`_onInterval`, `_restartWatchdog`, `_onSilence`, `_ensureHasActive`) are spelled out step-by-step.
- Dispose ordering is explicit: cancel watchdog → await subscriptions → close controllers. No source-instance disposal (correctly delegated to `App`).
- Scope is correctly bounded to Milestone 1 only — wiring (M2) and downstream layers (M3–M7) are explicitly excluded.
- Verification block is concrete and checkable (`flutter analyze`, absence of forbidden imports, additive-only check).

## Verdict

The plan is faithful to the spec, corrects the one inaccuracy in the spec (Logger path), and is internally consistent. No missing steps, no wrong codebase assumptions, no architectural or rules conflicts, no security/migration concerns (none apply to a pure-Dart additive class). Ready for implementation.

PLAN_REVIEW_PASS
