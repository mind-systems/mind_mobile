import 'dart:math' show min;

import 'package:neiry_kit/neiry_kit.dart' as neiry;

import 'package:mind/Logger.dart';

import '../Models/BciChannelQuality.dart';
import '../Models/BciLinkStatus.dart';
import 'DevicePort.dart';

/// Thin adapter that wraps [neiry.Device] and implements [DevicePort].
///
/// This is the only place where neiry device types are converted to domain
/// types for the three streams the provider subscribes to:
///   - [connectionStateStream] maps [neiry.NeiryConnectionState] → [BciLinkStatus]
///   - [resistanceStream] maps [neiry.ResistanceData] → [List<BciChannelQuality>]
///   - [batteryStream] passes through [int] unchanged
///
/// All five lifecycle methods delegate directly to [neiry.Device].
class NeiryDeviceAdapter implements DevicePort {
  NeiryDeviceAdapter(this._device);

  final neiry.Device _device;

  /// Exposes the underlying [neiry.Device] for classifier construction.
  ///
  /// Consumed by [NeiryClassifierFactory] to build the four hardware
  /// classifiers without exposing the vendor type to the rest of the app.
  neiry.Device get rawDevice => _device;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> connect() => _device.connect();

  @override
  Future<void> start() => _device.start();

  @override
  Future<void> stopStream() => _device.stopStream();

  @override
  Future<void> disconnect() => _device.disconnect();

  @override
  Future<void> dispose() => _device.dispose();

  @override
  bool get isStarted => _device.isStarted;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Maps [neiry.NeiryConnectionState] to [BciLinkStatus].
  ///
  /// Both [neiry.NeiryConnectionState.disconnected] and
  /// [neiry.NeiryConnectionState.unsupportedConnection] map to
  /// [BciLinkStatus.down]. The idempotency guard (`if (_device == null) return`)
  /// lives in the provider's [_onConnectionStatus], so no logging is done here
  /// — logging inside the adapter would fire unconditionally, even during the
  /// brief noise window that follows our own `disconnect()`.
  @override
  late final Stream<BciLinkStatus> connectionStateStream =
      _device.connectionStateStream.map((s) {
    switch (s) {
      case neiry.NeiryConnectionState.connected:
        return BciLinkStatus.up;
      case neiry.NeiryConnectionState.disconnected:
        return BciLinkStatus.down;
      case neiry.NeiryConnectionState.unsupportedConnection:
        return BciLinkStatus.down;
    }
  });

  /// Maps [neiry.ResistanceData] to a list of [BciChannelQuality] entries.
  @override
  late final Stream<List<BciChannelQuality>> resistanceStream =
      _device.resistanceStream.map(_mapResistance);

  @override
  Stream<int> get batteryStream => _device.batteryStream;

  // ── Private helpers ────────────────────────────────────────────────────────

  List<BciChannelQuality> _mapResistance(neiry.ResistanceData r) {
    if (r.channelNames.length != r.values.length ||
        r.channelNames.length != r.channelCount) {
      logPrint(
        'NeiryDeviceAdapter: channel count mismatch: '
        'names=${r.channelNames.length}, values=${r.values.length}, '
        'channelCount=${r.channelCount}',
      );
    }
    final count =
        min(min(r.channelNames.length, r.values.length), r.channelCount);
    final qualities = <BciChannelQuality>[];
    for (var i = 0; i < count; i++) {
      final name = r.channelNames[i];
      final value = r.values[i];
      final BciSignalLevel level;
      if (!value.isFinite || value > 1000) {
        level = BciSignalLevel.red;
      } else if (value > 500) {
        level = BciSignalLevel.yellow;
      } else {
        level = BciSignalLevel.green;
      }
      qualities.add(BciChannelQuality(
        channelName: name,
        impedanceOhm: value,
        level: level,
      ));
    }
    return qualities;
  }
}
