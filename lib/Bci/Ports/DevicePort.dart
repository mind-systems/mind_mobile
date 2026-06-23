import '../Models/BciChannelQuality.dart';
import '../Models/BciLinkStatus.dart';

/// Narrow port over the device surface that [NeiryBciProvider] actually calls.
///
/// Declares the minimal contract so [LocatorPort.createDevice] is typeable and
/// a test-controlled fake can implement this interface without depending on the
/// whole `neiry.Device` implicit interface.
///
/// Concrete implementation: [NeiryDeviceAdapter] (A2).
abstract interface class DevicePort {
  Future<void> connect();
  Future<void> start();
  Future<void> stopStream();
  Future<void> disconnect();
  Future<void> dispose();
  bool get isStarted;
  Stream<BciLinkStatus> get connectionStateStream;
  Stream<List<BciChannelQuality>> get resistanceStream;
  Stream<int> get batteryStream;
}
