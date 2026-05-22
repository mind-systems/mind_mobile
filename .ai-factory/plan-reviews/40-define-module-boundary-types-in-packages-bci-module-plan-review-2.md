# Plan Review — 40-define-module-boundary-types-in-packages-bci-module (round 2)

## Summary

**Plan:** Define DTOs, state model, and Service/Coordinator interfaces for the `bci_module` package boundary (Phase 17, milestone 11).
**Scope:** 8 tasks, all new files inside `packages/bci_module/lib/src/BciPairing/` plus barrel exports.
**Risk Level:** 🟢 Low — interface-only work, no runtime behaviour, no migrations.

Round 1's WARN findings (1, 2) and doc nits (3–6) have been folded in:

- `observeChanges()` as a method — ✅ adopted (Task 6, with explicit naming rationale citing `IBreathSessionListService` / `IBreathSessionService`).
- RULES.md Rule #1 compliance via `scan`-based pure reducer — ✅ documented as "Implementer guidance" in Task 6.
- `IBciPairingCoordinator` justification — ✅ revised to "single-action coordinator since the pairing screen has only one navigation exit".
- `BciCalibrationProgressDTO` invariants (range 0–4; authority of `isComplete`) — ✅ documented in Task 4.
- Failure mapping contract (clears `calibration`, drops `stage` to `impedance`, populates `errorMessage`) — ✅ added as a "Contract note" in Task 5.
- `BciPairingStage` collapse rationale (`disconnected/scanning/connecting` → `discovery`, granularity via booleans) — ✅ added as "Mapping note" in Task 1.

One new finding emerged on this re-read (a concrete bug in the implementer-guidance code snippet). Everything else from round 1 has been resolved.

## Context Gates

- **ARCHITECTURE.md:** ✅ Module Boundary respected — DTOs and interfaces declared inside the package, no `package:mind/Bci/…` imports, domain enums mirrored as package-local types. Aligned with the dependency rules in `ARCHITECTURE.md:67-82`.
- **RULES.md:** ✅ Interface as drafted permits a stateless concrete service; Task 6 explicitly captures the RxDart `scan` strategy and tells the next implementer not to reach for `StreamController` / `StreamSubscription` / `dispose()`. Rule #3 (constructor injection) is not in scope for this plan.
- **ROADMAP.md:** ✅ Plan matches the Phase 17 milestone bullet at `ROADMAP.md:91` (field list, file paths, enum variants). Linkage is implicit (filename includes the milestone slug); no roadmap edit needed.

## Critical Issues

### 1. (BLOCKING for the implementer) `scan` example in Task 6 has wrong arity

Task 6's implementer guidance shows:

```
bciNotifier.stream.scan<BciPairingState>(
  (acc, event, _) => _applyEvent(acc, event),
  BciPairingState.initial(),
  false,
).map(BciPairingStateUpdated.new)
```

RxDart 0.28.0's `scan` extension (`~/.pub-cache/.../rxdart-0.28.0/lib/src/transformers/scan.dart:59-61`) is defined as:

```dart
Stream<S> scan<S>(
  S Function(S accumulated, T value, int index) accumulator,
  S seed,
) => ScanStreamTransformer<T, S>(accumulator, seed).bind(this);
```

— exactly two positional arguments. The trailing `false` will not compile. An implementer copying this snippet verbatim into the next milestone will hit a static error and waste cycles diagnosing it.

**Fix:** drop the third argument from the example. The seed parameter already controls when the seed is included; RxDart's `scan` does **not** emit the seed itself — it emits after each new upstream event with the accumulator applied. If the UI needs an immediate "initial" emission on subscribe, wrap with `.startWith(BciPairingStateUpdated(BciPairingState.initial()))` or document that the first upstream event triggers the first emission. (This nuance is worth one sentence so the next-milestone author isn't surprised on first subscribe.)

Corrected snippet:

```dart
Stream<BciPairingServiceEvent> observeChanges() => bciNotifier.stream
    .scan<BciPairingState>(
      (acc, event, _) => _applyEvent(acc, event),
      BciPairingState.initial(),
    )
    .map(BciPairingStateUpdated.new);
```

This is the only blocking issue.

## Architectural notes (WARN)

### 2. `BciPairingState.initial()` style

Task 5 specifies `static BciPairingState initial()`. Returning a `const` instance from a `static` method is fine, but two alternatives are more idiomatic in Dart:

- `factory BciPairingState.initial()` — pairs with the rest of the constructor surface naturally.
- `static const BciPairingState initialValue = BciPairingState(...)` — single shared constant, even cheaper.

Not blocking — pick one and move on. Worth noting because the existing codebase uses both shapes in different modules and consistency hasn't been pinned down anywhere.

## Smaller findings

### 3. Redundant `depends on Task 1` annotations

Tasks 2, 3, and 4 are marked `(depends on Task 1)` but none of them actually import `BciPairingStage` — they're sibling DTOs in `Models/`. Only Task 5 (`BciPairingState`) genuinely depends on Task 1. The annotation doesn't cause harm but suggests a tighter dependency than exists; if the implementer runs tasks in parallel this is moot, but if they read it as a hard serial ordering they'll pay for ordering that doesn't exist.

Either remove `(depends on Task 1)` from Tasks 2/3/4, or change it to "no dependencies" and note that the Phase-1 commit boundary is what holds them together.

### 4. `BciPairingState` field nullability for `calibration`

Task 5 makes `calibration` nullable (`BciCalibrationProgressDTO? calibration`). That's correct — it has no meaning before the calibration stage. Worth noting in the field doc that consumers should treat `calibration == null` as "no active calibration data" rather than "calibration is in stage 0", because the contract note about clearing it on failure sets up exactly that expectation.

Cosmetic.

### 5. Single-variant sealed event class — still ceremonial

`BciPairingServiceEvent` has one variant today (`BciPairingStateUpdated`). Round 1 already flagged this as acceptable (forward-compat headroom matches `BciNotifierEvent` precedent). Keeping for the record only — not a new finding.

## Positive Notes

- All round-1 WARNs and nits have been folded into the relevant task bodies with explicit rationale notes — the plan now teaches the implementer *why*, not just *what*.
- File paths align with the existing `BciPairing/` scaffold (`Models/` already created in the previous milestone).
- Field ordering in `BciPairingState` and barrel-export grouping mirror `breath_module` conventions exactly.
- The cross-reference to RULES.md Rule #1 inside Task 6 is unusually thorough — it tells the next-milestone author exactly which RxDart operator to use, why a `StreamController` is forbidden, and how `copyWith` (Task 5) ties in. This is good for cross-milestone continuity.
- Commit plan is appropriately atomic (Phase 1 = data shapes, Phase 2 = behaviour contracts).
- No `package:mind/Bci/…` imports anywhere in the package — boundary stays clean.
- Verification step in Task 8 uses the absolute Flutter path (`/usr/local/bin/flutter`) per `MEMORY.md`.

## Recommendation

Fix Critical Issue #1 (the `scan` arity bug in Task 6's implementer-guidance snippet) — it's a one-character fix but it will block the next milestone if left. Everything else (notes 2–5) is cosmetic and can be addressed in-flight by the implementer without re-review.
