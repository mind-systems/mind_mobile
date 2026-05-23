# Code Review: Define BCI data screen module boundary in `packages/bci_module`

**Plan:** `.ai-factory/plans/56-define-bci-data-screen-module-boundary-in-packages-bci-module.md`
**Spec note:** `.ai-factory/notes/24-bci-data-screen.md`
**Scope:** types-only milestone — 5 new Dart files inside `packages/bci_module/lib/src/BciData/` plus exports in `bci_module.dart`.

## Verification performed

- `git status` and `git diff HEAD` reviewed in full.
- Each new file read in full (`BciEmotionsDTO.dart`, `BciNfbDTO.dart`, `BciDataState.dart`, `IBciDataService.dart`, `IBciDataCoordinator.dart`).
- Diff of `packages/bci_module/lib/bci_module.dart` reviewed.
- `flutter analyze packages/bci_module` → **0 issues**.
- Cross-checked against existing pairing pattern (`BciPairingState.dart`, `IBciPairingService.dart`, `IBciPairingCoordinator.dart`).

## Findings

### 1. Service interface diverges from `IBciPairingService` convention — Minor / style

Plan finding #1 from the plan review surfaced this and the implementer (correctly) followed the plan + note rather than the existing pairing convention:

| | `IBciPairingService` (existing) | `IBciDataService` (new) |
|---|---|---|
| Event base | `BciPairingServiceEvent` | `BciDataEvent` |
| Stream | `Stream<...> observeChanges()` (method) | `Stream<BciDataEvent> get events` (getter) |

`RULES.md` line 7 explicitly cites `observeChanges()` as the canonical name: *"`observeChanges()` must return a derived stream directly from the notifier (e.g. `notifier.stream.expand(...)`)"*. The new getter `get events` will still satisfy the spirit of that rule (downstream ViewModel can still wire it via `ref.onDispose`), but the package now ships two different conventions for the same concept.

**Not a runtime bug.** Worth flagging because:
- the future `BciDataViewModel` cannot copy-paste subscription wiring from `BciPairingViewModel`,
- code-readers must remember two names for the same concept,
- `RULES.md` literally names `observeChanges()`.

**Recommendation:** rename `BciDataEvent` → `BciDataServiceEvent` and replace `Stream<BciDataEvent> get events;` with `Stream<BciDataServiceEvent> observeChanges();` (mirroring `IBciPairingService.observeChanges()`). Update the spec note accordingly so future BCI service interfaces don't repeat the asymmetry. This is the only finding worth acting on now — fixing later means rewriting both interface and every call site after the ViewModel/service land.

### 2. `BciDataState.copyWith` cannot distinguish "no change" from "set to empty" for `channels` — Minor / by design

`channels` and `isConnected` use the plain null-coalescing pattern (`channels ?? this.channels`), so:
- Passing `channels: []` correctly replaces with empty list (non-null).
- Passing `channels: null` is impossible at the call site (parameter type is non-nullable `List<BciChannelQualityDTO>?` — wait, it IS nullable in the param but the field isn't, so `null` means "no change").

Since the field is non-nullable, "clear" and "no change" are conceptually identical. This is the same pattern `BciPairingState.copyWith` uses for its own `channels` parameter (line 53 of `BciPairingState.dart`). Correct as written — flagging only to document the intentional asymmetry vs. the sentinel-protected nullable fields.

### 3. No `==`/`hashCode` on any of the new types — Acceptable

`BciDataState`, `BciEmotionsDTO`, `BciNfbDTO` rely on referential equality. Downstream Riverpod consumers (the future `BciDataViewModel`) will rebuild on every emitted `BciDataStateUpdated`, even when the inner field values are unchanged. Same trade-off as `BciPairingState` (also has no equality) so the package stays consistent. Not a bug; flagging in case the future ViewModel hits perf issues on the bar animations and a `freezed` migration becomes worth it.

### 4. `initial()` returns a const instance — Verified safe

`BciDataState.initial()` returns the literal `const BciDataState(channels: [], isConnected: false)`. Dart canonicalizes the const expression, so every call returns the same object — identity equality works for "this state is still pristine" checks. Matches the pairing pattern (`BciPairingState.initial()` does the same).

### 5. Import path for `BciChannelQualityDTO` reaches across feature folder — Acknowledged / deferred

`BciDataState.dart` imports from `../../BciPairing/Models/BciChannelQualityDTO.dart`. The spec note (lines 131–135) calls for relocating this DTO to a `shared/` folder. The plan explicitly defers this ("any relocation is out of scope here"), so this is consistent with what was agreed. Just flagging so a follow-up milestone doesn't get lost — `BciData` now structurally depends on internals of a sibling feature folder.

## Positive observations

- `flutter analyze packages/bci_module` clean.
- Sentinel `_undefined` pattern correctly applied to all four nullable fields (`heartRate`, `emotions`, `nfb`, `batteryPercent`) — clearing semantics work.
- `BciNfbDTO` field order matches the note: `delta`, `theta`, `alpha`, `smr`, `beta`. `BciEmotionsDTO` field order matches the note: `attention`, `cognitiveLoad`, `relaxation`, `cognitiveControl`, `selfControl`.
- Sealed event hierarchy uses `final class` for the subtype — matches the pairing style precisely.
- Exports placed under the matching section headers in `bci_module.dart` (interfaces under "Service + Coordinator interfaces", models under "Other public symbols") — clean grouping.
- DTOs are spartan: `const` constructor, no `copyWith`, no JSON — exactly what stream-fed read-only boundary types need.
- No `dart:` or `package:flutter` imports leaked into the package — boundary discipline holds.
- `IBciDataCoordinator` is a single-method abstract — minimal surface, easy to mock.
- No proto changes, no migration concerns, no inputs to validate — zero security surface.

## Verdict

Implementation is correct, analyze-clean, and faithful to the plan. The only meaningful follow-up is finding #1 (interface-style asymmetry with `IBciPairingService` / `RULES.md`). All other findings are documentation or acknowledged scoping decisions.

REVIEW_PASS
