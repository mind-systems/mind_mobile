## Plan Review Summary

**Plan:** A2 · DevicePort + neiry adapter (behavior-preserving)
**Files Reviewed:** plan + 5 codebase files (DevicePort, NeiryBciProvider, existing A1 test, spec note 158, RULES/ARCH gates)
**Risk Level:** 🟢 Low

The plan is accurate and well-scoped. Every load-bearing claim was verified against the actual code:

- `NeiryBciProvider({LocatorPort Function()? locatorFactory})` constructor exists (`lib/Bci/NeiryBciProvider.dart:46`) — the injection seam the plan relies on is real.
- The cast `(_device as NeiryDeviceAdapter).rawDevice` is at **line 171** exactly as stated, and it executes *after* `await _device!.connect()` (line 168) — so a `FakeDevicePort` will have its `connect()` called before the cast throws. Task 2's assertion ("fake's `connect()` called, then throws") is correct.
- The catch/cleanup block calls `_device?.disconnect()` (195) and `_device?.dispose()` (196), then nulls `_device` (198). Task 2's cleanup assertion matches lines 194–198.
- `DevicePort` surface (`lib/Bci/Ports/DevicePort.dart`) is exactly 5 methods + `isStarted` + 3 typed streams — matches the fake the plan describes.
- The existing `_StubDevicePort` / `FakeLocatorPort` patterns in `test/Bci/neiry_bci_provider_locator_port_test.dart` are correctly cited (the new fake should mirror `FakeLocatorPort`'s style).
- Spec note 158's Verify clause genuinely requires a fake injected via the locator that drives the streams + lifecycle — the no-op `_StubDevicePort` does not satisfy it, so the gap analysis in Context is correct.

### Context Gates
- **Architecture** (`ARCHITECTURE.md`): WARN-none. Test-only change; narrow-port + thin-adapter decision is consistent with the existing A1 seam.
- **Rules** (`RULES.md`): PASS. Rules govern module Services/App.dart/constructor injection — none apply to a test file.
- **Roadmap** (`ROADMAP.md`): PASS. This is the test half of an already-tracked Phase-55 layer-A task (A2). No missing linkage.

### Critical Issues
None.

### Issues / Risks to Address (non-blocking)

1. **Task 2 fake teardown must resolve synchronously, or `connect()` hangs.** Task 1 offers two options for `stopStream`/`disconnect`/`dispose`: "gate each on a `Completer`" *or* "return immediately by default." For Task 2 this is not optional: after the cast throws, the catch block does `await _device?.disconnect(); await _device?.dispose();` (lines 195–196). If the fake gates those on an *uncompleted* Completer, `connect()` never rethrows and the `expect(..., throwsA(...))` will time out instead of passing. The plan should state explicitly that Task 2 uses the immediate-return path (or pre-completes the completers), reserving the gated-async behavior for Task 3's deterministic-teardown assertions. Recommend making "return immediately by default" the constructor default and having tests opt *into* gating.

2. **Reused `FakeLocatorPort.dispose()` double-completes its Completer on the connect-failure path.** When `connect()` fails, the catch block calls `_resetLocatorSession()` (line 199), which calls `_locator.dispose()` (line 440) and then re-creates the locator from the same factory — which returns the *same* fake instance (`locatorFactory: () => fakeLocator`). A later `provider.dispose()` calls `_locator.dispose()` again (line 652). The existing `FakeLocatorPort.dispose()` does `_disposeCompleter.complete()` unconditionally, so the second call throws `StateError` (Completer already completed) and `_devicesController.close()` is called twice. Both provider call sites swallow it in `try/catch`, so it is **not a test failure** — but if the implementer adds an assertion on `disposeCallCount` or reuses the fake locator verbatim while listening for errors, it can surprise. Recommend guarding the fake's dispose (`if (!_disposeCompleter.isCompleted) ...`) when extending it for this test.

3. **Provider never subscribes to the fake's streams in this test — by design; keep Task 3 driving the controllers directly.** `_subscribeDeviceStreams()` runs only at line 202, *after* a successful `connect()`, which never happens with the fake (cast throws first). Task 3 correctly tests the stream emits "through the fake's stream controllers to listeners" (i.e., the test attaches its own listeners), not through the provider. This is consistent — just confirming the broadcast-controller rationale in Task 1 ("the provider subscribes once") does not apply on the reachable path here; broadcast is still fine and harmless. No change needed, noted to prevent an implementer from wrongly asserting provider-side propagation.

### Positive Notes
- Correctly identifies that a full `connect()` happy path is A3-gated (raw-device classifier construction) and scopes the assertions to the reachable seam — avoids writing a test that can't pass yet.
- Honors the behavior-preserving guard: no production edits, default real-adapter path explicitly re-asserted via `returnsNormally`.
- Dependencies between tasks (Task 2/3 depend on Task 1) are correct and the final `flutter test test/Bci/` step uses the correct absolute flutter path per project memory.
- Line-number citations throughout the plan are accurate, which substantially de-risks implementation.

The three items above are clarifications/robustness notes, not blockers — the plan as written will produce a working test if the implementer keeps fake teardown non-blocking for Task 2. Approving.

PLAN_REVIEW_PASS
