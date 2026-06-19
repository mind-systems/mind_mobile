/// BLE link-layer state emitted by [IBciDeviceProvider.connectionStateStream].
///
/// This is a low-level transport signal — it models only whether the underlying
/// BLE connection is physically up or down. It is distinct from the app-domain
/// [BciConnectionState] sealed hierarchy, which owns the higher-level phases
/// (scanning, connecting, impedance, calibrating, ready) and carries the
/// connected device serial.
enum BciLinkStatus { down, up }
