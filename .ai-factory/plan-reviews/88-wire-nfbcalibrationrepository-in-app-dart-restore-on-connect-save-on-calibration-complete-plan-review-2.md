# Plan Review 2: Wire NfbCalibrationRepository in App.dart + restore on connect + save on calibration complete

## Summary

**Plan File:** `.ai-factory/plans/88-wire-nfbcalibrationrepository-in-app-dart-restore-on-connect-save-on-calibration-complete.md`
**Roadmap Item:** Phase 24 — "Wire `NfbCalibrationRepository` in `App.dart` + restore on connect + save on calibration complete" (ROADMAP.md line 199)
**Risk Level:** 🟢 Low

The plan is small, surgical, and demonstrates careful reading of the existing codebase. Every claim made about file contents, line numbers, signatures, and behavior was verified against the actual sources.

## Context Gates

### ARCHITECTURE.md — PASS
Layered architecture is respected. `NfbCalibrationRepository` is a pure-Dart, Flutter-free repository wired into the domain layer (`BciDeviceManager`). No domain types are leaked across the module boundary by this change; `BciDeviceManager` itself is domain-side. The plan does not introduce new exports into `packages/bci_module`.

### RULES.md — PASS (with note)
- ✅ "All dependencies must be injected via constructor" — the plan injects `NfbCalibrationRepository` into `BciDeviceManager` via a `required` named parameter and stores it as a private final field.
- ✅ "Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only" — the plan **explicitly deviates from the roadmap wording** which suggested adding a `late final NfbCalibrationRepository nfbCalibrationRepository` field on `App`. The plan instead constructs it as a local in `initialize()` and passes it directly into `BciDeviceManager`. This deviation is **correct and rules-aligned** — it mirrors the existing `BciDeviceRepository` pattern (App.dart:162), keeps `App` from accumulating module state, and the repository has a single consumer.

### ROADMAP.md — PASS (with note)
The plan addresses the Phase 24 task at line 199. Three intentional refinements over the roadmap text, each justified:
1. **Restore happens AFTER `_provider.connect(serial)`, not before** — the roadmap suggested calling `importCalibration` before connect. The plan correctly identifies that `NfbCalibrator.importCalibrationData` in `NeiryBciProvider.dart:393-408` mirrors the live `calibrateIndividual()` call (`NeiryBciProvider.dart:360`) and needs an active device binding. Verified: there is no device-bind step that would let import succeed pre-connect.
2. **Short-circuit to `ready` on successful restore** — the roadmap is silent on this. The plan correctly observes that without the short-circuit, the UI would proceed through `impedance` → `startCalibration()` → `BciCalibrationCompleted`, which would overwrite the just-restored data. This is the difference between "the feature works" and "the feature secretly does nothing observable."
3. **Gate `record()` on `data.isValid`** — the roadmap is ambiguous (`_nfbCalibrationRepository.record(_connectedSerial!, data)`). The plan correctly notes that `NfbCalibrationRepository` has a 20-entry FIFO (`NfbCalibrationRepository.dart:7,40-42`) and `latestValid` walks newest→oldest; without the gate, 20 consecutive failures would evict the last good entry permanently. The gate is the right call.

## Codebase Verification

Each plan claim was checked against the actual source:

| Plan claim | Verified |
|---|---|
| `prefs` constructed at App.dart:160 | ✅ line 160 |
| `BciDeviceManager(...)` invocation at lines 164–170 | ✅ matches |
| `BciDeviceRepository` is local + constructor-injected at line 162 | ✅ matches |
| `_repository` field exists in `BciDeviceManager` | ✅ line 24 |
| Initializer list ends with `_repository = repository` | ✅ line 52 |
| `connectDevice` body lines 178–183 | ✅ matches (`await connect`, `_connectedSerial = serial`, `_setState(impedance)`, `unawaited(registerDevice...)`) |
| Outer `catch (e)` at 184–187 | ✅ matches |
| `BciCalibrationCompleted(data: final _)` switch arm | ✅ line 74 |
| `IBciDeviceProvider.importCalibration(NfbCalibrationData)` exists | ✅ IBciDeviceProvider.dart:59 |
| `NfbCalibrator.importCalibrationData` at NeiryBciProvider.dart:408 | ✅ matches |
| `NfbCalibrationData.isValid` field | ✅ NfbCalibrationData.dart:11 |
| `NfbCalibrationRepository.latestValid` returns null if none valid | ✅ NfbCalibrationRepository.dart:30-35 |
| `record()` is `Future<void>` | ✅ NfbCalibrationRepository.dart:37 |
| `dart:async` already imported (no new import for `unawaited`) | ✅ BciDeviceManager.dart:1 |

## Correctness Notes

- The `try`/`catch` around `importCalibration` is essential: `NeiryBciProvider.importCalibration` calls `NfbCalibrationFailReason.values.firstWhere((e) => e.name == data.failReason)` (NeiryBciProvider.dart:396–397), which throws `StateError` if the persisted `failReason` string does not match any current enum name (e.g. enum renamed in a future SDK version). The plan flags this exact failure mode.
- `_connectedSerial!` inside the synchronous listener block after the null check is safe — Dart single-threading guarantees no other listener body or async continuation can null it between the check and the call.
- The plan does not introduce a race against `disconnect()` that wasn't already present. The pre-existing `connectDevice` already had a window between `await _provider.connect(serial)` and `_setState` where a concurrent `disconnect()` could leave state in disagreement; the plan's behavior in that edge case is no worse than current.

## Minor Suggestion (Non-Blocking)

The plan inserts `final nfbCalibrationRepository = NfbCalibrationRepository(prefs: prefs);` immediately after `final prefs = await SharedPreferences.getInstance();` (line 160). That puts it ahead of the `bciDevicesApi`/`bciRepository`/`bciProvider` block (lines 161–163). For readability, placing it next to `bciRepository` (e.g. right before the `BciDeviceManager(...)` call) would group all BCI-related constructions together. The plan's chosen placement is still correct — just slightly less clustered.

## Positive Notes

- Plan accurately quotes line numbers and existing code structure.
- The `try`/`catch` around restore (fault-isolating a corrupt cache entry from the connect path) is the right defensive posture.
- The `data.isValid` gate before `record()` shows the author understood the FIFO eviction semantics.
- Deviation from the roadmap text (no public field on `App`) is documented and justified, not silent.
- The "short-circuit to `ready`" rationale is the highest-value insight in the plan — without it the change would compile, pass casual review, and do nothing observable.

PLAN_REVIEW_PASS
