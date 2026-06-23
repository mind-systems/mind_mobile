/// The app's BCI connection state-machine as a sealed class hierarchy.
///
/// This is distinct from `neiry_kit`'s lower-level `NeiryConnectionState`
/// (which only models BLE link-layer state) and from [BciLinkStatus]
/// (the provider-layer translation of that link-layer signal).
/// [BciConnectionState] captures higher-level app phases, and device-bound
/// branches carry the connected device [BciActive.serial] so illegal states
/// such as "connecting without a serial" are unrepresentable.
sealed class BciConnectionState {
  const BciConnectionState();
}

/// No device connection is active or in progress.
///
/// Replaces the former `disconnected` enum value.
class BciIdle extends BciConnectionState {
  const BciIdle();
}

/// A BLE scan for nearby devices is running.
class BciScanning extends BciConnectionState {
  const BciScanning();
}

/// Bluetooth permissions were permanently denied by the user.
///
/// Replaces the former `bluetoothPermissionDenied` enum value.
class BciPermissionDenied extends BciConnectionState {
  const BciPermissionDenied();
}

/// Base for all device-bound phases — carries the [serial] of the target device.
///
/// Using a sealed ancestor for the device-bound phases ensures that every
/// branch that needs the serial has it; "connecting without a serial" is
/// unrepresentable.
sealed class BciActive extends BciConnectionState {
  final String serial;
  const BciActive(this.serial);
}

/// The app is establishing the BLE + SDK connection to [serial].
class BciConnecting extends BciActive {
  const BciConnecting(super.serial);
}

/// The device is connected and showing impedance / signal-quality data.
class BciImpedance extends BciActive {
  const BciImpedance(super.serial);
}

/// A calibration sequence is running on [serial].
///
/// [totalStages] indicates the scope of the run: 4 for the initial full
/// calibration flow, 1 for a quick single-stage retry.
class BciCalibrating extends BciActive {
  final int totalStages;
  const BciCalibrating(super.serial, {required this.totalStages});
}

/// The device is fully connected and ready for a session.
class BciReady extends BciActive {
  const BciReady(super.serial);
}
