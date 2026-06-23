import '../Models/BciDeviceInfo.dart';
import 'DevicePort.dart';

/// Port-level device-type enum so [LocatorPort.requestDevices] carries a
/// type parameter without leaking [neiry.NeiryDeviceType] across the seam.
enum BciScanDeviceType { headband }

/// Narrow port over the locator surface that [NeiryBciProvider] actually calls.
///
/// Declares exactly the three call sites:
///   - [requestDevices] (`:142` in NeiryBciProvider)
///   - [createDevice] (`:158`)
///   - [dispose] (`:463`, `:675`)
///
/// A fake that implements only these three methods is sufficient to drive
/// [NeiryBciProvider] entirely from a test without touching the real SDK.
///
/// Concrete implementation: [NeiryLocatorAdapter].
abstract interface class LocatorPort {
  /// Scans for BCI devices and emits the already-mapped [BciDeviceInfo] list.
  ///
  /// The mapping from vendor device-info types is done inside the adapter, so
  /// this port never exposes neiry-specific types.
  Stream<List<BciDeviceInfo>> requestDevices({
    BciScanDeviceType type = BciScanDeviceType.headband,
    int searchTime = 5,
  });

  /// Creates a device handle for [serial] and returns it as a [DevicePort].
  Future<DevicePort> createDevice(String serial);

  /// Releases the underlying locator resource.
  Future<void> dispose();
}
