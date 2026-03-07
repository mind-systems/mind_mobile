abstract class IGoogleAuthProvider {
  /// Phase 1: shows the native Google account picker. Throws
  /// [GoogleSignInCanceledException] if the user dismisses the dialog.
  Future<void> pickGoogleAccount();

  /// Phase 2: exchanges the picked account for a server auth code.
  Future<String> getServerAuthCode();

  Future<void> signOut();
}
