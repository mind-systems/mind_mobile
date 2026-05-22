# Plan Review — 40-define-module-boundary-types-in-packages-bci-module

## Summary

**Plan:** Define the DTOs, state model, and Service/Coordinator interfaces for the `bci_module` package boundary (Phase 17, milestone 11).
**Scope:** 8 tasks, all new files inside `packages/bci_module/lib/src/BciPairing/` plus barrel exports.
**Risk Level:** 🟢 Low — interface-only work, no runtime behaviour, no migrations.

The plan is well-grounded in the existing codebase: it references the right domain types (`lib/Bci/Models/*`), follows the breath_module package conventions, and matches the milestone description in ROADMAP.md verbatim. A few observations follow.

## Context Gates

- **ARCHITECTURE.md:** ✅ Plan honours the Module Boundary contract — DTOs declared inside the package, no `lib/Bci/` imports, domain enums (`BciConnectionState`, `BciSignalLevel`) intentionally mirrored as package-local types (`BciPairingStage`, `BciSignalQuality`). Aligned with the layer rules in `ARCHITECTURE.md:75-82`.
- **RULES.md:** ⚠️ See WARN under Architectural notes — the interface as drafted does not violate Rule #1, but it must be designed so the concrete service (next milestone) can be stateless.
- **ROADMAP.md:** ✅ Plan matches the milestone bullet at ROADMAP.md:91 exactly (field list, file paths, enum variants).

## Critical Issues

None.

## Architectural notes (WARN)

### 1. Service-naming divergence from breath_module

Plan uses `Stream<BciPairingServiceEvent> get events;` — a getter named `events`.
The existing module convention (`IBreathSessionListService.observeChanges()`, `IBreathSessionService.observeSession(id)`) uses a **method named `observeChanges()` / `observeXxx()`**. The plan doesn't justify the divergence.

Either rename to `Stream<BciPairingServiceEvent> observeChanges();` for consistency, or add a one-line rationale in Task 6 explaining why this service uses a getter (e.g. "no arguments and no per-call semantics, so a getter reads more naturally than a method"). My recommendation: rename to match siblings — the cost is zero and grep/onboarding benefit is real.

### 2. RULES.md Rule #1 — interface must permit a stateless concrete service

`RULES.md` Rule #1 mandates that the concrete Service "must be stateless — no `StreamController`, no `StreamSubscription`, no `dispose()`. `observeChanges()` must return a derived stream directly from the notifier (e.g. `notifier.stream.expand(...)`)".

The plan emits `BciPairingStateUpdated(BciPairingState state)` — a snapshot of the **entire** rolling pairing state. `BciNotifier` emits **incremental** events (`BciStateChanged`, `BciDevicesDiscovered`, `BciSignalQualityUpdated`, `BciBatteryUpdated`, `BciCalibrationEventReceived`, `BciError`). To produce a rolling `BciPairingState`, the concrete service has to accumulate. If it does this with a private field + `StreamController`, the next milestone violates Rule #1.

The interface itself is fine — `Stream<…> get events` can be implemented statelessly via RxDart `scan`:

```dart
Stream<BciPairingServiceEvent> get events => bciNotifier.stream
    .scan<BciPairingState>(
      (acc, event, _) => _applyEvent(acc, event),
      BciPairingState.initial(),
    )
    .map((s) => BciPairingStateUpdated(s));
```

**Recommendation:** add a one-sentence note in Task 6 that the concrete service (next milestone) is expected to implement `events` via `notifier.stream.scan(...)` with a pure `_applyEvent` reducer — so the contract designer (this plan) and the implementer (next plan) share the same compliance model. Without that note, the next implementer may reach for `StreamController` and trip Rule #1.

This is also the underlying reason `copyWith` is required on `BciPairingState` (Task 5 calls this out correctly).

## Smaller findings

### 3. `IBciPairingCoordinator` justification

