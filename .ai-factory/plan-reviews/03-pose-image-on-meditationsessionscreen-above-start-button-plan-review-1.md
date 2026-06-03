# Plan Review: Pose image on MeditationSessionScreen above start button

**Plan:** `.ai-factory/plans/03-pose-image-on-meditationsessionscreen-above-start-button.md`
**Files Reviewed:** 4 (state, ViewModel, module wiring, screen) + assets + ROADMAP/RULES
**Risk Level:** 🔴 High — two blocking defects, both verifiable against the codebase

---

## Context Gates

- **Architecture (`ARCHITECTURE.md`)** — present. The module boundary (package = presentation, `lib/` = wiring) is respected by the plan's file split. No boundary violation in the *intent*, but see RULES below for the wiring *mechanism*.
- **Rules (`RULES.md`)** — **ERROR.** RULES.md line 9: *"All dependencies must be injected via constructor. Never wire a class from the outside by calling its methods or subscribing to streams on its behalf — if a class needs a dependency, pass it in the constructor."* Task 3 (`MeditationSessionViewModel().._poseId = poseId`) wires the VM from the outside by mutating a field, which is exactly the pattern this rule forbids. See Critical Issue 1.
- **Roadmap (`ROADMAP.md`)** — linked. This plan implements the Phase milestone at ROADMAP line 17 ("Pose image on `MeditationSessionScreen` above start button"). Note: the roadmap line itself encodes the same two defects below (`vm.._poseId` and raw `meditation-pose-$poseId.png`) — the plan faithfully copied them, so the roadmap text should be treated as a spec sketch, not a verified contract.

---

## Critical Issues

### 1. BLOCKER — `_poseId` is library-private; Task 3 will not compile

`_poseId` is declared (Task 2) inside
`packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`,
which belongs to the **`meditation_module` package library**.

Task 3 then writes `MeditationSessionViewModel().._poseId = poseId` from
`lib/MeditationModule/MeditationModule.dart`, which is a **different library** (the host app).

In Dart, identifiers prefixed with `_` are library-private. A private member declared in the package is **not visible** from the host-app file. `vm.._poseId = poseId` therefore fails to compile:
> The setter '_poseId' isn't defined for the type 'MeditationSessionViewModel'.

This is not a style nit — the plan as written does not build.

**The note (`63-meditation-session-pose-image.md`) justifies this by claiming BreathModule threads params "by setting a field on the notifier." That claim is false.** `BreathModule.buildSession` (lib/BreathModule/BreathModule.dart:43) injects via the **constructor**:
```dart
final vm = BreathViewModel(tickService: ..., service: ..., coordinator: ..., sessionId: sessionId);
```
There is no external field mutation anywhere in BreathModule.

**Fix (matches BreathModule + satisfies RULES.md line 9):** make `poseId` a constructor parameter of the Notifier.

```dart
// MeditationSessionViewModel.dart
class MeditationSessionViewModel extends Notifier<MeditationSessionState> {
  MeditationSessionViewModel({required this.poseId});
  final String poseId;
  ...
  @override
  MeditationSessionState build() {
    ref.onDispose(() => _stateController.close());
    return MeditationSessionState.initial(poseId: poseId);
  }
}
```
```dart
// MeditationModule.buildSession — override factory
meditationSessionViewModelProvider.overrideWith(() {
  final vm = MeditationSessionViewModel(poseId: poseId);
  stateChannel = MeditationModuleStateChannel(
    channel: App.shared.moduleStateChannel,
    stateStream: vm.stream,
    poseId: poseId,
  );
  return vm;
});
```
This removes Task 2's `String? _poseId` field and the `_poseId ?? ''` fallback entirely (poseId is always supplied by the route — `lib/router.dart:64` does `state.extra as String`), so `build()` no longer needs an empty-string default.

