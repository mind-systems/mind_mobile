# Plan: T8 · Fix the unsupported-connection comment + restore the diagnostic

## Context
Restore the lost unsupported-vs-normal-disconnect diagnostic by adding a distinct `logPrint` for the `unsupportedConnection` case in `NeiryDeviceAdapter`, then make both the adapter and provider comments agree with the code. Per the ruling: **Option A (recommended)** — restore the log.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Restore diagnostic + align comments

- [x] **Task 1: Restore a distinct log for the unsupported-connection case**
  Files: `lib/Bci/Ports/NeiryDeviceAdapter.dart`
  In the `connectionStateStream` map (`:64-75`), add a `logPrint` only in the `neiry.NeiryConnectionState.unsupportedConnection` branch (`:72-73`) before returning `BciLinkStatus.down`. Use a clear, greppable message tagged with the class name, e.g. `logPrint('NeiryDeviceAdapter: unsupportedConnection → BciLinkStatus.down');`. Do NOT add logging to the `disconnected` branch — that branch must stay silent to avoid firing during the post-`disconnect()` noise window. Mapping behavior is unchanged (`unsupportedConnection` still → `BciLinkStatus.down`). `logPrint` is already imported and used in this file (`:90`), so no new import is needed.

- [x] **Task 2: Correct the adapter doc comment**
  Files: `lib/Bci/Ports/NeiryDeviceAdapter.dart`
  Update the `connectionStateStream` doc comment (`:56-63`) so it agrees with Task 1: state that `disconnected` and `unsupportedConnection` both map to `BciLinkStatus.down`, that the `unsupportedConnection` case is logged (distinct triage), and that the `disconnected` case is intentionally NOT logged here because it would fire unconditionally during the brief noise window after our own `disconnect()`.

- [x] **Task 3: Correct the provider handler comment**
  Files: `lib/Bci/NeiryBciProvider.dart`
  Update the `_onConnectionStatus` doc comment (`:255-259`). It currently claims `NeiryDeviceAdapter` "maps and logs the latter" — after Task 1 this is now true for the unsupported case. Keep the wording accurate: the adapter maps both to `BciLinkStatus.down` and logs the unsupported-connection case before it reaches this handler.
