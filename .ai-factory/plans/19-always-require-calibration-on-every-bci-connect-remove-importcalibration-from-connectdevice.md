# Plan: Always require calibration on every BCI connect — remove `importCalibration()` from `connectDevice()`

## Context
On every BCI connection the device must pass through `impedance → calibrating → ready` with a fresh user-initiated calibration; remove the auto-restore path that imported a cached calibration and let the Neiry SDK silently skip to `ready`.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes (doc edits are part of the milestone)

## Tasks

### Phase 1: Code change

- [x] **Task 1: Remove the `importCalibration()` auto-restore block from `connectDevice()`**
  Files: `lib/Bci/BciDeviceManager.dart`
  In `connectDevice(String serial)` (currently lines ~195–226), delete the entire `restored`/`latestValid`/`importCalibration` logic:
  - Remove `var restored = false;`
  - Remove the `final cal = _nfbCalibrationRepository.latestValid(serial);` lookup and the surrounding `if (cal != null) { try { await _provider.importCalibration(cal); restored = true; } catch ... }` block.
  - Change the post-connect transition so it always goes to `impedance`: the guarded block becomes
    ```dart
    // Guard against disconnect() racing with the awaited connect call. If the user
    // disconnected mid-flight, _state moved to disconnected and must not be overridden.
    if (_state == BciConnectionState.connecting) {
      _setState(BciConnectionState.impedance);
    }
    ```
  Leave everything else in `connectDevice()` intact: `_provider.connect(serial)`, `_connectedSerial = serial`, `_repository.registerDevice(serial)`, and the outer `catch` that sets `disconnected`.
  Do NOT touch the `BciCalibrationCompleted` handler in `_subscribeProviderStreams` — `_nfbCalibrationRepository.record()` history recording and the `calibrating → ready` transition stay exactly as-is. Do NOT remove the `NfbCalibrationRepository` field, `refreshFromServer` calls, or any import (`_nfbCalibrationRepository` is still used by `record()` and `refreshFromServer()`).

### Phase 2: Docs

- [x] **Task 2: Update `docs/bci/nfb-calibration.md`** (depends on Task 1)
  Files: `docs/bci/nfb-calibration.md`
  The intro already states calibration is performed manually at each connection — verify it stays accurate. Ensure no section describes auto-restore / `importCalibration` on connect. In the "Локальный кэш" section, the `latestValid(serial)` bullet now describes a capability used only for history/analytics and potential future opt-in flows (it is no longer called on connect) — adjust the wording so it does not imply automatic reuse on connection. Keep the history, local cache, and server-sync descriptions otherwise unchanged.

- [x] **Task 3: Update `docs/bci/device-manager.md`** (depends on Task 1)
  Files: `docs/bci/device-manager.md`
  In the "Калибровка" section, remove the sentence stating calibration results are reused on subsequent connections to avoid recalibrating (currently: "Они сохраняются локально и переиспользуются при следующих подключениях того же устройства, чтобы пользователь не проходил калибровку повторно."). Replace with wording that the results are saved locally for history/analytics, while calibration is always performed manually on each connection. Keep the rest of the section (manual init from `impedance`, stage progress, failure returns to `impedance`, raw data never leaving the adapter) unchanged.

## Notes
Single commit at the end (3 tasks, one logical change). Suggested message: "Always require user-initiated BCI calibration on connect".
