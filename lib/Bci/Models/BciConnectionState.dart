/// The app's BCI connection state-machine enum.
///
/// This is distinct from `neiry_kit`'s lower-level `NeiryConnectionState`,
/// which only models BLE link-layer state. [BciConnectionState] captures
/// higher-level app states including impedance checking and calibration
/// phases that have no direct counterpart in the plugin.
enum BciConnectionState {
  disconnected,
  scanning,
  connecting,
  impedance,
  calibrating,
  ready,
  bluetoothPermissionDenied,
}
