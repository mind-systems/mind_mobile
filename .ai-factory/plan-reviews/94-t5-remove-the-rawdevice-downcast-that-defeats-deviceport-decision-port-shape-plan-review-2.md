# Plan Review #2 — Remove the `rawDevice` downcast that defeats DevicePort (T5)

**Plan:** `94-t5-remove-the-rawdevice-downcast-that-defeats-deviceport-decision-port-shape.md`
**Files Reviewed:** plan + 6 production files + all 5 Bci test files + prior review #1
**Risk Level:** 🟢 Low (all review-#1 blockers resolved; two minor test-migration completeness nits remain)

## Review-#1 Follow-up — all four issues resolved

- **Issue #1 (dangling doc refs → would fail Task 8 grep):** RESOLVED. Task 4 now explicitly enumerates the two surviving references and their edits. Verified accurate: `NeiryClassifierSet.dart:21` literally contains *"This is one of two files (with [NeiryClassifierFactory]) permitted to import `neiry_kit`."*; `ClassifierSet.dart:9` literally contains *"Production default: [NeiryClassifierFactory] (A3)."* Both line numbers and quoted text match the codebase exactly.
- **Issue #2 (device_port/locator_port lack `FakeClassifierSet` + import):** RESOLVED. Task 6 now states *"Neither file currently defines a `FakeClassifierSet` or imports `ClassifierSet.dart`"* and instructs adding both. Confirmed: neither `neiry_bci_provider_device_port_test.dart` nor `neiry_bci_provider_locator_port_test.dart` imports `ClassifierSet.dart` or defines a set fake.
- **Issue #3 (build-once counter):** RESOLVED. The shared migration pattern and Task 5 now specify `buildClassifierSetCallCount` to preserve the "built once per connect()" assertion that previously read `fakeFactory.buildCallCount`.
- **Issue #4 (threading the set into vended device fakes):** RESOLVED. The plan now explicitly picks "each device fake **owns its own** `FakeClassifierSet`" and notes no test asserts cross-reconnect set identity (verified).

## Context Gates

- **Roadmap (PASS):** T5 milestone is real; the Option-2 decision and blast-radius rationale carry over unchanged from review #1's verification.
- **Rules (PASS):** Removing the `classifierFactory` constructor seam does not violate constructor-injection rules — `DevicePort` is still injected via `locatorFactory`, and tests drive the set through the injected device fake.
- **Architecture (PASS):** `buildClassifierSet()` on `DevicePort` returns the neiry-free `ClassifierSet`, keeping the port vendor-clean. No circular import (`ClassifierSet.dart` does not import `DevicePort.dart`).

## Verified Accurate (against the codebase)

- Production line refs all match: `NeiryDeviceAdapter.rawDevice` getter `:29` (+ its `NeiryClassifierFactory`-referencing doc at `:25`–`:28`); `NeiryBciProvider` imports `:27`/`:31`, `_classifierFactory` field `:44`, ctor params `:51`/`:52`/`:54`, build site `:183`, quarantine doc `:38`.
- `NeiryBciProvider` still references `neiry.` types directly (calibration: `:74`, `:286`, `:327`, `:355`, `:369`), so the line-5 `neiry_kit` import correctly stays — the plan does not remove it, and the quarantine list correctly keeps `NeiryBciProvider`. ✓
- Quarantine accounting correct: `neiry_kit` is imported by exactly 5 files today; deleting `NeiryClassifierFactory` shrinks the set to 4 as stated.
- `ClassifierFactory`/`NeiryClassifierFactory` are referenced in `lib/` only inside `NeiryBciProvider.dart` (imports + field/ctor) — no other production caller injects `classifierFactory:`. Safe to delete the seam.
- Test fake-class names verified per file: classifier-port (`FakeDevicePort`, `FakeClassifierSet`, `FakeClassifierFactory`); device_port/locator_port (`FakeDevicePort`/`_StubDevicePort`, no set fake); races + full_teardown (`GatedFakeDevicePort`, `RecordingLocatorPort`, `FakeClassifierSet`, `FakeClassifierFactory`); races `_ThrowingDeviceLocatorPort`; command_queue (`_GatedFakeDevicePort`, `_RecordingLocatorPort`, `_FakeClassifierSet`, `_FakeClassifierFactory`). All match the Task 5–7 names.
- Test line refs match: classifier-port A2 group `:353`/`:351`–`:374`, default-ctor smoke `:341`–`:349`; device_port cleanup test `:138`–`:170` with the stale `rawDevice` comment at `:146`–`:150`; races `_connectThenDrop` `:329` constructing `FakeClassifierSet()` at `:331` and wiring `classifierSet: fakeSet` at `:368`; races "Phase 4 — partial L1" `:766`–`:812` and `_ThrowingDeviceLocatorPort` `:824`–`:833` (both currently assert `throwsA(isA<TypeError>())`).
- Catch-block flow preserved: a throwing `buildClassifierSet()` lands at the same point the cast `TypeError` did (after `device.connect()`, before `device.start()`), so the migrated failure-path tests keep `disconnect()`/`dispose()` counts at 1 each. In Phase 4 both the thrown set-build error and the swallowed `throwOnDispose` are `StateError`, so `throwsA(isA<StateError>())` matches the rethrown build error — verified the inner try/catch swallows the dispose throw.
- command_queue `fakeSet` locals (`:180`/`:214`/`:245`) are never asserted against — they only satisfy the ctor. Migration there is purely mechanical (delete the factory injection; `_GatedFakeDevicePort` owns an argless `_FakeClassifierSet()`).

## Minor Issues / Completeness Nits (non-blocking)

**1. Task 7's "In particular" callout names only the races test, but the identical `_connectThenDrop`/`_DropSetup.classifierSet` pattern also lives in `full_teardown_test.dart` — and is used more heavily there.**
The callout cites *"races test `:331`/`:368`"*, but `neiry_bci_provider_full_teardown_test.dart` has its own `_DropSetup` (`:430`, `classifierSet` field `:435`), `_connectThenDrop` (`:458`, constructs `FakeClassifierSet(order)` `:461`, wires `classifierSet: fakeSet` `:483`), plus a `_connectThenDropRunToCompletion` variant (`:509`). The set there is dereferenced as `s.classifierSet.throwOnDispose` / `.closeControllers()` across ~6 sites (`:552`, `:565`, `:599`, `:728`, …). The blanket Task-7 instruction ("re-source the dispose-order/identity assertions from the device-owned set") *does* cover this since full_teardown is a listed Task-7 file, but the explicit pointer naming only the races file risks the implementer overlooking full_teardown's identical re-sourcing. **Suggestion:** widen the callout to "both `races` and `full_teardown` `_connectThenDrop`/`_DropSetup.classifierSet`."

**2. full_teardown's `FakeClassifierSet` constructor differs from the others — it requires the shared `TeardownOrder`.**
`full_teardown`'s `FakeClassifierSet(this._order)` (`:254`) appends `'classifierDispose'` to the shared ordering list that the dispose-sequence assertions depend on; races/command_queue use argless sets. The plan's "device owns its own `FakeClassifierSet`" is correct, but for full_teardown the device fake `GatedFakeDevicePort(this._order)` (which already holds `_order`, `:159`) must **forward** that order into its set: `FakeClassifierSet(_order)`. This is compile-guarded (an argless construction won't compile against the required positional param), so the risk is low — but a one-line note prevents the implementer from trying to make full_teardown's set argless and losing the `'classifierDispose'` ordering step. **Suggestion:** add "in full_teardown, forward the device fake's `TeardownOrder` into its owned `FakeClassifierSet` to preserve the dispose-ordering step."

**3. Stale test description string in the default-ctor smoke test.**
classifier-port `:342`–`:344` describes the smoke test as *"default NeiryClassifierFactory wired, production path untouched"*. Task 5 says to keep this test but doesn't mention updating the now-inaccurate description (there is no default factory after the change). Cosmetic — covered in spirit by Settings "update affected inline doc-comments only" — but worth an explicit word so the string isn't left referencing a deleted class.

## Positive Notes

- The revision cleanly folded in every review-#1 finding with concrete, codebase-accurate edits (verified line numbers and quoted text), rather than vague acknowledgements.
- The shared migration pattern (own-your-own set, `buildClassifierSetCallCount`, `throwOnBuildClassifierSet` → `StateError`) is the right abstraction and removes per-task repetition.
- The failure-path reasoning (throw lands at the same point as the old cast; cleanup counts unchanged; `StateError` matcher swap) is correct and verified against the provider's catch block.
- Commit split (1–4 production, 5–8 tests) matches the dependency ordering and keeps the tree green at each commit.

## Verdict

All blocking issues from review #1 are resolved, and every production and test line reference checks out against the codebase. The remaining three items are minor completeness/cosmetic nits in the test migration — each is compile-guarded or cosmetic and would not derail an implementer. The plan is ready to implement.

PLAN_REVIEW_PASS
