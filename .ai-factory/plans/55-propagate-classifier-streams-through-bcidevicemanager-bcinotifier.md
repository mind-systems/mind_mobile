# Plan: Propagate classifier streams through `BciDeviceManager` + `BciNotifier`

## Context
Wire the three new classifier streams (NFB, cardio, emotions) — already exposed by `IBciDeviceProvider` / `NeiryBciProvider` from the previous milestone — up through `BciDeviceManager` and `BciNotifier` so the domain notifier emits typed `BciNfbUpdated`, `BciCardioUpdated`, `BciEmotionsUpdated` events. This is the third step in the BCI Data Screen feature (Phase 19) and must land before the `BciDataService` work begins.

Assumption: `BciPairingService._reduce` is an exhaustive sealed-class switch on `BciNotifierEvent` with no `default:`. Adding new sealed variants breaks compilation. The milestone says "no changes — it ignores unknown events via exhaustive switch"; to satisfy both intents we add three no-op `return acc;` cases to keep `BciPairingService` behaviorally unchanged while keeping the switch exhaustive. This is the minimum possible touch to that file.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Event variants

- [x] **Task 1: Add three new sealed event variants to `BciNotifierEvent`**
  Files: `lib/Bci/Models/BciNotifierEvent.dart`
  Add imports for `BciNfbData`, `BciCardioData`, `BciEmotionsData` from `lib/Bci/Models/`. Add three new `final class` variants extending `BciNotifierEvent`, each holding a single payload field, mirroring the style of the existing variants (`BciStateChanged`, `BciBatteryUpdated`):
  - `BciNfbUpdated` with `final BciNfbData data`
  - `BciCardioUpdated` with `final BciCardioData data`
  - `BciEmotionsUpdated` with `final BciEmotionsData data`
  Add a short doc comment above each in the same `///` single-line style used by neighbors. Place them after `BciBatteryUpdated` and before `BciError`.

### Phase 2: Manager delegation

- [x] **Task 2: Expose three classifier streams from `BciDeviceManager`** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  Add three public getters to `BciDeviceManager` that delegate directly to `_provider` — same passive delegation pattern already used for `signalQualityStream`, `batteryStream`, `calibrationStream`:
  - `Stream<BciNfbData> get nfbStream => _provider.nfbStream;`
  - `Stream<BciCardioData> get cardioStream => _provider.cardioStream;`
  - `Stream<BciEmotionsData> get emotionsStream => _provider.emotionsStream;`
  Add the corresponding `import` lines for `BciNfbData`, `BciCardioData`, `BciEmotionsData` from `lib/Bci/Models/`. No state, no subscriptions, no controllers — pure pass-through. Place getters next to the existing provider-delegating getters in the "Public getters" section.

### Phase 3: Notifier subscriptions

- [x] **Task 3: Subscribe to the three new streams in `BciNotifier` and emit typed events** (depends on Task 2)
  Files: `lib/Bci/BciNotifier.dart`
  Mirror the existing pattern used for `_batterySub` (subscribe, map payload → event variant, emit via `_subject.add(...)`, log + emit `BciError` on stream errors).
  - Add three new nullable fields: `StreamSubscription<dynamic>? _nfbSub;`, `_cardioSub;`, `_emotionsSub;`.
  - In the constructor, after `_batterySub = …`, add three `listen` blocks subscribing to `manager.nfbStream`, `manager.cardioStream`, `manager.emotionsStream`, emitting `BciNfbUpdated(data)`, `BciCardioUpdated(data)`, `BciEmotionsUpdated(data)` respectively. Use the same `onError` shape: `logPrint('BciNotifier: <name>Stream error: $e'); _subject.add(BciError(e.toString()));`.
  - In `dispose()`, cancel the three new subscriptions before `_subject.close()` (same order as their declaration). No need to import the new data models — they're only referenced indirectly through the event variants.

### Phase 4: Keep `BciPairingService` switch exhaustive

- [x] **Task 4: Add no-op cases for the new event variants in `BciPairingService._reduce`** (depends on Task 1)
  Files: `lib/BciModule/BciPairingService.dart`
  The existing `_reduce` switch on `BciNotifierEvent` is exhaustive with no `default:` clause; Task 1 makes it non-exhaustive and breaks compilation. Add three minimal no-op cases at the end of the switch (before the closing brace), each immediately returning `acc` unchanged:
  ```dart
  case BciNfbUpdated():
  case BciCardioUpdated():
  case BciEmotionsUpdated():
    return acc;
  ```
  This preserves `BciPairingService` behavior — it does not consume classifier data — while keeping the sealed-switch exhaustive. No imports change (the variants come from the already-imported `BciNotifierEvent` library). Do not touch any other branch.

<!-- orchestrator-sessions
planner: 0b1219a5-b7a0-41b1-826d-6d81bf02d689
implementer: 74d4fe34-9472-466f-9121-89f9c089ee78
-->
