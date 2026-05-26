# NFB Calibration History — Technical Brief

**Date:** 2026-05-26
**Status:** decisions locked
**Scope:** persist and sync a per-user, per-device history of NFB calibration results — `IndividualNfbData` produced by `NfbCalibrator.calibrateIndividual()` — to both local storage and a new server-side table. Enables calibration restore without re-calibrating and long-term tracking of how individual alpha parameters drift over time.

---

## Context

The entire calibration system is currently stateless. `NeiryBciProvider.startCalibration()` streams `BciCalibrationCompleted()` with no payload; the `IndividualNfbData` produced by the Neiry SDK lives only inside the native plugin until it is garbage-collected. The existing roadmap task "Persist and restore `IndividualNfbData` after NFB calibration" planned single-slot SharedPreferences storage — one record per device, overwritten on each calibration.

The user's requirement is different: keep every record, link it to the authenticated user on the server, and expose the history for future analytics.

---

## What `IndividualNfbData` contains

All fields are `double` except where noted.

| Field | Unit | Meaning |
|---|---|---|
| `timestamp: DateTime?` | — | When calibration was performed; `null` if SDK returned -1 |
| `failReason: NfbCalibrationFailReason` | enum | `none` = success, `tooManyArtifacts`, `peakFrequencyAtBorder` |
| `individualFrequency` | Hz | Detected individual alpha peak frequency |
| `individualPeakFrequency` | Hz | Legacy alias for `individualFrequency` (same value) |
| `individualPeakFrequencyPower` | uV²/Hz | Spectral power at the alpha peak |
| `individualPeakFrequencySuppression` | dimensionless | Closed-eyes / open-eyes alpha power ratio |
| `individualBandwidth` | Hz | Width of the individual alpha band |
| `individualNormalizedPower` | 0–1 | Normalized alpha power in the individual band |
| `lowerFrequency` | Hz | Lower bound of the individual alpha band |
| `upperFrequency` | Hz | Upper bound of the individual alpha band |

`IndividualNfbData.isValid` is `failReason == NfbCalibrationFailReason.none`. Only valid records are used to restore the native classifier; invalid ones are still stored for diagnostics and to understand how often calibration fails.

---

## Data model: `NfbCalibrationData` (domain)

New file `lib/Bci/Models/NfbCalibrationData.dart`. Pure Dart — no neiry_kit import.

```dart
@immutable
class NfbCalibrationData {
  final DateTime calibratedAt;
  final bool isValid;
  final String failReason; // "none" | "tooManyArtifacts" | "peakFrequencyAtBorder"
  final double individualFrequency;
  final double individualPeakFrequencyPower;
  final double individualPeakFrequencySuppression;
  final double individualBandwidth;
  final double individualNormalizedPower;
  final double lowerFrequency;
  final double upperFrequency;

  const NfbCalibrationData({required ...});

  Map<String, dynamic> toJson();
  factory NfbCalibrationData.fromJson(Map<String, dynamic> json);
}
```

`individualPeakFrequency` (legacy alias) is **not** stored — consumers use `individualFrequency`. `toJson` / `fromJson` are used by the repository for both SharedPreferences serialization and proto field mapping.

---

## Mapping `IndividualNfbData` → `NfbCalibrationData`

Done inside `NeiryBciProvider` — the only file that imports neiry_kit. On `CalibrationCompleted(data)`:

```dart
NfbCalibrationData(
  calibratedAt: data.timestamp ?? DateTime.now(),
  isValid: data.isValid,
  failReason: data.failReason.name, // enum.name gives "none" / "tooManyArtifacts" / ...
  individualFrequency: data.individualFrequency,
  individualPeakFrequencyPower: data.individualPeakFrequencyPower,
  individualPeakFrequencySuppression: data.individualPeakFrequencySuppression,
  individualBandwidth: data.individualBandwidth,
  individualNormalizedPower: data.individualNormalizedPower,
  lowerFrequency: data.lowerFrequency,
  upperFrequency: data.upperFrequency,
)
```

The reverse mapping (for `NfbCalibrator.importCalibrationData`) must also live inside `NeiryBciProvider` — no other layer may create an `IndividualNfbData` instance.

---

## Event propagation change

`BciCalibrationCompleted` currently carries no payload (by design — to prevent neiry_kit types leaking into domain models). That design decision was correct; now we add the domain-level payload:

```dart
// before
final class BciCalibrationCompleted extends BciCalibrationEvent {}

// after
final class BciCalibrationCompleted extends BciCalibrationEvent {
  final NfbCalibrationData data;
  const BciCalibrationCompleted(this.data);
}
```

Chain of changes: `NeiryBciProvider` (emit with data) → `BciDeviceManager._subscribeCalibration` (receive data, save to repository) → `BciNotifier` (forward inside `BciCalibrationEventReceived` unchanged — it already wraps the event).

---

## Repository: `NfbCalibrationRepository`

New file `lib/Bci/NfbCalibrationRepository.dart`.

### Local storage

