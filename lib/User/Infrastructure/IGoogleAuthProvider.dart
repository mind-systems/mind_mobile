abstract class IGoogleAuthProvider {
  /// Returns a record with the server auth code and an optional redirect URI.
  /// redirectUri is non-null only when the browser fallback was used — pass it
  /// to the backend so it can complete the code exchange.
  /// Throws [GoogleSignInCanceledException] if the user cancels.
  Future<({String code, String? redirectUri})> getServerAuthCode();

  Future<void> signOut();
}
