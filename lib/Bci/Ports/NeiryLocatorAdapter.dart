import 'package:neiry_kit/neiry_kit.dart' as neiry;

import '../Models/BciDeviceInfo.dart';
import 'DevicePort.dart';
import 'LocatorPort.dart';
import 'NeiryDeviceAdapter.dart';

/// Thin adapter that wraps [neiry.DeviceLocator] and implements [LocatorPort].
///
/// This is the only new file permitted to import `neiry_kit` alongside
/// [NeiryDeviceAdapter], consistent with the existing rule on [NeiryBciProvider].
///
/// The [BciDeviceInfo] mapping that previously lived inline in
/// [NeiryBciProvider.scan] is relocated here so the port never exposes
/// neiry-specific types.
class NeiryLocatorAdapter implements LocatorPort {
  final neiry.DeviceLocator _locator = neiry.DeviceLocator();

  @override
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  }) {
    return _locator
        .requestDevices(
          type: _mapDeviceType(type),
          searchTime: searchTime,
        )
        .map((list) =>
            list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name)).toList());
  }

  @override
  Future<DevicePort> createDevice(String serial) async {
    final device = await _locator.createDevice(serial);
    return NeiryDeviceAdapter(device);
  }

  @override
  Future<void> dispose() => _locator.dispose();

  // ── Private helpers ────────────────────────────────────────────────────────

  static neiry.NeiryDeviceType _mapDeviceType(BciScanDeviceType type) {
    switch (type) {
      case BciScanDeviceType.headband:
        return neiry.NeiryDeviceType.headband;
    }
  }
}
