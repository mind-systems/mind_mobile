# Handoff — Tear down all BCI objects on an unexpected device power-off

## 1. Frame
We are hardening the BCI device lifecycle in `NeiryBciProvider` against an **unexpected hardware disconnect** (user powers the headset off mid-session), and folding in a **new `neiry_kit` native fix** that supersedes one claim in the prior handoff (`06-bci-device-session-reset-on-reconnect.md`). The chat is compacted; the knowledge is durable in the files referenced here — rehydrate from them, don't trust memory.

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `.ai-factory/handoffs/06-bci-device-session-reset-on-reconnect.md` — the prior handoff (reconnect→recalibration 255, locator caching). Still valid EXCEPT its line "No kit library change is needed" is now **superseded** — see §3 and §6.
- `lib/Bci/NeiryBciProvider.dart` — the device-lifecycle owner. Key spots: `final _locator` (~L35, still not recreated), `connect()` (~L147, guards `if (_device != null) throw`), `_subscribeDeviceStreams()` (~L189), `_onNeiryConnectionState()` (~L246, routes `disconnected` → teardown), `_teardownAfterUnexpectedDrop()` (~L429), `disconnect()` (~L563), `_doDispose()` (~L603).
- `.ai-factory/ROADMAP.md` → **Phase 52 — BCI device-session reset on reconnect** (tasks 145/146/147, all `[ ]`).

### Read on demand
- `neiry_kit/android/src/main/cpp/jni_nfb_calibrator.cpp` — new `invalidate_calibrator()` (nulls the file-static `g_calibrator`).
- `neiry_kit/android/src/main/cpp/jni_device.cpp` — `nativeReleaseDevice` now calls `invalidate_calibrator()` before `clCDevice_Release`.
- `neiry_kit/.ai-factory/ROADMAP.md` → `[x]` "Clear the cached calibrator pointer on device release …" (the kit-side fix, committed `836699b`).
- `neiry_kit/.ai-factory/notes/35-…` and `36-…` — kit-side specs: (35) guard connect() against a stale device; (36) auto-teardown on unexpected disconnect + the pivotal "does the SDK emit a disconnect event?" question.

## 3. Current state

**Done (kit side, committed `836699b`):**
- Root-caused and fixed the **recalibration-after-reconnect SIGABRT** entirely inside `neiry_kit` (native). It was NOT the locator caching — it was a dangling file-static `g_calibrator`. On reconnect, `calibrateIndividual()` calls `nativeStopCalibration` first, which ran `clCNFBCalibrator_SetOnCalibrationStageFinishedEvent` on the **stale calibrator from the destroyed session** → scheduled work on a dead `async_scope` → `try_record_start()` → recursive `abort`. Fix: `invalidate_calibrator()` nulls `g_calibrator` on `nativeReleaseDevice`, so a post-reconnect stop no-ops. Verified on SM A705FN: no more SIGABRT across reconnect+recalibrate.
- **Implication for mobile:** handoff 06's "no kit *library* change is needed" is **superseded** — a kit library change WAS required and is now in. Mobile must **bump `neiry_kit` to include `836699b`**; the Phase 52 locator-recreate (task 145) alone would NOT have prevented this SIGABRT.

**Established this session (the new crash, reproduced in the kit example — kit logs log01/02/03):**
- Powering the headset off mid-session emits Android `BluetoothGatt onClientConnectionState status=8` (GATT_CONN_TIMEOUT). In the **kit example**, nothing tore the session down on this drop, so the next Connect re-created classifiers over the live session and the SDK rejected every module: `Failed to create nfb/emotions/productivity/cardio/mems module: clC… module already exists` → `0xebadde09` (stale JNI ref) → **`Fatal signal 64`** on a background SDK thread. The Device screen stayed "connected".

**Mobile's current protection (better than the kit example — verified by reading the code):**
- `connect()` guards `if (_device != null) throw StateError` (~L148) → it will NOT double-register modules; it throws instead.
- `_onNeiryConnectionState()` (~L246) routes `NeiryConnectionState.disconnected`/`unsupportedConnection` → `_teardownAfterUnexpectedDrop()` (~L256/261), which nulls all fields synchronously then asynchronously does `stopStream → cancel all subs → dispose all 4 classifiers → device.disconnect+dispose` in the correct invariant order (note 82/83 already applied).

**Trigger VERIFIED (resolves the prior open question):**
- The Capsule SDK **does** emit `clCDevice` `NeiryConnectionState.disconnected` on a hardware power-off — confirmed on SM A705FN (kit example, temporary log on `Device.connectionStateStream`):
  ```
  Tab → Device                                   (user on Device screen)
  BluetoothGatt onClientConnectionState status=8 (~T+0s — headset powered off, GATT timeout)
  Device.connectionState event: disconnected     (~T+7s — SDK surfaces it)
  ```
- So mobile's `_onNeiryConnectionState` **will** fire on power-off → `_teardownAfterUnexpectedDrop()` **will** run. **No fallback trigger (error-stream etc.) is needed.** This overturns this handoff's original premise.
- **Caveat — ~7 s latency:** the SDK surfaces `disconnected` ~7 seconds after the BLE drop (GATT status=8). During that window `_device` is non-null but the link is dead: the UI still shows "connected" and a reconnect tap hits `connect()`'s `if (_device != null) throw StateError` (so it fails cleanly, no crash, but cannot reconnect until teardown runs). This ~7 s gap is the "stuck at connected" symptom — it self-clears once the event arrives. Consider showing a transient "reconnecting…" affordance, but it is not a crash risk.
- **Why the kit *example* still crashed on reconnect:** its `NeiryService` only *forwards* the `disconnected` event to the UI and does **not** tear down — so `_device`/classifiers/modules leak and the next connect hits `module already exists`. That is a kit-example gap; **mobile already has the teardown** (`_teardownAfterUnexpectedDrop`), so mobile does not share this crash.

