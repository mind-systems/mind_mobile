# Plan: Wire `activeRrSource` in `App.initialize()`

## Context
Expose the existing `ActiveRrSource` (Phase 22 Milestone 1, already implemented in `lib/Biometrics/ActiveRrSource.dart`) via the `App` singleton so that `BreathModule.buildSession()` can reach it through `App.shared.activeRrSource`. This is wiring only — no behavior change yet; the breath module starts consuming it in later milestones.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Construct and expose `activeRrSource`

- [x] **Task 1: Import `ActiveRrSource` in `App.dart`**
  Files: `lib/Core/App.dart`
  Add `import 'package:mind/Biometrics/ActiveRrSource.dart';` to the existing import block (keep grouping consistent with the other `lib/Biometrics/...` imports already present, e.g. next to `BioStreamRouter.dart`).

- [x] **Task 2: Add `activeRrSource` field and constructor parameter on `App`**
  Files: `lib/Core/App.dart`
  - Add a new `final` field on the `App` class: `final ActiveRrSource activeRrSource;` — place it next to the other biometrics-related fields (right after `bioStreamRouter` or near `biometricBatcher`).
  - Add a matching `required this.activeRrSource,` entry in the private `App._({...})` constructor parameter list, preserving the existing field order.

- [x] **Task 3: Construct `activeRrSource` in `initialize()` after the `bioStreamRouter` block**
  Files: `lib/Core/App.dart`
  Immediately after the last `bioStreamRouter.register*(bciProvider);` line (currently `bioStreamRouter.registerMotionSource(bciProvider);`) — and before the `biometricStreamClient` line — add:
  ```dart
  final activeRrSource = ActiveRrSource([bciProvider]);
  ```
  Use the **same** `NeiryBciProvider` instance (`bciProvider`) that was registered into `bioStreamRouter` above. The two consumers (router = server-merge, ActiveRrSource = client-active) intentionally share the source instance — that is the architectural point of this wiring.
  Follow `App.dart`'s house style (see header comment on lines 1–4): keep the assignment on a single line, no trailing comma, no multi-line named-parameter formatting.

- [x] **Task 4: Pass `activeRrSource` into `App._(...)` invocation**
  Files: `lib/Core/App.dart`
  In the `shared = App._( ... );` block near the end of `initialize()`, add `activeRrSource: activeRrSource,` in the same relative position as the field declaration from Task 2 (keep the order consistent across field list, constructor params, and constructor invocation).

## Notes

- **No `dispose()` path exists on `App` today** — the milestone description's "if `App` has a `dispose()` path" branch does not apply. The spec's dispose-order requirement (`activeRrSource.dispose()` before `bciProvider.dispose()`) is recorded here for the day an `App.dispose()` is introduced, but no code is added in this plan.
- **No UI / module imports are changed.** `BreathModule.buildSession()` will consume `App.shared.activeRrSource` in a later milestone (Phase 22 M5); that is out of scope here.
- **Style discipline:** `lib/Core/App.dart` enforces single-line initializers, no trailing commas on initializer lines, and no multi-line named-parameter calls inside `initialize()`. All edits in this plan are trivially single-line; preserve that contract.
- **Reference spec:** `.ai-factory/notes/29-heart-rate-tick-source.md` — "Milestone 2 — Wire `activeRrSource` in `App.initialize()`".

<!-- orchestrator-sessions
planner: be075dac-d0ae-4bd3-950d-7084f083eea7
elapsed: 334
implementer: 90bc90b6-4a9f-44dd-b9a9-4ff77352d229
-->
