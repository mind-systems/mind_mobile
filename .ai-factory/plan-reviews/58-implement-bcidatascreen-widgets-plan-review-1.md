# Plan Review: Implement BciDataScreen + widgets

**Plan:** `.ai-factory/plans/58-implement-bcidatascreen-widgets.md`
**Risk Level:** 🟡 Medium — direction and scope are correct, but several spots will require interpretation or hit avoidable correctness issues during implementation.

## Context Gates

- **ARCHITECTURE.md:** PASS — plan respects the domain/module boundary. The new screen, header, and metric bar live inside `packages/bci_module/lib/src/BciData/` and depend only on the DTOs and ViewModel that already exist in the package. No domain types leak into the module. The two new coordinator-entry methods on `BciDataViewModel` correctly funnel UI taps through the `IBciDataCoordinator` interface.
- **RULES.md:** PASS — no concrete service or app-layer state is added. Coordinator is invoked through the ViewModel-owned interface; no streams introduced in App.dart. Task 5 mentions keeping the coordinator field "private to the ViewModel" — see Issue #5 below; current code has it as a public field `final IBciDataCoordinator coordinator;`, which is fine, but the plan's wording is misleading.
- **ROADMAP.md:** PASS — task aligns with roadmap line 127 (`Implement BciDataScreen + widgets`); follow-up wiring (service/coordinator/route/HomeCoordinator) is correctly scoped out to roadmap items 129 and 131.

## Critical Issues

### 1. Heart-rate text concatenation produces broken UX in both locales
Task 4 specifies the heart-rate row as:

```
state.heartRate != null ? '${state.heartRate} ${l10n.bciHeartRate}' : '-- ${l10n.bciHeartRate}'
```

The l10n value of `bciHeartRate` is `"Heart rate"` / `"Пульс"` — a **label**, not a unit. Concatenating produces literal text like:
- EN: `72 Heart rate`
- RU: `72 Пульс`

Both read as bugs. The notes (`24-bci-data-screen.md`) explicitly say the unit is **BPM** (`Heart rate (BPM)`), not the word "Heart rate" appended to a number. Fix options:

- Add a `bciBpm` ARB key (`"BPM"` / `"уд/мин"`) and use it as the trailing unit, with `bciHeartRate` shown only as a section/row label or removed from the value text.
- Or restructure the row to `Icon + "Heart rate" label + value + " BPM"`.

This bug propagates into the disconnected-fallback string `'-- ${l10n.bciHeartRate}'` as well, which would render `-- Heart rate` / `-- Пульс`.

### 2. Task 4 references `l10n` without instructing implementer to obtain it
The Task 4 body code snippets use `l10n.bciNotConnectedMessage`, `l10n.bciHeartRate`, `l10n.bciEegBands`, `l10n.bciEmotionalStates`, etc., but the build method description does not include `final l10n = AppLocalizations.of(context)!;`. Existing screens in the package (e.g. `_BciPairingHeader`) follow this convention. Add this binding explicitly to avoid an implementer omission and a compilation error.

### 3. Task ordering reverses real dependency between Task 4 and Task 5
Task 4 says it depends on Tasks 2 and 3 and calls `vm.onConnectPressed` / `vm.onHeaderTap`. Task 5 says it depends on Task 4 and *adds* those very methods. As written, an implementer working strictly top-to-bottom would write Task 4 referencing methods that do not yet exist on `BciDataViewModel`, breaking compilation between tasks. Swap the dependency: Task 5 should come **before** Task 4 (or fold the two-line VM additions into Task 4 directly). Also note: Task 4's prose mid-step still presents the choice between exposing the coordinator vs. adding ViewModel methods — pick one in the plan; this kind of "OR / pick the latter" wording invites implementer drift.

## Minor Issues / Suggestions

### 4. `BciSectionHeader` is reached via a cross-feature relative import
Task 4 instructs reuse of `BciSectionHeader` from `BciPairing/Views/` via relative import. Functionally fine — it's still inside the same package — but the notes file (`24-bci-data-screen.md`) created a `shared/` directory concept for similar cross-feature reuse (`BciChannelQualityDTO`). The plan opts not to move `BciChannelQualityDTO` to `shared/` (Task 3 imports it from its current location `BciPairing/Models/`), which contradicts the notes' explicit guidance:

> `BciChannelQualityDTO` is currently in `packages/bci_module/lib/src/BciPairing/Models/`. `BciDataState` also needs it. Move it to `packages/bci_module/lib/src/shared/BciChannelQualityDTO.dart`...

Either:
- explicitly defer the move (state in the plan that the shared-folder reorg is out of scope), or
- add a small Task to relocate `BciChannelQualityDTO` and update the existing import in `BciPairingState` + `BciDataState`. The current `BciDataState.dart` already reaches across via `../../BciPairing/Models/BciChannelQualityDTO.dart`, which is an unannounced cross-feature coupling.

The same call applies to `BciSectionHeader` — if it is reused, consider moving it to a `shared/` (or `Views/shared/`) location rather than reaching across feature folders.

