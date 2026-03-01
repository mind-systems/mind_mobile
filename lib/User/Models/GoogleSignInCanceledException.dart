/// Thrown by [UserRepository.loginWithGoogle] when the user dismisses the
/// Google Sign-In sheet without completing authentication.
///
/// This is a deliberate user action, not an error. Upper layers that catch
/// this type should silently reset UI state rather than show an error.
class GoogleSignInCanceledException implements Exception {
  @override
  String toString() => 'GoogleSignInCanceledException: user cancelled Google Sign-In';
}
