# Plan Review: Implement `BciPairingService` + `BciPairingCoordinator`

**Plan:** `.ai-factory/plans/44-implement-bcipairingservice-bcipairingcoordinator.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** ✅ Plan adheres to the module-boundary contract. The concrete `Service` lives in `lib/BciModule/` (app side), implements the `IBciPairingService` interface declared in `packages/bci_module/`, and converts domain models (`BciDeviceInfo`, `BciChannelQuality`, `BciCalibrationEvent`) → DTOs. No domain types cross the package boundary. Coordinator depends on GoRouter, matching the existing pattern.
- **RULES.md:** ✅ The service is stateless (constructor stores only `bciNotifier`, no `StreamController`, no `StreamSubscription`, no `dispose()`); `observeChanges()` returns a derived stream directly from `bciNotifier.stream`. All dependencies injected via constructor. Matches rule 1 verbatim.
- **ROADMAP.md:** ✅ Plan covers exactly the open task on line 97 of `.ai-factory/ROADMAP.md` (Phase 17 — BCI Device Pairing). Next task (line 99, `BciModule.dart` + `App.dart` + `router.dart` wiring) is correctly out of scope.

## Verification of Assumptions

Spot-checked the codebase against the plan's claims:

| Claim | Status |
|---|---|
| `lib/BciModule/` does not yet exist | ✅ Confirmed |
| `IBciPairingService` declares `observeChanges()`, `startScan`, `connectDevice`, `startCalibration`, `disconnect` — all command methods return `void` | ✅ Confirmed (`packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`) |
| `BciNotifier.startScan/connectDevice/startCalibration/disconnect` all return `Future<void>` | ✅ Confirmed (`lib/Bci/BciNotifier.dart` lines 80–86) |
| `BciNotifier` exposes `knownSerials: List<String>` for `isKnown` derivation | ✅ Confirmed (line 78) |
| `BciNotifierEvent` is sealed with the 6 listed variants | ✅ Confirmed |
| `BciConnectionState` enum has the 6 listed values | ✅ Confirmed |
| `BciCalibrationEvent` is sealed with 3 variants; stage is 1‑indexed | ✅ Confirmed (`NeiryBciProvider.dart:158` emits `BciCalibrationStageFinished(stage.index + 1)`, so `stagesCompleted: stage` is correct) |
| `BciPairingState.copyWith` uses `_undefined` sentinel for nullable fields (`calibration`, `batteryPercent`, `errorMessage`) | ✅ Confirmed (`Models/BciPairingState.dart:42–68`) |
| `BciSignalLevel` enum is `green/yellow/red`; `BciSignalQuality` DTO enum is `good/fair/poor` | ✅ Confirmed; mapping is consistent |
| `BreathSessionCoordinator.dismiss()` uses `if (!context.mounted) return; context.pop();` | ✅ Confirmed — coordinator pattern matches |
| `rxdart 0.28.0` `scan` extension has signature `(S Function(S acc, T value, int index), S seed)` | ✅ Confirmed against `~/.pub-cache/.../rxdart-0.28.0/lib/src/transformers/scan.dart` |
| `dart:async` exports `unawaited` | ✅ Confirmed |
| `App.shared.bciNotifier` exists for the next-milestone wiring | ✅ Confirmed in `lib/Core/App.dart:84,153,195` |

## Issues

### Critical
*(none)*

### Important

1. **`copyWith(channels: ...)` cannot clear the channels list with `null`.** The plan states: "`BciConnectionState.disconnected` → … clear `calibration` and `channels`". `BciPairingState.copyWith` declares `channels` as `List<BciChannelQualityDTO>? channels` (no `_undefined` sentinel), so the body is `channels ?? this.channels`. Passing `channels: null` is therefore a **no-op** that preserves the existing list — only `calibration: null` correctly clears (because `calibration` does use the sentinel).
   - **Fix:** the implementer must pass `channels: const <BciChannelQualityDTO>[]` for the `disconnected` branch (and explicitly state this in the plan to prevent the off-by-one footgun). Same applies if the implementer reads "clear" as "set to null" for `devices` — `devices` is also a plain `List?` falling through.
   - This is the highest-value clarification needed before implementation starts.

### Minor / Worth Considering

2. **`errorMessage` is never cleared on subsequent successful events.** After a `BciError("…")` or `BciCalibrationFailed("…")`, the plan's reducer leaves `errorMessage` populated on every later `BciStateChanged`, `BciDevicesDiscovered`, etc. UI consumers will see stale error text alongside a fresh "connecting" state. Two options worth deciding before implementation:
   - **(a) Clear on transition:** `BciStateChanged` to `scanning` / `connecting` / `ready` clears `errorMessage` via `copyWith(errorMessage: null)`.
   - **(b) Leave as-is** and let the UI dismiss errors explicitly.
   - The plan doesn't choose; pick one and document it as a comment in `_reduce`.

3. **`BehaviorSubject` only replays the last event on subscribe.** `BciNotifier._subject` is a `BehaviorSubject<BciNotifierEvent>` — it caches a single event, not the latest event of each variant. If multiple slice events have already been emitted before the pairing screen mounts (e.g. `BciStateChanged → BciDevicesDiscovered → BciSignalQualityUpdated`), the new subscriber only replays the most recent one. The plan correctly relies on `BciPairingViewModel.initState()` calling `service.startScan()` to trigger fresh emissions, but this assumes the BCI manager re-emits the connection state and discovered devices on every `startScan()` call. Worth a one-line note in the plan acknowledging this assumption — it's load-bearing.

4. **`_reduce` exhaustiveness on `BciNotifierEvent`.** Plan describes the 6 variants but writes them in prose, not a `switch (event)` skeleton. A `switch` over a sealed type yields compile-time exhaustiveness; chained `if (event is ...)` does not. Recommend the plan say explicitly: "use a `switch (event)` statement so the compiler enforces the variant set, mirroring `BreathSessionListService._mapEvent`".

5. **No clearing of `devices` on `disconnected`.** Phrasing-wise the plan says "clear `calibration` and `channels`" but is silent on `devices` and `batteryPercent`. Whether disconnect should reset the discovery list is a UX decision — please call it out (one way or the other) so the implementer doesn't guess.

## Positive Notes

- Plan correctly chose `scan` over the `expand(state.lastEvent)` pattern used by `BreathSessionListService` — the BCI notifier emits typed *slice* events (not a whole-state-with-event-tail), so a rolling reducer is the right shape.
- Imports list is complete and accurate, including the `dart:async` import for `unawaited`.
- `unawaited(...)` wrapping of `Future<void>` commands is the right call given the `void` interface — avoids unhandled future warnings and matches the fire-and-forget contract documented on the interface.
- `_mapStage` extraction keeps `_reduce` readable; the level mapping helper does the same.
- Coordinator implementation mirrors `BreathSessionCoordinator.dismiss()` (including the `context.mounted` guard) — no surprises for downstream maintainers.
- Stage indexing is correct: `NeiryBciProvider` emits `stage.index + 1`, and the plan maps `stagesCompleted: stage` directly.
- Scope is tight — the plan resists the temptation to also do the next-milestone wiring (`BciModule.dart`, `router.dart`).

## Verdict

The plan is structurally sound and architecturally aligned. Only issue (1) is genuinely load-bearing — without the clarification, the `disconnected` branch will silently fail to reset channels and pass code review only because no test exists. Issues (2)–(5) are clarifications that will save back-and-forth during implementation but don't block the design.

Recommend a single revision pass to:
- Make the `disconnected` branch's `copyWith` call explicit (`channels: const []`),
- Pick a stance on `errorMessage` clearing,
- Note the `BehaviorSubject` replay assumption,
- Confirm the desired behaviour of `devices` / `batteryPercent` on `disconnected`.
