/// Thrown by [AuthApi.verifyCode] when the user has exceeded the maximum number
/// of wrong code attempts and the account is temporarily locked out.
///
/// The backend returns gRPC `RESOURCE_EXHAUSTED` on [VerifyCode] after 5 wrong
/// attempts. Upper layers should show a recovery message and not retry
/// automatically.
class OtpLockedException implements Exception {
  const OtpLockedException();

  @override
  String toString() => 'OtpLockedException: too many wrong OTP attempts, account temporarily locked';
}