> If a public mutable field is preferred over a constructor arg for some reason, it must be **public** (`poseId`) — but constructor injection is the codebase convention and the RULES.md requirement, so prefer that.

### 2. BLOCKER — raw `$poseId` interpolation breaks the `half_lotus` pose (invisible image)

Task 4 builds the asset path as:
```dart
'assets/images/modules/meditation/meditation-pose-$poseId.png'
```

The pose ids (`packages/meditation_module/lib/src/Models/MeditationPoses.dart`) use **underscores**:
`easy`, `lotus`, `half_lotus`, `seiza`, `chair`, `savasana`.

The asset files on disk use **hyphens**:
```
meditation-pose-chair.png      meditation-pose-half-lotus.png   meditation-pose-savasana.png
meditation-pose-easy.png       meditation-pose-lotus.png        meditation-pose-seiza.png
```

For `poseId == 'half_lotus'`, raw interpolation yields `meditation-pose-half_lotus.png`, **which does not exist**. Because Task 4 wires `errorBuilder: (_, __, ___) => const SizedBox.shrink()`, the failure is **silent** — the half-lotus pose simply renders nothing above the button, with no error box to make the bug obvious in a smoke test. The other five ids happen to contain no underscore and work, which is exactly what makes this easy to miss.

This is the *same defect* already caught and resolved in
`.ai-factory/plan-reviews/01-declare-pose-assets-meditation-list-cell-with-image-plan-review-1.md`.
The fix already shipped in the sibling widget — `MeditationListCell.dart:17`:
```dart
final assetName = 'meditation-pose-${poseId.replaceAll('_', '-')}.png';
```

**Fix:** normalize underscores to hyphens, identical to `MeditationListCell`:
```dart
SizedBox(
  width: 240, height: 240,
  child: Image.asset(
    'assets/images/modules/meditation/meditation-pose-${poseId.replaceAll('_', '-')}.png',
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  ),
),
```
Also correct the plan's "Known pose ids" note (line 35): it lists `half-lotus` (hyphen) as an id, but the actual id is `half_lotus` (underscore) — that wording is what masks the bug.

> Keep the `errorBuilder` as a safety net for genuinely unknown ids, but it must not be relied on to paper over the underscore mismatch for a *known* pose.

---

## Non-blocking Notes

- **`.initial({required String poseId})` initializer** (Task 1) — `: status = MeditationSessionStatus.idle, poseId = poseId` is valid Dart (left `poseId` = field, right = param). With Fix 1 the `build()` call becomes `MeditationSessionState.initial(poseId: poseId)` (no `?? ''`). Fine as-is.
- **Narrow `select` on `poseId`** (Task 4) — correct and efficient. Note that `poseId` never changes after init (route-provided, never mutated by `start()`/`stop()`/`copyWith` callers), so the select effectively never re-fires for it — harmless, just slightly more machinery than needed. Acceptable.
- **`copyWith({String? poseId})`** (Task 1) — adding the param is correct and keeps `poseId` preserved across `start()`/`stop()` transitions. Good.

## Positive Notes

- Correct, minimal file set; respects the package/`lib` module boundary.
- Reuses the established `Image.asset` + `errorBuilder` + 240×240 sizing convention.
- Narrow `select` shows awareness of Riverpod rebuild scoping.
- Threading via the `overrideWith` factory is the right injection point — only the *mechanism* (private field vs constructor) needs correcting.

---

## Verdict

Two blocking defects that the implementation will hit immediately (one is a hard compile error, one is a silent runtime gap for `half_lotus`). Both have concrete, codebase-proven fixes above. Resolve Critical Issues 1 and 2, then the plan is sound.

**Required before implementation:**
1. Inject `poseId` via the `MeditationSessionViewModel` **constructor** (drop the private `_poseId` field) — fixes the compile error and the RULES.md violation.
2. Normalize the asset path with `poseId.replaceAll('_', '-')` — fixes the invisible `half_lotus` image.
