import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';

class GoogleAuthProvider implements IGoogleAuthProvider {
  final GoogleSignIn _google = GoogleSignIn.instance;

  @override
  Future<String> getServerAuthCode() async {
    try {
      final serverAuth =
          await _google.authorizationClient.authorizeServer(['email']);
      if (serverAuth == null) {
        throw Exception('Google Sign-In did not return a serverAuthCode.');
      }
      return serverAuth.serverAuthCode;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCanceledException();
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _google.signOut();
}
