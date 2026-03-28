# Patch: 42-create-moduleinstructionstream-instruction-samples-over-telemetry-proto

## Issue 1: Redundant import triggers `unnecessary_import` lint warning

**File:** `lib/Core/Grpc/ModuleInstructionStream.dart` (line 11)

**Problem:** Line 11 imports `telemetry.pb.dart` explicitly, but line 12 already imports `telemetry.pbgrpc.dart` which re-exports all symbols from `telemetry.pb.dart`. `flutter analyze` flags this as `unnecessary_import`. Every symbol used in the file (`TelemetryData`, `TelemetryResponse`, `TelemetryResponse_Event`, `TelemetryAck`) is available through the `.pbgrpc.dart` import alone.

**Current code:**
```dart
import 'package:mind/Core/Grpc/generated/telemetry.pb.dart';
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';
```

**Fixed code:**
```dart
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';
```

**Why:** Remove the redundant line to keep `flutter analyze` clean (zero warnings). The `.pbgrpc.dart` file contains `export 'telemetry.pb.dart'`, so all proto message types remain accessible.
