import 'dart:async';

import 'Models/BciCalibrationEvent.dart';
import 'Models/BciChannelQuality.dart';
import 'Models/BciConnectionState.dart';
import 'Models/BciDeviceInfo.dart';

/// Domain-side abstraction for any BCI hardware provider.
///
/// Concrete implementations (e.g. a `neiry_kit`-backed adapter) live
/// outside this file and must translate plugin types into the `Bci` domain
/// models declared in `lib/Bci/Models/`. Nothing above this interface
/// should depend on `neiry_kit` or any other hardware-specific package.
///
/// Lifecycle note: after [dispose] is called, all observation streams are
/// closed and any subsequent call on this instance is undefined. Callers
/// must construct a new provider instance to resume operation.
abstract interface class IBciDeviceProvider {
  /// Starts a scan for nearby BCI devices.
  ///
  /// Each call starts a fresh scan session and returns a stream that emits
  /// one or more snapshots of currently-discovered devices. The stream
  /// completes when the scan session finishes (either by timeout or by an
  /// explicit stop from the implementation). Callers must not assume the
  /// stream is long-lived across multiple scan sessions.
  Stream<List<BciDeviceInfo>> scan();

  /// Connects to the device identified by [serial].
  Future<void> connect(String serial);

  /// Disconnects from the currently connected device.
  Future<void> disconnect();

  /// Emits the current connection state whenever it changes.
  Stream<BciConnectionState> get connectionStateStream;

  /// Emits updated per-channel signal quality snapshots.
  Stream<List<BciChannelQuality>> get signalQualityStream;

  /// Emits device battery level as a percentage (0–100).
  Stream<int> get batteryStream;

  /// Emits calibration lifecycle events.
  Stream<BciCalibrationEvent> get calibrationStream;

  /// Requests the device to start its calibration sequence.
  Future<void> startCalibration();

  /// Releases all resources held by this provider.
  ///
  /// After this call, all observation streams are closed and any subsequent
  /// call on this instance is undefined. Callers must construct a new
  /// provider instance to resume operation.
  void dispose();
}
