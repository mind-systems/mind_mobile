import 'BciPairingStage.dart';
import 'BciScannedDeviceDTO.dart';
import 'BciChannelQualityDTO.dart';
import 'BciCalibrationProgressDTO.dart';

const Object _undefined = Object();

class BciPairingState {
  final BciPairingStage stage;
  final List<BciScannedDeviceDTO> devices;
  final bool isScanning;
  final bool isConnecting;
  final bool isBluetoothPermissionDenied;
  final List<BciChannelQualityDTO> channels;

  /// `null` means no active calibration data (e.g. before calibration has
  /// started, or after a failure has cleared it) — not "calibration is in
  /// stage 0".
  final BciCalibrationProgressDTO? calibration;

  final int? batteryPercent;
  final String? errorMessage;

  const BciPairingState({
    required this.stage,
    required this.devices,
    required this.isScanning,
    required this.isConnecting,
    required this.isBluetoothPermissionDenied,
    required this.channels,
    this.calibration,
    this.batteryPercent,
    this.errorMessage,
  });

  static BciPairingState initial() => const BciPairingState(
        stage: BciPairingStage.discovery,
        devices: [],
        isScanning: false,
        isConnecting: false,
        isBluetoothPermissionDenied: false,
        channels: [],
      );

  BciPairingState copyWith({
    BciPairingStage? stage,
    List<BciScannedDeviceDTO>? devices,
    bool? isScanning,
    bool? isConnecting,
    bool? isBluetoothPermissionDenied,
    List<BciChannelQualityDTO>? channels,
    Object? calibration = _undefined,
    Object? batteryPercent = _undefined,
    Object? errorMessage = _undefined,
  }) {
    return BciPairingState(
      stage: stage ?? this.stage,
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      isBluetoothPermissionDenied:
          isBluetoothPermissionDenied ?? this.isBluetoothPermissionDenied,
      channels: channels ?? this.channels,
      calibration: identical(calibration, _undefined)
          ? this.calibration
          : calibration as BciCalibrationProgressDTO?,
      batteryPercent: identical(batteryPercent, _undefined)
          ? this.batteryPercent
          : batteryPercent as int?,
      errorMessage: identical(errorMessage, _undefined)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