Task 7 says `void close()` "mirrors the minimalism of `IBreathSessionCoordinator`". `IBreathSessionCoordinator` actually has three methods (`openConstructor`, `shareSession`, `dismiss`). The reference is fine in spirit (coordinator is intentionally tiny), but the comparison is inaccurate. Either cite `IBreathSessionConstructorCoordinator` (if it's leaner — worth a glance), or just say "single-action coordinator since the pairing screen has only one nav exit". Cosmetic.

### 4. `BciCalibrationProgressDTO.stagesCompleted` documentation

Task 4 says "range 0–4 documented in a `///` comment". Good. Also worth documenting in the same comment what `isComplete` means relative to `stagesCompleted` — specifically whether `isComplete == true` implies `stagesCompleted == 4`, or whether `isComplete` can be `true` with `stagesCompleted < 4` (e.g. early-finish path). The domain has `BciCalibrationCompleted` as a separate event from `BciCalibrationStageFinished(stage)`, so an implementer might reasonably set `isComplete = true` without first receiving stage-3 finished. The DTO's invariants should be explicit.

### 5. Failure mapping not represented in `BciCalibrationProgressDTO`

`BciCalibrationFailed(String reason)` exists in the domain (`BciCalibrationEvent.dart:31-33`). The plan correctly funnels this into `BciPairingState.errorMessage`, but Task 4's `BciCalibrationProgressDTO` has no `isFailed` flag. That's fine if calibration failure resets `state.stage` back to `impedance` (or `discovery`) and surfaces only via `errorMessage`. Worth adding a single line under Task 5 clarifying this:

> "On calibration failure the concrete service clears `calibration` (sets to `null`), drops `stage` back to `impedance`, and populates `errorMessage` with the failure reason."

This is technically out of scope for an interface-only plan, but documenting the contract here prevents ambiguity for the implementer.

### 6. `BciPairingStage` collapse rationale

Domain `BciConnectionState` has 6 states (`disconnected, scanning, connecting, impedance, calibrating, ready`); the DTO enum has 4 (`discovery, impedance, calibrating, ready`). The collapse is sensible (discovery covers `disconnected/scanning/connecting`, with the granularity captured in `isScanning`/`isConnecting` booleans on the state), but the plan doesn't make the mapping explicit. One sentence in Task 1 would help:

> "`disconnected/scanning/connecting` all map to `BciPairingStage.discovery`; `isScanning`/`isConnecting` carry the granularity for UI affordances (spinner placement, list shimmer)."

### 7. Single-variant sealed event class

`BciPairingServiceEvent` has one variant (`BciPairingStateUpdated`). This is fine and consistent with `BciNotifierEvent` precedent, but is arguably ceremonial — a `Stream<BciPairingState>` would be equivalent today. The plan justifies it ("sealed so future events extend cleanly"). Accept as written; the cost of leaving headroom is one wrapping class.

### 8. Verification step

Task 8 ends with `flutter pub get` + `flutter analyze packages/bci_module`. Per `MEMORY.md`, the canonical Flutter path is `/usr/local/bin/flutter`. The plan uses the absolute path in the verification command — ✅ correct. Just double-checking.

## Positive Notes

- File paths are exact and consistent with the existing `BciPairing/` scaffold (`.gitkeep` already present in `Models/`).
- Field ordering in `BciPairingState` is sensible (stage → device-discovery fields → quality → calibration → battery → error) and the `initial()` factory is correctly `const`.
- Barrel-export grouping follows the breath_module convention precisely.
- Commit plan is appropriately atomic (Phase 1 = data shapes, Phase 2 = behaviour contracts).
- Plan correctly avoids any `import 'package:mind/Bci/...'` inside the package — the boundary stays clean.

## Recommendation

Address WARNs 1 and 2 (rename `events` → `observeChanges()` or add a one-line rationale, **and** add a note that the concrete service uses `scan` to comply with RULES.md Rule #1). The smaller findings (3–6) are doc nits — fold them into the relevant task descriptions if convenient, but they don't block.

