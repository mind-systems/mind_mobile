# Plan Review: Define BCI data screen module boundary in `packages/bci_module`

**Plan file:** `.ai-factory/plans/56-define-bci-data-screen-module-boundary-in-packages-bci-module.md`
**Spec note:** `.ai-factory/notes/24-bci-data-screen.md`
**Risk Level:** 🟢 Low

## Summary

Types-only milestone: introduces `BciData/` subfolder inside `packages/bci_module`, with two DTOs (`BciEmotionsDTO`, `BciNfbDTO`), one immutable state (`BciDataState`), two interfaces (`IBciDataService`, `IBciDataCoordinator`), and the matching public exports. Scope is narrow and well-defined. The plan correctly mirrors the existing `BciPairing/` shape — sealed event base + `final` subtypes, sentinel `_undefined` for clearable nullables in `copyWith`, `static initial()` returning a `const` instance, module boundary in the package with no domain leakage.

## Context Gates

- **Architecture (CLAUDE.md / module-system.md):** PASS. Service + coordinator interfaces declared inside the package alongside future ViewModel; DTOs replace domain models at the boundary; no Flutter / Riverpod / domain imports introduced in this milestone.
- **Rules:** PASS. English-only files, no `.proto` modification, `pubspec.yaml` untouched, no commits performed during planning.
- **Roadmap:** Not checked (no `.ai-factory/ROADMAP.md` referenced from the plan; milestone is task-scoped, not roadmap-scoped). WARN — non-blocking.

## Findings

### 1. Stream API name and event class name diverge from `IBciPairingService` — WARN

Task 4 says *"Match style used in `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart` (sealed event base, `final class` subtypes)"*, but the snippet it prescribes differs from pairing in two ways:

| | Pairing (existing) | Plan for Data |
|---|---|---|
| Event base class | `BciPairingServiceEvent` | `BciDataEvent` |
| Stream accessor | `Stream<...> observeChanges()` (method) | `Stream<BciDataEvent> get events` (getter) |

The `BciPairingViewModel` already wires against the method-style API (`StreamSubscription<BciPairingServiceEvent>` on line 18 of `BciPairingViewModel.dart`). Mixing styles inside the same package means the eventual `BciDataViewModel` won't be copy-pasteable from `BciPairingViewModel` and code-readers have to keep two conventions in their head.

The note (lines 182–192) uses the `get events` form, so the plan is faithful to the note — but the note was authored before the pairing implementation landed. Recommend one of:

- **Preferred:** rename to `BciDataServiceEvent` and use `Stream<BciDataServiceEvent> observeChanges();` so the two interfaces are symmetric.
- **Alternative:** keep the plan as-is but explicitly call out the divergence as intentional and acknowledge it'll create asymmetry in the package.

Either way, drop the "match style" claim if the chosen names don't actually match.

### 2. `BciChannelQualityDTO` relocation to `shared/` is deferred — WARN (acknowledged)

The note (lines 131–135) instructs moving `BciChannelQualityDTO` from `BciPairing/Models/` to `shared/BciChannelQualityDTO.dart`. The plan deliberately defers this (Task 3 last paragraph) and imports from the current pairing-scoped path via `../../BciPairing/Models/BciChannelQualityDTO.dart`.

This is a reasonable scoping decision for a types-only milestone, but it leaves `BciData` reaching across feature boundaries into `BciPairing/Models/`, which is exactly the layout problem the relocation was meant to fix. Acceptable as long as:

- a follow-up task explicitly captures the relocation + import updates (currently no roadmap/follow-up reference is named in the plan), **and**
- reviewers of subsequent milestones don't accidentally normalize the temporary import.

Recommend adding one line to the plan's Context section: *"Follow-up milestone X handles relocation to `shared/` — out of scope here."*

### 3. `initial()` factory must be `const`-compatible — minor

Task 3 says *"`static BciDataState initial()` returning a const instance with all nullable fields `null`, `channels` empty, and `isConnected: false`."*

This is achievable (`=> const BciDataState(channels: [], isConnected: false);`) because `BciPairingState.initial()` does the same. Just flagging that the implementation MUST return the `const` instance from a single const literal — not call the constructor without `const`, since the const-ness is what gives identity-equality for the initial state. The plan wording is correct; this is a note for whoever implements.

### 4. Export grouping is described but example ordering is not committed — minor

Task 6 lists the five exports but doesn't show the final block. Given the pairing block:

```dart
// Service + Coordinator interfaces
export 'src/BciPairing/IBciPairingService.dart';
export 'src/BciPairing/IBciPairingCoordinator.dart';
// Other public symbols
export 'src/BciPairing/Models/BciPairingStage.dart';
// ...
```

Implementer should place the new interfaces after the pairing pair and the DTO/state exports after the pairing Models exports — i.e., interleave by section, not append at the bottom. The plan implies this with "group under existing sections" but doesn't show the result; an implementer might still append at the end. Suggest making the desired ordering explicit, or accept that this is a trivial review issue at implementation time.

## Positive Notes

- Correctly identifies this as types-only and explicitly excludes ViewModel/concrete service/widgets — keeps the milestone reviewable.
- References the concrete file (`BciPairingState.dart`) for the sentinel `_undefined` `copyWith` pattern rather than describing it abstractly — implementer can copy the pattern verbatim.
- Commit plan splits cleanly along data-vs-interface boundary; both commits compile independently (assuming Task 6's pairing exports stay untouched — they will, since the plan only adds lines).
- DTOs explicitly disclaim `copyWith` and JSON — appropriately spartan for stream-fed read-only boundary types.
- No proto changes; no migration concerns; no security surface introduced (read-only stream consumer, no inputs).
- No assumption that `channels: const []` becomes a shared instance — that nuance is correctly inherited from the pairing pattern.

## Verdict

Plan is solid and accurately scoped. The two WARN findings (interface-style asymmetry, deferred relocation) are documentation/consistency concerns, not correctness blockers — recommend addressing finding #1 (rename to `BciDataServiceEvent` + `observeChanges()`) before implementation to avoid creating a second convention inside the package. Findings #2–#4 can be handled inline by the implementer.

PLAN_REVIEW_PASS
