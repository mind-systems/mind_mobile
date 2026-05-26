# Roadmap Review Findings (Phase 20–24)

Review conducted 2025-05-28. Four open questions were raised; this note records the findings and the fixes applied.

---

## 1. Phase 22 M4/M6 — Module boundary violation (FIXED in roadmap)

**Problem:** `BreathSessionViewModel` (in `packages/breath_module`) needed to cast `tickService` to `SwitchableTickService` (in `lib/BreathModule/`) — a package cannot import from `lib/`.

**Fix applied in roadmap:**
- M4 now adds two new methods to `ITickService` atomically with creating `SwitchableTickService`:
  - `Stream<TickSource> get sourceChanges` — `ClockTickService` and `HeartRateTickService` return `const Stream.empty()`; `SwitchableTickService` returns `_sourceChangesController.stream`
  - `bool trySwitchTo(TickSource target)` — non-switchable services return `false`; `SwitchableTickService` contains the real logic
- M6 now uses `tickService.sourceChanges` and `tickService.trySwitchTo()` — no casts needed

---

## 2. Phase 24 Tasks 7/8 — Wrong execution order (FIXED in roadmap)

**Problem:** Old task 7 ("Sync calibration history") called `api.list()` on `NfbCalibrationRepository`, but `api` field was only added in old task 8 ("Add NfbCalibrationGrpcApi"). Code would not compile.

**Fix applied in roadmap:** Tasks 7 and 8 swapped.
- New task 7: Create `NfbCalibrationGrpcApi`, add `api` to repository constructor, wire `record()` — now `api` exists when task 8 runs.
- New task 8: Add `refreshFromServer()` and wire `BciDeviceManager.startScan()` — `api.list()` is now valid.

---

## 3. Phase 24 Task 4 — "persist synchronously" wording (FIXED in roadmap)

**Problem:** Roadmap said `NfbCalibrationRepository.record()` should "persist synchronously", but `SharedPreferences.setString()` returns `Future<bool>`. The codebase has NO fire-and-forget pattern for SP writes — all 5 write sites use `async/await`:
- `SharedPreferencesStorage.setString()` — async, awaited
- `AppSettingsRepository.setTheme/setLanguage` — async, awaited
- `BciDeviceRepository._writeCache()` — async, awaited (closest analogue)

**Fix applied in roadmap:** Task 4 now says `Future<void> record(...)` with `await prefs.setString(...)`, with explicit reference to `BciDeviceRepository._writeCache` as the pattern to follow.

---

## 4. Phase 21 M7 — BioSample data serialization into proto

**Finding:** No gap in the notes — this is already resolved by existing code.

The notes file `28-biometric-stream-pipeline.md` already specifies:
- Proto field type: `google.protobuf.Struct`
- Wire encoding: `..data = _toStruct(sample.data)` inside `BiometricStreamClient.sendBatch()`

A reference implementation already exists in `lib/Core/Grpc/ModuleInstructionStream.dart` (lines 157–176):

```dart
Struct _mapToStruct(Map<String, dynamic> map) {
  return Struct(
    fields: map.entries.map((e) => MapEntry(e.key, _valueFrom(e.value))),
  );
}

Value _valueFrom(dynamic v) {
  if (v == null) return Value(nullValue: NullValue.NULL_VALUE);
  if (v is String) return Value(stringValue: v);
  if (v is int) return Value(numberValue: v.toDouble());
  if (v is double) return Value(numberValue: v);
  if (v is bool) return Value(boolValue: v);
  if (v is Map<String, dynamic>) return Value(structValue: _mapToStruct(v));
  if (v is List) return Value(listValue: ListValue(values: v.map(_valueFrom).toList()));
  throw ArgumentError('Unsupported type for proto Value: ${v.runtimeType}');
}
```

**Action for M7 implementer:** Copy `_mapToStruct`/`_valueFrom` directly from `ModuleInstructionStream.dart` — same import (`google/protobuf/struct.pb.dart`), same logic. No re-invention needed.

---

## 5. Phase 23 M1 — "Docs already updated" vs. doc content

**Finding:** No contradiction. `docs/bci/pairing-screen.md` already describes the target state:
- No explicit close button
- Battery indicator on the left, Disconnect button on the right
- Exit via back swipe / system back

The code (`BciPairingScreen.dart`) still has `IconButton(Icons.close)` — the task is pending implementation. The doc is pro-actively correct; "Docs already updated" in the roadmap is accurate. No roadmap edit needed.

---

## 6. Phase 22 M6 — BreathSessionError rename scope

**Finding:** Exactly one callsite for `BreathSessionError`/`onErrorEvent`. The roadmap claim is accurate.

- `BreathSessionError` defined and used only in `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` (lines 12, 32, 286)
- `onErrorEvent` assigned in exactly one place: `BreathSessionScreen.dart:95` inside `initState()`
- Other `onErrorEvent` usages in the codebase (`BreathSessionListViewModel`, `LoginViewModel`) are for different enum types and are unaffected
