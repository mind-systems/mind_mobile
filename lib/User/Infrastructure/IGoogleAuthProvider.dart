abstract class IGoogleAuthProvider {
  /// Shows the native Google account picker and returns a server auth code
  /// in a single OAuth flow. Throws [GoogleSignInCanceledException] if the
  /// user dismisses the dialog.
  Future<String> getServerAuthCode();

  Future<void> signOut();
}
