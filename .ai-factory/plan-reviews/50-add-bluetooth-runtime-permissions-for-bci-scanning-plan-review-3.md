# Plan Review 3: Add Bluetooth runtime permissions for BCI scanning

**Plan:** `.ai-factory/plans/50-add-bluetooth-runtime-permissions-for-bci-scanning.md`
**Spec note:** `.ai-factory/notes/23-bci-bluetooth-permissions.md`
**Prior reviews:** `plan-reviews/50-...-plan-review-1.md`, `plan-reviews/50-...-plan-review-2.md`
**Risk Level:** 🟢 Low

This revision resolves both blockers from review-2 (C1 and M1) and folds every minor remark into the task text. After verifying each claim against the actual codebase, the plan is implementation-ready.

---

## Verification against the codebase

| Plan claim | File / location | Verified |
|---|---|---|
| `BciPairingViewModel` lacks a rescan entry point; `initState()` is guarded against re-subscription | `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart:34-38` (`if (_eventsSubscription != null) return;`) | ✅ Confirmed — Task 10's new `onRescan() => service.startScan()` is necessary and correctly bypasses the subscription guard while still going through the service. |
| `BciPairingState.copyWith` uses `_undefined` sentinel only for nullable fields; non-nullable bools (`isScanning`, `isConnecting`) use plain `bool? ?? this.x` | `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart:42-68` | ✅ Confirmed — Task 8's direction matches the existing convention. |
| `_reduceStateChanged` exists with all six current enum branches; `disconnected` and `scanning` cases are the right place to clear the flag | `lib/BciModule/BciPairingService.dart:86-141` | ✅ Confirmed — exact branches called out, including `disconnected` already clearing `errorMessage: null` and `channels: const <BciChannelQualityDTO>[]`. |
| `BciDeviceManager._attemptReconnect()` lives around lines 175–204 and has its own `onError` that needs identical branching | `lib/Bci/BciDeviceManager.dart:175-204` | ✅ Confirmed — `onError` at line 194 currently calls `_setState(BciConnectionState.disconnected)` and needs the new branch. |
| `_setState` dedup short-circuits when `next == _state`; `startScan()` bypasses dedup by direct field write at lines 100-107 | `lib/Bci/BciDeviceManager.dart:80-84` and `99-107` | ✅ Confirmed — the Task 7 dedup-safety note is accurate. |
| `BciNotifier.stateStream.onError` emits a `BciError` log but the permission exception is converted inside `BciDeviceManager._scanSub.onError`, not via `stateStream.onError` | `lib/Bci/BciNotifier.dart:30-33` | ✅ Confirmed — no stray `BciError` will accompany `bluetoothPermissionDenied`, so the reducer's `errorMessage: null` is sufficient. |
| `BciConnectionState` enum has exactly the six values listed | `lib/Bci/Models/BciConnectionState.dart:7-14` | ✅ Confirmed — appending `bluetoothPermissionDenied` after `ready` is a clean addition. |
| `AndroidManifest.xml` currently has `<application>` first, `<queries>` second, no `<uses-permission>` entries | `android/app/src/main/AndroidManifest.xml` | ✅ Confirmed — Task 2's "first children inside `<manifest>`, immediately after the opening tag" anchor is unambiguous and works for the actual structure. |
| `minSdk = 26` (matters for the SDK<31 branch that requests `locationWhenInUse`) | `android/app/build.gradle.kts:28` | ✅ Confirmed. |
| `device_info_plus: ^12.3.0` already exists in root `pubspec.yaml` | `pubspec.yaml:71` | ✅ Confirmed — Task 6 import of `device_info_plus` needs no new dependency at the root pubspec level. |
| `permission_handler` is **not** in either root or package `pubspec.yaml` | grep across both files | ✅ Confirmed — Task 1's dual-add is necessary. |
| `cancel` l10n key exists | `packages/mind_l10n/lib/l10n/app_en.arb:6` | ✅ Confirmed — Task 12's "reuse the existing `cancel` key" is correct. |
| `BciDiscoverySection` is already a `ConsumerStatefulWidget`, so adding `WidgetsBindingObserver` to its `State` is a clean extension | `packages/bci_module/lib/src/BciPairing/Views/BciDiscoverySection.dart:10-17` | ✅ Confirmed. The existing `ref.listen<BciPairingState>` block at line 24 is the right insertion point for the new edge detection. |
| ROADMAP linkage | `.ai-factory/ROADMAP.md:109` | ✅ Plan target matches the unchecked roadmap entry exactly, and links to `notes/23-bci-bluetooth-permissions.md`. |

No discrepancies found between plan claims and actual code.

---

## Context Gates

