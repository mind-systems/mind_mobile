import 'package:flutter/foundation.dart';

/// Domain projection of a discovered BCI device.
///
/// This is the app's view of a device — it deliberately omits plugin-level
/// fields (e.g. `type` from `neiry_kit`'s `DeviceInfo`) so that the domain
/// layer remains decoupled from the plugin.
@immutable
class BciDeviceInfo {
  final String serial;
  final String name;

  const BciDeviceInfo({
    required this.serial,
    required this.name,
  });
}