**Remaining mobile gaps:**
- `_locator` is still `final` (~L35); Phase 52 task 145 (recreate on disconnect) is not landed.
- `neiry_kit` not yet bumped to `836699b` (calibrator SIGABRT fix).

**Uncommitted working-tree state:** mind_mobile — none (this is a handoff only; no edits made here). neiry_kit — committed (`836699b`); some uncommitted notes/roadmap unrelated to mobile.

## 4. Next step
The power-off teardown trigger is verified (§3) — mobile's `_teardownAfterUnexpectedDrop()` already runs. Two concrete items remain:
1. **Bump `neiry_kit` to include `836699b`** (the `g_calibrator` SIGABRT fix) — required for recalibrate-after-reconnect; independent of the locator work.
2. **Land Phase 52 task 145** — make `_locator` mutable and `await _locator.dispose(); _locator = neiry.DeviceLocator();` at the end of both `disconnect()` and `_teardownAfterUnexpectedDrop()` (guard `_doDispose()` against double-dispose). Needed for a clean reconnect (fresh native session) so a repeat calibration doesn't hit `code 255`.
3. *(Optional UX)* The ~7 s gap between BLE drop and the `disconnected` event leaves the UI showing "connected"; a transient "reconnecting…" state would smooth it. Not a crash risk — `connect()`'s stale-`_device` guard already prevents a crash if the user taps reconnect in that window.

## 5. Working discipline
- Do not auto-commit; confirm / show diff before committing. Stop and ask on ambiguity.
- All generated/edited files in English.
- `neiry_kit/proto` ownership etc. not relevant here; this is consumer-side BCI lifecycle work.

## 6. Error log (what was wrong before — don't repeat)
- **Prior handoff (06) said "No kit *library* change is needed — `DeviceLocator.dispose()` already exposes the capability."** Superseded: the recalibration crash escalated from a catchable `code 255` to an **uncatchable recursive SIGABRT**, whose true cause was a kit-internal dangling `g_calibrator`, fixed only by a kit native change (`836699b`). Locator teardown alone does not address it. Bump the kit.
- **Do not assume "disconnect" or "release the device" tears down the session / frees native modules.** In the kit example a power-off with no teardown left the SDK modules registered; the next connect hit `clC… module already exists` → signal 64. Teardown must actually run on the drop.
- **Initially assumed the SDK might be silent on power-off (only GATT sees it).** Disproven by test (§3): the SDK emits `NeiryConnectionState.disconnected`, just ~7 s after the BLE drop. The "stuck at connected" symptom was that latency window, not a missing event. Don't design a fallback trigger around the silent-SDK theory.

## 7. Orientation (traps)
- **Two distinct crashes, do not conflate.** (a) Recalibration-after-reconnect = recursive `SIGABRT` from a dangling `g_calibrator` — **fixed in kit `836699b`**. (b) Power-off-then-reconnect = `Fatal signal 64` + `0xebadde09` from re-registering modules over a not-torn-down session — **consumer-side teardown/trigger problem** (this handoff).
- **`status=8` is BLE/GATT-layer (Android); the `clCDevice` `disconnected` event is separate and lags it by ~7 s.** Both happen on power-off, but at different layers and different times — the GATT timeout first, the SDK `NeiryConnectionState.disconnected` ~7 s later. Mobile reacts to the latter.
- **Mobile ≠ kit example on the connect guard.** Mobile `connect()` throws on a stale `_device` (safe-ish: no double-register, but no self-heal); the kit example proceeded and crashed. So mobile's failure mode on a silent power-off is "stuck connected + StateError on reconnect", not the signal-64 crash — unless a path nulls `_device` without freeing modules.

## 8. Domain model spine (settled — don't re-litigate)
- **A clean reconnect needs a fresh `DeviceLocator`** (the SDK caches `clCDevice` per serial; `clCDevice_Release` does not evict). Still true; Phase 52 task 145 implements it. Pointer: `neiry_kit/lib/src/api/device_locator.dart`, handoff 06 §8.
- **The NFB calibrator is session-scoped and has no SDK reset; its native pointer must be invalidated on device release** — now handled inside the kit (`invalidate_calibrator()`), so consumers don't touch it. Pointer: `neiry_kit/android/src/main/cpp/jni_nfb_calibrator.cpp`.
- **Teardown ordering invariant** (already applied in mobile, note 82/83): `stopStream()` (= nativeUnregister + nativeStop) FIRST, then cancel subs, then dispose classifiers, then `device.disconnect()` + `dispose()`. Keep it.

## 11. Per-unit map with watch-points
- **`NeiryBciProvider.connect()` (~L147)** — guards `_device != null` by throwing. Watch-point: during the ~7 s gap before the `disconnected` event arrives, a reconnect tap throws `StateError` (clean fail, no crash). Tearing down a stale `_device` here instead of throwing would let reconnect self-heal inside that window — optional polish.
- **`NeiryBciProvider._onNeiryConnectionState()` (~L246)** — the trigger for unexpected-drop teardown. Watch-point: verified to fire `disconnected` on power-off (~7 s after the BLE drop), so `_teardownAfterUnexpectedDrop()` runs; no extra trigger needed.
- **`NeiryBciProvider._teardownAfterUnexpectedDrop()` (~L429)** — correct full teardown, but does NOT recreate `_locator`. Watch-point: add the locator dispose+recreate here AND in `disconnect()` (Phase 52 task 145); guard `_doDispose()` against double-dispose.
- **neiry_kit bump** — pull `836699b`. Watch-point: without it, recalibrate-after-reconnect still SIGABRTs even after task 145 lands.