SharedPreferences key: `'bci_nfb_cal_history_<serial>'`  
Value: JSON array of `NfbCalibrationData.toJson()`, newest first.  
Max 20 entries per device — on `record()`, prepend and truncate to 20.

Methods:
- `void record(String serial, NfbCalibrationData data)` — prepend to local cache, persist, then fire-and-forget `api.record(serial, data)` (log error, never rethrow)
- `NfbCalibrationData? latestValid(String serial)` — synchronous read from cache; returns first entry where `isValid == true`, or null
- `List<NfbCalibrationData> history(String serial)` — full cached list (newest first)

### Remote sync

`NfbCalibrationGrpcApi` (separate file, same pattern as `BciDevicesGrpcApi`) is injected into the repository. The `record()` method fire-and-forgets the gRPC call after persisting locally — local write is the primary contract; server sync is best-effort.

Constructor: `NfbCalibrationRepository({required NfbCalibrationGrpcApi api, required SharedPreferences prefs})`

---

## Restore flow on connect

In `BciDeviceManager.connectDevice(serial)`, before `await _provider.connect(serial)`:

```dart
final latestCalibration = _nfbCalibrationRepository.latestValid(serial);
if (latestCalibration != null) {
  await _provider.importCalibration(latestCalibration);
}
```

`IBciDeviceProvider` gains `Future<void> importCalibration(NfbCalibrationData data)`.  
`NeiryBciProvider` implements it by mapping `NfbCalibrationData` → `IndividualNfbData` (reverse of the calibration mapping) and calling `NfbCalibrator.importCalibrationData(neiryData)`.

---

## Proto: `nfb_calibration.proto`

Authored in `mind_api/proto/` (single source of truth), then copied to `mind_mobile/proto/`.

```proto
syntax = "proto3";
package mind;

service NfbCalibrationService {
  rpc Record(RecordNfbCalibrationRequest) returns (NfbCalibrationRecord);
  rpc List(ListNfbCalibrationsRequest)   returns (ListNfbCalibrationsResponse);
}

message NfbCalibrationRecord {
  string id                                 = 1;
  string device_serial                      = 2;
  string calibrated_at                      = 3;  // ISO-8601
  bool   is_valid                           = 4;
  string fail_reason                        = 5;  // "none" | "tooManyArtifacts" | "peakFrequencyAtBorder"
  float  individual_frequency               = 6;
  float  individual_peak_frequency_power    = 7;
  float  individual_peak_frequency_suppression = 8;
  float  individual_bandwidth               = 9;
  float  individual_normalized_power        = 10;
  float  lower_frequency                    = 11;
  float  upper_frequency                    = 12;
  string created_at                         = 13; // ISO-8601, server-assigned
}

message RecordNfbCalibrationRequest {
  string device_serial                      = 1;
  string calibrated_at                      = 2;
  bool   is_valid                           = 3;
  string fail_reason                        = 4;
  float  individual_frequency               = 5;
  float  individual_peak_frequency_power    = 6;
  float  individual_peak_frequency_suppression = 7;
  float  individual_bandwidth               = 8;
  float  individual_normalized_power        = 9;
  float  lower_frequency                    = 10;
  float  upper_frequency                    = 11;
}

message ListNfbCalibrationsRequest {
  string device_serial = 1;
  int32  limit         = 2; // 0 = server default (50)
}

message ListNfbCalibrationsResponse {
  repeated NfbCalibrationRecord records = 1;
}
```

No `user_id` in request messages — identity comes from the JWT auth interceptor (same pattern as `BciDevicesService`).

---

## API: table `nfb_calibration_records`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK DEFAULT uuid_generate_v4()` | |
| `user_id` | `uuid NOT NULL → users(id) ON DELETE CASCADE` | |
| `device_serial` | `varchar NOT NULL` | |
| `calibrated_at` | `timestamptz NOT NULL` | from client |
| `is_valid` | `boolean NOT NULL` | |
| `fail_reason` | `varchar NOT NULL` | |
| `individual_frequency` | `float NOT NULL` | |
| `individual_peak_frequency_power` | `float NOT NULL` | |
| `individual_peak_frequency_suppression` | `float NOT NULL` | |
| `individual_bandwidth` | `float NOT NULL` | |
| `individual_normalized_power` | `float NOT NULL` | |
| `lower_frequency` | `float NOT NULL` | |
| `upper_frequency` | `float NOT NULL` | |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | server-assigned |

Index `IDX_nfb_calibration_records_user_device` on `(user_id, device_serial)` to back the `List` query.  
No unique constraint — each calibration is a distinct historical record.  
`List` returns ordered by `created_at DESC`.

---

## Dependency order

```
API task 1  (proto authored)
    ↓
API tasks 2–6  (migration, entity, service, controller, register)
Mobile task 4  (copy proto + regen stubs)  ← can't start before API task 1
Mobile task 5  (NfbCalibrationGrpcApi)     ← depends on task 4
Mobile tasks 1–3 and 6 are independent of the proto and can proceed in parallel.
```
