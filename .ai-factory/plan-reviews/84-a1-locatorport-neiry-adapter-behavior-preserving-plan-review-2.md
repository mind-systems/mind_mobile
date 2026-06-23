# Plan Review 2: A1 · LocatorPort + neiry adapter (behavior-preserving)

**Plan:** `.ai-factory/plans/84-a1-locatorport-neiry-adapter-behavior-preserving.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid and implementable as written. Two carry-over/low nits, no blockers.

## Verification performed (re-checked against current source)

Independently re-confirmed every codebase assertion the plan makes:

| Plan claim | Verified |
|---|---|
| `_locator` field at `:35` = `neiry.DeviceLocator _locator = neiry.DeviceLocator();` | ✅ exact |
| `_device?` `:36`, `_disposed` `:37`, `_teardownComplete` `:38` | ✅ |
| Teardown drains (`try { await _teardownComplete; }`) at `:106` (scan) / `:151` (connect) / `:617` (disconnect) | ✅ |
| Inline `.map(...)` scan mapping at `:141-144` | ✅ (`requestDevices(type: neiry.NeiryDeviceType.headband, searchTime: 5).map(...)`) |
| `createDevice(serial)` consumed at `:158` | ✅ |
| `_locator.dispose()` `:463`, recreate `_locator = neiry.DeviceLocator()` `:468`, `try/finally` recreate `:561-562` | ✅ |
| `_doDispose` `_locator.dispose()` at `:675` | ✅ |
| Only construction site is `lib/Core/App.dart:193` (`final bciProvider = NeiryBciProvider();`) | ✅ — confirmed line 193, no other `NeiryBciProvider(` in `lib/` or `test/` |
| `BciDeviceInfo` has only `serial` + `name` (no `type`) | ✅ (`Models/BciDeviceInfo.dart:9-17`) |
| `lib/Bci/Ports/` does not yet exist; `test/Bci/` exists | ✅ |

neiry_kit API surface re-confirmed against `../neiry_kit/lib/src/api/`:
- `DeviceLocator.requestDevices({NeiryDeviceType type = NeiryDeviceType.any, int searchTime = 5}) → Stream<List<DeviceInfo>>` (`device_locator.dart:124-127`) ✅. SDK default is `.any`; provider always passes `headband`, and Task 2's `BciScanDeviceType.headband` default preserves that — byte-identical for the provider's call path.
- `DeviceLocator.createDevice(String serial) → Future<Device>` (`:219`) ✅
- `DeviceLocator.dispose() → Future<void>` (`:269`) ✅
- `Device` surface for `DevicePort`: `connect()` (`device.dart:168`, optional `{bipolarChannels=false}` — provider calls no-arg, port declares `connect()`, adapter bridges) ✅, `start()` (`:212`), `stopStream()` (`:228`), `disconnect()` (`:196`), `dispose()` (`:252`), `bool get isStarted` (`:337`), `connectionStateStream` (`:275`), `resistanceStream` (`:305`), `batteryStream` (`:311`) ✅ — matches note 158 exactly.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): PASS. The `LocatorPort`/`NeiryLocatorAdapter` seam lives in `lib/Bci/Ports/`, inside the BCI domain layer, and is consistent with the existing adapter-isolation rule. See nit 2 about the now-stale "only file" doc comment.
- **Rules**: No `.ai-factory/RULES.md` and no `aif-review` skill-context file present (WARN: optional files absent — nothing project-specific to enforce). `CLAUDE.md` logging rule (`logPrint` only) respected — plan adds no logging.
- **Roadmap** (`.ai-factory/ROADMAP.md:282-295`): PASS. A1 at `:292`, A2 at `:293`, B1 at `:295`. Plan's co-dependency framing (A1 declares `DevicePort`, A2 implements it; commit jointly; build green only at A1+A2) matches the roadmap and notes 155/158 precisely.

## Critical Issues

None. Nothing blocks implementation.

## Findings

### 1. (Carry-over from review 1) DevicePort stream element types are still deferred with a soft marker — medium, but A2-territory

Review 1's finding 1 was not incorporated into the plan text: Task 1 still says only "leave a clear `// A2:` marker so A2 finalizes element types." The three device streams emit neiry types today (`connectionStateStream → neiry.NeiryConnectionState`, `resistanceStream → neiry.ResistanceData`, `batteryStream → int`), and `DevicePort` is required to have no neiry imports. The real decision (expose domain-typed streams → relocate `_onNeiryConnectionState` / `_onResistance` mapping into `NeiryDeviceAdapter`, while the `_device == null` idempotency guards at `:258` / `:264` must stay provider-side because they read provider state) lands in A2, not A1.

This remains **not an A1 blocker** — A1 only declares the abstract interface and is genuinely free to emit either shape — but since A1 is committed jointly with A2, the implementer should resolve it during this same change rather than discover it mid-A2. Recommend the `// A2:` marker spell out: battery stays `Stream<int>`; the connection-state/resistance streams are the open wrap-or-expose decision; and the connection-state idempotency logic does not move. This keeps the joint A1+A2 honestly byte-identical.

### 2. (New) The "only file that may import neiry_kit" doc comment goes stale — low

`NeiryBciProvider.dart:32` asserts: *"This is the only file in `mind_mobile` that may import `neiry_kit`."* After this refactor that claim is false on two counts: `NeiryLocatorAdapter` (Task 4) and, jointly, `NeiryDeviceAdapter` (A2) both import `neiry_kit`, and the provider itself still imports it for the classifiers. The plan says the adapter is "consistent with the existing rule on `NeiryBciProvider`" but never schedules updating that comment. Add a one-line task/note to amend the doc comment (e.g. "neiry_kit imports are confined to `NeiryBciProvider` and the `lib/Bci/Ports/` adapters") so the invariant statement stays truthful. Cosmetic, no behavior impact.

### 3. (Carry-over, low) Relative import paths are illustrative, not literal

Task 3's "Import `Models/BciDeviceInfo.dart` and `DevicePort.dart`" won't compile verbatim from `lib/Bci/Ports/` — the model is `../Models/BciDeviceInfo.dart` (or a `package:` import) and `DevicePort.dart` is same-dir. Trivial; the implementer resolves it.

## Positive Notes

- **Line-accurate after a full re-check.** Every cited line still matches the current file — valuable for a behavior-preserving refactor.
- **Factory-not-instance is correct and necessary.** The locator is recreated at `:468` and `:562`; a single injected instance would break the reset path. `LocatorPort Function()` with default `() => NeiryLocatorAdapter()` keeps `NeiryBciProvider()` byte-identical, so `App.dart:193` needs no change.
- **Singleton lifecycle preserved.** `neiry.DeviceLocator()` is a singleton that re-creates only after `dispose()`; wrapping it unchanged in the default adapter reproduces today's exact lifecycle, and the fake deliberately bypasses it — which is the seam's whole point.
- **scan() mapping relocation is exact and the `headband` default preserves the always-headband call.**
- **Teardown gate explicitly fenced.** Hard guards correctly forbid touching `_teardownComplete`, the drains, the `try/finally`, and ordering.
- **Co-dependency honesty.** The explicit "do not expect a green build from A1 in isolation; verification is joint" prevents a false compile-failure panic and matches the roadmap/notes.
- **Anti-goals respected** — no domain latches / `ModuleStateEvent` bus folded in; classifier construction correctly deferred to A3.

## Conclusion

The plan is accurate, well-scoped, and faithful to the characterization-first intent; all codebase and SDK assertions verify against current source. The only substantive item (finding 1) is a deferred design decision that resolves in A2 — the co-committed sibling — not an error in A1, and findings 2–3 are cosmetic. Safe to implement.

PLAN_REVIEW_PASS