### 5. Task 5 wording about coordinator privacy contradicts current code
> "Keep the coordinator field private to the ViewModel (it is already a positional/required-named constructor parameter); do not expose the coordinator instance on the ViewModel's public surface."

`BciDataViewModel.dart` currently declares `final IBciDataCoordinator coordinator;` — **public**, not private. The phrase "keep it private" is inaccurate. Either:
- rename it to `_coordinator` and reference internally (matches the stated intent), or
- drop the "keep private" claim and just document that the coordinator should not be exposed via getters/methods that return the instance.

This is cosmetic but the plan's claim is currently false against the codebase and may confuse the implementer.

### 6. `Views/` directory creation not noted
Tasks 2 and 3 create `packages/bci_module/lib/src/BciData/Views/BciMetricBar.dart` and `BciDataHeader.dart`, but `BciData/Views/` does **not** exist yet (only `BciData/Models/` and the three top-level files). Most editors create parent dirs automatically, but the plan should call this out for completeness — and to keep the structure parallel with `BciPairing/Views/`.

### 7. Task 3 wording "Private ConsumerWidget" is misleading for a file-scope public class
Dart privacy is file-scope. Putting `BciDataHeader` in its own file means it cannot be `_BciDataHeader` if anything outside the file (e.g. `BciDataScreen`) constructs it. The intent — *not exported from the package barrel* — should be the stated rule. Same applies to `BciMetricBar`; Task 2 gets this right ("Keep the widget package-private to `BciData/` — do not export"). Apply the same precise language to Task 3.

### 8. Header `onTap` parameter on `BciDataHeader` overlaps with VM's `onHeaderTap`
Task 3 makes `BciDataHeader` take a `VoidCallback onTap`, then Task 4 wires `BciDataHeader(onTap: vm.onHeaderTap)`. The indirection works, but consider: the header is described as a `ConsumerWidget` that already reads `bciDataViewModelProvider`, so it could call `ref.read(bciDataViewModelProvider.notifier).onHeaderTap()` directly instead of taking the callback in the constructor. Either approach is fine — the plan should commit to one to avoid implementer guesswork (currently it specifies both the constructor callback *and* state-watching from the same provider, which is redundant work).

### 9. `state.batteryPercent` opacity gate mismatch with `isConnected`
Task 3 says battery opacity uses `state.batteryPercent != null`. Task 3 separately says impedance opacity uses `!state.isConnected || channels.isEmpty`. The notes file says battery is `--` and 0.3 opacity when `null`. The notes also say "When disconnected (channels empty) all dots render at 0.3 opacity". These two gates are inconsistent design: when disconnected, the battery could still report a stale percent — should it grey out then, too? Clarify whether the battery opacity should additionally honor `isConnected` (recommended: gate battery opacity on `isConnected && batteryPercent != null` to keep the disconnected header visually uniform).

### 10. `flutter gen-l10n` working directory
Task 1 says "run `flutter gen-l10n` from `packages/mind_l10n/`". The package has `l10n.yaml` and `pubspec.yaml`, so this works. Add an explicit `cd` instruction or absolute-path command, and remind the implementer that the global user rule mandates `/usr/local/bin/flutter`. Plan already mentions the path — good. Consider also a verification step (e.g. `flutter analyze`) since regenerated `app_localizations*.dart` files are committed to the repo.

## Positive Notes

- Scope is appropriately narrow — service/coordinator/wiring are correctly deferred to follow-up roadmap items.
- DTO + state model assumptions are accurate: existing `BciDataState`, `BciEmotionsDTO`, `BciNfbDTO`, and `IBciDataCoordinator.openPairing()` match what the screen needs.
- Color palette matches the notes file exactly.
- Animation parameters (400ms `easeOut`) and bar geometry follow the notes spec.
- Adding `onConnectPressed`/`onHeaderTap` on the ViewModel (instead of exposing the coordinator through a getter) is the correct architectural call and is well justified in-plan.
- Empty-state layout decision (header still visible + centered column with icon + message + Connect button) matches the notes ASCII mock.
- Task 1 correctly enumerates all 10 ARB keys and both locales.
- Plan correctly identifies that `BciMetricBar` should not be exported from the package barrel.
- Task 6 (barrel export) correctly places `BciDataScreen` next to `BciPairingScreen` and leaves internal widgets unexported.

## Recommended Plan Edits Before Implementation

1. Reverse the Task 4 ↔ Task 5 dependency, or merge them.
2. Replace `'${state.heartRate} ${l10n.bciHeartRate}'` with a layout that uses a unit (`bciBpm`) or separates the label from the value.
3. Add an explicit `final l10n = AppLocalizations.of(context)!;` line in the Task 4 build snippet.
4. Decide and document whether `BciChannelQualityDTO` and `BciSectionHeader` should move to a `shared/` folder, or explicitly defer it.
5. Correct the Task 5 privacy statement (or rename the field to `_coordinator`).
6. Pick one wiring pattern for `BciDataHeader`: constructor callback **or** ViewModel access — not both.
7. Clarify whether battery opacity should also gate on `isConnected`.

Once the heart-rate concatenation bug, the task-ordering issue, and the l10n binding are addressed, the plan is ready for implementation.
