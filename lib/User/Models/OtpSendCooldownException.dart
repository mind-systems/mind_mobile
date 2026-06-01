/// Thrown by [AuthApi.sendCode] when a new code was requested too soon after
/// the previous one (60-second send cooldown).
///
/// The backend returns gRPC `RESOURCE_EXHAUSTED` on [SendCode] during the
/// cooldown window. Upper layers should prompt the user to wait rather than
/// retrying immediately.
class OtpSendCooldownException implements Exception {
  const OtpSendCooldownException();

  @override
  String toString() => 'OtpSendCooldownException: send-code cooldown active, wait before requesting a new code';
}