- **ARCHITECTURE.md** — Domain/module boundary preserved: permission gating lives in `NeiryBciProvider` (domain), `openAppSettings()` is invoked only from `BciDiscoverySection` (presentation package). The Task 1 architectural note explicitly acknowledges the new `permission_handler` coupling on `bci_module` and the long-term direction (host-injected callback). ✅
- **RULES.md** — Rule 1 (stateless `Service`) preserved: `BciPairingService` gains only reducer branches and a field copy — no new state, no streams, no `dispose()`. Rule 3 (constructor DI) not affected. ✅
- **ROADMAP.md** — Plan is tied to a tracked phase 17 milestone (`.ai-factory/ROADMAP.md:109`). ✅

---

## Critical Issues

None.

---

## Major Issues

None.

---

## Minor Issues / Recommendations

### m1. Resume hook may invoke `onRescan()` on every backgrounding round-trip

The lifecycle hook in Task 11 only fires `onRescan()` when `isBluetoothPermissionDenied == true`. That correctly limits noise: a normal background→resume with no denied permission is a no-op. However, when the user has cancelled the alert (flag remains `true`), every subsequent resume will re-trigger the system permission flow → re-throw → re-show the alert. This is the spec'd behaviour ("show again if still denied") but worth confirming during QA that the alert does not stack if `showDialog` is invoked while a previous instance is still on screen. The edge-only listener (`prev?.isBluetoothPermissionDenied != true && next.isBluetoothPermissionDenied == true`) already guards against state-steady-true re-fires within the same screen session; the resume path also re-asserts `scanning` first via `startScan()`, so it always traces a real edge. No fix required, but flag in QA.

### m2. `bci_module` cancellation key naming convention

Task 12 introduces `bciBluetoothPermissionTitle`, `bciBluetoothPermissionMessage`, `bciOpenSettings`. The first two follow the existing `bciPairing*` / `bci*` prefix convention; `bciOpenSettings` is generic enough that it could be reused outside BCI contexts later. Consider whether to drop the `bci` prefix on `bciOpenSettings` (e.g. `openSettings`) so the key can be reused by a future microphone/notifications permission alert without duplicating. Not a blocker — pure naming hygiene.

### m3. iOS `Permission.bluetooth.status` QA step deserves a one-line failure plan

Task 6 already calls out the QA verification step on a fresh iOS simulator. As a small refinement, the plan could add the failure-handling instruction inline rather than leaving it as a conditional in the QA note ("If `.permanentlyDenied` is returned, fall through on it too..."). Either way the implementer has the information; this is just plan-readability polish.

---

## Positive Notes

- **C1 from review-2 is fully addressed.** Task 10 introduces a public `onRescan()` method placed near other gesture handlers — a clean one-liner that doesn't leak the service through the ViewModel. The lifecycle hook in Task 11 references it correctly.
- **M1 from review-2 is fully addressed.** `mounted` guards added at both the lifecycle hook entry and before invoking the dialog helper. The plan explicitly calls out the disposed-context risk in the wording so the implementer cannot accidentally drop the guard.
- **M2 from review-2 is fully addressed.** QA verification step on fresh iOS simulator is concrete and includes a fallback if `permission_handler` returns `.permanentlyDenied` instead of `.denied` on first launch.
- **m1–m7 from review-2 are folded into the task text:** literal `requestDevices(type: NeiryDeviceType.headband, searchTime: 5)` preservation (Task 6), manifest anchor clarified (Task 2), `_setState` dedup analysis documented inline (Task 7), `BciError` non-pathway noted (Task 7), `copyWith` sentinel anti-pattern called out (Task 8), `NSBluetoothPeripheralUsageDescription` explicitly excluded with rationale (Task 3), `pubspec.lock` wording corrected to "regenerated, commit, do not hand-edit" (Task 1).
- The reducer change in Task 9 clears `isBluetoothPermissionDenied: false` in **both** `scanning` and `disconnected` branches — kills the "flag sticks" failure mode under any state-machine path.
- The `_attemptReconnect()` patch in Task 7 closes the silent-denial gap on the auto-reconnect path. Without it, a user who revokes permission between sessions would see `disconnected` with no alert.
- Commit grouping (`Phase 1 / 2 / 3` → commits 1 / 2 / 3) maps cleanly to deployable increments — each commit leaves the app in a buildable state.
- Phase ordering puts dependencies before consumers (manifest → exception → enum → provider → manager → state/reducer → ViewModel → UI → l10n), so the implementer can checkpoint between tasks without leaving the build in a broken state.

---

## Recommendation

This plan is ready for `/aif-implement`. The minor items above are polish, not blockers.

PLAN_REVIEW_PASS
