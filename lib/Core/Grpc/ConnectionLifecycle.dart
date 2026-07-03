/// The explicit lifecycle of `ModuleStateChannel`'s session stream connection.
///
/// Replaces the previously implicit combination of `isConnected` +
/// `_backoffConfirmed` with a single state machine, routed through one
/// `_transition` chokepoint in `ModuleStateChannel`.
enum ConnectionLifecycle {
  /// No session stream is open. Entered on init, on logout/`GuestState`
  /// reset, and (transitionally, before the reconnect impl wires
  /// `SUPERSEDED → yielded`) whenever the channel is not actively trying to
  /// connect or reconnect.
  disconnected,

  /// The session stream sink/subscription has just been opened and is
  /// waiting for its first frame from the server. `isConnected` is true in
  /// this state.
  opening,

  /// The first frame has been received on the current stream open —
  /// `_connectionManager.confirmConnected()` has fired exactly once for this
  /// stream. `isConnected` is true in this state.
  active,

  /// The stream closed (transport error, `onDone`, or an explicit
  /// `disconnected` signal from `GrpcConnectionManager`) and a reconnect has
  /// been scheduled. `isConnected` is false in this state.
  reconnecting,

  /// Defined but dormant in this milestone — no transition reaches `yielded`
  /// yet. It is reserved for the later reconnect implementation, which will
  /// wire `SUPERSEDED → yielded` and gate `_openSessionStream` on it.
  yielded,
}
