# Plan Review: Always require calibration on every BCI connect

**Plan:** `19-always-require-calibration-on-every-bci-connect-remove-importcalibration-from-connectdevice.md`
**Files Reviewed:** 4 (1 plan + 3 targets) plus interface/provider/repository cross-checks
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** No boundary violation. The change is confined to the `lib/Bci/` domain layer (`BciDeviceManager`), touches no module/service boundary, no DTO, no DI wiring. ✅
- **Rules (`RULES.md`):** N/A — none of the three rules (stateless module Services, App.dart purity, constructor injection) are affected by this change. ✅
- **Roadmap (`ROADMAP.md`):** Milestone-aligned — ROADMAP line 67 references this exact "always require calibration" work. Note 98 (`98-nfb-calibration-always-require.md`) is the research anchor for the plan and is consistent with it. ✅

## Verification Against Codebase

All plan assumptions check out against the actual source:

- **`connectDevice()` lines ~195–226** — exact match. The `var restored = false;`, the `latestValid(serial)` lookup, the `try { await _provider.importCalibration(cal); restored = true; }` block, and the guarded `_setState(restored ? ready : impedance)` all exist as described (lines 204–221). ✅
- **Replacement block is correct** — after removal, the guard `if (_state == BciConnectionState.connecting) { _setState(BciConnectionState.impedance); }` is the right transition. `_provider.connect()`, `_connectedSerial = serial`, `registerDevice()`, and the outer `catch → disconnected` are correctly preserved. ✅
- **`BciCalibrationCompleted` handler** (lines 78–89) — plan correctly says to leave it untouched; `record()` history + `calibrating → ready` transition are independent of the removed code. ✅
- **`_nfbCalibrationRepository` field stays used** — confirmed: still referenced by `record()` (line 85) and `refreshFromServer()` (line 149). No imports become unused. ✅
- **Doc Task 3 quote** — the sentence in `docs/bci/device-manager.md` line 41 matches the plan's quote verbatim ("Они сохраняются локально и переиспользуются при следующих подключениях…"). ✅
- **Doc Task 2 target** — `docs/bci/nfb-calibration.md` line 32 has the `latestValid(serial)` bullet, and the intro (line 3) already states manual calibration on each connect. ✅
- **No tests reference** the removed behavior (`test/` has no matches for `importCalibration`/`connectDevice`/`restored`), consistent with `Testing: no`. ✅

## Non-Blocking Observations

1. **`importCalibration` becomes dead in app code.** After this change, `IBciDeviceProvider.importCalibration()` and its `NeiryBciProvider` implementation (line 402, calling `neiry.NfbCalibrator.importCalibrationData`) will have no callers. The plan (and note 98) deliberately keeps them for a possible future opt-in "restore previous" action. This is an intentional, reasonable choice — just be aware a lint/analyzer "unused" warning will not fire (interface methods aren't flagged), so no build impact. No action required.

2. **Pre-existing stale doc reference (out of scope).** `docs/bci/nfb-calibration.md` line 37 names the handler `_subscribeCalibration`, but the actual method is `_subscribeProviderStreams`. This is a pre-existing inaccuracy unrelated to this plan. Since Task 2 already edits this file, the implementer *could* opportunistically fix it, but it is not required by the milestone and the plan correctly does not claim to.

3. **Behavioral note worth confirming with intent (informational).** Auto-reconnect (`_attemptReconnect` → `connectDevice`) will now also always land on `impedance` and require fresh manual calibration after a transient BLE drop, not just first connects. This is the literal meaning of "every connect" and matches the stated context, so it is correct — flagging only so it is a conscious decision rather than a surprise.

## Conclusion

The plan is accurate, well-scoped, and correctly preserves the calibration recording / state-machine paths. File paths, line ranges, the quoted doc sentence, and the API surface (`latestValid`, `importCalibration`, `record`, `refreshFromServer`) all match the current code. Single-commit strategy is appropriate for one logical change. No missing steps, no wrong assumptions, no migrations needed, no security surface.

PLAN_REVIEW_PASS
