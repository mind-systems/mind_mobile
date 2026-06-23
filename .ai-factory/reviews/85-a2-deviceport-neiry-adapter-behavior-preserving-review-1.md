# Code Review: A2 · DevicePort + neiry adapter (behavior-preserving)

## Code Review Summary

**Files Reviewed:** 1 code file (`test/Bci/neiry_bci_provider_device_port_test.dart`) + 3 planning artifacts
**Risk Level:** 🟢 Low

This milestone is test-only: a controllable `FakeDevicePort` test double plus characterization-lite tests. No production source changed (verified via `git diff HEAD` / `git status` — only the new test file and `.ai-factory/` plan artifacts are staged), so the behavior-preserving guard holds by construction.

### Verification
- Ran `/usr/local/bin/flutter test test/Bci/` — **all 35 tests pass**, including the 8 new tests in the device-port file and the pre-existing A1 locator-port file.
- Traced `connect('FAKE-001')` through `lib/Bci/NeiryBciProvider.dart`: `createDevice` (count→1) → `_device.connect()` (count→1) → `(_device as NeiryDeviceAdapter)` cast on a `FakeDevicePort` throws `TypeError` → catch block calls `disconnect()` (count→1) + `dispose()` (count→1) → `_resetLocatorSession()` → `rethrow`. The test's assertions match the real cleanup path at `NeiryBciProvider.dart:177-200`.
- `throwsA(isA<TypeError>())` is correct for a failed `as` cast in modern Dart (`_TypeError implements TypeError`; legacy `CastError` is now an alias of `TypeError`).
- Stream/lifecycle contract tests correctly use broadcast controllers, subscribe before emitting, and drain with a `Duration.zero` event-loop turn.

### Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. `FakeDevicePort` implements only the narrow `DevicePort` surface and never imports `neiry_kit`, honoring the adapter-boundary rule that only `NeiryBciProvider` and the port adapters may depend on the vendor SDK. The injectable-locator/`createDevice→DevicePort` seam is exercised exactly as the port design intends.
- **Rules (`.ai-factory/RULES.md`):** PASS. No raw logging in test code (the `logPrint` facade rule targets `lib/` and module packages); no `pubspec.yaml` edits; no proto changes.
- **Roadmap:** Plan is anchored to milestone A2 with explicit A1/A3/B1/B2 sequencing notes; scoping to the reachable seam (rather than full happy-path) is documented and justified.

### Critical Issues
None.

### Minor Observations (non-blocking)
- `_ControlledLocatorPort.createDevice` returns the *same* `FakeDevicePort` instance on every call. After the first `connect()` fails, `dispose()` closes that fake's three stream controllers, so a hypothetical *second* `connect()` in the same test would receive a device with already-closed controllers. The current tests only call `connect()` once, so this is not a defect today — just a note for whoever extends these tests under A3/B1/B2 (they will likely want a fresh fake per `createDevice` call).
- The `connect()`-seam test asserts behavior that depends on the `(_device as NeiryDeviceAdapter)` cast remaining in place; this coupling is intentional and clearly documented inline as A3-gated, so it is acceptable as a characterization anchor.

### Positive Notes
- Excellent inline documentation: the A3-gating rationale, the broadcast-controller choice, and the "don't await `close()` with no listener" deadlock-avoidance comment all explain *why*, not just *what*.
- Test-controlled `Completer`s (pre-completed by default, replaceable to gate teardown) are a clean, forward-looking design that sets up B1/B2 ordering characterization without over-building now.
- Call-count + `isStarted` tracking mirrors the established `FakeLocatorPort` seam style, keeping the test suite consistent.
- Default-constructor smoke check confirms the real adapter path is untouched.

REVIEW_PASS
