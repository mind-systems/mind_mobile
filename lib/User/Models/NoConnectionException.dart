/// Thrown when a Google Sign-In attempt fails due to no network connectivity.
///
/// This is the anti-corruption boundary between GMS infrastructure errors and
/// the domain layer. `GoogleAuthProvider` maps GMS network-failure codes onto
/// this type so that upper layers never need to inspect raw `GoogleSignInException`
/// details or platform-specific error strings.
///
/// Upper layers should show a "no internet connection" message and not retry
/// automatically.
class NoConnectionException implements Exception {
  @override
  String toString() => 'NoConnectionException: no network connectivity for Google Sign-In';
}
