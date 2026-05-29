# Plan Review: Extract capability mixins + clean `IBciDeviceProvider`

**Plan:** `.ai-factory/plans/65-extract-capability-mixins-clean-ibcideviceprovider.md`
**Spec source:** `.ai-factory/notes/27-biometrics-refactor.md` (Milestone 3)

## Code Review Summary

**Files Reviewed:** 1 plan + relevant codebase (`IBciDeviceProvider.dart`, `NeiryBciProvider.dart`, `BciDeviceManager.dart`, `BciNotifier.dart`, `Core/App.dart`, `neiry_kit` models/classifiers, `Biometrics/Models/*`).
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — no BCI/biometrics section; no boundary rules to enforce. ✅ no gate trigger.
- **Rules (`.ai-factory/RULES.md`)** — all three rules satisfied:
  - "All dependencies must be injected via constructor" → plan injects three new sources into `BciDeviceManager` via constructor. ✓
  - "Never add module-specific state to `App.dart`" → plan reuses the existing `bciProvider` local; no new fields. ✓
  - "Module Services stateless" → not applicable (no Service touched).
- **Roadmap (`.ai-factory/ROADMAP.md`)** — Phase 21 Milestone 3 is the explicit target; plan aligns. ✅

### Verified facts
- `neiry_kit` exports `MEMSClassifier`, `MemsSample`, `RRInterval` — all reachable via the existing `package:neiry_kit/neiry_kit.dart` import (already aliased as `neiry` in `NeiryBciProvider`).
- `MEMSClassifier(device)` factory exists; `memsStream` returns `Stream<List<MemsSample>>` (batched) — plan's per-sample unroll is correct.
- `MemsSample.accelerometer` and `gyroscope` are `({double x, double y, double z})` records — shape-compatible with `MotionData`'s record fields. ✓
- `RRInterval` has `intervalMs`, `timestamp`, `isArtifact` fields — match the handler in Task 8. ✓
- `CardioData` (our domain) requires a `timestamp` field (added in Milestone 2). Plan does NOT touch the existing `_onCardioState` body, which is correct (no migration concern).
- Removed getters in `IBciDeviceProvider` are consumed only by `BciDeviceManager` (verified via `grep`), which is updated in the same milestone. No external consumers break.
- No test mocks of `IBciDeviceProvider` or `BciDeviceManager` exist in the repo, so the interface narrowing + constructor signature change won't break test suites.
- `App.dart:152` is the only `BciDeviceManager(...)` construction site — Task 11's surgical edit is sufficient.
- `BciNotifier` subscribes via `manager.nfbStream` / `cardioStream` / `emotionsStream`, which still exist as delegating getters after Task 10. ✓

### Critical Issues
None. The plan compiles atomically, preserves the existing API surface for downstream consumers (`BciNotifier`, `BciDataService`), and correctly disambiguates the `neiry_kit` types using the existing `neiry.` alias.

### Findings (non-blocking)

**Finding 1 — MEMS classifier construction location is inconsistent with sibling classifiers.**
Task 9 instructs to construct `_memsClassifier = neiry.MEMSClassifier(_device!);` inside `_subscribeDeviceStreams()`. The three sibling classifiers (`_nfbClassifier`, `_cardioClassifier`, `_emotionsClassifier`) are instead constructed inside `connect()` at lines 139–141, with explicit rollback in the `catch` block at lines 142–161. Putting MEMS construction in `_subscribeDeviceStreams()` means:
- If `MEMSClassifier(_device!)` ever throws (the factory throws `StateError` if `device.isConnected` is false), `_subscribeDeviceStreams()` has no try/catch and leaves the provider in a partially-subscribed state with the device already started.
- The pattern silently diverges from the sibling classifiers, making the file harder to read.

In practice the `StateError` is unreachable here because `_device!.connect()` has succeeded by the time `_subscribeDeviceStreams()` runs, so the risk is theoretical. Recommendation: either (a) construct `_memsClassifier` in `connect()` alongside the others and extend that method's rollback `catch` to dispose it too, or (b) keep the plan as-is and add a one-line comment noting that MEMS is constructed lazily inside `_subscribeDeviceStreams()` because it has no per-call options. Mention this choice explicitly in the plan so the implementer doesn't unify the patterns by accident.

**Finding 2 — Plan's rationale for the MEMS dispose call is factually wrong.**
Task 9 comment: *"MEMS is the exception — other classifiers are released indirectly via `_device!.dispose()`, but MEMS leaks native resources without an explicit call."* This is incorrect: the existing `_cancelDeviceSubscriptions()` at lines 340–358 **already** calls `await _nfbClassifier?.dispose()`, `await _cardioClassifier?.dispose()`, and `await _emotionsClassifier?.dispose()` explicitly inside try/catch blocks. The MEMS dispose call is **not** an exception — it follows the same pattern as the other three. The instruction itself (add `await _memsClassifier?.dispose();` in a try/catch) is correct, but the justification should be removed or corrected to "follows the existing classifier dispose pattern".

**Finding 3 — Task 9 wording nit: `MEMSClassifier` should be qualified.**
Task 9 lists the new field as `neiry.MEMSClassifier? _memsClassifier;` (correctly aliased) but the subscribe block writes `_memsClassifier = neiry.MEMSClassifier(_device!);` — both correct. The original note's snippet (`MEMSClassifier(_device!)`, unaliased) would have collided if no alias were used; the plan corrects this. Worth keeping the `neiry.` prefix consistent in every snippet in the plan to avoid copy-paste regression.

### Positive Notes
- Clear separation of capability interfaces vs device-class concerns — matches the long-term goal of plugging non-Neiry sources behind `IHeartRateSource` etc.
- Atomic ordering (interfaces first → interface narrowing + provider + manager wiring together → `App.dart` wire) avoids non-compiling intermediate states.
- Plan correctly chooses not to route `IRrIntervalSource` / `IMotionSource` through `BciDeviceManager` and justifies it (no UI consumer; would pollute `BciNotifierEvent`).
- Plan preserves SDK-supplied `timestamp` per-sample for both RR and MEMS — never substitutes `DateTime.now()`. Matches `RrInterval` / `MotionData` contracts.
- Three-commit plan groups changes by milestone in a way that each commit compiles independently.
- File paths and import strings have been verified against the current codebase; `App.dart:152` confirmed as the single construction site.

PLAN_REVIEW_PASS
