# Patch: 05-run-codegen-patch-1

**Review:** `05-run-codegen-review-1.md`
**Issues:** 1

---

## Issue 1: Missing direct `fixnum` dependency

**Severity:** Low (info-level analyzer lint, no runtime impact)

**Problem:** Three generated files import `package:fixnum/fixnum.dart` for `int64` proto fields, but `fixnum` is not listed as a direct dependency in `pubspec.yaml`. The Dart analyzer flags this as:

```
info • The imported package 'fixnum' isn't a dependency of the importing package
```

**Affected files:**
- `lib/Core/Grpc/generated/live.pb.dart:15` — `int64` field `SessionErrorEvent.timestamp`
- `lib/Core/Grpc/generated/sync.pb.dart:15` — `int64` fields `SyncEventDto.id`, `SyncChangesPayload.cursor`, `GetChangesRequest.after`, `WatchChangesRequest.after_id`
- `lib/Core/Grpc/generated/telemetry.pb.dart:15` — `int64` fields `TelemetryData.timestamp`, `TelemetryAck.received_count`, `TelemetryAck.dropped_count`, `TelemetryAck.timestamp`

**Why it matters:** `fixnum` is currently resolved as a transitive dependency via `protobuf`, so compilation succeeds. However, transitive dependencies can disappear or change versions when intermediate packages update. Making it a direct dependency pins intent and silences the analyzer.

**Fix:**

```bash
flutter pub add fixnum
```

This adds `fixnum` to the `dependencies` section of `pubspec.yaml`. No code changes required — the generated imports already use the correct package path.

**Verification:**

```bash
flutter analyze lib/Core/Grpc/generated/
```

Expected: zero info/warning/error diagnostics for the generated directory.
