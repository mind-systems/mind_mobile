import 'package:mind/Bci/Models/BciCalibrationEvent.dart';
import 'package:mind/Bci/Models/BciChannelQuality.dart';
import 'package:mind/Bci/Models/BciConnectionState.dart';
import 'package:mind/Bci/Models/BciDeviceInfo.dart';

/// Base sealed class for all events emitted by [BciNotifier].
///
/// Each variant maps to a single underlying stream from [BciDeviceManager].
/// Consumers switch exhaustively on this type to react to device lifecycle
/// changes without holding a reference to any lower-level manager or provider.
sealed class BciNotifierEvent {
  const BciNotifierEvent();
}

/// Emitted on every connection-state transition.
final class BciStateChanged extends BciNotifierEvent {
  final BciConnectionState state;
  const BciStateChanged(this.state);
}

/// Emitted on every scan snapshot with the current list of discovered devices.
final class BciDevicesDiscovered extends BciNotifierEvent {
  final List<BciDeviceInfo> devices;
  const BciDevicesDiscovered(this.devices);
}

/// Emitted when a new signal-quality reading arrives for all EEG channels.
final class BciSignalQualityUpdated extends BciNotifierEvent {
  final List<BciChannelQuality> channels;
  const BciSignalQualityUpdated(this.channels);
}

/// Wraps a calibration lifecycle event from the device provider.
final class BciCalibrationEventReceived extends BciNotifierEvent {
  final BciCalibrationEvent event;
  const BciCalibrationEventReceived(this.event);
}

/// Emitted when the device reports a battery level update.
///
/// [percent] is in the range 0–100.
final class BciBatteryUpdated extends BciNotifierEvent {
  final int percent;
  const BciBatteryUpdated(this.percent);
}

/// Emitted when any underlying provider stream surfaces an error.
///
/// [message] is derived from the thrown object's [toString].
final class BciError extends BciNotifierEvent {
  final String message;
  const BciError(this.message);
}
